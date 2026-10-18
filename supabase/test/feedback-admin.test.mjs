import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createSupportAdmin} from '../functions/_shared/support-admin.mjs';
import {feedbackCard} from '../../admin-console/src/feedback.js';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
const admin='12345678-1234-4234-8234-123456789abc',player='22345678-1234-4234-8234-123456789abc',other='32345678-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1),($2),($3)',[admin,player,other]);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[admin]);
await db.collection('players').doc(player).set({nickname:'Автор',wallet:{energy:50}});
await db.collection('players').doc(other).set({nickname:'Друг',wallet:{energy:50}});
for(let i=0;i<28;i++)await db.collection('feedback').doc(`review_${String(i).padStart(2,'0')}`).set({uid:i===27?other:player,comment:i===0?'Touch delay <script>unsafe</script>':i===1?'No stars':'A useful experience',rating:i===1?null:i===0?5:3,createdAt:1000,privateField:'must never return'});
const identities=new Map([[player,{identities:[{provider:'google',identity_data:{email:'player@example.invalid'}}]}],[other,{identities:[]}]]);
const execute=createSupportAdmin({db:local.pool,auth:{getUserById:async uid=>({data:{user:identities.get(uid)},error:identities.has(uid)?null:{status:404}})}});

test('feedback directory is admin-only and rejects unbounded or invalid filters',async()=>{
  await assert.rejects(execute(other,{action:'feedback_list'}),e=>e.code==='admin_required');
  for(const body of [{search:'x'.repeat(161)},{search:{}},{offset:-1},{offset:100001},{offset:1.5},{rating:0},{rating:6},{rating:'5'}])
    await assert.rejects(execute(admin,{action:'feedback_list',...body}));
});
test('feedback pages have stable tie ordering, full text, author and optional rating',async()=>{
  const first=await execute(admin,{action:'feedback_list'}),second=await execute(admin,{action:'feedback_list',offset:first.nextOffset});
  assert.equal(first.total,28);assert.equal(first.feedback.length,25);assert.equal(first.nextOffset,25);
  assert.equal(second.feedback.length,3);assert.equal(second.nextOffset,null);
  const ids=[...first.feedback,...second.feedback].map(x=>x.id);assert.equal(new Set(ids).size,28);assert.equal(ids[0],'review_27');assert.equal(ids.at(-1),'review_00');
  const last=second.feedback.at(-1);assert.equal(last.userId,player);assert.equal(last.nickname,'Автор');assert.equal(last.email,'player@example.invalid');assert.equal(last.rating,5);assert.match(last.comment,/<script>/);assert.equal(last.privateField,undefined);
});
test('search and rating combine, unrated differs from all, SQL wildcards are literal',async()=>{
  const match=await execute(admin,{action:'feedback_list',search:'touch DELAY',rating:5});assert.equal(match.total,1);assert.equal(match.feedback[0].id,'review_00');
  assert.equal((await execute(admin,{action:'feedback_list',search:'Touch',rating:1})).total,0);
  assert.equal((await execute(admin,{action:'feedback_list',search:'Автор'})).total,27);
  assert.equal((await execute(admin,{action:'feedback_list',search:other})).total,1);
  const unrated=await execute(admin,{action:'feedback_list',rating:'unrated'});assert.equal(unrated.total,1);assert.equal(unrated.feedback[0].rating,null);
  assert.equal((await execute(admin,{action:'feedback_list',search:'%'})).total,0);
});
test('feedback rendering escapes user content and distinguishes missing assessment',()=>{
  const html=feedbackCard({nickname:'<img src=x onerror="alert(1)">',email:'<email>',userId:'" onclick="alert(1)',comment:'First line\n<script>alert(1)</script>',rating:null,createdAt:1000,userAvailable:true});
  assert.ok(!html.includes('<script>'));assert.ok(!html.includes('<img'));assert.ok(!html.includes('data-feedback-user="" onclick='));
  assert.match(html,/&lt;script&gt;/);assert.match(html,/First line\n/);assert.match(html,/Без оценки/);assert.ok(!html.includes('null'));
  assert.match(feedbackCard({nickname:'Гость',userId:player,comment:'Text',rating:1,createdAt:1000,userAvailable:false}),/Оценка 1 из 5/);
});
