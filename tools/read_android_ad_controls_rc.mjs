// Read-only release check. No RC publication or player data access.
import fs from 'node:fs';
import path from 'node:path';
import {root,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
const remote=createRemoteConfig({credentials});
const current=await remote.get();
const value=current.template.parameters?.android_config_v1?.defaultValue?.value;
if(!value)throw Error('android_config_v1_missing');
const snapshot=JSON.parse(value);
const dir=path.join(root,'tmp/main-ad-controls-228-20261027');
const backup=path.join(dir,'before-banner-unit.dpapi');
if(!fs.existsSync(backup))fs.writeFileSync(backup,dpapi(JSON.stringify(current)),{flag:'wx'});
fs.writeFileSync(path.join(dir,'live-android-config.json'),JSON.stringify(snapshot,null,2));
const c=snapshot.config;
const result={checkedAt:new Date().toISOString(),rcVersion:current.template.version?.versionNumber,revision:snapshot.revision,advertising:c.advertising,automatic:Object.fromEntries(['interstitialGraceSec','interstitialSessionGraceSec','interstitialSessionFreeRounds','interstitialCooldownSec','interstitialMinLives'].map(k=>[k,c.economy[k]])),published:false};
fs.writeFileSync(path.join(dir,'rc-readback.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
