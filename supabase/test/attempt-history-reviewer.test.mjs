import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {attemptHistory} from '../functions/_shared/attempt-history.mjs';
import {uncachedAverageRanking} from '../functions/_shared/average-ranking.mjs';

// Independent reviewer fixtures: a direct weighted RMS oracle, not production helpers.
const local=await testDatabase();after(()=>local.close());
for(const migration of ['20261019205914_android_average_ranking_cache.sql','20261019223954_telegram_platform_core.sql']){
  await local.pg.exec(await fs.readFile(new URL(`../migrations/${migration}`,import.meta.url),'utf8'));
}
const db=new PostgresStore(local.pool),baseAt=Date.UTC(2026,9,22),stamp=baseAt+1000000;
const config=(patch={})=>({ranking:{average:{windowSize:50,previousWeightPercent:92,minAttempts:1,minDurationMs:1000,...patch}}});
const near=(actual,expected)=>expected===null?assert.equal(actual,null):assert.ok(Math.abs(actual-expected)<1e-6,`${actual} != ${expected}`);
async function seed(uid,values,{platform='android',at=i=>baseAt+Math.floor(i/3)}={}){
  await db.collection('players').doc(uid).set({nickname:uid,platform});
  const rows=values.map((timeMs,i)=>({id:`review_${uid}_${String(i).padStart(5,'0')}`,uid,platform,timeMs,createdAt:baseAt+900000+i,attemptAt:at(i),runDistance:i*3,riskCount:i%7,hadJump:i%2===0,hadHelmet:i%5===0}));
  await local.pool.query(`insert into untouch.documents(path,parent,key,body)
    select 'scores/'||(value->>'id'),'scores',value->>'id',value from jsonb_array_elements($1::jsonb)`,[JSON.stringify(rows)]);
  return rows;
}
function oracle(rows,rules){
  const eligible=[];
  return rows.slice().sort((a,b)=>(a.attemptAt??a.createdAt)-(b.attemptAt??b.createdAt)||(a.id<b.id?-1:a.id>b.id?1:0)).map((row,i)=>{
    const included=row.timeMs>rules.minDurationMs;
    if(included)eligible.push(row);
    const window=eligible.slice(-rules.windowSize).reverse(),q=rules.previousWeightPercent/100;
    let numerator=0,denominator=0;
    for(let j=0;j<window.length;j++){const weight=q**j;numerator+=window[j].timeMs**2*weight;denominator+=weight;}
    return {...row,number:i+1,included,windowCount:window.length,averageMs:denominator?Math.sqrt(numerator/denominator):null};
  });
}
async function readAll(uid,cfg,limit=200){
  let cursor,first,rows=[];
  do{const page=await attemptHistory({db,config:cfg,uid,stamp,cursor,limit});first??=page;
    assert.equal(page.history.snapshot,first.history.snapshot);assert.deepEqual(page.average,first.average);
    rows.push(...page.history.rows);cursor=page.history.nextCursor;
    assert.ok(rows.length<=10000,'pagination cannot loop');
  }while(cursor);
  return {...first,allRows:rows};
}

test('reviewer: 713 rows across pages retain exact RMS context, numbering, equal-date key order and old record',async()=>{
  const values=Array.from({length:713},(_,i)=>i===13?42000:i%11===0?1:i%13===0?1000:i%17===0?999:1001+(i*193)%17000);
  const source=await seed('history_full',values,{platform:'telegram'});
  // A giant foreign record must not affect any personal field or revision.
  await seed('history_foreign',[999999],{platform:'telegram'});
  for(const rules of [{windowSize:3},{windowSize:50},{windowSize:500,previousWeightPercent:100,minAttempts:9999}]){
    const cfg=config(rules),expected=oracle(source,cfg.ranking.average),actual=await readAll('history_full',cfg);
    assert.equal(actual.history.totalCount,713);assert.equal(actual.allRows.length,713);
    assert.equal(new Set(actual.allRows.map(r=>r.id)).size,713);
    assert.deepEqual(actual.allRows.map(r=>r.id),expected.map(r=>r.id).reverse());
    for(const row of actual.allRows){const target=expected[row.number-1];assert.equal(row.id,target.id);near(row.averageMs,target.averageMs);assert.equal(row.included,target.included);assert.equal(row.windowCount,target.windowCount);assert.equal(row.createdAt,target.attemptAt);}
    near(actual.average.mine.averageMs,expected.at(-1).averageMs);
    assert.equal(actual.average.mine.totalAttempts,713);
    assert.equal(actual.average.mine.eligibleCount,source.filter(r=>r.timeMs>1000).length);
    assert.equal(actual.average.mine.usedCount,expected.at(-1).windowCount);
    assert.equal(actual.average.mine.userId,'supabase:history_full');
    assert.equal(actual.history.best.id,source[13].id);assert.equal(actual.history.best.number,14);
    near(actual.history.best.averageMs,expected[13].averageMs);
    const ranking=await uncachedAverageRanking({db,config:cfg,uid:'history_full',stamp});
    near(actual.average.mine.averageMs,ranking.mine.averageMs);
  }
});

