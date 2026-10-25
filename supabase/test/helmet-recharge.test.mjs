import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {androidRoundProof} from '../functions/_shared/android-replay.mjs';
import {defaults,hash,validatePolicy} from '../functions/_shared/core/policy.mjs';
import {fields,getValue} from '../functions/_shared/config-schema.mjs';
import {createConfigAdmin} from '../functions/_shared/config-admin.mjs';
import {readAndroidTemplate} from '../functions/_shared/remote-config.mjs';
import {patchScopedTemplate,readPlatformTemplate,materializePlatform} from '../functions/_shared/platform-config.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {testDatabase} from './database.mjs';

const fixtures=JSON.parse(await fs.readFile(new URL('./fixtures/android-helmet-v3.json',import.meta.url),'utf8'));
const local=await testDatabase();after(()=>local.close());
for(const migration of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql'])
 await local.pg.exec(await fs.readFile(new URL('../migrations/'+migration,import.meta.url),'utf8'));
const actor='11111111-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1)',[actor]);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);

test('new verifier is reproducible from actual native shield/physics; legacy modules stay frozen',async()=>{
 const manifest=JSON.parse(await fs.readFile(new URL('../functions/_shared/android-helmet-replay.generated.json',import.meta.url),'utf8'));
 for(const [name,expected]of Object.entries(manifest.files)){
  const source=await fs.readFile(new URL('../../'+name,import.meta.url),'utf8');
  assert.equal(crypto.createHash('sha256').update(source.replaceAll('\r\n','\n')).digest('hex'),expected,name);
 }
 for(const [name,fn]of [['android-replay.generated.mjs','untouchReplay'],['telegram-replay.generated.mjs','untouchTelegramReplay']]){
  assert.equal(typeof globalThis[fn],'function');assert.ok((await fs.stat(new URL('../functions/_shared/'+name,import.meta.url))).size>0);
 }
});
test('24 native v3 rounds with 0/.5/30/60 s and repeated shields match server',()=>{
 assert.equal(fixtures.length,24);
 for(const f of fixtures){
  const round={proofVersion:3,policy:{config:f.config},requestId:f.requestId,hadHelmet:f.hadHelmet,hadJump:f.hadJump};
  androidRoundProof.finish(f,round);
  if(f.config.game.helmetCooldownSec>0)assert.equal(f.restores,2);
  assert.throws(()=>androidRoundProof.finish({...f,timeMs:f.timeMs+1},round),{code:'result_proof_invalid'});
  assert.throws(()=>androidRoundProof.finish({...f,proof:{...f.proof,events:[...f.proof.events,[0,20]]}},round),{code:'result_proof_invalid'});
 }
});
test('admin publishes only the helmet field: 0/30/60, old snapshots remain readable',async()=>{
 const old=structuredClone(defaults);delete old.config.game.helmetCooldownSec;old.revision=hash(old.config);
 validatePolicy(old);assert.equal(getValue(old.config,'game.helmetCooldownSec'),0);
 let template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(old)}},unrelated:{defaultValue:{value:'keep'}}}},etag='1';
 const remote={get:async()=>({template:structuredClone(template),etag,initialized:true,...readAndroidTemplate(template)}),
  publishScoped:async(current,scope,patches)=>{assert.equal(current.etag,etag);template=patchScopedTemplate(template,current.snapshot,scope,patches).template;etag=String(Number(etag)+1);return{publishedVersion:etag};}};
 const admin=createConfigAdmin({db:local.pool,remote});
 const field=fields.find(f=>f.path==='game.helmetCooldownSec');assert.equal(field.readOnly,false);
 for(const value of [30,0,60,30]){
  const current=await admin(actor,{action:'get',scope:'common'});
  const args={scope:'common',baseEtag:current.etag,patches:[{path:field.path,value}]};
  const preview=await admin(actor,{action:'preview',...args});
  await admin(actor,{action:'publish',...args,confirmRevision:preview.snapshot.revision});
  const saved=await remote.get(),envelope=readPlatformTemplate(saved.template,saved.snapshot);
  assert.equal(materializePlatform(envelope,'android').config.game.helmetCooldownSec,value);
  assert.equal(template.parameters.unrelated.defaultValue.value,'keep');
  const strip=o=>{const copy=structuredClone(o);delete copy.game.helmetCooldownSec;return copy;};
  assert.deepEqual(strip(saved.snapshot.config),strip(old.config));
 }
 for(const value of [-1,3601,'30',null,NaN]){
  const current=await admin(actor,{action:'get',scope:'common'});
  await assert.rejects(admin(actor,{action:'preview',scope:'common',baseEtag:current.etag,patches:[{path:field.path,value}]}));
 }
});
test('production engine never skips v3 proof checking and uses accepted round policy',async()=>{
 const f=fixtures.find(f=>f.config.game.helmetCooldownSec===30&&!f.hadJump);
 const policy={ok:true,config:f.config,revision:hash(f.config)};validatePolicy(policy);
 const db=new PostgresStore(local.pool);let stamp=Date.UTC(2026,9,24,12);
 let currentPolicy=policy;
 const engine=createEngine({db,now:()=>stamp,getPolicy:async()=>currentPolicy});
 // Use normal identity and API workflow in the isolated in-memory database.
 const uid='22222222-1234-4234-8234-123456789abc';
 await local.pg.query('insert into auth.users(id) values($1)',[uid]);
 const input={action:'round_start',requestId:f.requestId,proofVersion:3,helmet:true,jump:false,rulesRevision:policy.revision,revision:policy.config.economy.androidEnergyV2.revision};
 const started=await engine.execute(uid,input);
 await engine.execute(uid,{action:'round_activate',requestId:f.requestId});
 const replacement=structuredClone(policy.config);replacement.game.helmetCooldownSec=0;
 currentPolicy={ok:true,config:replacement,revision:hash(replacement)};
 stamp+=f.timeMs+100;
 await assert.rejects(engine.execute(uid,{action:'round_finish',roundId:started.roundId,...f,timeMs:f.timeMs+1}),{code:'result_proof_invalid'});
 const result=await engine.execute(uid,{action:'round_finish',roundId:started.roundId,...f});
 assert.ok(result);
});
