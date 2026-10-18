// User-authorized Android RC leaves only; credentials remain in memory/DPAPI.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../supabase/functions/_shared/config-admin.mjs';
const apply=process.argv.includes('--publish');let o;
try{
 o=await operator();const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
 const remote=createRemoteConfig({credentials});const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;
 const execute=createConfigAdmin({db:o.pool,remote}),current=await execute(actor,{action:'get'});
 const prefix='economy.androidEnergyV2.simpleBonus.';
 const patches=[{path:prefix+'videoDailyLimit',value:20},{path:prefix+'videoCooldownSec',value:120}];
 const preview=await execute(actor,{action:'preview',baseEtag:current.etag,patches});
 const strip=value=>{const copy=structuredClone(value);delete copy.economy.androidEnergyV2.simpleBonus.videoDailyLimit;delete copy.economy.androidEnergyV2.simpleBonus.videoCooldownSec;delete copy.economy.androidEnergyV2.watchAdCooldownSec;return copy;};
 assert.deepEqual(strip(current.snapshot.config),strip(preview.snapshot.config));
 const directory=path.join(privateDirectory,'rewarded-daily-limit-20261018');fs.mkdirSync(directory,{recursive:true});
 const backup=path.join(directory,'rc-before.dpapi');if(!fs.existsSync(backup))fs.writeFileSync(backup,dpapi(JSON.stringify(current)),{flag:'wx'});
 let result;
 if(apply&&preview.changes.length){result=await execute(actor,{action:'publish',baseEtag:current.etag,patches,confirmRevision:preview.snapshot.revision});}
 const after=await remote.get();if(apply){assert.equal(after.snapshot.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit,20);assert.equal(after.snapshot.config.economy.androidEnergyV2.simpleBonus.videoCooldownSec,120);assert.deepEqual(strip(current.snapshot.config),strip(after.snapshot.config));}
 console.log(JSON.stringify({ok:true,published:!!result,version:result?.version??current.version,dailyLimit:20,cooldownSec:120,changedFields:preview.changes.map(c=>c.path),otherSettingsUnchanged:true,encryptedBackup:true}));
}catch(e){console.error(JSON.stringify({ok:false,error:e.code??e.message}));process.exitCode=1;}finally{await o?.close();}
