import test from 'node:test';
import assert from 'node:assert/strict';
import {adServiceFixture} from './ads-service-fixture.mjs';
const own=t=>{const f=adServiceFixture();t.after(f.dispose);return f;};
test('absent/false automatic flag is off while voluntary rewarded ads still work',async t=>{
 for(const value of [undefined,false,null,'true',1]){const f=adServiceFixture({mode:'reward'});t.after(f.dispose);f.ready();if(value===undefined)delete f.state.platform.ads.interstitialEnabled;else f.state.platform.ads.interstitialEnabled=value;await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);f.state.screen='video';await f.service.watchRewardedAd();assert.deepEqual(f.calls.map(v=>v.kind),['rewarded_ad_start','watch_ad']);}
});
test('energy-v2 session and bonus clocks work with legacy lastDailyAt zero',async t=>{
 const f=own(t);f.ready();await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);assert.equal(f.views[0].blockId,'int-55425');assert.equal(f.calls.length,0);
 const g=own(t);g.ready();g.state.profile.wallet.simpleBonus.lastClaimAt=g.wallNow();await g.service.maybeResultInterstitial();assert.equal(g.views.length,0);g.advance(210000);await g.service.maybeResultInterstitial();assert.equal(g.views.length,1);
});
test('age, consent, visibility, subscription, energy and platform guards fail closed',async t=>{
 const guards=[f=>f.flags.adult=false,f=>f.flags.consent=false,f=>f.flags.native=false,f=>f.flags.active=false,f=>f.document.hidden=true,f=>f.state.platform.ads.enabled=false,f=>f.state.screen='energy',f=>f.energy.value=5,f=>f.energy.value=NaN,f=>f.state.platform.ads.interstitialBlockId='55424',f=>f.state.profile.wallet.energySubscription={expiresAt:f.wallNow()+1000},f=>f.state.profile.wallet.energySubscription={expiresAt:0,awaitingReconciliation:true},f=>f.state.config.config.economy.interstitialCooldownSec=undefined];
 for(const guard of guards){const f=own(t);f.ready();guard(f);await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);assert.equal(f.service.adsState.showing,false);}
});
test('first ten unique rounds and the session grace remain free even with duplicate callbacks',async t=>{
 const f=own(t);f.advance(300000);for(let i=0;i<10;i++)f.round(`r${i}`);for(let i=0;i<20;i++)f.service.completedRound('r9');await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);f.round('r10');await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
 const g=own(t);for(let i=0;i<11;i++)g.round(`r${i}`);g.advance(179999);await g.service.maybeResultInterstitial();assert.equal(g.views.length,0);g.advance(30001);await g.service.maybeResultInterstitial();assert.equal(g.views.length,1);
});
test('last daily timestamp is irrelevant; fresh bonus resets the grace and future timestamp delays it',async t=>{
 const f=own(t);f.ready();f.state.profile.wallet.lastDailyAt=f.wallNow()+999999;f.state.profile.wallet.simpleBonus.lastClaimAt=f.wallNow()+1000;await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);f.advance(211000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
});
test('every eligibility restriction is checked again after asynchronous SDK loading',async t=>{
 const changes=[f=>f.state.platform.ads.interstitialEnabled=false,f=>f.flags.consent=false,f=>f.flags.adult=false,f=>f.state.profile.wallet.energySubscription={expiresAt:f.wallNow()+99999},f=>f.energy.value=0,f=>f.state.profile.wallet.simpleBonus.lastClaimAt=f.wallNow(),f=>f.state.config.revision='new',f=>f.state.platform.ads.interstitialBlockId='int-999',f=>f.state.screen='energy',f=>f.state.resultId='other',f=>f.deactivate(),f=>f.hide()];
 for(const change of changes){const f=adServiceFixture({delaySdk:true});t.after(f.dispose);f.ready();const pending=f.service.maybeResultInterstitial();assert.equal(f.service.adsState.showing,true);change(f);f.releaseSdk();await pending;assert.equal(f.views.length,0);assert.equal(f.initializations.length,0);assert.equal(f.service.adsState.showing,false);assert.equal(f.state.externalBusy,false);}
});
test('ownership resets counts and clocks and rejects A→B→A while SDK is loading',async t=>{
 const f=adServiceFixture({delaySdk:true});t.after(f.dispose);f.ready();const pending=f.service.maybeResultInterstitial();f.state.profile.id='owner-b';f.state.profile.id='owner-a';f.releaseSdk();await pending;assert.equal(f.views.length,0);f.advance(300000);f.round('new-1');await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);for(let i=2;i<=11;i++)f.round(`new-${i}`);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
});
test('one provider attempt per result, including skip/no-fill/error, and one flight at a time',async t=>{
 for(const mode of ['success','skip','nofill','error']){const f=adServiceFixture({mode});t.after(f.dispose);f.ready();await Promise.all([f.service.maybeResultInterstitial(),f.service.maybeResultInterstitial()]);assert.equal(f.views.length,1);f.advance(1000000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);assert.equal(f.calls.length,0);}
});
test('successful display cooldown applies to the next round at the configured boundary',async t=>{
 const f=own(t);f.ready();await f.service.maybeResultInterstitial();f.round('next');f.advance(219999);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);f.advance(1);await f.service.maybeResultInterstitial();assert.equal(f.views.length,2);
});
