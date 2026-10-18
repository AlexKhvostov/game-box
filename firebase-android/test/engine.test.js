'use strict';
const {test,before} = require('node:test');
const assert = require('node:assert/strict');
const functionsRequire = require('node:module').createRequire(require('node:path').resolve('functions/package.json'));
const {initializeApp} = functionsRequire('firebase-admin/app');
const {getFirestore} = functionsRequire('firebase-admin/firestore');
const {createEngine,codeFor} = require('../functions/src/engine');
const {defaults,hash,validatePolicy} = require('../functions/src/policy');
const {createPlayVerifier} = require('../functions/src/play');
const projectId='demo-untouch-android';
process.env.GCLOUD_PROJECT=projectId;
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8088';
const db=getFirestore(initializeApp({projectId}),'android-v1');
const runTag=require('node:crypto').randomBytes(4).toString('hex');
let stamp=Date.UTC(2026,9,16,12),serial=0;
const id=() => hash(`operation:${++serial}`);
const unique=prefix => `${prefix}_${runTag}_${++serial}`;
const identity={googleLinked:true,name:'Test',email:'not-persisted@example.invalid'};
const engine=createEngine({db,now:() => stamp,verifyPlay:async (uid,sku,token) => ({valid:true,consumed:token.startsWith('consumed'),expiresAt:stamp+86400000,orderId:hash(token),endConfirmed:false})});
const call=(uid,action,args={},google={}) => engine.execute(uid,{action,...args},google);
const op=(uid,kind,args={},operationId=id(),google={}) => call(uid,'wallet_operation',{kind,args,operationId},google);
const rejects=(promise,code) => assert.rejects(promise,e => e.code === code);
before(async () => {await db.collection('_tests').doc('ready').set({at:stamp});});

