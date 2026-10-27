// Read production inventory only. No player records, IAM, policy or file writes remotely.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {privateDirectory,dpapi,root} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {readPlatformTemplate,materializePlatform} from '../supabase/functions/_shared/platform-config.mjs';
const out='C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027';
fs.mkdirSync(out,{recursive:true});
const remote=createRemoteConfig({credentials:JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true))});
const current=await remote.get();
const backup=path.join(out,'before-rc.dpapi');
if(!fs.existsSync(backup))fs.writeFileSync(backup,dpapi(JSON.stringify(current)),{flag:'wx'});
const envelope=readPlatformTemplate(current.template,current.snapshot);
const require=createRequire('D:/_P_R_O_J_E_C_T/game/square/Untouch/firebase-android/package.json');
const auth=require('firebase-tools/lib/auth');
const account=auth.getGlobalDefaultAccount();if(!account)throw Error('firebase_account_missing');
const {access_token}=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
async function hosting(resource){
 const response=await fetch('https://firebasehosting.googleapis.com/v1beta1/'+resource,{headers:{Authorization:'Bearer '+access_token}});
 if(!response.ok)throw Error('hosting_inventory_'+response.status);
 return response.json();
}
const site='untouch-admin-game-box-b30d4';
const channel=await hosting(`sites/${site}/channels/live`);
const version=await hosting(channel.release.version.name);
let pageToken='',files=[];
do{const page=await hosting(version.name+'/files?pageSize=1000'+(pageToken?'&pageToken='+encodeURIComponent(pageToken):''));files.push(...page.files??[]);pageToken=page.nextPageToken??'';}while(pageToken);
fs.writeFileSync(path.join(out,'before-hosting.json'),JSON.stringify({site,channel,version,files},null,2));
const summary={rcVersion:current.template.version?.versionNumber,schemaVersion:envelope.schemaVersion,
 advertising:envelope.common.advertising??null,
 automaticTiming:Object.fromEntries(['interstitialGraceSec','interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialCooldownSec','interstitialMinLives'].map(k=>[k,envelope.common.economy[k]])),
 rewarded:Object.fromEntries(['videoReward','videoCooldownSec','videoDailyLimit'].map(k=>[k,envelope.common.economy.androidEnergyV2.simpleBonus[k]])),
 platformGates:Object.fromEntries(['android','telegram'].map(p=>[p,envelope.platforms[p].ads])),
 hostingVersion:version.name,hostingFiles:files.map(f=>({path:f.path,hash:f.hash})),encryptedRcBackup:true};
fs.writeFileSync(path.join(out,'inventory-summary.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));
