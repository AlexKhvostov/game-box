import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import ts from '../node_modules/typescript/lib/typescript.js';
import {reactive,watch} from '../node_modules/vue/dist/vue.runtime.esm-bundler.js';
import {createAdPresenter} from '../src/platform/adsgram.ts';

// Independent service review. Real Vue watchers; fake clock/provider/network.
const source=fs.readFileSync(new URL('../src/services/ads.ts',import.meta.url),'utf8');
const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
function fixture(){
  let tick=0,wall=2e9,adult=true,consent=true,native=true,next=0,release;
  const state=reactive({profile:{id:'review-owner',wallet:{simpleBonus:{lastClaimAt:0},energySubscription:null}},screen:'result',resultId:'',locale:'ru',externalBusy:false,
    config:{revision:'review-revision',config:{economy:{interstitialSessionGraceSec:180,interstitialSessionFreeRounds:10,interstitialGraceSec:210,interstitialCooldownSec:220,interstitialMinLives:6}}},
    platform:{ads:{enabled:true,interstitialEnabled:true,rewardedBlockId:'55424',interstitialBlockId:'int-55425'}}});
  const energy=reactive({value:100}),doc={hidden:false,addEventListener(){},removeEventListener(){}},tg={isActive:true,onEvent(){},offEvent(){}};
  const stored=new Map(),views=[],sdkCalls=[],walletCalls=[];let delayed=false,destroyed=0,complete=true;
  const presenter={async show(block,rewarded,debug,canShow){views.push({block,rewarded,debug});if(delayed)await new Promise(resolve=>release=resolve);if(!canShow())return false;sdkCalls.push({block,rewarded});return complete;},destroy(){destroyed++;}};
  class ApiError extends Error{constructor(code){super(code);this.code=code;}}
  const mocks={vue:{reactive,watch},'./game-store':{state,energy,now:()=>wall,request:async()=>{},walletOperation:async(kind,args,id)=>walletCalls.push({kind,args,id})},
    './storage':{DurableStorage:class{get(k,f){return stored.get(k)??f;}set(k,v){stored.set(k,v);}},operationId:()=>String(++next)},
    '../platform/audience':{ensureResourceAge:async()=>adult,requestRewardedAds(){},canShowRewardedAds:()=>adult&&consent,canShowAds:()=>adult&&consent},
    '../platform/adsgram':{adPresenter:presenter},'../platform/telegram':{isNativeTelegram:()=>native,telegram:()=>tg},'../platform/audio':{stopAudio(){},syncMusic(){}},'./api':{ApiError}};
  const service={};new Function('require','exports','window','document','performance',js)(key=>{assert.ok(key in mocks,key);return mocks[key];},service,{addEventListener(){}},doc,{now:()=>tick});
  const round=id=>{state.resultId=id;service.completedRound(id);};
  return {state,energy,doc,tg,views,sdkCalls,walletCalls,service,round,
    advance(ms){tick+=ms;wall+=ms;},eligible(){this.advance(300000);for(let i=0;i<11;i++)round(`review-round-${i}`);},
    setAdult(v){adult=v;},setConsent(v){consent=v;},setNative(v){native=v;},delay(value=true){delayed=value;},release(){release?.();},setComplete(v){complete=v;},destroyed:()=>destroyed};
}

test('reviewer: fresh energy-v2 without legacy daily claim can show, missing/off switch cannot, rewarded is independent',async()=>{
  const f=fixture();f.eligible();assert.equal(f.state.profile.wallet.lastDailyAt,undefined);
  await f.service.maybeResultInterstitial();assert.equal(f.sdkCalls.length,1);assert.equal(f.sdkCalls[0].rewarded,false);
  for(const flag of [undefined,false]){const blocked=fixture();blocked.eligible();blocked.state.platform.ads.interstitialEnabled=flag;await blocked.service.maybeResultInterstitial();assert.equal(blocked.views.length,0);
    blocked.state.screen='video';await blocked.service.watchRewardedAd();assert.equal(blocked.sdkCalls.length,1);assert.equal(blocked.sdkCalls[0].rewarded,true);assert.deepEqual(blocked.walletCalls.map(c=>c.kind),['rewarded_ad_start','watch_ad']);}
});

