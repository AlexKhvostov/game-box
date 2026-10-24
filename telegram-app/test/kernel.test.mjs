import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import '../public/kernel/android-world.js';

const root=path.resolve(import.meta.dirname,'../..');
const baseline=JSON.parse(fs.readFileSync(path.join(root,'docs/release-evidence/telegram-port/P0/baseline.json')));
const frozen=path.join(root,baseline.privateSnapshot);
await import(pathToFileURL(path.join(frozen,'supabase/functions/_shared/android-replay.generated.mjs')));
const config=JSON.parse(fs.readFileSync(path.join(frozen,'assets/config/android-firebase.json'))).config;
const call=input=>JSON.parse(globalThis.untouchKernel(JSON.stringify(input)));

test('browser adapter rejects invalid requests and lifecycle order',()=>{
  assert.equal(call({op:'tick',ms:16}).ok,false);
  assert.equal(call({op:'create',config,requestId:'invalid-check'}).ok,true);
  assert.equal(call({op:'tick',ms:16}).ok,false);
  assert.equal(call({op:'idle',ms:NaN}).ok,false);
  assert.equal(call({op:'start'}).ok,true);
  assert.equal(call({op:'start'}).ok,false);
  assert.equal(call({op:'tick',ms:51}).ok,false);
  assert.equal(call({op:'move',dx:3000,dy:0}).ok,false);
});
test('actual frozen Android GameStartGuard accepts proportions and rejects invisible/distorted fields before activation',()=>{
  call({op:'create',config,requestId:'geometry-guard'});
  const guard=patch=>call({op:'guard',field:[16,112,380,380],visible:[0,0,412,844],dpr:2,...patch});
  assert.equal(guard({}).issue,null);
  assert.equal(guard({field:[16,112,0,0]}).issue,'field_not_ready');
  assert.equal(guard({field:[16,112,360,380]}).issue,'field_distorted');
  assert.equal(guard({visible:[0,0,412,200]}).issue,'field_clipped');
  assert.equal(guard({dpr:0}).issue,'field_not_ready');
  assert.equal(call({op:'snapshot'}).playing,false);
});

test('seeded browser idle/start/input/helmet/jump proofs match frozen server replay exactly',()=>{
  let total=0;
  const timings=[];
  for(let seed=0;seed<64;seed++){
    const requestId=`telegram-parity-${seed}`,hadJump=seed%2===0,hadHelmet=seed%3===0;
    let s=call({op:'create',config,requestId,hadJump,hadHelmet});
    assert.equal(s.ok,true);
    assert.equal(s.player.size,config.player.size*1.2);
    for(const e of s.enemies){assert.ok(Math.abs(e.w*e.h/(s.player.size**2)-config.enemies.areaMultiplier)<1e-10);}
    for(let i=0;i<seed%35;i++) s=call({op:'idle',ms:16.67});
    const before=s.enemies.map(e=>[e.x,e.y,e.angle]);
    s=call({op:'start'});
    assert.deepEqual(s.enemies.map(e=>[e.x,e.y,e.angle]),before);
    // Include first-move-before-first-frame, variable timestep and collisions.
    if(seed%4===0) s=call({op:'move',dx:40,dy:-35});
    for(let frame=0;frame<15000&&!s.dead;frame++){
      if(hadJump && frame%127===0)s=call({op:'jump'});
      if(frame%3===0&&!s.dead)s=call({op:'move',dx:Math.sin(frame*.37+seed)*14,dy:Math.cos(frame*.21+seed)*13});
      if(s.dead)break;
      const start=performance.now();
      s=call({op:'tick',ms:[16,16.67,33.3,50][frame%4]});
      timings.push(performance.now()-start);total++;
      assert.equal(s.ok,true,`seed=${seed}, frame=${frame}`);
    }
    assert.equal(s.dead,true,`unfinished seed ${seed}`);
    const proof=call({op:'proof'}).proof;
    assert.ok(proof.events.length>0);
    assert.ok(proof.startPose.length===config.enemies.aspects.length);
    const result=JSON.parse(globalThis.untouchReplay(JSON.stringify({config,requestId,hadJump,hadHelmet,proof})));
    assert.equal(result.ok,true,`server rejected seed ${seed}`);
    assert.deepEqual(result,{ok:true,timeMs:s.timeMs,runDistance:s.runDistance,riskCount:s.riskCount},`metrics seed ${seed}`);
  }
  timings.sort((a,b)=>a-b);
  const report={kind:'node-desktop-incremental-kernel-only-not-device-fps',seeds:64,totalTicks:total,
    p50Ms:timings[Math.floor(timings.length*.5)],p95Ms:timings[Math.floor(timings.length*.95)],p99Ms:timings[Math.floor(timings.length*.99)]};
  fs.mkdirSync(path.join(root,'docs/release-evidence/telegram-port/P1'),{recursive:true});
  fs.writeFileSync(path.join(root,'docs/release-evidence/telegram-port/P1/kernel-performance.json'),JSON.stringify(report,null,2)+'\n');
});

test('first move records minimum tick, border stays clamped and proof is bounded',()=>{
  call({op:'create',config,requestId:'first-swipe',hadHelmet:true});call({op:'start'});
  const s=call({op:'move',dx:500,dy:0});
  const p=call({op:'proof'}).proof;
  assert.deepEqual(p.events[0],[0,1]);
  assert.equal(s.timeMs,1);
  assert.ok(s.player.x+s.player.size<=380);
});
