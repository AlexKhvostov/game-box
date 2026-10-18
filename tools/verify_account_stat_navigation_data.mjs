// Task-scoped read-only acceptance. No player, wallet or Remote Config writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
const file=path.join(privateDirectory,'account-stat-navigation-20261018/before.dpapi');
let o;
try{
 o=await operator();
 const players=(await o.pool.query("select key,body->'wallet' as wallet,body->'completedGames' as completed from untouch.documents where parent='players' order by key")).rows;
 const scores=(await o.pool.query("select count(*)::integer as count from untouch.documents where parent='scores'")).rows[0].count;
 const revision=(await o.pool.query("select published_version from untouch.config_audit where status='published' order by completed_at desc,id desc limit 1")).rows[0].published_version;
 if(process.argv.includes('--baseline')){
  fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,dpapi(JSON.stringify({players,scores,revision})),{flag:'wx'});
  console.log(JSON.stringify({ok:true,baselineEncrypted:true,players:players.length,scores,revision}));
 }else{
  const before=JSON.parse(dpapi(fs.readFileSync(file,'utf8'),true));
  assert.equal(players.length,before.players.length);assert.equal(scores,before.scores);assert.equal(revision,before.revision);
  const keys=['energy','bestTimeMs','gamesStarted','feedbackSpentEnergy','claimed','unlocked','energySubscription'];
  for(const old of before.players){const row=players.find(r=>r.key===old.key);assert.ok(row);assert.equal(row.completed,old.completed);for(const key of keys)assert.deepEqual(row.wallet[key],old.wallet[key],key);}
  console.log(JSON.stringify({ok:true,players:players.length,scores,revision,protectedWalletFieldsUnchanged:true,completedGamesUnchanged:true,liveWrites:0}));
 }
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
