import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {defaults} from '../functions/_shared/core/policy.mjs';
import {createConfigAdmin} from '../functions/_shared/config-admin.mjs';
import {readAndroidTemplate} from '../functions/_shared/remote-config.mjs';
import {patchScopedTemplate,readPlatformTemplate,materializePlatform} from '../functions/_shared/platform-config.mjs';
import {testDatabase} from './database.mjs';

const local=await testDatabase();after(()=>local.close());
for(const migration of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql'])
 await local.pg.exec(await fs.readFile(new URL(`../migrations/${migration}`,import.meta.url),'utf8'));
const actor='12345678-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1)',[actor]);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
let template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}},unrelated:{defaultValue:{value:'keep'}}}},etag='1',writes=0;
const remote={get:async()=>({template:structuredClone(template),etag,initialized:true,...readAndroidTemplate(template)}),
 publishScoped:async(current,scope,patches)=>{
  assert.equal(current.etag,etag);template=patchScopedTemplate(template,current.snapshot,scope,patches).template;
  etag=String(Number(etag)+1);writes++;return{publishedVersion:etag};
 }};
const admin=createConfigAdmin({db:local.pool,remote});

test('all ten enemy-pace controls survive audited admin publication, RC serialization and both clients',async()=>{
 const wanted={initialSpeed:1,growthMultiplier:71,growthExponent:.21,startSmoothingSec:3.1,initialCompensation:1.1,
  brakeCooldownSec:7,brakeFirstReadySec:5,brakeRewindSec:4,brakeEnabled:false,speedBarEnabled:false};
 const current=await admin(actor,{action:'get',scope:'common'});
 const patches=Object.entries(wanted).map(([key,value])=>({path:`enemyPace.${key}`,value}));
 const request={scope:'common',baseEtag:current.etag,patches};
 const preview=await admin(actor,{action:'preview',...request});
 assert.equal(preview.changes.length,10);assert.equal(writes,0,'preview must not publish');
 await admin(actor,{action:'publish',...request,confirmRevision:preview.snapshot.revision});
 const reloaded=await admin(actor,{action:'get',scope:'common'});
 assert.deepEqual(reloaded.snapshot.config.enemyPace,wanted);
 const serialized=JSON.parse(JSON.stringify(template));
 const legacy=readAndroidTemplate(serialized).snapshot;
 const envelope=readPlatformTemplate(serialized,legacy);
 for(const platform of ['android','telegram'])assert.deepEqual(materializePlatform(envelope,platform).config.enemyPace,wanted);
 assert.deepEqual(legacy.config.enemyPace,wanted);
 assert.equal(template.parameters.unrelated.defaultValue.value,'keep');
 const audit=await local.pg.query("select status,changes from untouch.config_audit where status='published'");
 assert.equal(audit.rows.length,1);assert.equal(audit.rows[0].changes.length,10);
 assert.ok(audit.rows[0].changes.every(change=>change.scope==='common'));

 const combinations=[];
 for(const brakeEnabled of [false,true])for(const speedBarEnabled of [false,true]){
  const now=await admin(actor,{action:'get',scope:'common'});
  const change={scope:'common',baseEtag:now.etag,patches:[{path:'enemyPace.brakeEnabled',value:brakeEnabled},{path:'enemyPace.speedBarEnabled',value:speedBarEnabled}]};
  const p=await admin(actor,{action:'preview',...change});
  if(p.changes.length)await admin(actor,{action:'publish',...change,confirmRevision:p.snapshot.revision});
  const stored=await remote.get(),actual=readPlatformTemplate(stored.template,stored.snapshot);
  for(const platform of ['android','telegram']){
   const pace=materializePlatform(actual,platform).config.enemyPace;
   assert.equal(pace.brakeEnabled,brakeEnabled);assert.equal(pace.speedBarEnabled,speedBarEnabled);
   for(const key of Object.keys(wanted).filter(key=>!['brakeEnabled','speedBarEnabled'].includes(key)))assert.equal(pace[key],wanted[key]);
  }
  combinations.push([brakeEnabled,speedBarEnabled]);
 }
 assert.equal(combinations.length,4);
 const count=writes,currentEtag=etag;
 await assert.rejects(admin(actor,{action:'preview',scope:'common',baseEtag:etag,patches:[{path:'enemyPace.brakeEnabled',value:'false'}]}));
 assert.equal(writes,count);assert.equal(etag,currentEtag);
});
