import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {PostgresStore} from '../functions/_shared/postgres-store.mjs';
import {createEngine,codeFor} from '../functions/_shared/core/engine.mjs';
import {defaults,hash} from '../functions/_shared/core/policy.mjs';
const local=await testDatabase();after(()=>local.close());const db=new PostgresStore(local.pool);
test('changed Remote Config bonus and both invite rewards reach actual server payouts',async()=>{
 const policy=structuredClone(defaults),e=policy.config.economy.androidEnergyV2,b=e.simpleBonus;
 Object.assign(b,{initialEnergy:90,reward:41,tier2Reward:82,tier5Reward:205,periodSec:3600,videoReward:47,videoCooldownSec:300,inviterReward:73});e.rewards.invite=29;
 policy.revision=hash(policy.config);let stamp=Date.UTC(2026,9,17);let serial=0;
 const engine=createEngine({roundProof:{start(){},finish(){}},db,getPolicy:async()=>policy,now:()=>stamp});
 const call=(uid,action,extra={},google=false)=>engine.execute(uid,{action,...extra},{googleLinked:google});
 const host='config_host',friend='config_friend';
 let profile=(await call(host,'guest')).profile;
 assert.equal(profile.wallet.energy,90);assert.equal(profile.wallet.energyConfig.reward,undefined);
 assert.equal(profile.wallet.energyConfig.rewards.invite,73);assert.equal(profile.wallet.simpleBonus.reward,41);
 assert.equal(profile.wallet.simpleBonus.policy.tier2Reward,82);assert.equal(profile.wallet.simpleBonus.policy.tier5Reward,205);
 assert.equal(profile.wallet.energyConfig.rewards.ad,47);assert.equal(profile.wallet.energyConfig.watchAdCooldownSec,300);
 await call(host,'wallet_operation',{kind:'energy_bonus_claim',args:{},operationId:hash('bonus')});
 profile=(await call(host,'profile')).profile;assert.equal(profile.wallet.energy,131);assert.equal(profile.wallet.simpleBonus.durationMs,3600000);
 await call(friend,'invites_bind',{code:codeFor(host)},true);
 for(let i=0;i<5;i++){
   const requestId=hash(`config-round:${++serial}`);
   const r=await call(friend,'round_start',{requestId,helmet:false,jump:false,revision:e.revision,rulesRevision:policy.revision},true);
   await call(friend,'round_activate',{requestId},true);stamp+=2000;
   await call(friend,'round_finish',{roundId:r.roundId,timeMs:1000,runDistance:0,riskCount:0,hadHelmet:false,hadJump:false},true);
 }
 await call(host,'google_link',{},true);
 const hostWallet=(await call(host,'profile',{},true)).profile.wallet;
 const friendWallet=(await call(friend,'profile',{},true)).profile.wallet;
 assert.equal(hostWallet.energy,204);assert.equal(friendWallet.energy,114);
 assert.equal((await call(host,'invites_state',{},true)).invites.reward,73);
 await call(friend,'google_link',{},true);assert.equal((await call(host,'profile',{},true)).profile.wallet.energy,204);
});
