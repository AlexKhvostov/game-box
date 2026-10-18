import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
const local=await testDatabase();after(()=>local.close());
const db=new PostgresStore(local.pool);let clock=1000000;
const engine=createEngine({roundProof:{start(){},finish(){}},db,now:()=>clock,verifyPlay:async()=>({valid:true,expiresAt:clock+86400000,orderId:'test-only'})});
test('revoked subscription cannot restore paid rights on a later valid-looking response',async()=>{
  const command={action:'play_verify',productId:'energy_batteries_2_v1',purchaseToken:'test-revoked-sub-token'};
  await engine.execute('revoked_sub',command,{googleLinked:true});
  await engine.revokePurchase('revoked_sub',command.purchaseToken);
  await assert.rejects(engine.execute('revoked_sub',command,{googleLinked:true}),error=>error.code==='purchase_canceled');
  assert.equal((await engine.execute('revoked_sub',{action:'profile'})).profile.wallet.energySubscription,null);
});
test('background reconciliation keeps actual last player activity intact',async()=>{
  await engine.execute('background_user',{action:'guest'});
  const before=(await db.collection('players').doc('background_user').get()).data().lastActiveAt;
  clock+=60000;await engine.execute('background_user',{action:'profile'},{background:true});
  assert.equal((await db.collection('players').doc('background_user').get()).data().lastActiveAt,before);
});
test('future Telegram score cannot enter Android rankings and input cannot select platform',async()=>{
  await engine.execute('platform_user',{action:'guest'});
  await db.collection('scores').doc('telegram_score').set({uid:'platform_user',platform:'telegram',timeMs:5000,createdAt:clock});
  assert.equal((await engine.execute('platform_user',{action:'scores',period:'all',platform:'telegram'})).scores.length,0);
});
test('Telegram identifiers retain full text precision, uniqueness and cascade on account deletion',async()=>{
  const uid='12345678-1234-4234-8234-123456789abc';
  await local.pg.query('insert into auth.users(id) values($1)',[uid]);
  await local.pg.query("insert into untouch.external_identities(provider,subject,uid,username) values('telegram','9007199254740993',$1,'mutable_name')",[uid]);
  const row=(await local.pg.query('select subject from untouch.external_identities')).rows[0];assert.equal(row.subject,'9007199254740993');
  await assert.rejects(local.pg.query("insert into untouch.external_identities(provider,subject,uid) values('telegram','9007199254740993',$1)",[uid]),e=>e.code==='23505');
  await local.pg.query('delete from auth.users where id=$1',[uid]);
  assert.equal((await local.pg.query('select * from untouch.external_identities')).rows.length,0);
});
