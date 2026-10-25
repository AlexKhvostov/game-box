// Merge already identical Android/Telegram gates; never change their values.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {operator,privateDirectory,dpapi,root} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {createPlatformConfigAdmin} from '../supabase/functions/_shared/platform-config-admin.mjs';
import {readPlatformTemplate,patchScopedTemplate,materializePlatform,PLATFORMS_RC_KEY} from '../supabase/functions/_shared/platform-config.mjs';
const out=path.join(root,'docs/release-evidence/google-play-final-internal-20261025');
const publish=process.argv.includes('--publish');let op;
try{
  const remote=createRemoteConfig({credentials:JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true))});
  const current=await remote.get(),before=readPlatformTemplate(current.template,current.snapshot);
  const candidate=patchScopedTemplate(current.template,current.snapshot,'common',[]);
  for(const p of ['android','telegram'])assert.deepEqual(materializePlatform(candidate.envelope,p),materializePlatform(before,p));
  const strip=t=>{t=structuredClone(t);delete t.version;for(const ps of [t.parameters,...Object.values(t.parameterGroups??{}).map(g=>g.parameters)])if(ps){delete ps[PLATFORMS_RC_KEY];delete ps.android_config_v1;}return t;};
  assert.deepEqual(strip(candidate.template),strip(current.template));
  let result;
  if(publish&&before.schemaVersion!==2){
    const ready=JSON.parse(fs.readFileSync(path.join(out,'edge-common-ads-deployed.json'),'utf8'));
    assert.equal(ready.passed,true);assert.equal(ready.functions.length,5);assert.ok(ready.functions.every(f=>f.sourceMatches&&f.verifyJwtUnchanged));
    fs.writeFileSync(path.join(privateDirectory,`common-ads-before-${Date.now()}.dpapi`),dpapi(JSON.stringify(current)),{flag:'wx'});
    op=await operator();
    const actor=(await op.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;assert.ok(actor);
    const execute=createPlatformConfigAdmin({db:op.pool,remote});
    const preview=await execute(actor,{action:'preview',scope:'common',baseEtag:current.etag,patches:[]});
    assert.deepEqual(preview.snapshot,candidate.snapshot);
    result=await execute(actor,{action:'publish',scope:'common',baseEtag:current.etag,patches:[],confirmRevision:preview.snapshot.revision});
  }
  const after=publish?await remote.get():current,actual=publish?readPlatformTemplate(after.template,after.snapshot):candidate.envelope;
  assert.deepEqual(actual,candidate.envelope);
  for(const p of ['android','telegram'])assert.deepEqual(materializePlatform(actual,p),materializePlatform(before,p));
  const report={passed:true,published:publish,alreadyShared:before.schemaVersion===2,checkedAt:new Date().toISOString(),previousVersion:current.template.version?.versionNumber,version:result?.version??after.template.version?.versionNumber,schemaVersion:actual.schemaVersion,commonAdRules:Object.fromEntries(['interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialGraceSec','interstitialCooldownSec','interstitialMinLives'].map(k=>[k,actual.common.economy[k]])),effectivePlatformSnapshotsUnchanged:true,providerSettings:actual.platforms.telegram.ads,otherRemoteConfigParametersUnchanged:true,auditWritten:!!result,playerDataWritten:false};
  fs.writeFileSync(path.join(out,publish?'common-ads-rc-published.json':'common-ads-rc-preview.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}catch(error){console.error(JSON.stringify({passed:false,error:error.code??error.message}));process.exitCode=1;}
finally{await op?.close();}
