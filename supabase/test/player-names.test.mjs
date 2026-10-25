import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {fallbackNickname} from '../functions/_shared/player-names.mjs';
const local=await testDatabase(),db=new PostgresStore(local.pool);after(()=>local.close());
const engine=createEngine({db,roundProof:{start(){},finish(){}}}),google=email=>({googleLinked:true,email}),tg=username=>({platform:'telegram',telegramVerified:true,username});
test('short fallback is stable English and resolves occupied names without taking another owner',async()=>{
 const uid='short-name';await db.collection('names').doc(hash(fallbackNickname(uid))).set({uid:'someone-else'});
 const a=await engine.execute(uid,{action:'guest'});assert.match(a.profile.nickname,/^player-[a-z0-9]{3}$/);assert.notEqual(a.profile.nickname,fallbackNickname(uid));assert.equal((await engine.execute(uid,{action:'guest'})).profile.nickname,a.profile.nickname);
});
test('Google localpart and Telegram username are chosen on initial verified login',async()=>{
 assert.equal((await engine.execute('google-name',{action:'guest'},google('alice.test@example.invalid'))).profile.nickname,'alice.test');
 assert.equal((await engine.execute('tg-name',{action:'guest'},tg('telegram_name'))).profile.nickname,'telegram_name');
 assert.match((await engine.execute('tg-no-username',{action:'guest'},tg(null))).profile.nickname,/^player-[a-z0-9]{3}$/);
});
test('account connected before first attempt replaces only the auto fallback; custom name stays',async()=>{
 await engine.execute('early-name',{action:'guest'});assert.equal((await engine.execute('early-name',{action:'google_link'},google('early@example.invalid'))).profile.nickname,'early');
 await engine.execute('custom-name',{action:'guest'});await engine.execute('custom-name',{action:'rename',nickname:'Chosen by player'});
 assert.equal((await engine.execute('custom-name',{action:'google_link'},google('different@example.invalid'))).profile.nickname,'Chosen by player');
});
test('first attempt permanently locks automatic account rename including refunded cancellation',async()=>{
 const uid='started-name',before=await engine.execute(uid,{action:'guest'}),requestId=hash('name-round');
 const start=await engine.execute(uid,{action:'round_start',requestId,revision:defaults.config.economy.androidEnergyV2.revision,rulesRevision:defaults.revision});
 await engine.execute(uid,{action:'round_cancel',requestId,roundId:start.roundId});
 assert.equal((await engine.execute(uid,{action:'google_link'},google('late@example.invalid'))).profile.nickname,before.profile.nickname);
});
test('locally prepared attempts can lock autorename and banned/long/colliding identity names do not break login',async()=>{
 const before=await engine.execute('local-start',{action:'guest'});assert.equal((await engine.execute('local-start',{action:'guest',nicknameAutoLocked:true},google('after-local-start@example.invalid'))).profile.nickname,before.profile.nickname);
 assert.match((await engine.execute('bad-identity',{action:'guest'},google('fuck@example.invalid'))).profile.nickname,/^player-/);
 const long='a'.repeat(80);const a=await engine.execute('long-first',{action:'guest'},tg(long)),b=await engine.execute('long-second',{action:'guest'},tg(long));assert.equal(a.profile.nickname.length,24);assert.ok(b.profile.nickname.length<=24);assert.notEqual(a.profile.nickname,b.profile.nickname);
});
