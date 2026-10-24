import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
import {verifyTelegramInitData,createTelegramIdentityResolver,createTelegramInviteGuard} from '../functions/_shared/telegram-auth.mjs';
import {createTelegramApi} from '../functions/_shared/telegram-api.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
import {createSupportAdmin} from '../functions/_shared/support-admin.mjs';
import {createTelegramStars} from '../functions/_shared/telegram-stars.mjs';
import '../../telegram-app/public/kernel/android-world.js';

const local=await testDatabase();after(()=>local.close());
await local.pg.exec(await fs.readFile(new URL('../migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8'));
await local.pg.exec(await fs.readFile(new URL('../migrations/20261019223954_telegram_platform_core.sql',import.meta.url),'utf8'));
await local.pg.exec(await fs.readFile(new URL('../migrations/20261022085951_telegram_bot_namespaces.sql',import.meta.url),'utf8'));
const db=new PostgresStore(local.pool);
let stamp=Date.UTC(2026,9,20,1),serial=0;
const token='123456789:'+ 'local-fixture-not-a-real-token-12345';
const signed=(fields={},botToken=token)=>{
  const params=new URLSearchParams({auth_date:String(Math.floor(stamp/1000)),user:JSON.stringify({id:100001,first_name:'QA',username:'qa_fixture'}),...fields});
  const check=[...params].sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,v])=>`${k}=${v}`).join('\n');
  const secret=crypto.createHmac('sha256','WebAppData').update(botToken).digest();
  params.set('hash',crypto.createHmac('sha256',secret).update(check).digest('hex'));return params.toString();
};
const resolve=createTelegramIdentityResolver({pool:local.pool,botToken:token,now:()=>stamp});
const engine=createEngine({db,now:()=>stamp});
const checkInvite=createTelegramInviteGuard({pool:local.pool});
const api=createTelegramApi({engine,resolveIdentity:resolve,checkInvite});
const opid=()=>hash(`tg-qa-operation-${++serial}`);
const identity=platform=>platform==='telegram'?{platform,telegramVerified:true,username:'qa_fixture'}:{platform,googleLinked:true};
const rejects=(promise,code)=>assert.rejects(promise,e=>e.code===code);
const k=input=>JSON.parse(globalThis.untouchKernel(JSON.stringify(input)));

test('Telegram HMAC validates only signed user, rejects duplicates/tampering/stale/future/wrong bot',()=>{
  const raw=signed({signature:'signed-third-party-field'});
  assert.equal(verifyTelegramInitData(raw,token,{now:()=>stamp}).subject,'100001');
  for(const bad of [raw.replace('100001','100002'),raw+'&user=x',raw+'&hash=0'])assert.throws(()=>verifyTelegramInitData(bad,token,{now:()=>stamp}));
  assert.throws(()=>verifyTelegramInitData(raw,token+'x',{now:()=>stamp}));
  assert.throws(()=>verifyTelegramInitData(signed({auth_date:String(Math.floor(stamp/1000)-86401)}),token,{now:()=>stamp}),e=>e.code==='telegram_session_expired');
  assert.throws(()=>verifyTelegramInitData(signed({auth_date:String(Math.floor(stamp/1000)+60)}),token,{now:()=>stamp}));
});
test('Telegram HMAC does not depend on the Node global Buffer in the Edge runtime',()=>{
  const raw=signed(),saved=globalThis.Buffer;
  try{globalThis.Buffer=undefined;assert.equal(verifyTelegramInitData(raw,token,{now:()=>stamp}).subject,'100001');}
  finally{globalThis.Buffer=saved;}
});