test('new profile starts at 50 once; old MySQL fields cannot seed or choose UID',async () => {
  const uid=unique('new');
  const a=await call(uid,'guest',{energy:999999,owner:'firebase:someone-else',secret:'legacy'});
  assert.equal(a.profile.id,`firebase:${uid}`);assert.equal(a.profile.wallet.energy,50);
  assert.equal((await call(uid,'guest')).profile.wallet.energy,50);
  assert.equal((await db.collection('players').doc('someone-else').get()).exists,false);
  assert.equal(a.profile.wallet.tokens,0);
  await rejects(call(unique('rename_impostor'),'rename',{nickname:a.profile.nickname}),'nickname_taken');
});
test('concurrent duplicate hidden taps credit exactly 20; changed payload conflicts',async () => {
  const uid=unique('tap'),operationId=id();await call(uid,'guest');
  await Promise.all(Array.from({length:6},()=>op(uid,'energy_hidden_tap',{},operationId)));
  assert.equal((await call(uid,'profile')).profile.wallet.energy,70);
  await rejects(op(uid,'energy_bonus_claim',{},operationId),'operation_conflict');
  await rejects(op(uid,'energy_hidden_tap',{amount:999}),'operation_invalid');
  await op(uid,'energy_hidden_tap');assert.equal((await call(uid,'profile')).profile.wallet.energy,90);
});
test('bonus 30 and 8h server clock; lost reply replay; racing distinct nonces only one award',async () => {
  const uid=unique('bonus');await call(uid,'guest');const operationId=id();
  const a=await op(uid,'energy_bonus_claim',{},operationId);
  assert.equal(a.profile.wallet.energy,80);assert.equal(a.profile.wallet.simpleBonus.nextAt,stamp+28800000);
  assert.deepEqual((await op(uid,'energy_bonus_claim',{},operationId)).bonusClaim,a.bonusClaim);
  await rejects(op(uid,'energy_bonus_claim',{}),'bonus_not_ready');
  stamp+=28800000;
  const race=await Promise.allSettled([op(uid,'energy_bonus_claim'),op(uid,'energy_bonus_claim')]);
  assert.equal(race.filter(r=>r.status === 'fulfilled').length,1);
  assert.equal((await call(uid,'profile')).profile.wallet.energy,110);
});
test('pending paid entitlement blocks bonus until Google reconciliation',async () => {
  const uid=unique('pending');await call(uid,'guest');
  await db.collection('players').doc(uid).update({'wallet.energySubscription':{productId:'energy_batteries_2_v1',batteryCount:2,expiresAt:stamp-1,endConfirmed:false}});
  const p=await call(uid,'profile');assert.equal(p.profile.wallet.energySubscription.awaitingReconciliation,true);
  await rejects(op(uid,'energy_bonus_claim'),'subscription_verification_pending');
});
test('video grants 40 only with server cooldown; owner isolation; no local amount',async () => {
  const uid=unique('video');await op(uid,'watch_ad');
  assert.equal((await call(uid,'profile')).profile.wallet.energy,90);
  await rejects(op(uid,'watch_ad'),'ad_not_ready');
  stamp+=120000;await op(uid,'watch_ad');assert.equal((await call(uid,'profile')).profile.wallet.energy,130);
  await rejects(op(uid,'watch_ad',{energy:999999}),'operation_invalid');
  assert.equal((await call(unique('other'),'guest')).profile.wallet.energy,50);
});
test('achievement/age/google require server state and are once-only across new nonces',async () => {
  const uid=unique('task');await rejects(op(uid,'energy_reward',{id:'google'}),'bonus_locked');
  await rejects(op(uid,'energy_reward',{id:'age'}),'bonus_locked');
  await rejects(op(uid,'energy_reward',{id:'survive_10s'}),'bonus_locked');
  await rejects(op(uid,'energy_age_completed',{age:18}),'operation_invalid');
  await op(uid,'energy_age_completed');await op(uid,'energy_reward',{id:'age'});await op(uid,'energy_reward',{id:'age'});
  await op(uid,'energy_reward',{id:'google'},id(),identity);
  assert.equal((await call(uid,'profile')).profile.wallet.energy,70);
  assert.equal(JSON.stringify((await db.collection('players').doc(uid).get()).data()).includes('not-persisted'),false);
});
test('feedback validated and atomically credited once; no external messages',async () => {
  const uid=unique('feedback');await rejects(op(uid,'energy_feedback',{comment:'short'}),'feedback_length');
  await op(uid,'energy_feedback',{comment:'This is a sufficiently long test comment',rating:4});
  await op(uid,'energy_feedback',{comment:'This is another sufficiently long comment'});
  assert.equal((await call(uid,'profile')).profile.wallet.energy,70);
  assert.equal((await db.collection('feedback').where('uid','==',uid).get()).size,1);
});
test('nickname uniqueness and Google privacy are server controlled',async () => {
  const a=unique('name'),b=unique('name');await call(a,'rename',{nickname:`Тест ${runTag}`});
  await rejects(call(b,'rename',{nickname:`ТЕСТ ${runTag}`.toUpperCase()}),'nickname_taken');
  await rejects(call(a,'rename',{nickname:'<script>'}),'nickname_invalid');
  await op(a,'google_privacy',{hide:false});assert.equal((await call(a,'profile')).profile.hideGoogleAccount,false);
});
async function finished(uid,{helmet=false,jump=false,timeMs=2000,runDistance=0,riskCount=0}={}) {
  const requestId=id();
  const r=await call(uid,'round_start',{requestId,rulesRevision:defaults.revision,helmet,jump});
  await call(uid,'round_activate',{requestId});stamp+=timeMs;
  const result={roundId:r.roundId,timeMs,runDistance,riskCount,hadHelmet:helmet,hadJump:jump};
  return {r,result,response:await call(uid,'round_finish',result)};
}
test('round 1+helmet+jump costs 3; cancellation refunds frozen cost once before activation',async () => {
  const uid=unique('cancel'),requestId=id(),args={requestId,rulesRevision:defaults.revision,helmet:true,jump:true};
  const r=await call(uid,'round_start',args);assert.equal(r.profile.wallet.energy,47);assert.equal(r.attemptCost,3);
  assert.equal((await call(uid,'round_start',args)).profile.wallet.energy,47);
  await call(uid,'round_cancel',{requestId});await call(uid,'round_cancel',{requestId});
  assert.equal((await call(uid,'profile')).profile.wallet.energy,50);
  await rejects(call(uid,'round_start',args),'round_canceled');
});
test('active round cannot refund; forged owner, boosts, clock and duplicate changed result rejected',async () => {
  const uid=unique('round'),requestId=id();
  const r=await call(uid,'round_start',{requestId,rulesRevision:defaults.revision});await call(uid,'round_activate',{requestId});
  await rejects(call(uid,'round_cancel',{requestId}),'round_already_started');
  const result={roundId:r.roundId,timeMs:10000,runDistance:1000,riskCount:8,hadHelmet:false,hadJump:false};
  await rejects(call(uid,'round_finish',result),'result_time_invalid');
  stamp+=10000;await rejects(call(unique('intruder'),'round_finish',result),'round_not_found');
  await rejects(call(uid,'round_finish',{...result,hadHelmet:true}),'result_boost_invalid');
  const response=await call(uid,'round_finish',result);assert.equal(response.energyReward,2);assert.equal(response.profile.wallet.energy,51);
  assert.equal((await call(uid,'round_finish',result)).profile.wallet.energy,51);
  await rejects(call(uid,'round_finish',{...result,timeMs:9999}),'operation_conflict');
});
test('round freezes policy while new requests must negotiate active revision',async () => {
  const uid=unique('policy');let policy=structuredClone(defaults);
  const en=createEngine({db,now:()=>stamp,getPolicy:async()=>policy});
  const requestId=id(),r=await en.execute(uid,{action:'round_start',requestId,rulesRevision:policy.revision});
  await en.execute(uid,{action:'round_activate',requestId});
  policy.config.economy.runRewardEvery=1;policy.revision=hash(policy.config);stamp+=2000;
  const result=await en.execute(uid,{action:'round_finish',roundId:r.roundId,timeMs:2000,runDistance:1000,riskCount:0});
  assert.equal(result.energyReward,1);
  await rejects(en.execute(uid,{action:'round_start',requestId:id(),rulesRevision:defaults.revision}),'rules_changed');
});
test('Play verified receipts are globally owned and idempotent; consumed unknown token rejected',async () => {
  const uid=unique('purchase'),token=unique('token_12345678');
  await rejects(call(uid,'play_verify',{productId:'energy_100_v1',purchaseToken:token}),'purchase_requires_recovery');
  const a=await call(uid,'play_verify',{productId:'energy_100_v1',purchaseToken:token},identity);assert.equal(a.profile.wallet.energy,150);
  assert.equal((await call(uid,'play_verify',{productId:'energy_100_v1',purchaseToken:token},identity)).profile.wallet.energy,150);
  await rejects(call(unique('thief'),'play_verify',{productId:'energy_100_v1',purchaseToken:token},identity),'purchase_owner_invalid');
  await rejects(call(uid,'play_verify',{productId:'energy_100_v1',purchaseToken:unique('consumed')},identity),'purchase_already_consumed');
});
test('Google subscription rights select bonus60/150 and expired confirmed rights select30',async () => {
  for (const [tier,amount] of [[2,60],[5,150]]) {
    const uid=unique('tier'),sku=`energy_batteries_${tier}_v1`;
    await call(uid,'play_verify',{productId:sku,purchaseToken:unique('tier_token')},identity);
    assert.equal((await op(uid,'energy_bonus_claim')).bonusClaim.amount,amount);
  }
  const uid=unique('expired');await call(uid,'guest');
  await db.collection('players').doc(uid).update({'wallet.energySubscription':{batteryCount:5,expiresAt:stamp-1,endConfirmed:true}});
  assert.equal((await op(uid,'energy_bonus_claim')).bonusClaim.amount,30);
});
test('SKU quote immutable and cannot switch product with same nonce',async () => {
  const uid=unique('quote'),requestId=id();const q=await call(uid,'play_quote',{requestId,productId:'energy_100_v1'});
  assert.equal(q.quote.terms.amount,100);assert.equal(q.quote.immutableSku,true);
  await rejects(call(uid,'play_quote',{requestId,productId:'energy_250_v1'}),'operation_conflict');
});
test('inviter60 only after5 confirmed games and Google, no repeated payout on unlink/relink',async () => {
  const host=unique('host'),guest=unique('invitee');await call(host,'guest');
  const bind=await call(guest,'invites_bind',{code:codeFor(host)});assert.equal(bind.invites.bonusStatus,'waiting_games');
  await rejects(call(guest,'invites_bind',{code:codeFor(guest)}),'invite_already_bound');
  await rejects(call(host,'invites_bind',{code:codeFor(host)}),'invite_self');
  for(let i=0;i<5;i++) await finished(guest);
  assert.equal((await call(host,'profile')).profile.wallet.energy,50);
  await call(guest,'google_link',{},identity);
  assert.equal((await call(host,'profile')).profile.wallet.energy,50);
  await call(host,'google_link',{},identity);
  assert.equal((await call(host,'profile')).profile.wallet.energy,110);
  await call(guest,'google_unlink');await call(guest,'google_link',{},identity);
  const list=await call(host,'invites_list');assert.equal(list.invites.paidRows.length,1);assert.equal(list.invites.rewardTotal,60);
  assert.equal((await call(guest,'profile')).profile.wallet.energy,65);
});
test('Firebase ranking is private-data free and one best row per player for all periods',async () => {
  const uid=unique('board');await finished(uid,{timeMs:4000});await finished(uid,{timeMs:3000});
  for (const period of ['all','day','week','month','year']) {
    const result=await call(uid,'scores',{period});const rows=result.scores.filter(r=>r.uid === uid);
    assert.equal(rows.length,1);assert.equal(rows[0].timeMs,4000);assert.equal(JSON.stringify(result).includes('email'),false);
  }
});
test('Play REST validation checks state, SKU and obfuscated owner; no actual payment',async () => {
  const uid='play_mock',account=hash(`firebase:${uid}`);
  const good=createPlayVerifier({request:async()=>({purchaseState:0,consumptionState:0,obfuscatedExternalAccountId:account,orderId:'GPA.test'})});
  assert.equal((await good.verify(uid,'energy_100_v1','test-token-123')).valid,true);
  const bad=createPlayVerifier({request:async()=>({purchaseState:0,obfuscatedExternalAccountId:'someone-else'})});
  await rejects(bad.verify(uid,'energy_100_v1','test-token-123'),'purchase_owner_invalid');
});
test('policy hash and critical ranges reject malformed configuration',() => {
  const broken=structuredClone(defaults);broken.config.economy.androidEnergyV2.baseAttemptCost=-1;broken.revision=hash(broken.config);
  assert.throws(()=>validatePolicy(broken));assert.throws(()=>validatePolicy({...defaults,revision:'0'.repeat(64)}));
});
test('deferred Google replacement keeps outgoing tier until its paid expiry',async()=>{
  const uid='deferred_mock',account=hash(`firebase:${uid}`),end=Date.now()+86400000;
  const response={subscriptionState:'SUBSCRIPTION_STATE_ACTIVE',externalAccountIdentifiers:{obfuscatedExternalAccountId:account},linkedPurchaseToken:'old-five-token',lineItems:[
    {productId:'energy_batteries_2_v1',offerDetails:{basePlanId:'weekly'}},
    {productId:'energy_batteries_5_v1',offerDetails:{basePlanId:'weekly'},expiryTime:new Date(end).toISOString(),deferredItemReplacement:{productId:'energy_batteries_2_v1'},latestSuccessfulOrderId:'GPA.old'}
  ]};
  const verifier=createPlayVerifier({request:async()=>response});
  const verified=await verifier.verify(uid,'energy_batteries_2_v1','new-two-token');
  assert.equal(verified.activeProductId,'energy_batteries_5_v1');assert.equal(verified.expiresAt,end);
  response.lineItems[1].expiryTime=new Date(Date.now()-1000).toISOString();
  response.lineItems[0].expiryTime=new Date(end+86400000).toISOString();
  assert.equal((await verifier.verify(uid,'energy_batteries_2_v1','new-two-token')).activeProductId,'energy_batteries_2_v1');
});
test('replaced token cannot overwrite new rights; sync survives Google unlink; refund debited once',async()=>{
  const uid=unique('replacement'),oldToken=unique('old_token'),newToken=unique('new_token');
  const en=createEngine({db,now:()=>stamp,verifyPlay:async(u,sku,t)=>({valid:true,expiresAt:stamp+86400000,orderId:t,activeProductId:sku,
    linkedPurchaseToken:t===newToken ? oldToken : null})});
  await en.execute(uid,{action:'play_verify',productId:'energy_batteries_2_v1',purchaseToken:oldToken},identity);
  await en.execute(uid,{action:'play_verify',productId:'energy_batteries_5_v1',purchaseToken:newToken},identity);
  await en.execute(uid,{action:'play_verify',productId:'energy_batteries_2_v1',purchaseToken:oldToken},identity);
  assert.equal((await en.execute(uid,{action:'play_sync'})).profile.wallet.energySubscription.batteryCount,5);
  const token=unique('refund_token');await call(uid,'play_verify',{productId:'energy_100_v1',purchaseToken:token},identity);
  await engine.revokePurchase(uid,token);await engine.revokePurchase(uid,token);
  assert.equal((await call(uid,'profile')).profile.wallet.energy,50);
});
test('public Google name follows privacy immediately and never exposes email in cached ranking',async()=>{
  const uid=unique('privacy');await call(uid,'google_link',{},identity);await finished(uid);
  await op(uid,'google_privacy',{hide:false},id(),identity);
  let board=await call(unique('viewer'),'scores',{period:'all'});
  assert.equal(board.scores.find(r=>r.uid === uid).googleName,'Test');assert.equal(JSON.stringify(board).includes(identity.email),false);
  await op(uid,'google_privacy',{hide:true},id(),identity);
  board=await call(unique('viewer'),'scores',{period:'all'});
  assert.equal(board.scores.find(r=>r.uid === uid).googleName,null);
});
test('Play consume/acknowledge retry does not fail after a lost successful store response',async()=>{
  let consumed=false,posts=0;
  const verifier=createPlayVerifier({request:async request=>{
    if(request.method === 'GET') return {purchaseState:0,consumptionState:consumed?1:0};
    posts++;consumed=true;return {};
  }});
  await verifier.acknowledge('energy_100_v1','test-lost-reply-token');
  await verifier.acknowledge('energy_100_v1','test-lost-reply-token');
  assert.equal(posts,1);
  const sub=createPlayVerifier({request:async request=>{
    assert.equal(request.method,'GET');return {acknowledgementState:'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'};
  }});
  await sub.acknowledge('energy_batteries_2_v1','test-sub-token');
});