test('reviewer: empty and strictly cutoff-only history never fabricate zero/NaN means',async()=>{
  await seed('history_empty',[]);await seed('history_short',[1,1,999,1000]);
  for(const uid of ['history_empty','history_short']){
    const response=await readAll(uid,config(),2);
    assert.equal(response.average.mine.averageMs,null);assert.equal(response.average.mine.usedCount,0);assert.equal(response.average.mine.eligibleCount,0);
    assert.ok(response.allRows.every(r=>r.averageMs===null&&!r.included&&r.windowCount===0));
    assert.equal(response.history.best?.timeMs??null,uid==='history_empty'?null:1000);
  }
});

test('reviewer: all-short gaps preserve previous mean and attemptAt fallback is chronological',async()=>{
  const rows=await seed('history_gaps',[2000,1000,999,8000,1]);
  await db.collection('scores').doc(rows[1].id).update({attemptAt:null,createdAt:baseAt+2});rows[1].attemptAt=null;rows[1].createdAt=baseAt+2;
  const actual=await readAll('history_gaps',config({windowSize:2}),2),expected=oracle(rows,config({windowSize:2}).ranking.average);
  assert.deepEqual(actual.allRows.map(r=>r.id),expected.map(r=>r.id).reverse());
  for(const row of actual.allRows)near(row.averageMs,expected[row.number-1].averageMs);
});

test('reviewer: historical zero-duration rows remain visible but never enter strict-zero RMS',async()=>{
  const rows=await seed('history_legacy_zero',[0,1000,0,3000]);
  const cfg=config({minDurationMs:0}),actual=await readAll('history_legacy_zero',cfg,2),expected=oracle(rows,cfg.ranking.average);
  assert.equal(actual.history.totalCount,4);assert.equal(actual.average.mine.eligibleCount,2);
  assert.deepEqual(actual.allRows.map(r=>r.timeMs),[3000,0,1000,0]);
  for(const row of actual.allRows)near(row.averageMs,expected[row.number-1].averageMs);
});

test('reviewer: opaque cursors are owner/rules/revision-bound, including metadata correction',async()=>{
  const source=await seed('history_cursor',[2000,3000,4000,5000,6000]);await seed('history_other',[5000,6000,7000]);
  const page=()=>attemptHistory({db,config:config(),uid:'history_cursor',stamp,limit:2});
  let first=await page();assert.ok(first.history.nextCursor);
  const read=(patch={})=>attemptHistory({db,config:config(),uid:'history_cursor',stamp,limit:2,cursor:first.history.nextCursor,...patch});
  await assert.rejects(()=>read({uid:'history_other'}),e=>e.code==='attempt_history_cursor_invalid'&&e.status===400);
  await assert.rejects(()=>read({cursor:'bad cursor'}),e=>e.code==='attempt_history_cursor_invalid'&&e.status===400);
  await assert.rejects(()=>read({config:config({windowSize:3})}),e=>e.code==='attempt_history_changed'&&e.status===409);
  await db.collection('scores').doc(source[0].id).update({timeMs:2001});
  await assert.rejects(()=>read(),e=>e.code==='attempt_history_changed'&&e.status===409);
  first=await page();await db.collection('scores').doc(source[0].id).update({riskCount:123});
  await assert.rejects(()=>read(),e=>e.code==='attempt_history_changed'&&e.status===409);
  first=await page();await db.collection('scores').doc(source[0].id).update({attemptAt:baseAt+500});
  await assert.rejects(()=>read(),e=>e.code==='attempt_history_changed'&&e.status===409);
});

test('reviewer: another owner update does not invalidate personal pagination; disabled profile fails closed',async()=>{
  const first=await attemptHistory({db,config:config(),uid:'history_cursor',stamp,limit:2});
  await db.collection('scores').doc('review_history_other_00000').update({timeMs:8765});
  const page=await attemptHistory({db,config:config(),uid:'history_cursor',stamp,limit:2,cursor:first.history.nextCursor});assert.equal(page.history.snapshot,first.history.snapshot);
  await db.collection('players').doc('history_other').update({supportDisabled:true});
  await assert.rejects(()=>attemptHistory({db,config:config(),uid:'history_other',stamp}),e=>e.status===403||e.status===404);
});

test('reviewer: worst-size page uses bounded eligible context and the owner history index',async t=>{
  await seed('history_perf',Array.from({length:3500},(_,i)=>1001+(i*71)%12000));
  await local.pool.query('analyze untouch.documents');
  let query;
  const recording={pool:{query:async(text,values)=>{query={text,values};return local.pool.query(text,values);}}};
  const page=await attemptHistory({db:recording,config:config({windowSize:500,previousWeightPercent:50}),uid:'history_perf',stamp,limit:200});
  assert.equal(page.history.rows.length,200);assert.equal(page.average.mine.usedCount,500);
  const explained=await local.pool.query(`explain(analyze,buffers,format json) ${query.text}`,query.values);
  const report=explained.rows[0]['QUERY PLAN'][0],nodes=[];
  function visit(node){nodes.push(node);for(const child of node.Plans??[])visit(child);}
  visit(report.Plan);
  const contextIndex=nodes.find(n=>n['Index Name']==='scores_platform_history'&&(n['Actual Loops']??0)>1);
  assert.ok(contextIndex,'each historical point must use the bounded owner history index');
  assert.ok(contextIndex['Actual Rows']<=500,'lateral history reads are bounded by windowSize');
  t.diagnostic(`PGlite fixture3500/page200/window500: execution=${report['Execution Time']}ms; history-index loops=${contextIndex['Actual Loops']}; rows/loop=${contextIndex['Actual Rows']}`);
});
