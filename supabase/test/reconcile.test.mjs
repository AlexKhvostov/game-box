import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {createReconciler,reconcileAuthorized} from '../functions/_shared/play-reconcile.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
const now=()=>1800000000000;let calls=0,voided=[];
const engine=createEngine({db,now,verifyPlay:async(uid,sku,token)=>{
  calls++;return{valid:true,expiresAt:now()+86400000,orderId:`order_${token}`};
}});
const worker=createReconciler({db,pool:local.pool,engine,now,getIdentity:async()=>({googleLinked:false}),acknowledge:async r=>db.collection('purchases').doc((await import('../functions/_shared/core/policy.mjs')).hash(r.token)).update({acknowledged:true}),listVoided:async()=>({voidedPurchases:voided})});
test('scheduled endpoint requires exact nonempty server credential',()=>{
  const secret='a'.repeat(64);assert.equal(reconcileAuthorized(`Bearer ${secret}`,secret),true);
  for(const input of ['',null,`Bearer ${secret}x`,`Bearer ${'b'.repeat(64)}`])assert.equal(reconcileAuthorized(input,secret),false);
  assert.equal(reconcileAuthorized('Bearer ',''),false);
});
test('worker refreshes known subscriptions, retries acknowledgement, leaves last player activity unchanged',async()=>{
  const uid='reconcile_user';await engine.execute(uid,{action:'play_verify',productId:'energy_batteries_2_v1',purchaseToken:'known-sub-token'},{googleLinked:true});
  const before=(await db.collection('players').doc(uid).get()).data().lastActiveAt;
  calls=0;const result=await worker();assert.equal(result.checked,1);assert.equal(calls,1);
  assert.equal((await db.collection('players').doc(uid).get()).data().lastActiveAt,before);
});
test('refunds match both known purchase token and exact order; old renewed order cannot revoke newer rights',async()=>{
  voided=[{purchaseToken:'known-sub-token',orderId:'older-order'},{purchaseToken:'unknown-token',orderId:'other'}];
  assert.equal((await worker()).revoked,0);
  voided=[{purchaseToken:'known-sub-token',orderId:'order_known-sub-token'}];
  assert.equal((await worker()).revoked,1);
  assert.equal((await worker()).revoked,0);
  assert.equal((await db.collection('players').doc('reconcile_user').get()).data().wallet.energySubscription,null);
});
test('live lease prevents two cron invocations from processing the same batch',async()=>{
  await db.collection('system').doc('play-reconcile').update({leaseUntil:now()+60000,leaseOwner:'other_worker'});
  assert.equal((await worker()).skipped,'already_running');
});
