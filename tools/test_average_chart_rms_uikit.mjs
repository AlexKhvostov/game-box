import assert from 'node:assert/strict';
import {averageChartDemo,averageChartSeries,averageChartPage,averageChartCard,selectAverageChart} from '../docs/design/simple-energy-bonus-20261016/live-kit/average-chart.js';

// Independent oracle using chronological powers rather than the renderer's loop.
function oracle(values,{windowSize=50,previousWeightPercent=92,minDurationMs=0}={}){
  const used=values.filter(t=>t>minDurationMs).slice(-windowSize);
  const weights=used.map((_,i)=>(previousWeightPercent/100)**(used.length-1-i));
  const total=weights.reduce((a,b)=>a+b,0);
  return {average:total?used.reduce((s,t,i)=>s+t*weights[i],0)/total:null,
    rms:total?Math.sqrt(used.reduce((s,t,i)=>s+t*t*weights[i],0)/total):null};
}
const near=(a,b)=>a===null||b===null?assert.equal(a,b):assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);
const rows=averageChartSeries(averageChartDemo);
assert.equal(rows.length,100);
for(const [i,row] of rows.entries()){
  const expected=oracle(averageChartDemo.slice(0,i+1));
  near(row.average,expected.average);near(row.rms,expected.rms);
  assert.ok(row.rms+1e-7>=row.average,'RMS must not be below arithmetic mean with the same weights');
}
near(rows.at(-1).average,9263.854161690324); // Existing chart baseline must stay unchanged.
const changed=averageChartSeries(averageChartDemo.map((t,i)=>i<50?t+100000:t));
near(changed.at(-1).rms,rows.at(-1).rms);
assert.notEqual(changed[49].rms,rows[49].rms);
const constant=averageChartSeries(Array(100).fill(3000)).at(-1);
near(constant.average,3000);near(constant.rms,3000);
const simple=averageChartSeries([15000,3000],{previousWeightPercent:100}).at(-1);
near(simple.rms,Math.sqrt(117)*1000);
const recency=averageChartSeries([15000,3000]).at(-1);
near(recency.rms,Math.sqrt((.92*15000**2+3000**2)/1.92));
assert.ok(recency.rms<simple.rms,'Recent weak attempt must have more influence');
const withShort=averageChartSeries([15000,3000,500]).at(-1);
assert.ok(withShort.rms<recency.rms,'Short attempts are included, not silently discarded');
for(const options of [{},{windowSize:3,previousWeightPercent:75,minDurationMs:1000},{previousWeightPercent:0}]){
  const values=[0,500,1000,15000,3000,800,2000];
  const actual=averageChartSeries(values,options);
  actual.forEach((row,i)=>{const expected=oracle(values.slice(0,i+1),options);near(row.rms,expected.rms);near(row.average,expected.average);});
}
const improved=averageChartDemo.map((t,i)=>i===80?t+1000:t);
assert.ok(averageChartSeries(improved).at(-1).rms>rows.at(-1).rms);
selectAverageChart(79);
const oldCard=averageChartCard({calculation:'weighted'}),newCard=averageChartCard();
for(const html of [oldCard,newCard]){
  assert.equal((html.match(/data-duration-ms=/g)||[]).length,100);
  assert.ok(html.includes('Попытка 80: <b>10,154 с</b>'));
  assert.ok(html.includes('В расчёте — последние 50'));
}
const bars=html=>[...html.matchAll(/data-attempt="(\d+)" data-duration-ms="(\d+)"/g)].map(m=>[m[1],m[2]]);
assert.deepEqual(bars(oldCard),bars(newCard));
assert.ok(oldCard.includes('ac-bars-weighted-page'));assert.ok(newCard.includes('ac-bars-rms-page'));
assert.equal((averageChartPage().match(/data-calculation=/g)||[]).length,2);
selectAverageChart(null);
console.log(JSON.stringify({ok:true,points:100,active:rows.filter(r=>r.inCurrentWindow).length,
  weightedMs:rows.at(-1).average,rmsMs:rows.at(-1).rms,deltaMs:rows.at(-1).rms-rows.at(-1).average,
  checks:['all-prefixes-independent-oracle','same-input','same-window','same-decay','old-baseline','short-attempts','threshold','equal-values','rms-monotonicity','linked-selection']}));
