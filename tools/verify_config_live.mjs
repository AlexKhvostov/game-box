import fs from 'node:fs';
import path from 'node:path';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../supabase/functions/_shared/config-admin.mjs';
import {fields} from '../supabase/functions/_shared/config-schema.mjs';
const o=await operator();
try {
 const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
 const remote=createRemoteConfig({credentials});
 const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0].id;
 const execute=createConfigAdmin({db:o.pool,remote});
 const current=await execute(actor,{action:'get'});
 const preview=await execute(actor,{action:'preview',baseEtag:current.etag,patches:[]});
 const energy=current.snapshot.config.economy.androidEnergyV2;
 const cases=JSON.parse(fs.readFileSync('test/fixtures/admin-config-cases.json','utf8'));
 const allPreview=await execute(actor,{action:'preview',baseEtag:current.etag,patches:cases});
 const player=(await o.pool.query('select body from untouch.documents where path=$1',['players/dcf26f4e-0c23-4c10-9ac7-45b21c2294dc'])).rows[0]?.body;
 const policies=await o.pool.query('select count(*)::int as count from untouch.policy_revisions where revision=$1',[current.snapshot.revision]);
 const output={checkedAt:new Date().toISOString(),version:current.version,revision:current.snapshot.revision,inviterReward:energy.simpleBonus.inviterReward,inviteeReward:energy.rewards.invite,editable:fields.filter(f=>!f.hidden).length,color:current.snapshot.config.field.colorHex,all57PreviewChanges:allPreview.changes.length,policyArchived:policies.rows[0].count===1,ownerEnergy:player?.wallet.energy,ownerCompleted:player?.completedGames,unchangedPreview:preview.changes.length===0,draftPresent:!!current.draft};
 fs.mkdirSync('docs/release-evidence/offline-zero-remote-config-20261017',{recursive:true});
 fs.writeFileSync('docs/release-evidence/offline-zero-remote-config-20261017/live-config.json',JSON.stringify(output,null,2));
 fs.writeFileSync('.private/remote-config-live-snapshot.json',JSON.stringify(current.snapshot));
 console.log(JSON.stringify(output));
} finally {await o.close();}
