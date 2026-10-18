// Alexey requested50 energy for internal feedback. Change that leaf only.
import fs from 'node:fs';
import path from 'node:path';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../supabase/functions/_shared/config-admin.mjs';
let o;
try{
  o=await operator();
  const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
  const remote=createRemoteConfig({credentials});
  const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;
  const execute=createConfigAdmin({db:o.pool,remote});
  const current=await execute(actor,{action:'get'});
  const before=current.snapshot.config.economy.androidEnergyV2.rewards.feedback;
  if(before===50)console.log(JSON.stringify({ok:true,alreadyPublished:true,version:current.version,feedback:50}));
  else{
    if(before!==20)throw Error('Feedback value changed externally; review required');
    const patches=[{path:'economy.androidEnergyV2.rewards.feedback',value:50}];
    const preview=await execute(actor,{action:'preview',baseEtag:current.etag,patches});
    const result=await execute(actor,{action:'publish',baseEtag:current.etag,patches,confirmRevision:preview.snapshot.revision});
    const verified=await remote.get();
    if(verified.snapshot.config.economy.androidEnergyV2.rewards.feedback!==50)throw Error('Publication not verified');
    console.log(JSON.stringify({ok:true,version:result.version,feedback:50,otherChanges:preview.changes.length-1,revision:result.revision}));
  }
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
