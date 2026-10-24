// Authorized release: only the ten common enemy-pace fields; no player writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import pg from '../supabase/node_modules/pg/lib/index.js';
import ca from '../supabase/functions/_shared/database-ca.mjs';
import {runtimeSecrets,privateDirectory,dpapi,project,root} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {readPlatformTemplate,patchScopedTemplate,materializePlatform,PLATFORMS_RC_KEY} from '../supabase/functions/_shared/platform-config.mjs';
import {createPlatformConfigAdmin} from '../supabase/functions/_shared/platform-config-admin.mjs';
const publish=process.argv.includes('--publish');
const wanted={initialSpeed:0,growthMultiplier:70,growthExponent:.2,startSmoothingSec:3,initialCompensation:1,
  brakeCooldownSec:6,brakeFirstReadySec:6,brakeRewindSec:6,brakeEnabled:true,speedBarEnabled:true};
const patches=Object.entries(wanted).map(([key,value])=>({path:`enemyPace.${key}`,value}));
const directory=path.join(root,'docs/release-evidence/telegram-brake-release-20261024');
fs.mkdirSync(directory,{recursive:true});
const strip=config=>{const copy=structuredClone(config);delete copy.enemyPace;return copy;};
let pool,stage='read';
try{
 const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
 const remote=createRemoteConfig({credentials,telegramStarsAccepted:true});
 const current=await remote.get(),before=readPlatformTemplate(current.template,current.snapshot);
 const candidate=patchScopedTemplate(current.template,current.snapshot,'common',patches,{telegramStarsAccepted:true});
 assert.deepEqual(candidate.envelope.platforms,before.platforms);
 assert.deepEqual(strip(candidate.envelope.common),strip(before.common));
 for(const platform of ['android','telegram'])assert.deepEqual(strip(materializePlatform(candidate.envelope,platform).config),strip(materializePlatform(before,platform).config));
 const explicit=template=>{
  const parameters=[template.parameters,...Object.values(template.parameterGroups??{}).map(g=>g.parameters)];
  const raw=parameters.find(p=>p?.[PLATFORMS_RC_KEY])?.[PLATFORMS_RC_KEY]?.defaultValue?.value;
  return raw?JSON.parse(raw).common?.enemyPace:null;
 };
 const already=JSON.stringify(explicit(current.template))===JSON.stringify(wanted);
 let version=current.template.version?.versionNumber,published=false;
 if(publish&&!already){
  stage='backup';const plain=JSON.stringify(current),sealed=dpapi(plain);assert.equal(dpapi(sealed,true),plain);
  fs.writeFileSync(path.join(root,'.private/telegram-port',`brake033-rc-before-${Date.now()}.dpapi`),sealed,{flag:'wx'});
  const secrets=runtimeSecrets();
  pool=new pg.Pool({connectionString:`postgresql://untouch_runtime.${project}:${secrets.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`,ssl:{rejectUnauthorized:true,ca},max:1,connectionTimeoutMillis:10000});
  const actor=(await pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;assert.ok(actor);
  const execute=createPlatformConfigAdmin({db:pool,remote,telegramStarsAccepted:true});
  stage='preview';const preview=await execute(actor,{action:'preview',scope:'common',baseEtag:current.etag,patches});
  stage='publish';const result=await execute(actor,{action:'publish',scope:'common',baseEtag:current.etag,patches,confirmRevision:preview.snapshot.revision});
  version=result.version;published=true;
 }
 stage='verify';const after=publish?await remote.get():current;
 if(publish){
  const actual=readPlatformTemplate(after.template,after.snapshot);
  assert.deepEqual(actual.platforms,before.platforms);assert.deepEqual(strip(actual.common),strip(before.common));
  assert.deepEqual(explicit(after.template),wanted);
  assert.deepEqual(after.snapshot.config.enemyPace,wanted);
 }
 const report={ok:true,checkedAt:new Date().toISOString(),published,version,explicitBefore:already,
  scope:'common',enemyPace:wanted,platformServicesUnchanged:true,otherCommonRulesUnchanged:true,
  androidAndTelegramSharePace:true,playerDataWritten:false};
 fs.writeFileSync(path.join(directory,publish?'rc-published.json':'rc-preview.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));
}catch(error){console.error(JSON.stringify({ok:false,stage,error:typeof error.code==='string'&&/^[a-z0-9_]{1,45}$/i.test(error.code)?error.code:'release_check_failed',assertion:error.code==='ERR_ASSERTION'?error.message.split('\n')[0]:undefined}));process.exitCode=1;}
finally{await pool?.end();}
