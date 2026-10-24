// Runs real services/ads.ts and the real presenter with a synthetic provider.
// No browser, device, persistence or HTTP; reactive ownership uses Vue itself.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import ts from '../node_modules/typescript/lib/typescript.js';
import {reactive,watch} from '../node_modules/vue/index.mjs';
function compile(relative,mocks,globals){
 const source=fs.readFileSync(new URL(relative,import.meta.url),'utf8');
 const output=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={};new Function('require','exports',...Object.keys(globals),output)(name=>{assert.ok(name in mocks,name);return mocks[name];},exports,...Object.values(globals));return exports;
}
export function adServiceFixture({delaySdk=false,mode='success',failClaim=false}={}){
 let mono=0,wallOffset=0,sequence=0,shouldFail=failClaim,release;
 const state=reactive({profile:{id:'owner-a',wallet:{lastDailyAt:0,simpleBonus:{lastClaimAt:0},energySubscription:null}},platform:{ads:{enabled:true,interstitialEnabled:true,rewardedBlockId:'55424',interstitialBlockId:'int-55425'}},screen:'result',resultId:'',locale:'ru',config:{revision:'revision-a',config:{economy:{interstitialSessionGraceSec:180,interstitialSessionFreeRounds:10,interstitialMinLives:6,interstitialCooldownSec:220,interstitialGraceSec:210}}}});
 const values=new Map(),calls=[],views=[],initializations=[],stops=[],events=new Map(),documentEvents=new Map(),energy={value:100};
 const flags={consent:true,adult:true,native:true,active:true};
 const document={hidden:false,addEventListener:(k,cb)=>documentEvents.set(k,cb),removeEventListener:(k,cb)=>{if(documentEvents.get(k)===cb)documentEvents.delete(k);}};
 const globals={window:{addEventListener(){}},document,performance:{now:()=>mono}};
 const presenterModule=compile('../src/platform/adsgram.ts',{},globals);
 const sdk={init:options=>{initializations.push(options);const callbacks=new Map();return{addEventListener:(name,cb)=>callbacks.set(name,cb),removeEventListener:(name,cb)=>{if(callbacks.get(name)===cb)callbacks.delete(name);},destroy(){},show:async()=>{views.push(options);if(mode==='error')throw Error('provider_error');if(mode==='reward')callbacks.get('onReward')?.();return{done:mode!=='skip',error:mode==='nofill'};}};}};
 const loaded=delaySdk?new Promise(resolve=>release=resolve):Promise.resolve();
 const presenter=presenterModule.createAdPresenter(async()=>{await loaded;return sdk;});
 class ApiError extends Error{constructor(code){super(code);this.code=code;}}
 const mocks={vue:{reactive,watch:(...args)=>{const stop=watch(...args);stops.push(stop);return stop;}},'./game-store':{state,energy,now:()=>1e9+mono+wallOffset,request:async()=>{},walletOperation:async(kind,args,id)=>{calls.push({kind,args,id});if(kind==='watch_ad'&&shouldFail){shouldFail=false;throw new ApiError('network_unavailable');}}},'./storage':{DurableStorage:class{get(k,f){return values.get(k)??f;}set(k,v){values.set(k,v);}},operationId:()=>String(++sequence).padStart(64,'0')},'../platform/audience':{ensureResourceAge:async()=>true,requestRewardedAds(){},canShowRewardedAds:()=>flags.adult,canShowAds:()=>flags.adult&&flags.consent},'../platform/adsgram':{adPresenter:presenter},'../platform/telegram':{isNativeTelegram:()=>flags.native,telegram:()=>({get isActive(){return flags.active;},onEvent:(k,cb)=>events.set(k,cb),offEvent:(k,cb)=>{if(events.get(k)===cb)events.delete(k);}})},'../platform/audio':{stopAudio(){},syncMusic(){}},'./api':{ApiError}};
 const service=compile('../src/services/ads.ts',mocks,globals);
 const fixture={state,service,calls,views,initializations,energy,flags,document,advance:ms=>mono+=ms,shiftWall:ms=>wallOffset+=ms,wallNow:()=>1e9+mono+wallOffset,releaseSdk:()=>release?.(),deactivate:()=>{flags.active=false;events.get('deactivated')?.();},hide:()=>{document.hidden=true;documentEvents.get('visibilitychange')?.();},round:id=>{state.screen='result';state.resultId=id;service.completedRound(id);},ready:()=>{fixture.advance(220000);for(let i=1;i<=11;i++)fixture.round(`round-${i}`);},dispose:()=>{presenter.destroy();for(const stop of stops)stop();}};
 return fixture;
}
