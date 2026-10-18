import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {defaults,hash,validatePolicy} from '../functions/_shared/core/policy.mjs';
import {applyChanges} from '../functions/_shared/config-schema.mjs';

const local=await testDatabase();after(()=>local.close());
const db=new PostgresStore(local.pool);
let stamp=Date.UTC(2026,9,18),serial=0,policy=structuredClone(defaults);
const engine=createEngine({db,getPolicy:async()=>policy,now:()=>stamp});
const call=(uid,action,args={})=>engine.execute(uid,{action,...args});
async function opened(uid) {
  const requestId=hash(`review:${++serial}`);
  const round=await call(uid,'round_start',{requestId,rulesRevision:policy.revision});
  await call(uid,'round_activate',{requestId});
  return {requestId,roundId:round.roundId};
}
test('impossible metrics cannot award energy or write a score; normal metrics and replay still work',async()=>{
  const uid='review_metrics';await call(uid,'guest');const run=await opened(uid);
  for(const result of [
    {timeMs:1,runDistance:10000000,riskCount:10000},
    {timeMs:1000,runDistance:999999,riskCount:0},
    {timeMs:1000,runDistance:0,riskCount:10000},
  ]) {
    stamp+=result.timeMs;
    await assert.rejects(call(uid,'round_finish',{roundId:run.roundId,...result}),e=>e.code==='result_metrics_invalid');
  }
  let p=(await call(uid,'profile')).profile;
  assert.equal(p.wallet.energy,49);
  assert.equal((await db.collection('scores').get()).size,0);
  const result={roundId:run.roundId,timeMs:2000,runDistance:1000,riskCount:8};
  const accepted=await call(uid,'round_finish',result);
  const replay=await call(uid,'round_finish',result);
  assert.equal(replay.energyReward,accepted.energyReward);
  p=(await call(uid,'profile')).profile;assert.equal(p.wallet.energy,49+accepted.energyReward);
  assert.equal((await db.collection('players').doc(uid).get()).data().completedGames,1);
});
test('rules change rejects a new old-revision start before debit but preserves an already accepted run',async()=>{
  const uid='review_rules';await call(uid,'guest');const run=await opened(uid),oldRevision=policy.revision;
  policy=structuredClone(policy);policy.config.audio.musicVolume=.31;policy.revision=hash(policy.config);
  await assert.rejects(call(uid,'round_start',{requestId:hash('obsolete'),rulesRevision:oldRevision}),e=>e.code==='rules_changed');
  assert.equal((await call(uid,'profile')).profile.wallet.energy,49);
  stamp+=10000;
  await call(uid,'round_finish',{roundId:run.roundId,timeMs:5000,runDistance:0,riskCount:0});
  const next=await opened(uid);assert.ok(next.roundId);
  policy=structuredClone(defaults);
});
test('early finish reports its exact retry delay and succeeds later without an extra debit',async()=>{
  const uid='review_early';await call(uid,'guest');const run=await opened(uid);
  const result={roundId:run.roundId,timeMs:5000,runDistance:0,riskCount:0};
  await assert.rejects(call(uid,'round_finish',result),e=>e.code==='result_time_invalid'&&e.retryAfterMs===3800);
  stamp+=5000;await call(uid,'round_finish',result);
  assert.equal((await call(uid,'profile')).profile.wallet.energy,49);
});
test('publication and runtime both reject configurations which cannot start Android',()=>{
  for(const patches of [
    [{path:'player.size',value:4}],
    [{path:'player.size',value:79}],
    [{path:'enemies.areaMultiplier',value:20}],
    [{path:'player.size',value:60},{path:'enemies.areaMultiplier',value:4}],
  ]) assert.throws(()=>applyChanges(defaults,patches),e=>e.code==='config_invalid');
  for(const mutate of [
    c=>c.player.size=4,
    c=>c.enemies.aspects=[1,1,1],
    c=>c.enemies.aspects=[1,1,1,99],
  ]) {
    const next=structuredClone(defaults);mutate(next.config);next.revision=hash(next.config);
    assert.throws(()=>validatePolicy(next),e=>e.code==='policy_geometry_invalid');
  }
  const valid=applyChanges(defaults,[{path:'player.size',value:40},{path:'enemies.spinDegPerSec',value:120}]);
  assert.doesNotThrow(()=>validatePolicy({ok:true,revision:hash(valid),config:valid}));
});