test('Telegram mapping is stable and accounts stay separate for the same user in different bots',async()=>{
  const a=await resolve(signed()),b=await resolve(signed({user:JSON.stringify({id:100001,first_name:'Renamed'})}));
  assert.equal(a.uid,b.uid);assert.equal(b.username,null);
  const otherBot=createTelegramIdentityResolver({pool:local.pool,botToken:'987654321:'+token.split(':')[1],now:()=>stamp});
  const other=await otherBot(signed({},'987654321:'+token.split(':')[1]));
  assert.notEqual(other.uid,a.uid);assert.equal(other.subject,a.subject);assert.notEqual(other.botId,a.botId);
  assert.equal((await resolve(signed())).uid,a.uid);
});
test('Only configured bot signatures are accepted; expired sessions cannot fall through to another bot',async()=>{
  const otherToken='987654321:'+token.split(':')[1];
  const both=createTelegramIdentityResolver({pool:local.pool,botToken:otherToken,additionalBotTokens:[token],now:()=>stamp});
  assert.equal((await both(signed())).uid,(await resolve(signed())).uid);
  assert.equal((await both(signed({},otherToken))).botId,'987654321');
  await rejects(both(signed({},'555555555:'+token.split(':')[1])),'telegram_unauthorized');
  await rejects(both(signed({auth_date:String(Math.floor(stamp/1000)-86401)})),'telegram_session_expired');
});
test('Main and test bot accounts do not inherit each other\'s wallet or completed games',async()=>{
  const otherToken='987654321:'+token.split(':')[1],fields={user:JSON.stringify({id:100080,first_name:'Independent'})};
  const both=createTelegramIdentityResolver({pool:local.pool,botToken:otherToken,additionalBotTokens:[token],now:()=>stamp});
  const mainApi=createTelegramApi({engine,resolveIdentity:both,miniAppLink:'https://t.me/UntouchGameBot',checkInvite});
  const testProfile=await api(signed(fields),{action:'guest'});
  await api(signed(fields),{action:'wallet_operation',operationId:opid(),kind:'energy_reward',args:{id:'telegram'}});
  const mainProfile=await mainApi(signed(fields,otherToken),{action:'guest'});
  assert.notEqual(mainProfile.profile.id,testProfile.profile.id);
  assert.equal(mainProfile.profile.wallet.energy,50);
  assert.equal(mainProfile.profile.wallet.gamesStarted,0);
  assert.ok((await api(signed(fields),{action:'profile'})).profile.wallet.energy>mainProfile.profile.wallet.energy);
  const invites=await mainApi(signed(fields,otherToken),{action:'invites_state'});
  assert.equal(invites.invites.completedGames,0);
  assert.ok(invites.invites.telegramInviteUrl.startsWith('https://t.me/UntouchGameBot?startapp=invite_'));
  const testInvites=await api(signed(fields),{action:'invites_state'});
  await rejects(mainApi(signed(fields,otherToken),{action:'invites_bind',code:testInvites.invites.ownCode}),'invite_self');
  const started=await mainApi(signed({...fields,start_param:`invite_${testInvites.invites.ownCode}`},otherToken),{action:'guest'});
  assert.equal(started.inviteError,'invite_self');
  assert.equal((await mainApi(signed(fields,otherToken),{action:'invites_state'})).invites.inviterAssigned,false);
  await rejects(api(signed(fields),{action:'invites_bind',code:invites.invites.ownCode}),'invite_self');
  const friendRaw=signed({user:JSON.stringify({id:100081,first_name:'Different person'})},otherToken);
  const friend=await mainApi(friendRaw,{action:'invites_bind',code:testInvites.invites.ownCode});
  assert.equal(friend.invites.inviterAssigned,true);
});
test('API ignores owner/identity spoof, starts fresh energy and never marks Telegram as Google',async()=>{
  const result=await api(signed(),{action:'guest',includeGameConfig:true,uid:'victim',googleLinked:true,energy:999999});
  assert.equal(result.profile.platform,'telegram');assert.equal(result.profile.googleLinked,false);
  assert.equal(result.profile.telegramVerified,true);assert.equal(result.profile.wallet.energy,50);
  assert.equal(result.profile.wallet.energyIdentityReady,true);assert.equal(result.profile.telegramUsername,null);
  const again=await api(signed(),{action:'profile'});assert.equal(again.profile.id,result.profile.id);
  await rejects(api(signed(),{action:'play_verify'}),'platform_action_invalid');
  await rejects(engine.execute(result.profile.id.slice(9),{action:'profile'},{googleLinked:true}),'platform_owner_invalid');
  await rejects(api('forged',{action:'profile'}),'telegram_unauthorized');
});
test('Telegram one-time identity reward is independent of Google claims and replay safe',async()=>{
  const raw=signed({user:JSON.stringify({id:100002,first_name:'Reward'})}),operationId=opid();
  const call=()=>api(raw,{action:'wallet_operation',operationId,kind:'energy_reward',args:{id:'telegram'}});
  const a=await call(),b=await call();assert.equal(a.profile.wallet.energy,b.profile.wallet.energy);
  assert.equal(a.profile.wallet.energy,50+defaults.config.economy.androidEnergyV2.rewards.google);
  await rejects(api(raw,{action:'wallet_operation',operationId:opid(),kind:'energy_reward',args:{id:'google'}}),'bonus_locked');
});

