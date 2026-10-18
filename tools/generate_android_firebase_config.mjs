// Produces three identical Android-only snapshots. Never uploads anything.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=process.argv[2];
if(!source) throw new Error('Pass the reviewed published snapshot path; no network or user-data import.');
const input=JSON.parse(fs.readFileSync(source,'utf8').replace(/^\uFEFF/,''));
if(input.ok !== true || !input.config?.economy?.androidEnergyV2) throw new Error('Invalid source snapshot');
const c=structuredClone(input.config),e=c.economy.androidEnergyV2;
e.enabled=true;e.revision='firebase-energy-v1';e.initialEnergy=50;e.chargeHours=8;e.watchAdCooldownSec=120;
e.rewards.feedback=50;e.rewards.ad=40; // Invitee keeps the existing20; inviter receives simpleBonus.inviterReward60.
e.simpleBonus={enabled:true,version:1,initialEnergy:50,reward:30,periodSec:28800,tier2Reward:60,tier5Reward:150,videoReward:40,videoCooldownSec:120,inviterReward:60};
e.packages=e.packages.map(p=>({id:p.id ?? p.productId,energy:p.energy ?? p.amount}));
e.subscriptions=e.subscriptions.map(s=>({id:s.id ?? s.productId,batteryCount:s.batteryCount,basePlanId:'weekly',capacity:20,chargeHours:8,periodDays:7}));
delete e.chargePolicy;
// Retired crystal/life/Telegram/cheat prices never drive Android Firebase.
const retained=['runRewardEvery','riskRewardEvery','earnSurviveSeconds','earnRecordSeconds','earnRisksInRun',
  'interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialGraceSec','interstitialCooldownSec','interstitialMinLives'];
c.economy={androidEnergyV2:e,...Object.fromEntries(retained.map(k=>[k,c.economy[k]])),initialLives:0,initialTokens:0,installBonusAutoClaim:false};
c.mobileEnemies={...c.mobileEnemies,speedVariation:0.05,accelerationVariation:0.08};
c.game.jumpCooldownSec ??= 2;
const snapshot={ok:true,revision:crypto.createHash('sha256').update(JSON.stringify(c)).digest('hex'),config:c};
for(const dest of ['assets/config/android-firebase.json','firebase-android/functions/config/defaults.json'])
  fs.writeFileSync(path.join(root,dest),JSON.stringify(snapshot,null,2)+'\n');
fs.writeFileSync(path.join(root,'firebase-android/remoteconfig.template.json'),JSON.stringify({parameters:{android_config_v1:{
  defaultValue:{value:JSON.stringify(snapshot)},valueType:'JSON',description:'Android only. Validated whole startup snapshot; no conditions; server reads the same default.'
}}},null,2)+'\n');
console.log(JSON.stringify({revision:snapshot.revision,sourceRevision:input.revision,mobileEnemies:c.mobileEnemies,userDataImported:false}));
