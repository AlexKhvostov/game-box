import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {createEngine,codeFor,shortCodeFor} from '../functions/_shared/core/engine.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {testDatabase} from './database.mjs';
const local=await testDatabase(),db=new PostgresStore(local.pool);
after(()=>local.close());
let stamp=Date.UTC(2026,9,18),serial=0;
const engine=createEngine({roundProof:{start(){},finish(){}},db,now:()=>stamp});
const call=(uid,action='invites_state',args={},linked=false)=>engine.execute(uid,{action,...args},{googleLinked:linked});
const reject=(promise,code)=>assert.rejects(promise,e=>e.code===code);
const player=uid=>db.collection('players').doc(uid);
const alias=code=>db.collection('inviteCodes').doc(code);
const canonical=r=>{assert.match(r.invites.ownCode,/^[A-HJ-NP-Z2-9]{6}$/);assert.equal(r.invites.inviteUrl,`https://untouch.fun/a/${r.invites.ownCode}`);};

test('first invite request lazily reserves stable six code for all responses, preserving legacy alias',async()=>{
  const uid='short_compat';await call(uid,'guest');
  assert.equal((await player(uid).get()).data().ownShortCode,undefined);
  const modern=await call(uid);canonical(modern);assert.equal(modern.invites.ownCode,shortCodeFor(uid,0));
  assert.equal((await alias(codeFor(uid)).get()).data().uid,uid);
  assert.equal((await alias(modern.invites.ownCode).get()).data().uid,uid);
  assert.equal((await player(uid).get()).data().ownCode,codeFor(uid));
  for(const action of ['invites_state','invites_list']){const response=await call(uid,action);canonical(response);assert.equal(response.invites.ownCode,modern.invites.ownCode);}
});
test('occupied candidates never overwritten; exhaustion rolls back whole lazy allocation',async()=>{
  const uid='short_collision';await call(uid,'guest');
  for(let i=0;i<3;i++)await alias(shortCodeFor(uid,i)).set({uid:`other_${i}`,createdAt:stamp});
  assert.equal((await call(uid)).invites.ownCode,shortCodeFor(uid,3));
  assert.equal((await alias(shortCodeFor(uid,0)).get()).data().uid,'other_0');
  const exhausted='short_exhausted';await call(exhausted,'guest');const before=(await player(exhausted).get()).data();
  for(let i=0;i<32;i++)await alias(shortCodeFor(exhausted,i)).set({uid:`occupied_${i}`});
  await reject(call(exhausted),'invite_code_collision');assert.deepEqual((await player(exhausted).get()).data(),before);
});
test('simultaneous first requests return one stable alias (SQL pool serializes these calls)',async()=>{
  const rows=await Promise.all(Array.from({length:5},()=>call('short_parallel')));
  assert.equal(new Set(rows.map(r=>r.invites.ownCode)).size,1);
  const mapped=await db.collection('inviteCodes').where('uid','==','short_parallel').get();assert.equal(mapped.size,2);
});
test('invalid/unknown/self rollback; both aliases bind same immutable inviter idempotently',async()=>{
  const a=await call('short_a'),b=await call('short_b');
  for(const code of ['ABCDE','ABCDEFG','ABCDEFGH','ABCDEFGH234','ABC01I','ABCDEſ'])await reject(call('short_b','invites_bind',{code}),'invite_code_invalid');
  await reject(call('short_b','invites_bind',{code:'ZZZZZZ'}),'invite_not_found');
  for(const code of [b.invites.ownCode,codeFor('short_b')])await reject(call('short_b','invites_bind',{code}),'invite_self');
  await call('short_b','invites_bind',{code:a.invites.ownCode.toLowerCase()});
  const rebound=await call('short_b','invites_bind',{code:codeFor('short_a')});assert.equal(rebound.invites.inviterCode,a.invites.ownCode);
  await call('short_c');await reject(call('short_b','invites_bind',{code:codeFor('short_c')}),'invite_already_bound');
  for(const action of ['invites_state','invites_list']){const response=await call('short_b',action);canonical(response);assert.equal(response.invites.inviterCode,a.invites.ownCode);}
  assert.equal((await player('short_b').get()).data().inviterCode,a.invites.ownCode);
});
test('failed bind rolls back newly reserved short alias and new profile',async()=>{
  const uid='short_failed_new';await reject(call(uid,'invites_bind',{code:'ZZZZZY'}),'invite_not_found');
  assert.equal((await player(uid).get()).exists,false);assert.equal((await alias(shortCodeFor(uid,0)).get()).exists,false);
  assert.equal((await alias(codeFor(uid)).get()).exists,false);
});
test('short alias retains 5 real rounds, Google at both, 60/20 once, immutable aliases after reward',async()=>{
  const host='short_reward_host',friend='short_reward_friend';const h=await call(host);
  await call(friend,'invites_bind',{code:h.invites.ownCode});
  let last;
  for(let i=0;i<5;i++){
    const requestId=hash(`short_round_${++serial}`),r=await call(friend,'round_start',{requestId,rulesRevision:defaults.revision});
    await call(friend,'round_activate',{requestId});stamp+=2000;
    last={roundId:r.roundId,timeMs:2000,runDistance:0,riskCount:0,hadHelmet:false,hadJump:false};
    await call(friend,'round_finish',last);
    assert.equal((await call(host,'profile')).profile.wallet.energy,50);
  }
  const before=(await call(friend,'profile')).profile.wallet.energy;
  await call(friend,'google_link',{},true);assert.equal((await call(host,'profile')).profile.wallet.energy,50);
  await call(host,'google_link',{},true);
  assert.equal((await call(host,'profile',{},true)).profile.wallet.energy,110);
  assert.equal((await call(friend,'profile',{},true)).profile.wallet.energy,before+20);
  await call(friend,'round_finish',last,true);await call(friend,'invites_bind',{code:codeFor(host)},true);
  const history=await call(host,'invites_list',{},true);assert.equal(history.invites.paidRows.length,1);assert.equal(history.invites.rewardTotal,60);
  assert.equal(history.invites.paidRows[0].amount,60);assert.equal(history.invites.reward,60);
  canonical(await call(friend,'invites_state',{},true));assert.equal((await player(friend).get()).data().inviterCode,h.invites.ownCode);
  assert.equal((await call(host,'profile',{},true)).profile.wallet.energy,110);
});
