import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createSupportAdmin} from '../functions/_shared/support-admin.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
const actor='12345678-1234-4234-8234-123456789abc',target='22345678-1234-4234-8234-123456789abc',friend='32345678-1234-4234-8234-123456789abc';
const identities=new Map([[actor,{id:actor,identities:[]}],[target,{id:target,identities:[{provider:'google',identity_data:{email:'player@example.invalid'}}]}],[friend,{id:friend,identities:[]}]]);
let deletes=0,deleteFailure=false;
const auth={getUserById:async id=>({data:{user:identities.get(id)},error:identities.has(id)?null:{status:404}}),deleteUser:async id=>{
  if(deleteFailure)return{error:{status:503}};deletes++;identities.delete(id);await local.pg.query('delete from auth.users where id=$1',[id]);return{error:null};
}};
await local.pg.query('insert into auth.users(id,email) values($1,$4),($2,$5),($3,null)',[actor,target,friend,'admin@example.invalid','player@example.invalid']);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
const engine=createEngine({db});await engine.execute(target,{action:'guest'});await engine.execute(friend,{action:'guest'});
const execute=createSupportAdmin({db:local.pool,auth});
const id=n=>`${n}2345678-1234-4234-8234-123456789abc`;
test('support denies non-admins and private email search finds a user without exposing Auth directory',async()=>{
  await assert.rejects(execute(friend,{action:'list'}),e=>e.code==='admin_required');
  const found=await execute(actor,{action:'list',search:'PLAYER@example.invalid'});assert.equal(found.users.length,1);assert.equal(found.users[0].id,target);assert.equal(found.users[0].energy,50);
});
test('directory includes Auth-only accounts, protected administrator has no editable game balance',async()=>{
  const all=await execute(actor,{action:'list'});assert.equal(all.total,3);assert.equal(all.users.length,3);
  const admin=await execute(actor,{action:'detail',userId:actor});assert.equal(admin.user.status,'not_started');assert.equal(admin.deleteAllowed,false);assert.equal(admin.user.energy,0);
});

test('only admins can read internal feedback in the matching player card',async()=>{
  await db.collection('feedback').doc('feedback_current').set({uid:target,comment:'Controls could be clearer. <script>untrusted</script>',rating:1,createdAt:1234});
  const detail=await execute(actor,{action:'detail',userId:target});
  assert.equal(detail.feedback.length,1);assert.equal(detail.feedback[0].rating,1);
  assert.match(detail.feedback[0].comment,/Controls/);
  assert.equal((await execute(actor,{action:'detail',userId:friend})).feedback.length,0);
  await assert.rejects(execute(friend,{action:'detail',userId:target}),e=>e.code==='admin_required');
});
test('manual energy is atomic, audited, stale-version protected, repeat does not grant twice',async()=>{
  const detail=await execute(actor,{action:'detail',userId:target});
  const command={action:'set_energy',userId:target,requestId:id(4),expectedVersion:detail.user.version,energy:80,reason:'compensation'};
  const changed=await execute(actor,command);assert.deepEqual([changed.before,changed.after,changed.delta],[50,80,30]);
  const repeated=await execute(actor,command);assert.equal(repeated.replayed,true);
  await assert.rejects(execute(actor,{...command,energy:90}),e=>e.code==='operation_conflict');
  await assert.rejects(execute(actor,{...command,requestId:id(5),energy:90}),e=>e.code==='support_conflict');
  assert.equal((await db.collection('players').doc(target).get()).data().wallet.energy,80);
});
test('delete requires exact user confirmation and cannot delete administrator',async()=>{
  const detail=await execute(actor,{action:'delete_preview',userId:target});
  await assert.rejects(execute(actor,{action:'delete_user',userId:actor,requestId:id(6)}),e=>e.code==='cannot_delete_administrator');
  await assert.rejects(execute(actor,{action:'delete_user',userId:target,requestId:id(7),expectedVersion:detail.user.version,confirmation:'wrong',acceptSubscriptionNotice:true}),e=>e.code==='delete_confirmation_required');assert.equal(deletes,0);
});
test('failed external deletion freezes only target; retry cleans personal data, preserves other players and purchase anti-replay tombstones',async()=>{
  const detail=await execute(actor,{action:'delete_preview',userId:target});
  await db.collection('purchases').doc('receipt_hash').set({uid:target,token:'secret-token',orderId:'private-order',productId:'energy_100_v1'});
  await db.collection('scores').doc('old_score').set({platform:'android',uid:target,id:'old_score',playerName:'private-name',timeMs:1000,createdAt:Date.now()});
  assert.equal((await engine.execute(friend,{action:'scores',period:'all'})).scores.length,1);
  await db.collection('players').doc(friend).update({inviterUid:target,inviterCode:'ABCDEFGH2345'});
  const command={action:'delete_user',userId:target,requestId:id(8),expectedVersion:detail.user.version,confirmation:target,acceptSubscriptionNotice:true};
  deleteFailure=true;await assert.rejects(execute(actor,command),e=>e.code==='auth_delete_unavailable');
  await assert.rejects(engine.execute(target,{action:'guest'}),e=>e.code==='profile_disabled');
  assert.equal((await db.collection('players').doc(friend).get()).exists,true);
  deleteFailure=false;assert.equal((await execute(actor,command)).deleted,true);assert.equal(deletes,1);
  assert.equal((await db.collection('players').doc(target).get()).exists,false);assert.equal((await db.collection('scores').doc('old_score').get()).exists,false);
  const receipt=(await db.collection('purchases').doc('receipt_hash').get()).data();assert.deepEqual(receipt,{deleted:true,revoked:true,acknowledged:true});
  const remaining=(await db.collection('players').doc(friend).get()).data();assert.equal(remaining.wallet.energy,50);assert.equal(remaining.inviterUid,'deleted');
  assert.equal((await engine.execute(friend,{action:'scores',period:'all'})).scores.length,0,'cached ranking must remove deleted profile immediately');
  assert.equal((await execute(actor,command)).replayed,true);assert.equal(deletes,1);
});
test('Auth-only account can be deleted without creating a playable profile or touching another account',async()=>{
  const guest=id(9);identities.set(guest,{id:guest,identities:[]});await local.pg.query('insert into auth.users(id) values($1)',[guest]);
  const detail=await execute(actor,{action:'delete_preview',userId:guest});assert.equal(detail.user.status,'not_started');
  await execute(actor,{action:'delete_user',userId:guest,requestId:id(1),expectedVersion:0,confirmation:guest,acceptSubscriptionNotice:true});
  assert.equal(identities.has(guest),false);assert.equal((await db.collection('players').doc(guest).get()).exists,false);
  assert.equal((await db.collection('players').doc(friend).get()).exists,true);
});
