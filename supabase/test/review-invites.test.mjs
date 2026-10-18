import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {createInviteReconciler} from '../functions/_shared/invite-reconcile.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
let lookups=0;
const engine=createEngine({db,googleLinkedForUid:async()=>{lookups++;return true;}});

test('list of120 unpaid invitations does no Auth fan-out',async()=>{
 await engine.execute('host',{action:'guest'},{googleLinked:true});
 for(let n=0;n<120;n++)await db.collection('invitations').doc('pending'+n).set({inviterUid:'host',boundAt:n,rewardedAt:null});
 lookups=0;
 for(const action of ['invites_state','invites_list'])await engine.execute('host',{action},{googleLinked:true});
 assert.equal(lookups,0);
 await db.runTransaction(async tx=>{for(let n=0;n<120;n++)tx.delete(db.collection('invitations').doc('pending'+n));});
});

test('durable bounded worker wraps cursor, retries failure and pays each side exactly once',async()=>{
 await engine.execute('recover-host',{action:'guest'},{googleLinked:false});
 const host=await engine.execute('recover-host',{action:'invites_state'},{googleLinked:false});
 for(let n=0;n<6;n++){
  const uid='a-friend'+n;
  await engine.execute(uid,{action:'invites_bind',code:host.invites.ownCode},{googleLinked:false});
  await db.collection('players').doc(uid).update({completedGames:5,googleLinked:true});
 }
 await db.collection('players').doc('recover-host').update({googleLinked:true});
 let fail=true,checked=0;
 const make=()=>createInviteReconciler({db,pool:local.pool,engine,batchSize:3,getIdentity:async uid=>{
  checked++;if(uid==='a-friend1'&&fail)throw Error('temporary');return{googleLinked:true};
 }});
 const first=await make()();assert.equal(first.checked,2);assert.equal(first.failed,1);assert.equal(checked,3);
 await make()(); // New worker instance resumes the persisted cursor.
 assert.equal((await db.collection('players').doc('recover-host').get()).data().wallet.energy,350);
 fail=false;
 await make()(); // End of scan wraps, without losing the failed invitation.
 await make()();
 const energy=(await db.collection('players').doc('recover-host').get()).data().wallet.energy;
 assert.equal(energy,410);
 for(let n=0;n<6;n++)assert.equal((await db.collection('players').doc('a-friend'+n).get()).data().wallet.energy,70);
 await make()();assert.equal((await db.collection('players').doc('recover-host').get()).data().wallet.energy,410);
});
