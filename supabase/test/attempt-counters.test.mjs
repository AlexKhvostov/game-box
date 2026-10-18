import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
const db=await testDatabase();after(()=>db.close());
let serial=0;
async function put(uid,timeMs,extra={}){
 const key=`counter-${++serial}`;
 await db.pool.query(`insert into untouch.documents(path,parent,key,body) values($1,'scores',$2,$3::jsonb)`,[`scores/${key}`,key,JSON.stringify({uid,timeMs,platform:'android',...extra})]);return key;
}
async function verify(uid){
 for(const threshold of [0,1,999,1000,1001,1500,59999,60000]){
  const r=await db.pool.query(`select
   coalesce((select attempts from untouch.attempt_counts where uid=$1 and node=65536),0) as total,
   untouch.attempt_count_through($1,$2) as through,
   count(*)::bigint as actual,
   count(*) filter(where (body->>'timeMs')::numeric <= $2)::bigint as actual_through
   from untouch.documents where parent='scores' and body->>'platform'='android' and body->>'uid'=$1`,[uid,threshold]);
  assert.equal(String(r.rows[0].total),String(r.rows[0].actual),uid);
  assert.equal(String(r.rows[0].through),String(r.rows[0].actual_through),`${uid}/${threshold}`);
 }
}
test('exact dynamic thresholds, duplicate upsert, owner/platform/duration changes and deletion',async()=>{
 for(const ms of [0,1,999,1000,1001,1500,60000,60001,10000000])await put('counter-a',ms);
 const key=await put('counter-a',1600);await put('counter-a',30000,{platform:'telegram'});
 await verify('counter-a');
 await db.pool.query(`update untouch.documents set body=body||'{"nickname":"same score"}' where key=$1`,[key]);await verify('counter-a');
 await db.pool.query(`update untouch.documents set body=body||'{"uid":"counter-b","timeMs":1000}' where key=$1`,[key]);await verify('counter-a');await verify('counter-b');
 await db.pool.query(`update untouch.documents set body=body||'{"platform":"telegram"}' where key=$1`,[key]);await verify('counter-b');
 await db.pool.query(`update untouch.documents set body=body||'{"platform":"android"}' where key=$1`,[key]);await verify('counter-b');
 await db.pool.query(`delete from untouch.documents where key=$1`,[key]);await verify('counter-b');
});
test('rollback leaves counters unchanged; unrelated document mutations have no effect',async()=>{
 await db.pg.exec('begin');await put('rollback',10000);await db.pg.exec('rollback');await verify('rollback');
 await db.pool.query(`insert into untouch.documents values('players/no-score','players','no-score','{}',now())`);await verify('no-score');
});
test('restricted runtime can maintain/read counters; public roles cannot access them',async()=>{
 await db.pg.exec('set role untouch_runtime');
 try{await put('runtime-counter',1800);await verify('runtime-counter');}finally{await db.pg.exec('reset role');}
 for(const role of ['anon','authenticated']){
  await db.pg.exec(`set role ${role}`);
  try{await assert.rejects(db.pool.query('select * from untouch.attempt_counts'),/permission denied/);}finally{await db.pg.exec('reset role');}
 }
});
test('migration backfills existing scores once without changing their contents',async()=>{
 const old=await testDatabase({beforeCounters:async pg=>{
  await pg.exec(`insert into untouch.documents(path,parent,key,body)
   select 'scores/old'||n,'scores','old'||n,jsonb_build_object('uid','old','platform','android','timeMs',n*1000) from generate_series(1,20)n`);
 }});
 try{
  const r=await old.pool.query(`select attempts,untouch.attempt_count_through('old',10000) as through from untouch.attempt_counts where uid='old' and node=65536`);
  assert.equal(Number(r.rows[0].attempts),20);assert.equal(Number(r.rows[0].through),10);
  assert.equal(Number((await old.pool.query(`select count(*) as n from untouch.documents where parent='scores'`)).rows[0].n),20);
  await old.pool.query(`delete from untouch.documents where key='old1'`);
  assert.equal(Number((await old.pool.query(`select attempts from untouch.attempt_counts where uid='old' and node=65536`)).rows[0].attempts),19);
 }finally{await old.close();}
});

