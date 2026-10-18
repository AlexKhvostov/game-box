import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {hash} from '../functions/_shared/core/policy.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
let stamp=Date.UTC(2026,9,17),serial=0;const uid='offline_replay_isolated';
const engine=createEngine({db,now:()=>stamp});const call=body=>engine.execute(uid,body);
const initial=await call({action:'guest'});const revision=initial.profile.wallet.energyConfig.revision;
const policy=(await db.collection('players').doc(uid).get()).data();
// The canonical rules revision comes from the same defaults as the engine.
const {defaults}=await import('../functions/_shared/core/policy.mjs');
const start=helmet=>({action:'round_start',requestId:hash(`offline:${++serial}`),helmet,jump:false,revision,rulesRevision:defaults.revision});
test('queued offline runs retain individual debits and results; ranking selects best after replay',async()=>{
  const one=start(true),two=start(false);
  const a=await call(one);await call({action:'round_activate',requestId:one.requestId});
  const b=await call(two);await call({action:'round_activate',requestId:two.requestId});
  await call(one);await call({action:'round_activate',requestId:one.requestId});
  let wallet=(await call({action:'profile'})).profile.wallet;assert.equal(wallet.energy,47);assert.equal(wallet.feedbackSpentEnergy,3);
  const result=(id,time,helmet)=>({action:'round_finish',roundId:id,timeMs:time,runDistance:0,riskCount:0,hadHelmet:helmet,hadJump:false});
  await assert.rejects(call(result(a.roundId,5000,true)),e=>e.code==='result_time_invalid');
  stamp+=6000;await call(result(a.roundId,5000,true));await call(result(b.roundId,3000,false));await call(result(a.roundId,5000,true));
  wallet=(await call({action:'profile'})).profile.wallet;assert.equal(wallet.energy,47);assert.equal(wallet.feedbackSpentEnergy,3);
  const rows=await call({action:'scores',period:'all'});assert.equal(rows.scores.length,1);assert.equal(rows.scores[0].timeMs,5000);
  assert.equal((await db.collection('players').doc(uid).get()).data().completedGames,2);
});

test('empty wallet rejects every new request and allows only an authoritative top-up',async()=>{
  const zeroUid='offline_zero_isolated';
  await engine.execute(zeroUid,{action:'guest'});
  const ref=db.collection('players').doc(zeroUid);
  const player=(await ref.get()).data();player.wallet.energy=3;await ref.set(player);
  const zeroCall=body=>engine.execute(zeroUid,body);
  const requests=[];
  for(let i=0;i<3;i++){
    const request={...start(false),requestId:hash(`zero:${i}`)};requests.push(request);
    const opened=await zeroCall(request);
    await zeroCall({action:'round_activate',requestId:request.requestId});
    stamp+=2000;
    await zeroCall({action:'round_finish',roundId:opened.roundId,timeMs:1000+i*100,runDistance:0,riskCount:0,hadHelmet:false,hadJump:false});
  }
  for(let i=0;i<5;i++)await assert.rejects(zeroCall({...start(false),requestId:hash(`blocked:${i}`)}),e=>e.code==='insufficient_energy');
  for(const request of requests)await zeroCall(request);
  const current=(await zeroCall({action:'profile'})).profile.wallet;
  assert.equal(current.energy,0);assert.equal(current.feedbackSpentEnergy,3);
  assert.equal((await ref.get()).data().completedGames,3);
  const scores=await zeroCall({action:'scores',period:'all'});
  assert.equal(scores.scores.find(s=>s.timeMs===1200)?.timeMs,1200);
  const credited=(await ref.get()).data();credited.wallet.energy=1;await ref.set(credited);
  await assert.rejects(zeroCall(start(true)),e=>e.code==='insufficient_energy');
  const allowed=start(false);await zeroCall(allowed);
  assert.equal((await zeroCall({action:'profile'})).profile.wallet.energy,0);
});