test('Telegram rewarded start requires enabled platform block, quoted callback claim remains once-only',async()=>{
  const raw=signed({user:JSON.stringify({id:100004,first_name:'Ad fixture'})}),sessionId=opid();
  await rejects(api(raw,{action:'wallet_operation',operationId:opid(),kind:'rewarded_ad_start',args:{sessionId}}),'ad_unavailable');
  let enabled=true;const adApi=createTelegramApi({engine,resolveIdentity:resolve,monetizationBotId:'123456789',platformConfig:async()=>({ads:{enabled,rewardedBlockId:'123'},stars:{salesEnabled:false}})});
  const before=await adApi(raw,{action:'guest'});
  const started=await adApi(raw,{action:'wallet_operation',operationId:opid(),kind:'rewarded_ad_start',args:{sessionId}});
  assert.equal(started.profile.wallet.energy,before.profile.wallet.energy);
  enabled=false;const operationId=opid(),body={action:'wallet_operation',operationId,kind:'watch_ad',args:{sessionId}};
  const first=await adApi(raw,body),again=await adApi(raw,body);
  assert.equal(first.profile.wallet.energy,before.profile.wallet.energy+defaults.config.economy.androidEnergyV2.simpleBonus.videoReward);
  assert.equal(again.profile.wallet.energy,first.profile.wallet.energy);
  assert.equal(again.profile.wallet.adQuota.used,1);
});
test('signed Telegram start parameter binds a common code once; input body cannot replace it',async()=>{
  const inviterRaw=signed({user:JSON.stringify({id:100007,first_name:'Inviter'})}),a=await api(inviterRaw,{action:'invites_state'}),code=a.invites.ownCode;
  const linkApi=createTelegramApi({engine,resolveIdentity:resolve,miniAppLink:'https://t.me/testuntouch_bot/game'});
  const raw=signed({user:JSON.stringify({id:100008,first_name:'Invitee'}),start_param:`invite_${code}`});
  await linkApi(raw,{action:'guest',includeGameConfig:true,start_param:'invite_FAKE33'});
  const state=await linkApi(raw,{action:'invites_state'});assert.equal(state.invites.inviterCode,code);
  assert.match(state.invites.telegramInviteUrl,/^https:\/\/t\.me\/testuntouch_bot\/game\?startapp=invite_[A-Z2-9]{6}$/);
  await linkApi(raw,{action:'guest'});assert.equal((await linkApi(raw,{action:'invites_state'})).invites.inviterCode,code);
});

