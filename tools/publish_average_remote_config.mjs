// Publish only the four explicitly approved average-ranking leaves. No players,
// balances, purchases, access settings, or other RC parameters are written.
import fs from 'node:fs';
import path from 'node:path';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../supabase/functions/_shared/config-admin.mjs';
import {PostgresStore} from '../supabase/functions/_shared/postgres-store.mjs';
import {averageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
import {averageDefaults} from '../supabase/functions/_shared/average-config.mjs';
const publish=process.argv.includes('--publish');
let o;
try{
 o=await operator();
 const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
 const remote=createRemoteConfig({credentials});
 const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;
 const execute=createConfigAdmin({db:o.pool,remote});
 const current=await execute(actor,{action:'get'});
 const patches=Object.entries(averageDefaults).map(([key,value])=>({path:`ranking.average.${key}`,value}));
 const preview=await execute(actor,{action:'preview',baseEtag:current.etag,patches});
 const strip=value=>{const copy=structuredClone(value);if(copy.ranking){delete copy.ranking.average;if(!Object.keys(copy.ranking).length)delete copy.ranking;}return JSON.stringify(copy);};
 if(strip(current.snapshot.config)!==strip(preview.snapshot.config))throw Error('unrelated_config_change');
 if(preview.changes.some(c=>!c.path.startsWith('ranking.average.')))throw Error('unrelated_patch');
 const players=await o.pool.query("select key,body->'wallet' as wallet,body->'completedGames' as completed from untouch.documents where parent='players' order by key");
 const db=new PostgresStore(o.pool);
 const uid=players.rows[0]?.key;
 if(!uid)throw Error('no_existing_player_for_readonly_check');
 const board=await averageRanking({db,config:preview.snapshot.config,uid,stamp:Date.now()});
 const destination=path.join(privateDirectory,'average-ranking-20261018');fs.mkdirSync(destination,{recursive:true});
 const backup=path.join(destination,'before.dpapi');
 if(!fs.existsSync(backup))fs.writeFileSync(backup,dpapi(JSON.stringify({remote:await remote.get(),players:players.rows})),{flag:'wx'});
 let result;
 if(publish){
   result=await execute(actor,{action:'publish',baseEtag:current.etag,patches,confirmRevision:preview.snapshot.revision});
   const verified=await remote.get();
   if(JSON.stringify(verified.snapshot.config.ranking?.average)!==JSON.stringify(averageDefaults))throw Error('publication_not_verified');
   if(strip(current.snapshot.config)!==strip(verified.snapshot.config))throw Error('unrelated_live_change');
 }
 console.log(JSON.stringify({ok:true,published:publish,version:result?.version??current.version,rules:averageDefaults,changedFields:preview.changes.map(c=>c.path),players:players.rowCount,qualifiedPlayers:board.rows.length,sqlChecked:true,backupEncrypted:true}));
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
