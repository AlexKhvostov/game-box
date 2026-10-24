import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {RoundJournal} from '../src/services/journal.ts';
import {averageChart} from '../src/domain/average.ts';
const config=JSON.parse(fs.readFileSync(new URL('../src/generated/android-config.json',import.meta.url)));
const id=n=>n.toString(16).padStart(64,'0');
test('result display preserves pre-run best and reward rules after delivery compaction and RC change',()=>{
  const storage=memory(),journal=new RoundJournal(storage,'owner'),rules=structuredClone(config);
  rules.config.economy.riskRewardEvery=8;rules.config.economy.runRewardEvery=999;
  journal.prepare(id(201),rules,false,false,50,1000,2345);
  journal.update(id(201),{phase:'confirmed',reward:3,result:{timeMs:12345,riskCount:12,runDistance:2345}});
  rules.config.economy.riskRewardEvery=1;rules.config.economy.runRewardEvery=1;
  const saved=new RoundJournal(storage,'owner').all[0];
  assert.deepEqual(saved.config.config,{});assert.equal(saved.previousBestTimeMs,2345);
  assert.deepEqual(saved.rewardDivisors,{risk:8,run:999});
  assert.equal(Math.floor(saved.result.riskCount/saved.rewardDivisors.risk)+Math.floor(saved.result.runDistance/saved.rewardDivisors.run),saved.reward);
});
function memory(){const data=new Map();return{data,get:(key,fallback)=>structuredClone(data.get(key)??fallback),set:(key,value)=>data.set(key,structuredClone(value))};}
test('journal persists before start, reserves offline energy, reloads same owner, prevents duplicate',()=>{
  const storage=memory(),journal=new RoundJournal(storage,'owner-a');
  const first=journal.prepare(id(1),config,true,true,50,1000);assert.equal(first.cost,3);assert.equal(journal.reserved(),3);
  assert.equal(new RoundJournal(storage,'owner-a').pending[0].requestId,id(1));assert.equal(new RoundJournal(storage,'owner-b').all.length,0);
  assert.throws(()=>journal.prepare(id(1),config,false,false,50,1001),/operation_conflict/);
  for(let n=2;n<=16;n++)journal.prepare(id(n),config,true,true,50,1000+n);
  assert.equal(journal.reserved(),48);assert.throws(()=>journal.prepare(id(17),config,true,true,50,2000),/insufficient_energy/);
});
test('failed persistence cannot begin a run or silently lose a finished result',()=>{
  const storage=memory(),journal=new RoundJournal(storage,'owner');const setter=storage.set;
  storage.set=()=>{throw Error('storage_unavailable');};assert.throws(()=>journal.prepare(id(1),config,false,false,50,1000));assert.equal(journal.all.length,0);
  storage.set=setter;journal.prepare(id(1),config,false,false,50,1000);
  storage.set=()=>{throw Error('storage_unavailable');};assert.throws(()=>journal.update(id(1),{phase:'confirmed'}));assert.equal(journal.all[0].phase,'prepared');
});
test('known server debit releases local reservation; local completion never invents a confirmed score',()=>{
  const storage=memory(),journal=new RoundJournal(storage,'owner');journal.prepare(id(1),config,false,false,50,1000);
  journal.update(id(1),{phase:'started',roundId:id(99)});assert.equal(journal.reserved(),0);
  journal.update(id(1),{phase:'activated',result:{timeMs:2000,runDistance:0,riskCount:0,proof:{version:1,startPose:[],events:[[0,16]]}}});
  assert.equal(new RoundJournal(storage,'owner').pending[0].phase,'activated');
  assert.throws(()=>journal.update(id(1),{owner:'someone-else'}),/owner_changed/);
});
test('corrupt/mismatched journal blocks play instead of silently creating a fresh balance',()=>{
  const storage=memory();storage.set('rounds:owner',{version:1,owner:'someone-else',attempts:[]});assert.throws(()=>new RoundJournal(storage,'owner'),/journal_invalid/);
});
test('delivered heavy proofs/config are compacted, history bounded, pending proof survives reload',()=>{
  const storage=memory(),journal=new RoundJournal(storage,'owner');
  const proof={version:1,startPose:[],events:Array.from({length:10000},()=>[0,16])};
  for(let i=1;i<=650;i++){
    journal.prepare(id(i),config,false,false,1000,i);
    journal.update(id(i),{result:{timeMs:160000,runDistance:0,riskCount:0,proof}});
    journal.update(id(i),{phase:'confirmed'});
  }
  const delivered=JSON.stringify(storage.data.get('rounds:owner'));
  assert.ok(delivered.length<350000,`bounded lightweight history, actual ${delivered.length}`);
  assert.equal(journal.all.length,600);assert.equal(journal.all[0].requestId,id(51));
  assert.equal(journal.all[0].result.proof,undefined);assert.deepEqual(journal.all[0].config.config,{});
  journal.prepare(id(999),config,false,false,1000,999);
  journal.update(id(999),{result:{timeMs:160000,runDistance:0,riskCount:0,proof}});
  const loaded=new RoundJournal(storage,'owner');assert.equal(loaded.pending[0].result.proof.events.length,10000);
  assert.equal(loaded.pending[0].config.config.player.size,36);
});
test('weighted RMS projection uses confirmed attempts, filters strictly, retains historical averages before slicing100',()=>{
  const ranking={rules:{algorithm:'weighted_rms_v1',windowSize:2,previousWeightPercent:92,minDurationMs:1000,minAttempts:1},mine:{totalAttempts:3,usedCount:2,averageMs:Math.sqrt((15000**2+5000**2*.92)/1.92)}};
  const rows=[5000,1000,15000].map((timeMs,i)=>({requestId:id(i),createdAt:i,phase:'confirmed',result:{timeMs}}));
  rows.push({requestId:id(4),createdAt:4,phase:'activated',result:{timeMs:999999}});
  const chart=averageChart(rows,ranking);assert.equal(chart.points.length,3);assert.equal(chart.awaitingCount,1);assert.equal(chart.historyComplete,true);
  assert.ok(Math.abs(chart.averageMs-Math.sqrt((15000**2+5000**2*.92)/1.92))<1e-9);assert.equal(chart.points[1].included,false);assert.equal(chart.points[1].averageMs,5000);
  const long=Array.from({length:110},(_,i)=>({requestId:id(i),createdAt:i,phase:'confirmed',result:{timeMs:5000+i}}));
  const truncated=averageChart(long,{...ranking,mine:{totalAttempts:120}});assert.equal(truncated.points.length,100);assert.ok(truncated.points[0].averageMs>5000);assert.equal(truncated.historyComplete,false);
});

 test('v2 protocol is atomic with preparation and survives offline recovery; v1 remains compatible',()=>{
 const storage=memory(),journal=new RoundJournal(storage,'protocol-owner');journal.prepare(id(301),config,false,false,50,1000,undefined,0,2);const recovered=new RoundJournal(storage,'protocol-owner');assert.equal(recovered.pending[0].proofVersion,2);recovered.recoverUnfinished();assert.equal(recovered.pending[0].proofVersion,2);recovered.prepare(id(302),config,false,false,50,1001);assert.equal(recovered.pending[1].proofVersion,1);
 });
