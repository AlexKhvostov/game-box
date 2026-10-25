import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
import {averageRanking} from '../functions/_shared/average-ranking.mjs';
import {averageDefaults,averageRules} from '../functions/_shared/average-config.mjs';
import {fields,applyChanges,getValue} from '../functions/_shared/config-schema.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
let stamp=Date.UTC(2026,9,18),serial=0;
let policy=structuredClone(defaults);
const engine=createEngine({roundProof:{start(){},finish(){}},db,getPolicy:async()=>policy,now:()=>stamp});
const board=uid=>engine.execute(uid,{action:'scores',period:'average'});
async function player(uid){await engine.execute(uid,{action:'guest'});}
async function seed(uid,values,extra={}){
  for(const timeMs of values){const id=hash(`${uid}:${++serial}`);await db.collection('scores').doc(id).set({id,uid,userId:`supabase:${uid}`,playerName:uid,platform:'android',timeMs,createdAt:stamp++,runDistance:0,riskCount:0,...extra});}
}
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);
test('legacy configured strict 1 second boundary and 19/20 admission; no fake seed',async()=>{
 policy.config.ranking={average:{...averageDefaults,minAttempts:20,minDurationMs:1000}};policy.revision=hash(policy.config);
 await player('boundary');await seed('boundary',[...Array(19).fill(5000),1,999,1000]);
 let b=await board('boundary');assert.equal(b.rules.minAttempts,20);assert.equal(b.mine.eligibleCount,19);assert.equal(b.mine.place,null);near(b.mine.averageMs,5000);assert.equal(b.rows.length,0);
 await seed('boundary',[1001]);b=await board('boundary');assert.equal(b.mine.eligibleCount,20);assert.equal(b.mine.usedCount,20);assert.equal(b.mine.place,1);
 near(b.mine.averageMs,Math.sqrt(5000**2+(1001**2-5000**2)*.08/(1-.92**20)));
 await player('empty');b=await board('empty');assert.equal(b.mine.averageMs,null);assert.equal(b.mine.eligibleCount,0);
});
test('new defaults rank the first confirmed attempt, including one millisecond',async()=>{
 assert.equal(averageRules({}).minAttempts,1);assert.equal(averageRules({}).minDurationMs,0);
 await player('first_short');await seed('first_short',[1]);
 const b=await averageRanking({db,config:{},uid:'first_short',stamp});
 assert.equal(b.mine.totalAttempts,1);assert.equal(b.mine.eligibleCount,1);assert.ok(b.mine.place>0);near(b.mine.averageMs,1);
 await seed('first_short',[999]);const next=await averageRanking({db,config:{},uid:'first_short',stamp});
 near(next.mine.averageMs,Math.sqrt((999**2+1*.92)/1.92));assert.equal(next.mine.eligibleCount,2);
 assert.equal(next.rules.algorithm,'weighted_rms_v1');
});
test('filter before last50; exponential normalization; one record; hidden/deleted/platform isolation',async()=>{
 await player('window');await seed('window',Array(50).fill(5000));await seed('window',Array(100).fill(1000));await seed('window',[15000]);
 let b=await board('window');assert.equal(b.mine.eligibleCount,51);assert.equal(b.mine.usedCount,50);near(b.mine.averageMs,Math.sqrt(5000**2+(15000**2-5000**2)*.08/(1-.92**50)));
 await seed('window',Array(50).fill(5000));b=await board('window');near(b.mine.averageMs,5000);
 await seed('window',[999999],{platform:'legacy_telegram'});b=await board('window');near(b.mine.averageMs,5000);
 await player('hidden');await seed('hidden',Array(20).fill(20000));await db.collection('players').doc('hidden').update({supportDisabled:true});
 await seed('deleted',Array(20).fill(30000));b=await board('window');assert.ok(!b.rows.some(r=>r.userId==='supabase:hidden'||r.userId==='supabase:deleted'));
});
test('all four RC fields affect existing history immediately without waiting for board cache',async()=>{
 const patches=[{path:'ranking.average.windowSize',value:30},{path:'ranking.average.previousWeightPercent',value:85},{path:'ranking.average.minAttempts',value:10},{path:'ranking.average.minDurationMs',value:1500}];
 await player('rc');await seed('rc',[...Array(50).fill(5000),...Array(10).fill(8000),1001]);
 const before=await board('rc');const config=applyChanges(policy,patches);policy={ok:true,config,revision:hash(config)};
 const after=await board('rc');assert.equal(after.mine.eligibleCount,before.mine.eligibleCount-1);assert.equal(after.mine.usedCount,30);assert.equal(after.rules.minAttempts,10);
 near(after.mine.averageMs,Math.sqrt(5000**2+(8000**2-5000**2)*(1-.85**10)/(1-.85**30)));
 for(const p of patches){assert.equal(fields.find(f=>f.path===p.path).hidden,false);assert.equal(getValue(config,p.path),p.value);}
 assert.throws(()=>averageRules({ranking:{average:{windowSize:0}}}));
 for(const [key,value]of [['windowSize',501],['previousWeightPercent',0],['minAttempts',0],['minDurationMs',60001]])assert.throws(()=>applyChanges(policy,[{path:`ranking.average.${key}`,value}]),e=>e.code==='config_invalid');
 policy=structuredClone(defaults);
});
test('actual accepted rounds: duplicate finish once; reverse delivery sorted by server round start',async()=>{
 await player('delivery');
 const cfg=structuredClone(defaults.config);cfg.ranking={average:{...averageDefaults,minAttempts:1,windowSize:2}};const p={ok:true,config:cfg,revision:hash(cfg)};
 const e=createEngine({roundProof:{start(){},finish(){}},db,getPolicy:async()=>p,now:()=>stamp});
 const call=body=>e.execute('delivery',body);const starts=[];
 for(let i=0;i<2;i++){const requestId=hash(`delivery:${i}`);const r=await call({action:'round_start',requestId,rulesRevision:p.revision});await call({action:'round_activate',requestId});starts.push(r.roundId);stamp+=10000;}
 const finish=(id,timeMs)=>({action:'round_finish',roundId:id,timeMs,runDistance:0,riskCount:0,hadJump:false,hadHelmet:false});
 await call(finish(starts[1],8000));await call(finish(starts[0],2000));await call(finish(starts[0],2000));
 const b=await call({action:'scores',period:'allPeriods'});assert.equal(b.average.mine.eligibleCount,2);near(b.average.mine.averageMs,Math.sqrt((8000**2+2000**2*.92)/1.92));
 assert.equal((await db.collection('players').doc('delivery').get()).data().completedGames,2);
});
test('ties deterministic, minimum independent of window,100% means ordinary RMS',async()=>{
 const config={ranking:{average:{windowSize:2,previousWeightPercent:100,minAttempts:3,minDurationMs:1000}}};
 await player('tie_a');await player('tie_b');await seed('tie_a',[9999,4000,6000]);await seed('tie_b',[11111,6000,4000]);
 const b=await averageRanking({db,config,uid:'tie_a',stamp});near(b.mine.averageMs,Math.sqrt(26000000));assert.equal(b.mine.usedCount,2);assert.equal(b.mine.eligibleCount,3);
 assert.ok(b.rows.find(r=>r.userId==='supabase:tie_a').place<b.rows.find(r=>r.userId==='supabase:tie_b').place);
});