test('reviewer: every mutable guard is checked after delayed SDK loading',async()=>{
  const changes=[f=>f.setAdult(false),f=>f.setConsent(false),f=>f.setNative(false),f=>f.state.screen='history',f=>f.doc.hidden=true,f=>f.tg.isActive=false,
    f=>f.state.platform.ads.interstitialEnabled=false,f=>f.state.platform.ads.enabled=false,f=>f.state.platform.ads.interstitialBlockId='int-999',f=>f.state.config.revision='new-revision',
    f=>f.energy.value=5,f=>f.state.profile.wallet.energySubscription={expiresAt:9e9},f=>f.state.profile.wallet.energySubscription={expiresAt:1,awaitingReconciliation:true},
    f=>f.state.profile.wallet.simpleBonus.lastClaimAt=2e9+300000,f=>f.state.config.config.economy.interstitialSessionFreeRounds=100,
    f=>f.state.profile={id:'other-owner',wallet:{simpleBonus:{lastClaimAt:0},energySubscription:null}}];
  for(const change of changes){const f=fixture();f.eligible();f.delay();const pending=f.service.maybeResultInterstitial();assert.equal(f.views.length,1);change(f);f.release();await pending;
    assert.equal(f.sdkCalls.length,0,change.toString());assert.equal(f.service.adsState.showing,false);assert.equal(f.state.externalBusy,false);}
});

test('reviewer: owner switch restarts free-round and time gates; duplicate result callbacks cannot spend free rounds',async()=>{
  const f=fixture();f.advance(300000);for(let i=0;i<40;i++)f.round('same-id');await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);
  for(let i=0;i<10;i++)f.round(`unique-${i}`);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
  f.state.profile={id:'second-owner',wallet:{simpleBonus:{lastClaimAt:0},energySubscription:null}};
  for(let i=0;i<11;i++)f.round(`second-${i}`);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
  f.advance(210000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,2);
});

test('reviewer: parallel calls reserve one request and failed/no-fill result does not repeat on reopen',async()=>{
  const f=fixture();f.eligible();f.delay();f.setComplete(false);const a=f.service.maybeResultInterstitial(),b=f.service.maybeResultInterstitial();assert.equal(f.views.length,1);f.release();await Promise.all([a,b]);
  f.delay(false);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1,'the same result cannot request another no-fill ad');
});

test('reviewer: session floors, configurable grace and cooldown boundaries remain inclusive',async()=>{
  const f=fixture();f.advance(179999);for(let i=0;i<11;i++)f.round(`boundary-${i}`);await f.service.maybeResultInterstitial();assert.equal(f.views.length,0);
  f.advance(30000);await f.service.maybeResultInterstitial();assert.equal(f.views.length,0,'initial grace210 still applies');
  f.advance(1);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
  f.round('new-result');f.advance(219999);await f.service.maybeResultInterstitial();assert.equal(f.views.length,1);
  f.advance(1);await f.service.maybeResultInterstitial();assert.equal(f.views.length,2);
});

test('reviewer: cancel while SDK is loading releases the caller without waiting for SDK/network timeout',async()=>{
  let release,initializations=0;
  const sdk={init(){initializations++;throw Error('canceled SDK must not initialize');}};
  const presenter=createAdPresenter(()=>new Promise(resolve=>release=resolve));
  const pending=presenter.show('int-55425',false);presenter.destroy();
  let timer;
  const result=await Promise.race([pending.then(value=>({settled:true,value})),new Promise(resolve=>timer=setTimeout(()=>resolve({settled:false}),50))]);
  clearTimeout(timer);release(sdk);await pending;
  assert.equal(result.settled,true,'destroy must release adsState/externalBusy immediately, not after the 15-second SDK timeout');
  assert.equal(result.value,false);assert.equal(initializations,0);
});
