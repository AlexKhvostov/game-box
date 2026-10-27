import {test,after} from 'node:test';import assert from 'node:assert/strict';
import {createEngine} from '../functions/_shared/core/engine.mjs';
import {defaults,hash,validatePolicy} from '../functions/_shared/core/policy.mjs';
import {fields,applyChanges} from '../functions/_shared/config-schema.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {testDatabase} from './database.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
let serial=0;const id=()=>hash('daily-test-'+(++serial));
function fixture(){let stamp=Date.UTC(2026,9,18,20);const config=structuredClone(defaults.config);
 const engine=createEngine({db,now:()=>stamp,getPolicy:async()=>({ok:true,config,revision:hash(config)})});
 const uid='daily_'+id();const op=(kind,args={},operationId=id())=>engine.execute(uid,{action:'wallet_operation',kind,args,operationId});
 return {uid,config,op,advance:ms=>stamp+=ms,at:ms=>stamp=ms,profile:()=>engine.execute(uid,{action:'profile'})};}
test('rewarded switch denies new sessions and still pays an already quoted session',async()=>{
 const f=fixture();await f.profile();const sessionId=id();
 await f.op('rewarded_ad_start',{sessionId});
 f.config.advertising={rewarded:{enabled:false}};
 await assert.rejects(f.op('rewarded_ad_start',{sessionId:id()}),e=>e.code==='ad_unavailable');
 const paid=await f.op('watch_ad',{sessionId});
 assert.equal(paid.profile.wallet.energy,90);
 assert.equal(paid.profile.wallet.adQuota.used,1);
});
test('20 confirmed rewards per Minsk day; duplicate ACK never consumes twice; next midnight resets',async()=>{
 const f=fixture();await f.profile();let last;
 for(let i=1;i<=20;i++){
  const sessionId=id();await f.op('rewarded_ad_start',{sessionId});
  const operationId=id();last=await f.op('watch_ad',{sessionId},operationId);
  assert.equal(last.profile.wallet.adQuota.used,i);
  assert.equal((await f.op('watch_ad',{sessionId},operationId)).profile.wallet.adQuota.used,i);
  f.advance(120000);
 }
 assert.equal(last.profile.wallet.energy,850);assert.equal(last.profile.wallet.adQuota.remaining,0);
 await assert.rejects(f.op('rewarded_ad_start',{sessionId:id()}),e=>e.code==='ad_daily_limit');
 f.at(Date.UTC(2026,9,18,20,59,59));assert.equal((await f.profile()).profile.wallet.adQuota.used,20);
 f.advance(1000);const tomorrow=await f.profile();assert.equal(tomorrow.profile.wallet.adQuota.used,0);
 const sessionId=id();await f.op('rewarded_ad_start',{sessionId});await f.op('watch_ad',{sessionId});
 assert.equal((await f.profile()).profile.wallet.adQuota.used,1);
});
test('last daily credit is atomic across sessions; abandoned sessions consume no quota',async()=>{
 const f=fixture();f.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit=1;await f.profile();
 const a=id(),b=id();await f.op('rewarded_ad_start',{sessionId:a});await f.op('rewarded_ad_start',{sessionId:b});
 assert.equal((await f.profile()).profile.wallet.adQuota.used,0);
 const outcomes=await Promise.allSettled([f.op('watch_ad',{sessionId:a}),f.op('watch_ad',{sessionId:b})]);
 assert.equal(outcomes.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await f.profile()).profile.wallet.energy,90);
 assert.equal((await f.profile()).profile.wallet.adQuota.used,1);
});
test('RC changes quota/cooldown immediately and preserves today usage; old config defaults to20',async()=>{
 const f=fixture();delete f.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit;
 assert.equal((await f.profile()).profile.wallet.adQuota.limit,20);
 const sessionId=id();await f.op('rewarded_ad_start',{sessionId});await f.op('watch_ad',{sessionId});
 f.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit=1;f.advance(120000);
 await assert.rejects(f.op('rewarded_ad_start',{sessionId:id()}),e=>e.code==='ad_daily_limit');
 f.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit=3;
 f.config.economy.androidEnergyV2.simpleBonus.videoCooldownSec=180;
 await assert.rejects(f.op('rewarded_ad_start',{sessionId:id()}),e=>e.code==='ad_not_ready');
 f.advance(60000);await f.op('rewarded_ad_start',{sessionId:id()});
 const p=await f.profile();assert.equal(p.profile.wallet.adQuota.used,1);assert.equal(p.profile.wallet.energyConfig.watchAdCooldownSec,180);
});
test('admin exposes daily count and cooldown with integer ranges; unrelated fields stay unchanged',()=>{
 const root='economy.androidEnergyV2.simpleBonus.';
 for(const key of ['videoCooldownSec','videoDailyLimit']){const field=fields.find(f=>f.path===root+key);assert.ok(field&&!field.readOnly&&!field.hidden);}
 const result=applyChanges(defaults,[{path:root+'videoDailyLimit',value:20},{path:root+'videoCooldownSec',value:150}]);
 assert.equal(result.economy.androidEnergyV2.simpleBonus.videoDailyLimit,20);
 assert.equal(result.economy.androidEnergyV2.watchAdCooldownSec,150);
 for(const value of [0,-1,1.5,1001])assert.throws(()=>applyChanges(defaults,[{path:root+'videoDailyLimit',value}]));
 for(const value of [0,-1,1.5,86401])assert.throws(()=>applyChanges(defaults,[{path:root+'videoCooldownSec',value}]));
 const old=structuredClone(defaults);delete old.config.economy.androidEnergyV2.simpleBonus.videoDailyLimit;old.revision=hash(old.config);assert.ok(validatePolicy(old));
});
