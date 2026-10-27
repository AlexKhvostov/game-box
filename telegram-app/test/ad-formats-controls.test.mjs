import {test} from 'node:test';
import assert from 'node:assert/strict';
import {adServiceFixture} from './ads-service-fixture.mjs';

test('automatic and rewarded switches are independent of banner',async()=>{
 const f=adServiceFixture();try{
  f.ready();f.state.config.config.advertising={banner:{enabled:true},automatic:{enabled:false},rewarded:{enabled:true}};
  assert.equal(f.service.adsAvailable(),true);
  await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);
  f.state.config.config.advertising={banner:{enabled:false},automatic:{enabled:true},rewarded:{enabled:false}};
  assert.equal(f.service.adsAvailable(),false);
  await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
 }finally{f.dispose();}
});
test('long background absence creates a quiet window on return',async()=>{
 const f=adServiceFixture();try{
  f.ready();f.state.config.config.advertising={automatic:{longAbsenceSec:300,resumeGraceSec:180}};
  f.hide();f.advance(300000);f.show();
  await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);
  f.advance(179000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);
  f.advance(1000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
 }finally{f.dispose();}
});
test('a pending automatic load cannot survive deactivation/reactivation',async()=>{
 const f=adServiceFixture({delaySdk:true});try{
  f.ready();const pending=f.service.maybeResultInterstitial();
  f.deactivate();f.advance(1000);f.activate();f.releaseSdk();
  await pending;assert.equal(f.views.length,0);
 }finally{f.dispose();}
});
