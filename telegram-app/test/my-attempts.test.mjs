import {test} from 'node:test';
import assert from 'node:assert/strict';
import {myAttemptsModel,attemptWindow,ownAttempts} from '../src/domain/my-attempts.ts';
const owner='supabase:owner';
const local=(i,phase='confirmed',who=owner)=>({requestId:`local-${i}`,roundId:`score-${i}`,owner:who,createdAt:10000+i*1000,phase,result:{timeMs:i*1000,runDistance:i,riskCount:0}});
const board={rules:{algorithm:'weighted_rms_v1',windowSize:50,previousWeightPercent:92,minAttempts:5,minDurationMs:1000},rows:[],mine:{userId:owner,averageMs:11716.093,usedCount:32,eligibleCount:32,totalAttempts:232,place:null}};
const snapshot=(n=100,total=232)=>({average:structuredClone(board),history:{userId:owner,snapshot:'revision-232',totalCount:total,nextCursor:n<total?'next':null,best:{id:'best',number:3,timeMs:50000,createdAt:13000},rows:Array.from({length:n},(_,i)=>({id:`score-${total-i}`,number:total-i,createdAt:10000+(total-i)*1000,timeMs:4000+(total-i)%5*3500,runDistance:12,riskCount:1,hadJump:true,hadHelmet:false,averageMs:5000+(total-i)%5*1000,included:true,windowCount:32}))}});
const model=(patch={})=>myAttemptsModel({attempts:[],profile:{id:owner,wallet:{bestTimeMs:999999}},allTime:[],board,...patch});

test('partial server page supplies real changing historical points and ordinal numbers',()=>{
 const server=snapshot(),m=model({server});
 assert.equal(m.rows.length,100);assert.equal(m.rows[0].number,133);assert.equal(m.rows.at(-1).number,232);
 assert.equal(m.chartMode,'trend');assert.equal(m.averageMs,11716.093);assert.equal(m.historyComplete,false);
 assert.deepEqual(m.rows.map(r=>r.averageMs),server.history.rows.slice().reverse().map(r=>r.averageMs));
 assert.ok(new Set(m.rows.map(r=>r.averageMs)).size>1);
 assert.equal(m.best.timeMs,50000);assert.equal(m.best.createdAt,13000);assert.equal(m.best.localId,null);
 assert.notEqual(m.rows.at(-1).averageMs,m.averageMs,'historical points are not forcibly overwritten by an unrelated latest aggregate');
});
test('the selected chart window never changes the one current average',()=>{
 const server=snapshot(232),m=model({server});assert.equal(m.historyComplete,true);
 for(const id of ['score-1','score-125','score-232']){const window=attemptWindow(m.rows,id);assert.ok(window.some(r=>r.attempt.requestId===id));assert.equal(window.length,100);assert.equal(m.averageMs,11716.093);}
 assert.equal(m.rules.windowSize,50,'100 displayed attempts do not expand the 50-attempt calculation');
 assert.equal(attemptWindow(m.rows,'score-232')[0].number,133);
 assert.equal(attemptWindow(m.rows,'missing').at(-1).number,232);
});
test('history snapshot owns average even after random ranking refresh',()=>{
 const server=snapshot(),m=model({server,board:{...board,mine:{...board.mine,averageMs:999999}}});
 assert.equal(m.averageMs,server.average.mine.averageMs);assert.equal(m.usedCount,32);
});
test('server best links exact id rather than equal-duration local attempt',()=>{
 const server=snapshot();server.history.best={...server.history.rows[0]};const m=model({server,attempts:[local(232)]});
 assert.equal(m.best.localId,'score-232');assert.equal(m.rows.length,100);assert.equal(m.pending.length,0);
});
test('local queued rows are separate and have no invented numbers or curve points',()=>{
 const server=snapshot(),a=local(999,'finished'),m=model({server,attempts:[a,local(2,'rejected'),local(3,'confirmed'),local(232,'finished'),local(4,'finished','foreign')]});
 assert.deepEqual(m.pending.map(r=>r.requestId),['local-2','local-999']);assert.equal(m.rows.length,100);
 assert.ok(m.rows.every(r=>r.attempt.phase==='confirmed'));assert.equal(m.best.source,'server');
});
test('local-only partial or apparently complete history never fabricates a curve',()=>{
 const m=model({attempts:[local(1),local(2,'finished')]});assert.deepEqual(m.rows,[]);assert.equal(m.pending.length,1);assert.equal(m.chartMode,'none');assert.equal(m.averageMs,11716.093);assert.equal(m.best,null);
});
test('total tile uses authoritative total, never loaded rows or the delivery queue',()=>{
 assert.equal(model({server:snapshot(),attempts:[local(999,'finished')]}).totalCount,232);
 assert.equal(model().totalCount,232);
 assert.equal(model({board:null}).totalCount,null);
 const empty=snapshot(0,0);assert.equal(model({server:empty}).totalCount,0);
});
test('foreign account snapshots and ranking aggregates never leak',()=>{
 const server=snapshot();server.history.userId='other';const m=model({server,board:{...board,mine:{...board.mine,userId:'other'}}});
 assert.equal(m.averageMs,null);assert.equal(m.rules,null);assert.equal(m.rows.length,0);assert.equal(m.best,null);
});
test('null and valid zero stay distinct without a fallback device RMS',()=>{
 for(const official of [null,0]){const server=snapshot(0,0);server.average.mine.averageMs=official;server.average.mine.totalAttempts=0;server.history.best=null;const m=model({server});assert.equal(m.averageMs,official);assert.equal(m.chartMode,'none');}
});
test('active window counts eligible attempts rather than raw ordinal positions',()=>{
 const server=snapshot(100,100);server.average.mine.usedCount=50;server.history.rows.forEach((r,i)=>r.included=i>=30);const m=model({server});
 assert.equal(m.rows.filter(r=>r.inCurrentWindow).length,50);assert.equal(m.rows.find(r=>r.number===21).inCurrentWindow,true);assert.equal(m.rows.find(r=>r.number===71).inCurrentWindow,false);
});
test('own journal filtering remains owner-bound, stable and nonmutating',()=>{
 const input=[local(3),local(1),local(2,'finished'),local(2,'finished'),local(4,'confirmed','foreign')];const copy=structuredClone(input);
 assert.deepEqual(ownAttempts(input,owner).map(r=>r.requestId),['local-1','local-2','local-3']);assert.deepEqual(input,copy);assert.deepEqual(ownAttempts(input,null),[]);
});
