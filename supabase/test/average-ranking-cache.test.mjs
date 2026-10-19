import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {averageRanking,uncachedAverageRanking} from '../functions/_shared/average-ranking.mjs';

const local=await testDatabase();after(()=>local.close());
await local.pg.exec(await fs.readFile(new URL('../migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8'));
let recomputed=null,serial=0,stamp=Date.UTC(2026,9,19);
const db=new PostgresStore({query:async(text,args)=>{const result=await local.pool.query(text,args);if(text.includes('cache_recomputed'))recomputed=result.rows[0].cache_recomputed;return result;},connect:()=>local.pool.connect()});
const config={ranking:{average:{windowSize:50,previousWeightPercent:92,minDurationMs:0,minAttempts:1}}};
async function player(uid){await db.collection('players').doc(uid).set({nickname:uid});}
async function seed(uid,values,extra={}){const ids=[];for(const timeMs of values){const id=`cache_${++serial}`;ids.push(id);await db.collection('scores').doc(id).set({uid,platform:'android',timeMs,createdAt:++stamp,...extra});}return ids;}
async function compare(uid,cfg=config){
  const args={db,config:cfg,uid,stamp};const cached=await averageRanking(args),old=await uncachedAverageRanking(args);
  assert.deepEqual(cached,old);return cached;
}
const cache=()=>local.pool.query('select uid,rules_key,score_revision::text,updated_at::text from untouch.average_rank_cache order by uid').then(r=>r.rows);

test('cold and warm boards equal uncached RMS; second read does not update cache',async()=>{
  await player('a');await player('b');await player('empty');
  await seed('a',Array.from({length:100},(_,i)=>i%9===0?500:1000+i*139));await seed('b',[15000,3000]);
  const first=await compare('a');assert.equal(first.mine.usedCount,50);assert.equal(recomputed,3);
  const saved=await cache();await compare('b');assert.equal(recomputed,0);assert.deepEqual(await cache(),saved);
  await compare('empty');assert.equal(recomputed,0);
});
test('new, corrected, deleted and out-of-order attempts invalidate only their owner',async()=>{
  const [id]=await seed('a',[17000]);await compare('a');assert.equal(recomputed,1);
  await db.collection('scores').doc(id).update({timeMs:2500});await compare('a');assert.equal(recomputed,1);
  await db.collection('scores').doc(id).update({attemptAt:1});await compare('a');assert.equal(recomputed,1);
  await local.pool.query('delete from untouch.documents where path=$1',[`scores/${id}`]);await compare('a');assert.equal(recomputed,1);
  await compare('a');assert.equal(recomputed,0);
});
test('irrelevant changes and duplicate delivery do not invalidate; platform/owner changes do',async()=>{
  const [id]=await seed('a',[7000]);await compare('a');
  const ref=db.collection('scores').doc(id);await ref.update({playerName:'new-name'});await compare('a');assert.equal(recomputed,0);
  const body=(await ref.get()).data();await ref.set(body);await compare('a');assert.equal(recomputed,0);
  await seed('a',[999999],{platform:'telegram'});await compare('a');assert.equal(recomputed,0);
  await ref.update({uid:'b'});await compare('a');assert.equal(recomputed,2);
  await ref.update({platform:'telegram'});await compare('b');assert.equal(recomputed,1);
});
test('all rule changes produce correct values immediately, including returning to previous rules',async()=>{
  for(const patch of [{windowSize:2},{previousWeightPercent:100},{minDurationMs:1000},{minAttempts:1000},{}]){
    const cfg={ranking:{average:{...config.ranking.average,...patch}}};await compare('a',cfg);assert.equal(recomputed,3);
    await compare('a',cfg);assert.equal(recomputed,0);
  }
});
test('fresh names, moderation, visibility and ranking positions do not reuse stale profile output',async()=>{
  await db.collection('players').doc('b').update({nickname:'Renamed',publicNameRestricted:true});
  let b=await compare('b');assert.equal(recomputed,0);assert.equal(b.rows.find(r=>r.userId==='supabase:b').playerName,'Игрок');assert.equal(b.mine.playerName,'Renamed');
  await db.collection('players').doc('b').update({supportDisabled:true});b=await compare('b');assert.equal(recomputed,0);assert.ok(!b.rows.some(r=>r.userId==='supabase:b'));assert.equal(b.mine.averageMs,null);
  await db.collection('players').doc('b').update({supportDisabled:false,publicNameRestricted:false});await seed('b',[60000]);b=await compare('b');assert.equal(recomputed,1);assert.equal(b.mine.place,1);
});
test('profile deletion cascades cache removal; empty/recreated profiles remain correct',async()=>{
  await player('remove');await seed('remove',[15000]);await compare('remove');
  await local.pool.query("delete from untouch.documents where path='players/remove'");
  assert.equal((await local.pool.query("select count(*)::integer as n from untouch.average_rank_cache where uid='remove'")).rows[0].n,0);
  await compare('remove');await player('remove');await compare('remove');assert.equal(recomputed,1);
});
test('rolled back attempt does not change revision/cache, and older revision cannot replace newer cache',async()=>{
  const before=await cache();const client=await local.pool.connect();
  try{await client.query('begin');await client.query("insert into untouch.documents(path,parent,key,body) values('scores/rollback','scores','rollback',$1::jsonb)",[JSON.stringify({uid:'a',platform:'android',timeMs:9000,createdAt:++stamp})]);await client.query('rollback');}finally{client.release();}
  await compare('a');assert.equal(recomputed,0);assert.deepEqual(await cache(),before);
  const guarded=await local.pool.query(`insert into untouch.average_rank_cache(uid,owner_path,rules_key,score_revision,average_ms,used_count,eligible_count,total_count)
    values('a','players/a','obsolete',0,999999,1,1,1) on conflict(uid) do update set score_revision=excluded.score_revision,average_ms=excluded.average_ms
    where untouch.average_rank_cache.score_revision<=excluded.score_revision returning uid`);
  assert.equal(guarded.rows.length,0);await compare('a');assert.equal(recomputed,0);
});
test('private runtime permissions work; browser roles have no cache or trigger access',async()=>{
  const access=await local.pool.query(`select has_table_privilege('anon','untouch.average_rank_cache','select') as anon,
    has_table_privilege('authenticated','untouch.average_rank_cache','update') as authenticated,
    has_function_privilege('authenticated','untouch.track_average_revision()','execute') as trigger_access`);
  assert.deepEqual(access.rows[0],{anon:false,authenticated:false,trigger_access:false});
  await local.pool.query('set role untouch_runtime');
  try{await seed('a',[8000]);await compare('a');await compare('a');assert.equal(recomputed,0);}
  finally{await local.pool.query('reset role');}
});
test('safe uncached fallback during migration rollout and concurrent profile deletion',async()=>{
  const fallbackDb={pool:{query:async(text,args)=>{if(text.includes('cache_recomputed'))throw Object.assign(Error('cache not present'),{code:'42P01'});return local.pool.query(text,args);}}};
  assert.deepEqual(await averageRanking({db:fallbackDb,config,uid:'a',stamp}),await uncachedAverageRanking({db,config,uid:'a',stamp}));
  const bad={pool:{query:async()=>{throw Object.assign(Error('permission denied'),{code:'42501'});}}};
  await assert.rejects(()=>averageRanking({db:bad,config,uid:'a',stamp}),e=>e.code==='42501');
});
test('accepted round refreshes the cached board once; duplicate finish preserves wallet and cache',async()=>{
  const {createEngine}=await import('../functions/_shared/core/engine.mjs');
  const {defaults,hash}=await import('../functions/_shared/core/policy.mjs');
  const cfg={...structuredClone(defaults.config),ranking:config.ranking};
  const policy={ok:true,config:cfg,revision:hash(cfg)};
  const engine=createEngine({db,getPolicy:async()=>policy,roundProof:{start(){},finish(){}},now:()=>stamp});
  const call=input=>engine.execute('round-cache',input);
  await call({action:'guest'});
  const initial=await call({action:'scores',period:'average'});assert.equal(initial.mine.averageMs,null);
  const requestId=hash('round-cache-request');
  const round=await call({action:'round_start',requestId,rulesRevision:policy.revision});
  await call({action:'round_activate',requestId});stamp+=10000;
  const command={action:'round_finish',roundId:round.roundId,timeMs:5000,runDistance:0,riskCount:0,hadJump:false,hadHelmet:false};
  const first=await call(command);
  const board=await call({action:'scores',period:'allPeriods'});
  assert.equal(board.average.mine.averageMs,5000);assert.equal(board.average.mine.totalAttempts,1);assert.equal(recomputed,1);
  const duplicate=await call(command);assert.equal(duplicate.profile.wallet.energy,first.profile.wallet.energy);
  const repeated=await call({action:'scores',period:'average'});assert.equal(recomputed,0);assert.equal(repeated.mine.totalAttempts,1);
});
test('approved 100-attempt fixture matches independent RMS and ignores old arithmetic cache',async()=>{
  const values=Array.from({length:100},(_,i)=>i%13===3?200+(i%8)*100:1000+((i*7307+1931)%19001));
  await player('rms-fixture');await seed('rms-fixture',values);
  const used=values.slice(-50).reverse();let squares=0,total=0;
  used.forEach((t,i)=>{const w=.92**i;squares+=t*t*w;total+=w;});
  let b=await compare('rms-fixture');
  assert.equal(b.rules.algorithm,'weighted_rms_v1');
  assert.ok(Math.abs(b.mine.averageMs-Math.sqrt(squares/total))<1e-7);
  assert.ok(Math.abs(b.mine.averageMs-10995.868454706817)<1e-7);
  await local.pool.query("update untouch.average_rank_cache set rules_key='weighted-v1:50:92:0:1',average_ms=9263.854161690324 where uid='rms-fixture'");
  b=await compare('rms-fixture');assert.equal(recomputed,1);
  assert.ok(Math.abs(b.mine.averageMs-10995.868454706817)<1e-7);
  await compare('rms-fixture');assert.equal(recomputed,0);
});
