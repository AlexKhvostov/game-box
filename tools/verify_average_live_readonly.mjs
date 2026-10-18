import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {PostgresStore} from '../supabase/functions/_shared/postgres-store.mjs';
import {averageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
let o,stage='connect';
try{
 o=await operator();
 const before=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'average-ranking-20261018/before.dpapi'),'utf8'),true));
 const after=await o.pool.query("select key,body->'wallet' as wallet,body->'completedGames' as completed from untouch.documents where parent='players' order by key");
 stage='player_count';assert.equal(after.rows.length,before.players.length);
 const installedAt=Date.parse('2026-10-18T00:13:56+03:00'); // adb dumpsys package lastUpdateTime
 const backupAt=Math.floor(fs.statSync(path.join(privateDirectory,'average-ranking-20261018/before.dpapi')).mtimeMs);
 const rounds=await o.pool.query("select body from untouch.documents where parent='rounds' and (body->>'startedAt')::bigint >= $1 order by body->'startedAt'",[backupAt]);
 stage='no_round_after_install';assert.ok(rounds.rows.every(r=>r.body.startedAt<installedAt));
 stage='documented_preinstall_round';assert.equal(rounds.rowCount,1);
 assert.equal(rounds.rows[0].body.finishedAt,1792271614807);assert.equal(rounds.rows[0].body.cost,2);
 const protectedKeys=['energy','bestTimeMs','gamesStarted','feedbackSpentEnergy','claimed','unlocked','energySubscription'];
 for(const old of before.players){
   const current=after.rows.find(p=>p.key===old.key);stage='owner_present';assert.ok(current);
   const owned=rounds.rows.map(r=>r.body).filter(r=>r.uid===old.key&&!r.canceled),finished=owned.filter(r=>r.finishedAt!=null),activated=owned.filter(r=>r.activatedAt!=null);
   stage='completed_games_reconciled';assert.equal(current.completed,old.completed+finished.length);
   const expected=structuredClone(old.wallet);
   expected.energy-=owned.reduce((sum,r)=>sum+r.cost,0);expected.energy+=finished.reduce((sum,r)=>sum+(r.result?.energyReward??0),0);
   expected.gamesStarted+=owned.length;expected.feedbackSpentEnergy+=activated.reduce((sum,r)=>sum+r.cost,0);
   for(const key of protectedKeys){stage='wallet_'+key;assert.deepEqual(current.wallet[key],expected[key],key);}
 }
 let qualifying=0,rowsChecked=0;
 for(const row of after.rows){
   const board=await averageRanking({db:new PostgresStore(o.pool),config:{},uid:row.key,stamp:Date.now()});
   const values=await o.pool.query("select body from untouch.documents where parent='scores' and body->>'platform'='android' and body->>'uid'=$1 order by coalesce((body->>'attemptAt')::bigint,(body->>'createdAt')::bigint) desc,key desc",[row.key]);
   const eligible=values.rows.map(v=>v.body.timeMs).filter(t=>t>1000),used=eligible.slice(0,50);
   const numerator=used.reduce((sum,v,i)=>sum+v*Math.pow(.92,i),0),denominator=used.reduce((sum,_,i)=>sum+Math.pow(.92,i),0);
   stage='eligible_count';assert.equal(board.mine.eligibleCount,eligible.length);stage='used_count';assert.equal(board.mine.usedCount,used.length);
   stage='numeric_average';if(used.length)assert.ok(Math.abs(board.mine.averageMs-numerator/denominator)<1e-8);else assert.equal(board.mine.averageMs,null);
   stage='admission';assert.equal(board.mine.place!==null,eligible.length>=20);if(board.mine.place!==null)qualifying++;
   rowsChecked+=values.rowCount;
 }
 console.log(JSON.stringify({ok:true,playersChecked:after.rowCount,attemptsChecked:rowsChecked,qualifiedPlayers:qualifying,preInstallCompletedRounds:rounds.rowCount,preInstallCost:2,newVersionRounds:0,protectedWalletFieldsReconciled:true,rankingMatchesIndependentCalculation:true,livePlayerWrites:0}));
}catch(error){console.error(JSON.stringify({ok:false,stage,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
