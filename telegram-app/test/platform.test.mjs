import {test} from 'node:test';
import assert from 'node:assert/strict';
import {rewardFrame} from '../src/domain/reward-motion.ts';
import {createAdPresenter} from '../src/platform/adsgram.ts';
import '../public/kernel/android-world.js';
test('web reward timeline equals compiled frozen Android EnergyRewardFrame, normal and reduced motion',()=>{
  for(const reduced of [false,true])for(let n=-1;n<=101;n++){
    const p=n/100,actual=rewardFrame(p,reduced),expected=JSON.parse(globalThis.untouchKernel(JSON.stringify({op:'rewardFrame',p,reduced})));
    assert.equal(expected.ok,true);for(const[key,value]of Object.entries(actual))assert.ok(Math.abs(value-expected[key])<1e-12,`${key} at ${p}, reduced=${reduced}`);
  }
});
function sdkFixture(mode){const events=new Map();let destroyed=0;const controller={addEventListener:(e,f)=>events.set(e,f),removeEventListener:e=>events.delete(e),destroy:()=>destroyed++,async show(){if(mode==='reward')events.get('onReward')?.();if(mode==='skip')throw Error('skip');if(mode==='nofill')return{done:false,error:true};return{done:true,error:false};}};return{sdk:{init:()=>controller},get destroyed(){return destroyed;},events};}
test('AdsGram only successful rewarded callback credits, skip/error/resolved-without-reward never credit',async()=>{
  const original=globalThis.document;globalThis.document={hidden:false,addEventListener(){},removeEventListener(){}};
  try{for(const mode of ['reward','skip','nofill','resolved-without-reward']){const f=sdkFixture(mode),p=createAdPresenter(async()=>f.sdk);assert.equal(await p.show('123',true),mode==='reward');assert.equal(f.events.size,0);assert.ok(f.destroyed>0);}}
  finally{globalThis.document=original;}
});
test('AdsGram validates format and rechecks eligibility after delayed SDK load',async()=>{
  let release,allowed=true,initialized=0;const gate=new Promise(resolve=>release=resolve),p=createAdPresenter(async()=>{await gate;return{init(){initialized++;throw Error('should not initialize');}}});
  await assert.rejects(p.show('int-123',true),/ad_unavailable/);await assert.rejects(p.show('123',false),/ad_unavailable/);
  const delayed=p.show('123',true,false,()=>allowed);allowed=false;release();assert.equal(await delayed,false);assert.equal(initialized,0);
});
