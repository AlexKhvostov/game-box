// Task-scoped read-only acceptance. No player, wallet or Remote Config writes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {hash} from '../supabase/functions/_shared/core/policy.mjs';
import {recordRankings} from '../supabase/functions/_shared/record-ranking.mjs';
import {averageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
const file=path.join(privateDirectory,'ranking-top200-20261018/before.dpapi');
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
  assert.equal(players.length,before.players.length);assert.equal(revision,before.revision);
  const installedAt=Date.parse('2026-10-18T01:52:07+03:00'); // adb dumpsys package, build168
  const baselineAt=fs.statSync(file).mtimeMs;
  const rounds=(await o.pool.query("select body from untouch.documents where parent='rounds' and (body->>'startedAt')::numeric >= $1 order by body->'startedAt'",[baselineAt])).rows.map(r=>r.body);
  const operations=(await o.pool.query("select parent,body from untouch.documents where parent like 'players/%/operations' and (body->>'createdAt')::numeric >= $1",[baselineAt])).rows;
  assert.ok(rounds.every(r=>r.startedAt<installedAt&&r.finishedAt<installedAt&&!r.canceled));
  assert.ok(operations.every(r=>r.body.createdAt<installedAt));
  assert.equal(scores,before.scores+rounds.length);
  const keys=['energy','bestTimeMs','gamesStarted','feedbackSpentEnergy','claimed','unlocked','energySubscription','lastAdAt'];
  let rewardTotal=0;
  for(const old of before.players){
    const row=players.find(r=>r.key===old.key);assert.ok(row);
    const owned=rounds.filter(r=>r.uid===old.key),expected=structuredClone(old.wallet);
    assert.equal(row.completed,old.completed+owned.length);
    expected.energy-=owned.reduce((sum,r)=>sum+r.cost,0);
    expected.energy+=owned.reduce((sum,r)=>sum+(r.result?.energyReward??0),0);
    expected.gamesStarted+=owned.length;
    expected.feedbackSpentEnergy+=owned.filter(r=>r.activatedAt!=null).reduce((sum,r)=>sum+r.cost,0);
    expected.bestTimeMs=Math.max(expected.bestTimeMs,...owned.map(r=>r.result?.timeMs??0));
    for(const op of operations.filter(r=>r.parent===`players/${old.key}/operations`)){
      assert.equal(op.body.fingerprint,hash({args:{},kind:'watch_ad'}));
      const policy=owned.find(r=>r.policy.revision===op.body.policyRevision)?.policy;assert.ok(policy);
      const reward=policy.config.economy.androidEnergyV2.simpleBonus.videoReward;
      expected.energy+=reward;expected.lastAdAt=op.body.createdAt;rewardTotal+=reward;
    }
    for(const key of keys)assert.deepEqual(row.wallet[key],expected[key],key);
  }
  let checked=0;const rankingValues=[];
  for(const player of players){
    const records=await recordRankings({db:{pool:o.pool},uid:player.key,stamp:Date.now()});
    const average=await averageRanking({db:{pool:o.pool},config:{},uid:player.key,stamp:Date.now()});
    const attempts=(await o.pool.query("select count(*)::integer as total from untouch.documents where parent='scores' and body->>'platform'='android' and body->>'uid'=$1",[player.key])).rows[0].total;
    assert.equal(average.mine.totalAttempts,attempts);
    for(const rows of Object.values(records.periods)){assert.ok(rows.length<=201);assert.ok(rows.every((r,i)=>r.place===i+1||r.userId==='supabase:'+player.key));}
    const values=(await o.pool.query("select body from untouch.documents where parent='scores' and body->>'platform'='android' and body->>'uid'=$1 order by coalesce((body->>'attemptAt')::numeric,(body->>'createdAt')::numeric) desc,key desc",[player.key])).rows.map(r=>r.body.timeMs).filter(v=>v>1000);
    const used=values.slice(0,50),weights=used.reduce((sum,_,i)=>sum+.92**i,0);
    const mean=used.reduce((sum,v,i)=>sum+v*.92**i,0)/weights;
    assert.equal(average.mine.eligibleCount,values.length);
    if(used.length)assert.ok(Math.abs(mean-average.mine.averageMs)<1e-8);
    rankingValues.push({totalAttempts:attempts,eligibleAttempts:values.length,averageSeconds:average.mine.averageMs==null?null:Number((average.mine.averageMs/1000).toFixed(3)),place:average.mine.place});
    checked++;
  }
  console.log(JSON.stringify({ok:true,players:players.length,scores,revision,protectedWalletFieldsReconciled:true,completedGamesReconciled:true,preInstallRounds:rounds.length,preInstallCost:rounds.reduce((sum,r)=>sum+r.cost,0),preInstallReward:rewardTotal,newVersionRounds:0,newVersionOperations:0,rankingValues,sqlBoardsChecked:checked,totalAttemptCounterMatches:true,liveWrites:0}));
 }
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
