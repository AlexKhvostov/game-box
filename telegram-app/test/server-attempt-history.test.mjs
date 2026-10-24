import {test} from 'node:test';
import assert from 'node:assert/strict';
import {ServerHistoryLoader,validateHistory} from '../src/domain/server-attempt-history.ts';
const owner='supabase:owner';
const response=(offset=0,limit=100,total=901,revision='revision-1')=>({ok:true,average:{rules:{algorithm:'weighted_rms_v1',windowSize:50,previousWeightPercent:92,minDurationMs:0,minAttempts:1},rows:[],mine:{userId:owner,averageMs:12000,usedCount:50,totalAttempts:total}},history:{userId:owner,snapshot:revision,totalCount:total,rows:Array.from({length:Math.min(limit,total-offset)},(_,i)=>({id:`score-${total-offset-i}`,number:total-offset-i,timeMs:1000+(total-offset-i)%30*1000,createdAt:1700000000000+(total-offset-i)*1000,runDistance:20,riskCount:1,hadJump:true,hadHelmet:false,averageMs:10000+(total-offset-i)%30*100,included:true,windowCount:50})),nextCursor:offset+limit<total?String(offset+limit):null,best:null}});
const memory=()=>{const data=new Map();return {data,get:(k,f)=>data.get(k)??f,set:(k,v)=>data.set(k,structuredClone(v))};};
test('all pages load beyond previous 200/600 device limit, first100 then200',async()=>{
 const requests=[],storage=memory(),loader=new ServerHistoryLoader(async body=>{requests.push(body);return response(Number(body.cursor??0),body.limit);},()=>{},storage);loader.setOwner(owner);await loader.refresh();
 assert.equal(loader.value.snapshot.history.rows.length,100);assert.equal(loader.value.snapshot.history.rows.at(-1).averageMs,response().history.rows.at(-1).averageMs);
 while(loader.value.snapshot.history.nextCursor)await loader.more();
 assert.equal(loader.value.snapshot.history.rows.length,901);assert.equal(requests[0].limit,100);assert.ok(requests.slice(1).every(r=>r.limit===200));assert.equal(loader.value.snapshot.history.rows.at(-1).number,1);
 assert.ok(storage.data.has(`attempt-history:v1:${owner}`));assert.equal(storage.data.size,1,'read cache cannot modify the journal');
 const cached=storage.data.get(`attempt-history:v1:${owner}`);assert.equal(cached.history.rows.length,100,'large loaded history is memory-only to preserve journal storage quota');assert.equal(cached.history.nextCursor,'100');
});
test('network failure retains verified page, retry continues exact failed page',async()=>{
 let fail=false;const loader=new ServerHistoryLoader(async b=>{if(fail)throw Error('network_unavailable');return response(Number(b.cursor??0),b.limit);},()=>{});loader.setOwner(owner);await loader.refresh();const old=loader.value.snapshot;fail=true;await loader.more();assert.equal(loader.value.snapshot,old);assert.equal(loader.value.error,'network_unavailable');fail=false;await loader.retry();assert.equal(loader.value.snapshot.history.rows.length,300);assert.equal(loader.value.error,'');
});
test('409 changed restarts first page without mixing snapshot revisions',async()=>{
 const requests=[];const loader=new ServerHistoryLoader(async b=>{requests.push(b);if(b.cursor)throw Error('attempt_history_changed');return response(0,b.limit,requests.length===1?901:902,requests.length===1?'r1':'r2');},()=>{});loader.setOwner(owner);await loader.refresh();await loader.more();assert.equal(loader.value.snapshot.history.snapshot,'r2');assert.equal(loader.value.snapshot.history.rows.length,100);assert.equal(loader.value.snapshot.history.rows[0].number,902);assert.equal(requests.length,3);
});
test('account switch and invalidation discard old in-flight responses',async()=>{
 let finish;const loader=new ServerHistoryLoader(()=>new Promise(r=>finish=r),()=>{});loader.setOwner(owner);const pending=loader.refresh();loader.setOwner('supabase:another');finish(response());await pending;assert.equal(loader.value.snapshot,null);assert.equal(loader.value.loading,false);
 loader.setOwner(owner);const pending2=loader.refresh();loader.invalidate();finish(response());await pending2;assert.equal(loader.value.snapshot,null);
});
test('concurrent page requests share one network operation',async()=>{
 let finish,count=0;const loader=new ServerHistoryLoader(()=>{count++;return new Promise(r=>finish=r);},()=>{});loader.setOwner(owner);const a=loader.refresh(),b=loader.refresh();assert.equal(a,b);assert.equal(count,1);finish(response());await a;assert.equal(loader.value.loading,false);
});
test('owner-bound cache restores curve and rejects foreign/corrupt cache',async()=>{
 const storage=memory();storage.set(`attempt-history:v1:${owner}`,response());const loader=new ServerHistoryLoader(async()=>{throw Error('offline');},()=>{},storage);loader.setOwner(owner);assert.equal(loader.value.snapshot.history.rows.length,100);await loader.refresh();assert.equal(loader.value.snapshot.history.rows.length,100);assert.equal(loader.value.error,'offline');loader.setOwner('other');assert.equal(loader.value.snapshot,null);
 storage.set('attempt-history:v1:other',response());loader.setOwner(owner);loader.setOwner('other');assert.equal(loader.value.snapshot,null);
});
test('malformed/foreign/out-of-order server responses never replace verified state',async()=>{
 for(const mutate of [r=>r.history.userId='other',r=>r.average.mine.userId='other',r=>r.history.rows.reverse(),r=>r.history.rows[0].averageMs=NaN,r=>r.history.rows[1].id=r.history.rows[0].id]){const v=response();mutate(v);assert.throws(()=>validateHistory(v,owner),/attempt_history_invalid/);}
 let bad=false;const loader=new ServerHistoryLoader(async b=>{const r=response(Number(b.cursor??0),b.limit);if(bad)r.average.mine.averageMs=999;return r;},()=>{});loader.setOwner(owner);await loader.refresh();const previous=loader.value.snapshot;bad=true;await loader.more();assert.equal(loader.value.snapshot,previous);assert.equal(loader.value.error,'attempt_history_invalid');
});

test('forced refresh after a new result keeps the last coherent snapshot on failure',async()=>{
 let fail=false;const loader=new ServerHistoryLoader(async()=>{if(fail)throw Error('offline');return response();},()=>{});loader.setOwner(owner);await loader.refresh();const previous=loader.value.snapshot;loader.invalidate(true);fail=true;await loader.refresh();assert.equal(loader.value.snapshot,previous);assert.equal(loader.value.error,'offline');
});

test('a nickname edit between pages does not invalidate the same calculated snapshot',async()=>{
 let edited=false;const loader=new ServerHistoryLoader(async b=>{const r=response(Number(b.cursor??0),b.limit);r.average.mine.playerName=edited?'New name':'Old name';return r;},()=>{});loader.setOwner(owner);await loader.refresh();edited=true;await loader.more();assert.equal(loader.value.error,'');assert.equal(loader.value.snapshot.history.rows.length,300);assert.equal(loader.value.snapshot.average.mine.playerName,'New name');
});

test('an invalid cached cursor resets to a first page even if the history revision is unchanged',async()=>{
 const loader=new ServerHistoryLoader(async b=>{if(b.cursor)throw Error('attempt_history_cursor_invalid');return response();},()=>{});loader.setOwner(owner);await loader.refresh();await loader.more();assert.equal(loader.value.error,'');assert.equal(loader.value.snapshot.history.rows.length,100);assert.equal(loader.value.snapshot.history.rows[0].number,901);
});
