import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {Buffer} from 'node:buffer';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {createTelegramApi} from '../functions/_shared/telegram-api.mjs';
import {attemptHistory} from '../functions/_shared/attempt-history.mjs';
import {ServerHistoryLoader} from '../../telegram-app/src/domain/server-attempt-history.ts';

const local=await testDatabase(); after(()=>local.close());
for(const name of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql'])
  await local.pg.exec(await fs.readFile(new URL(`../migrations/${name}`,import.meta.url),'utf8'));
const db=new PostgresStore(local.pool),stamp=Date.UTC(2026,9,22);
const engine=createEngine({db,now:()=>stamp});
const tgIdentity={uid:'tg_history_owner',platform:'telegram',telegramVerified:true,googleLinked:false,botId:'8773345829',subject:'100001'};
const api=createTelegramApi({engine,resolveIdentity:async()=>tgIdentity});
await engine.execute('android_history_owner',{action:'guest'},{googleLinked:true});
await api('',{action:'guest'});
for(const [uid,platform] of [['android_history_owner','android'],['tg_history_owner','telegram']]) {
  for(let i=0;i<4;i++)await db.collection('scores').doc(`${uid}_${i}`).set({uid,platform,timeMs:(i+1)*2000,createdAt:stamp+i,attemptAt:stamp+i,runDistance:i,riskCount:i,hadJump:true});
}
const rejects=(promise,code)=>assert.rejects(promise,e=>e.code===code);
test('Android and Telegram accept authenticated history and ignore all body owner overrides',async()=>{
  const android=await engine.execute('android_history_owner',{action:'attempts_history',uid:tgIdentity.uid,userId:`supabase:${tgIdentity.uid}`,limit:2},{googleLinked:true});
  const telegram=await api('',{action:'attempts_history',uid:'android_history_owner',userId:'supabase:android_history_owner',limit:2});
  assert.equal(android.history.userId,'supabase:android_history_owner');
  assert.equal(telegram.history.userId,`supabase:${tgIdentity.uid}`);
  assert.ok(android.history.rows.every(row=>row.id.startsWith('android_history_owner_')));
  assert.ok(telegram.history.rows.every(row=>row.id.startsWith('tg_history_owner_')));
  await rejects(api('',{action:'attempts_history',cursor:android.history.nextCursor}), 'attempt_history_cursor_invalid');
  assert.equal(telegram.history.rows[0].averageMs,telegram.average.mine.averageMs);
});
test('History rejects invalid input, missing boundary and cross-platform ownership before exposing records',async()=>{
  for(const limit of [0,201,-1,1.5,'100',null])await rejects(attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,limit}),'attempt_history_limit_invalid');
  for(const cursor of ['',{},'a'.repeat(2049),'%%%','e30'])await rejects(attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,cursor}),'attempt_history_cursor_invalid');
  const first=await attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,limit:2});
  const forged=JSON.parse(Buffer.from(first.history.nextCursor,'base64url'));
  forged.b.id='nonexistent';
  await rejects(attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,cursor:Buffer.from(JSON.stringify(forged)).toString('base64url')}),'attempt_history_cursor_invalid');
  await rejects(engine.execute(tgIdentity.uid,{action:'attempts_history'},{platform:'android',googleLinked:true}),'platform_owner_invalid');
});
test('History SQL is read-only, supports legacy zero rows and has no global Buffer dependency',async()=>{
  await db.collection('scores').doc('tg_history_zero').set({uid:tgIdentity.uid,platform:'telegram',timeMs:0,createdAt:stamp+10});
  const fingerprint=async()=>(await local.pool.query("select md5(string_agg(path||body::text,',' order by path)) as value from untouch.documents")).rows[0].value;
  const before=await fingerprint();
  const saved=globalThis.Buffer;let result;
  try {globalThis.Buffer=undefined;result=await attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,limit:1});}
  finally {globalThis.Buffer=saved;}
  const zero=result.history.rows[0];
  assert.equal(zero.timeMs,0);assert.equal(zero.included,false);assert.equal(zero.windowCount,4);
  assert.equal(result.history.totalCount,5);
  assert.ok(zero.averageMs>0);
  assert.equal(await fingerprint(),before);
  const next=await attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,cursor:result.history.nextCursor,limit:1});
  assert.equal(next.history.snapshot,result.history.snapshot);
  assert.deepEqual(next.average,result.average);
});
test('Renaming the owner between pages refreshes the entire average/history pair',async()=>{
  const first=await attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,limit:1});
  await db.collection('players').doc(tgIdentity.uid).update({nickname:'New history name'});
  await rejects(attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,cursor:first.history.nextCursor}), 'attempt_history_changed');
  const fresh=await attemptHistory({db,config:{},uid:tgIdentity.uid,stamp});
  assert.notEqual(fresh.history.snapshot,first.history.snapshot);
  assert.equal(fresh.average.mine.playerName,'New history name');
});
test('Actual SQL responses are accepted and merged by the Telegram loader',async()=>{
  const loader=new ServerHistoryLoader(body=>attemptHistory({db,config:{},uid:tgIdentity.uid,stamp,...body,limit:1}),()=>{});
  loader.setOwner(`supabase:${tgIdentity.uid}`);
  await loader.refresh();
  const first=loader.value.snapshot;
  assert.equal(loader.value.error,'');assert.equal(first.history.rows.length,1);
  while(loader.value.snapshot.history.nextCursor)await loader.more();
  assert.equal(loader.value.error,'');
  assert.equal(loader.value.snapshot.history.rows.length,first.history.totalCount);
  assert.deepEqual(loader.value.snapshot.average,first.average);
  if(process.env.ATTEMPT_HISTORY_CONTRACT_FIXTURE)
    await fs.writeFile(process.env.ATTEMPT_HISTORY_CONTRACT_FIXTURE,JSON.stringify(loader.value.snapshot,null,2)+'\n');
});
