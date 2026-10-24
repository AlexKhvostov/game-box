import {test} from 'node:test';
import assert from 'node:assert/strict';
import {MotionProbe} from '../src/game/motion-probe.ts';
const turn=()=>new Promise(r=>setImmediate(r));

test('production and inactive diagnostics collect nothing',async()=>{
  for(const enabled of [false,true]){
    const p=new MotionProbe(enabled);if(!enabled)p.start();
    p.frame(100,100,1,2);p.input(5,true);p.persisted(10,1000);p.finish();await turn();
    assert.equal(p.report(),null);
  }
});

test('active-only timing capture is bounded and freezes before a new run; logs contain no game identity',async t=>{
  t.mock.timers.enable({apis:['setTimeout']});
  const original=console.info,logs=[];console.info=s=>logs.push(s);
  try{
    const p=new MotionProbe(true);p.start();
    for(let i=0;i<1900;i++)p.frame(16.667,17,.5,1.25);
    for(let i=0;i<3700;i++)p.paint([.1,.2,.3,.4,.5,.6]);
    for(let i=0;i<80;i++)p.persisted(.25,2000);
    p.input(2,true);p.input();p.finish();await turn();
    const a=p.report();assert.equal(a.frames.length,1800);assert.equal(a.droppedFrames,100);assert.equal(a.paints.length,3600);assert.equal(a.droppedPaints,100);assert.equal(a.storage.length,64);assert.equal(a.moves,2);assert.equal(a.inputDraws,1);
    p.start();p.frame(33.333,33,2,3);p.finish();await turn();
    assert.equal(p.report().frames.length,1);assert.equal(a.frames.length,1800);
    t.mock.timers.tick(700);assert.ok(logs.length>1);
    for(const line of logs){assert.ok(line.length<4000);const data=JSON.parse(line.slice('UNTOUCH_MOTION '.length));assert.ok(['summary','frames'].includes(data.kind));assert.doesNotMatch(line,/requestId|roundId|initData|nickname|proof|Authorization/);}
  }finally{console.info=original;t.mock.timers.reset();}
});
