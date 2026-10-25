import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
import {createSupportAdmin} from '../functions/_shared/support-admin.mjs';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {defaults} from '../functions/_shared/core/policy.mjs';
const local=await testDatabase();after(()=>local.close());
for(const name of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql','20261022085951_telegram_bot_namespaces.sql'])await local.pg.exec(await fs.readFile(new URL(`../migrations/${name}`,import.meta.url),'utf8'));
await local.pg.exec(await fs.readFile(new URL('../migrations/20261022142057_support_directory_record.sql',import.meta.url),'utf8'));
const actor='12345678-1234-4234-8234-123456789abc';await local.pg.query('insert into auth.users(id) values($1)',[actor]);await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
let authCalls=0;const auth={getUserById:async()=>{authCalls++;return{data:{user:null},error:{status:404}};}};
const execute=createSupportAdmin({db:local.pool,auth,now:()=>2000000}),fixtures=[];
for(let i=0;i<57;i++){
 const id=`${(0x10000000+i).toString(16)}-1234-4234-8234-123456789abc`,platform=i%2?'telegram':'android';let raw=i<6?[undefined,null,-1000,'999999',1e20,1.5][i]:(i%7)*1000;
 const body={uid:id,nickname:`Record fixture ${String(i).padStart(2,'0')}`,platform,telegramVerified:platform==='telegram',version:1,createdAt:1000,lastActiveAt:1000,completedGames:2,wallet:{energy:50,...(raw===undefined?{}:{bestTimeMs:raw})}};
 if(platform==='android')await local.pg.query('insert into auth.users(id) values($1)',[id]);
 else await local.pg.query("insert into untouch.external_identities(provider,subject,uid,bot_id) values('telegram',$1,$2,'8773345829')",[String(10000+i),id]);
 await local.pg.query("insert into untouch.documents(path,parent,key,body) values($1,'players',$2,$3::jsonb)",[`players/${id}`,id,JSON.stringify(body)]);
 fixtures.push({id,platform,value:Number.isSafeInteger(raw)&&raw>=0?raw:0});
}
const query={action:'list',search:'Record fixture',sort:'record'};
async function pages(body){let offset=0,users=[];do{const page=await execute(actor,{...body,offset});users.push(...page.users);if(page.nextOffset===null)return {users,total:page.total};offset=page.nextOffset;}while(offset<10000);throw Error('pagination_loop');}
test('record sorting orders the entire directory before paging with stable ID ties in both directions',async()=>{
 for(const direction of ['asc','desc']){const result=await pages({...query,direction});const expected=fixtures.slice().sort((a,b)=>(direction==='asc'?a.value-b.value:b.value-a.value)||a.id.localeCompare(b.id));assert.equal(result.total,57);assert.deepEqual(result.users.map(u=>u.id),expected.map(r=>r.id));assert.deepEqual(result.users.map(u=>u.bestTimeMs),expected.map(r=>r.value));assert.equal(new Set(result.users.map(u=>u.id)).size,57);}
 assert.equal(authCalls,0,'directory must not query Auth per user');
});
test('platform filters apply globally before record sort and page boundaries',async()=>{
 for(const platform of ['android','telegram'])for(const direction of ['asc','desc']){const result=await pages({...query,platform,direction});const expected=fixtures.filter(r=>r.platform===platform).sort((a,b)=>(direction==='asc'?a.value-b.value:b.value-a.value)||a.id.localeCompare(b.id));assert.deepEqual(result.users.map(u=>u.id),expected.map(r=>r.id));assert.ok(result.users.every(u=>u.platform===platform));}
 const empty=await execute(actor,{...query,platform:'telegram',connection:'google'});assert.equal(empty.total,0);assert.deepEqual(empty.users,[]);assert.equal(empty.nextOffset,null);
 const past=await execute(actor,{...query,offset:100});assert.equal(past.total,57);assert.deepEqual(past.users,[]);assert.equal(past.nextOffset,null);
});
test('sort supports omitted platform, rejects injection and requires administrator rights',async()=>{
 assert.equal((await execute(actor,query)).total,57);
 for(const patch of [{sort:'record desc; drop table auth.users'},{direction:'desc;select 1'},{platform:'telegram;select 1'},{offset:-1}])await assert.rejects(execute(actor,{...query,...patch}),e=>['filter_invalid','page_invalid'].includes(e.code));
 await assert.rejects(execute(fixtures[0].id,query),e=>e.code==='admin_required');
});
test('Auth-only profiles have no record; zero sorts together with missing records',async()=>{
 const result=await execute(actor,{action:'list',search:actor,sort:'record',direction:'desc'});assert.equal(result.users[0].bestTimeMs,0);assert.equal(result.users[0].status,'not_started');
 const missing=await execute(actor,{...query,direction:'asc'});assert.ok(missing.users.slice(0,5).every(u=>u.bestTimeMs===0));
});
test('confirmed engine finishes update profile record atomically with the real score in both platforms',async()=>{
 const db=new PostgresStore(local.pool);let stamp=3000000;
 // Only the proof checker is a local fixture; real transaction/record logic runs.
 const engine=createEngine({db,now:()=>stamp,roundProof:{start(){},finish(){}}});
 for(const [index,platform] of ['android','telegram'].entries()){
  const uid=`${(0x20000000+index).toString(16)}-1234-4234-8234-123456789abc`,identity=platform==='telegram'?{platform,telegramVerified:true}:{platform};
  await engine.execute(uid,{action:'guest'},identity);
  const requestId=String(index+1).repeat(64);const start=await engine.execute(uid,{action:'round_start',requestId,rulesRevision:defaults.revision},identity);
  await engine.execute(uid,{action:'round_activate',requestId},identity);stamp+=5000;
  await engine.execute(uid,{action:'round_finish',roundId:start.roundId,timeMs:5000,runDistance:10,riskCount:0,hadHelmet:false,hadJump:false},identity);
  const score=(await db.collection('scores').doc(start.roundId).get()).data();const admin=await execute(actor,{action:'list',search:uid,platform,sort:'record'});
  assert.equal(admin.users[0].bestTimeMs,score.timeMs);assert.equal(score.timeMs,5000);
 }
});
test('private directory remains inaccessible to public roles',async()=>{
 for(const role of ['anon','authenticated']){await local.pg.exec('begin');try{await local.pg.exec(`set local role ${role}`);await assert.rejects(local.pg.query("select untouch.support_directory_v4('{}')"),e=>e.code==='42501');}finally{await local.pg.exec('rollback');}}
});
