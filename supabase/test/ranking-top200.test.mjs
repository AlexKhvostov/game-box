import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {recordRankings} from '../functions/_shared/record-ranking.mjs';
import {averageRanking} from '../functions/_shared/average-ranking.mjs';
const local=await testDatabase();after(()=>local.close());const db={pool:local.pool};
const stamp=Date.UTC(2026,9,18,12),uid=i=>'p'+String(i).padStart(4,'0');
await local.pool.query(`insert into untouch.documents(path,parent,key,body)
  select 'players/'||('p'||lpad(i::text,4,'0')),'players','p'||lpad(i::text,4,'0'),
    jsonb_build_object('nickname','Игрок '||i,'email','private@example.invalid','wallet',jsonb_build_object('energy',999))
  from generate_series(1,520) i`);
await local.pool.query(`insert into untouch.documents(path,parent,key,body)
  select 'scores/'||i||'-'||j,'scores',i||'-'||j,jsonb_build_object(
    'uid','p'||lpad(i::text,4,'0'),'platform','android','timeMs',case when j=21 then 500 else 200000-i end,
    'createdAt',$1::bigint-j,'hadJump',false,'hadHelmet',false)
  from generate_series(1,520) i cross join generate_series(1,21) j`,[stamp]);
test('both rankings: top200 only, actual own place1/50/200/201/520, all attempts counted',async()=>{
 for(const ownPlace of [1,50,200,201,520]){
  const records=await recordRankings({db,uid:uid(ownPlace),stamp});
  for(const rows of Object.values(records.periods)){
   assert.equal(rows.length,ownPlace>200?201:200);
   assert.deepEqual(rows.slice(0,200).map(r=>r.place),Array.from({length:200},(_,i)=>i+1));
   assert.equal(rows.filter(r=>r.userId==='supabase:'+uid(ownPlace)).length,1);
   assert.equal(rows.at(-1).place,ownPlace>200?ownPlace:200);
   assert.ok(rows.every(r=>!('wallet'in r)&&!('email'in r)));
  }
  const average=await averageRanking({db,config:{},uid:uid(ownPlace),stamp});
  assert.equal(average.rows.length,200);assert.equal(average.mine.place,ownPlace);
  assert.equal(average.mine.totalAttempts,21);assert.equal(average.mine.eligibleCount,20);
  assert.equal(average.mine.usedCount,20);assert.equal(average.mine.averageMs,200000-ownPlace);
  assert.equal(average.mine.userId,'supabase:'+uid(ownPlace));
  assert.ok(average.rows.every(r=>r.totalAttempts===21));
 }
});
test('periods independently pick own best attempt and rank before cutting',async()=>{
 await local.pool.query(`insert into untouch.documents(path,parent,key,body) values('scores/old','scores','old',
   jsonb_build_object('uid',$1::text,'platform','android','timeMs',999999,'createdAt',$2::bigint))`,[uid(520),Date.UTC(2025,0,1)]);
 const result=await recordRankings({db,uid:uid(520),stamp});
 assert.equal(result.periods.all[0].userId,'supabase:'+uid(520));
 assert.equal(result.periods.all[0].place,1);assert.equal(result.periods.all.length,200);
 for(const period of ['day','week','month','year'])assert.equal(result.periods[period].at(-1).place,520);
 const day=await recordRankings({db,uid:uid(520),stamp,period:'day'});
 assert.deepEqual(day.scores,result.periods.day);
 await assert.rejects(recordRankings({db,uid:uid(520),stamp,period:'invalid'}),e=>e.code==='period_invalid');
});
test('hidden, deleted and other-platform results cannot displace visible players; zero/short-only owner',async()=>{
 await local.pool.query(`update untouch.documents set body=body||'{"supportDisabled":true}'::jsonb where parent='players' and key=$1`,[uid(1)]);
 await local.pool.query(`insert into untouch.documents(path,parent,key,body) values
 ('scores/deleted','scores','deleted',jsonb_build_object('uid','missing','timeMs',9999999,'platform','android','createdAt',$1::bigint)),
 ('scores/telegram','scores','telegram',jsonb_build_object('uid',$2::text,'timeMs',9999998,'platform','telegram','createdAt',$1::bigint)),
 ('players/short','players','short','{"nickname":"Короткие"}'),
 ('scores/short','scores','short',jsonb_build_object('uid','short','timeMs',1000,'platform','android','createdAt',$1::bigint))`,[stamp,uid(2)]);
 const result=await recordRankings({db,uid:uid(201),stamp,period:'day'});
 assert.equal(result.scores.length,200);assert.equal(result.scores.at(-1).userId,'supabase:'+uid(201));
 assert.equal(result.scores[0].timeMs,199998);assert.equal(result.scores[0].place,1);
 const avg=await averageRanking({db,config:{},uid:'short',stamp});
 assert.equal(avg.rows.length,200);assert.equal(avg.mine.averageMs,null);assert.equal(avg.mine.place,null);
 assert.equal(avg.mine.totalAttempts,1);assert.equal(avg.mine.eligibleCount,0);
 const absent=await averageRanking({db,config:{},uid:'missing',stamp});assert.equal(absent.mine.place,null);
 const hidden=await averageRanking({db,config:{},uid:uid(1),stamp});assert.equal(hidden.mine.totalAttempts,0);
});