async function finish(uid,ident){
  const requestId=opid();
  await engine.execute(uid,{action:'round_start',requestId,proofVersion:1,rulesRevision:defaults.revision},ident);
  await engine.execute(uid,{action:'round_activate',requestId},ident);
  k({op:'create',config:defaults.config,requestId});k({op:'start'});
  let s;
  for(let i=0;i<10000;i++){s=k({op:'tick',ms:16});if(s.dead)break;}
  assert.equal(s.dead,true);
  const proof=k({op:'proof'}).proof;stamp+=s.timeMs+10;
  const roundId=hash(`${uid}:${requestId}`);
  const result=await engine.execute(uid,{action:'round_finish',roundId,proof,timeMs:s.timeMs,runDistance:s.runDistance,riskCount:s.riskCount},ident);
  return {roundId,result};
}
test('actual browser proof completes Telegram round once and joins common record/RMS counters/cache',async()=>{
  const uid=crypto.randomUUID(),ident=identity('telegram');
  const {roundId,result}=await finish(uid,ident);
  assert.equal((await db.collection('scores').doc(roundId).get()).data().platform,'telegram');
  const a=await engine.execute(uid,{action:'scores',period:'allPeriods'},ident);
  assert.ok(a.periods.all.some(r=>r.userId===`supabase:${uid}`));
  assert.equal(a.average.mine.totalAttempts,1);assert.equal(a.average.mine.usedCount,1);
  await finish(uid,ident);
  const b=await engine.execute(uid,{action:'scores',period:'average'},ident);
  assert.equal(b.mine.totalAttempts,2);assert.equal(b.mine.usedCount,2);
  assert.equal(result.profile.completedGames,undefined);
});
test('referrals reward once in all four platform directions after five actual proven rounds',async()=>{
  for(const from of ['android','telegram'])for(const to of ['android','telegram']){
    const inviter=crypto.randomUUID(),invitee=crypto.randomUUID(),a=identity(from),b=identity(to);
    const state=await engine.execute(inviter,{action:'invites_state'},a);
    await engine.execute(invitee,{action:'invites_bind',code:state.invites?.ownCode??state.ownCode},b);
    for(let i=0;i<4;i++)await finish(invitee,b);
    assert.equal((await db.collection('players').doc(invitee).get()).data().inviteRewarded,false);
    await finish(invitee,b);
    const p=(await db.collection('players').doc(invitee).get()).data();assert.equal(p.inviteRewarded,true,`${from}->${to}`);
    const first=await engine.execute(inviter,{action:'profile'},a),again=await engine.execute(inviter,{action:'profile'},a);
    assert.equal(first.profile.wallet.energy,again.profile.wallet.energy);
    assert.equal(first.profile.wallet.energy,50+defaults.config.economy.androidEnergyV2.simpleBonus.inviterReward);
  }
});
test('late Google link pays a Telegram invitee who already completed five games',async()=>{
  const inviter=crypto.randomUUID(),invitee=crypto.randomUUID(),tg=identity('telegram');
  const state=await engine.execute(inviter,{action:'invites_state'});
  await engine.execute(invitee,{action:'invites_bind',code:state.invites.ownCode},tg);
  for(let i=0;i<5;i++)await finish(invitee,tg);
  assert.equal((await db.collection('players').doc(invitee).get()).data().inviteRewarded,false);
  await engine.execute(inviter,{action:'google_link'},identity('android'));
  assert.equal((await db.collection('players').doc(invitee).get()).data().inviteRewarded,true);
});
test('admin platform filters before pagination and Telegram detail does not call Google Auth',async()=>{
  const actor=crypto.randomUUID();await local.pg.query('insert into auth.users(id) values($1)',[actor]);await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
  const admin=createSupportAdmin({db:local.pool,auth:{getUserById:async()=>{throw Error('Google Auth must not be called for Telegram detail');}}});
  const tg=await resolve(signed()),list=await admin(actor,{action:'list',platform:'telegram',connection:'all',status:'active'});
  assert.ok(list.total>=1);assert.ok(list.users.every(p=>p.platform==='telegram'));
  const detail=await admin(actor,{action:'detail',userId:tg.uid});assert.equal(detail.user.status,'active');assert.equal(detail.user.platform,'telegram');
  const android=await admin(actor,{action:'list',platform:'android'});assert.ok(android.users.every(p=>p.platform==='android'));
  await assert.rejects(admin(actor,{action:'list',platform:'fake'}),e=>e.code==='filter_invalid');
});
test('Telegram deletion removes mapping and personal payment data, preserves anonymous tombstones and ACKs late webhooks',async()=>{
  const actor=crypto.randomUUID();await local.pg.query('insert into auth.users(id) values($1)',[actor]);await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
  const raw=signed({user:JSON.stringify({id:100009,first_name:'Disposable deletion fixture'})}),tg=await resolve(raw);await engine.execute(tg.uid,{action:'guest'},tg);
  const order=opid(),charge=opid();await db.collection('telegramOrders').doc(order).set({uid:tg.uid,subject:tg.subject,privateOrder:true});await db.collection('telegramCharges').doc(hash(charge)).set({uid:tg.uid,chargeId:charge,privateCharge:true});
  const admin=createSupportAdmin({db:local.pool,auth:{getUserById:async()=>{throw Error('No Google Auth for Telegram deletion');},deleteUser:async()=>{throw Error('No Google Auth deletion for Telegram');}}});
  const preview=await admin(actor,{action:'delete_preview',userId:tg.uid});
  await admin(actor,{action:'delete_user',userId:tg.uid,requestId:crypto.randomUUID(),expectedVersion:preview.user.version,confirmation:tg.uid,acceptSubscriptionNotice:true});
  assert.equal((await db.collection('players').doc(tg.uid).get()).exists,false);
  const marker={deleted:true,revoked:true,acknowledged:true};assert.deepEqual((await db.collection('telegramOrders').doc(order).get()).data(),marker);assert.deepEqual((await db.collection('telegramCharges').doc(hash(charge)).get()).data(),marker);
  const stars=createTelegramStars({db,botId:'123456789',botApi:async()=>{throw Error('No actual Bot API');},getSettings:async()=>null,integrationAccepted:true});
  for(const type of ['successful_payment','refunded_payment'])assert.equal((await stars.update({message:{from:{id:100009},[type]:{invoice_payload:order,telegram_payment_charge_id:charge,currency:'XTR',total_amount:25}}})).ignored,true);
  assert.equal((await stars.update({update_id:1,subscription:{user:{id:100009},invoice_payload:order,state:'canceled'}})).ignored,true);
  assert.equal((await db.collection('players').doc(tg.uid).get()).exists,false);
  const fresh=await resolve(raw);assert.notEqual(fresh.uid,tg.uid);assert.equal((await engine.execute(fresh.uid,{action:'guest'},fresh)).profile.wallet.energy,50);
});
