// Regression scenarios retained from the previous independent review, adapted
// to authoritative server snapshots. Current independent review is separate.
import test from 'node:test';
import assert from 'node:assert/strict';
import {myAttemptsModel,attemptWindow} from '../src/domain/my-attempts.ts';
const owner='supabase:12345678-1234-4234-8234-123456789abc';
function fixture(count=175,rms=true){const data=Array.from({length:count},(_,i)=>({id:`id-${i}`,number:i+1,timeMs:500+i*151,createdAt:100000+i*1000,runDistance:73,riskCount:4,hadJump:true,hadHelmet:true,included:true,windowCount:Math.min(i+1,73),averageMs:null}));
 for(let i=0;i<data.length;i++){const prefix=data.slice(0,i+1).slice(-73).reverse();const weights=prefix.reduce((s,_,j)=>s+.8**j,0),sum=prefix.reduce((s,r,j)=>s+(rms?r.timeMs**2:r.timeMs)*.8**j,0);data[i].averageMs=rms?Math.sqrt(sum/weights):sum/weights;}
 return {history:{userId:owner,snapshot:'rev1',totalCount:count,nextCursor:null,rows:data.slice().reverse(),best:data.at(-1)??null},average:{rules:{algorithm:rms?'weighted_rms_v1':'weighted_arithmetic_v1',windowSize:73,previousWeightPercent:80,minDurationMs:0,minAttempts:1},rows:[],mine:{userId:owner,averageMs:data.at(-1)?.averageMs??null,totalAttempts:count,usedCount:Math.min(count,73)}}};}
const model=server=>myAttemptsModel({profile:{id:owner,wallet:{bestTimeMs:0}},attempts:[],allTime:[],board:null,server});
test('preserved regression: all server RMS/arithmetic prefixes survive projection and old selection',()=>{
 for(const rms of [true,false]){const server=fixture(175,rms),m=model(server),ascending=server.history.rows.slice().reverse();assert.equal(m.rows.length,175);for(let i=0;i<175;i++)assert.equal(m.rows[i].averageMs,ascending[i].averageMs);const window=attemptWindow(m.rows,'id-4');assert.equal(window[0].number,1);assert.equal(window.at(-1).number,100);assert.equal(m.averageMs,server.average.mine.averageMs);}
});
test('preserved regression: null rules never fabricate local values',()=>{
 const m=model(null);assert.equal(m.averageMs,null);assert.equal(m.rules,null);assert.equal(m.chartMode,'none');
});
test('preserved regression: a partial page includes exact server context before its oldest row',()=>{
 const server=fixture(175);server.history.rows=server.history.rows.slice(0,25);server.history.nextCursor='older';const m=model(server);assert.equal(m.rows[0].number,151);assert.equal(m.rows[0].averageMs,server.history.rows.at(-1).averageMs);assert.equal(m.historyComplete,false);assert.equal(m.chartMode,'trend');
});
test('preserved regression: unknown formula still displays server-computed points without local formulas',()=>{
 const server=fixture(3);server.average.rules.algorithm='future_v9';const m=model(server);assert.equal(m.rows[0].averageMs,server.history.rows.at(-1).averageMs);assert.equal(m.averageMs,server.average.mine.averageMs);
});
test('preserved regression: absent record row keeps the genuine server record date',()=>{
 const server=fixture(5);server.history.best={...server.history.best,id:'unloaded',createdAt:100};const m=model(server);assert.equal(m.best.createdAt,100);assert.equal(m.best.localId,null);
});
test('preserved regression: same timestamps preserve server ordinal order',()=>{
 const server=fixture(12);server.history.rows.forEach(r=>r.createdAt=1000);const m=model(server);assert.deepEqual(m.rows.map(r=>r.number),Array.from({length:12},(_,i)=>i+1));
});
test('preserved regression: a legacy zero-time row remains visible without invented mean',()=>{
 const server=fixture(3);Object.assign(server.history.rows[2],{timeMs:0,averageMs:null,included:false,windowCount:0});const m=model(server);assert.equal(m.rows[0].attempt.result.timeMs,0);assert.equal(m.rows[0].averageMs,null);assert.equal(m.rows.length,3);
});
