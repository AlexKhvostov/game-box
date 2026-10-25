// Read-only Remote Config audit. Credentials stay in memory, no publish calls.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {readPlatformTemplate,materializePlatform} from '../supabase/functions/_shared/platform-config.mjs';

try {
  const file=path.join(process.env.LOCALAPPDATA,'Untouch/private/untouch-remote-config.dpapi');
  const decrypted=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command',
    'Add-Type -AssemblyName System.Security;$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());[Console]::Out.Write([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))'],
    {input:fs.readFileSync(file,'utf8'),encoding:'utf8',windowsHide:true});
  if(decrypted.status!==0) throw Error('dpapi_failed');
  const remote=createRemoteConfig({credentials:JSON.parse(decrypted.stdout)});
  decrypted.stdout='';
  const live=await remote.get();
  const economy=live.snapshot.config.economy;
  const keys=['interstitialSessionGraceSec','interstitialSessionFreeRounds',
    'interstitialGraceSec','interstitialCooldownSec','interstitialMinLives'];
  const envelope=readPlatformTemplate(live.template,live.snapshot);
  const result={ok:true,readOnly:true,checkedAt:new Date().toISOString(),
    version:live.template.version?.versionNumber,revision:live.snapshot.revision,
    initialized:live.initialized,
    schemaVersion:envelope.schemaVersion,
    interstitial:Object.fromEntries(keys.map(key=>[key,economy[key]])),
    platforms:Object.fromEntries(['android','telegram'].map(platform=>[platform,{
      interstitial:Object.fromEntries(keys.map(key=>[key,materializePlatform(envelope,platform).config.economy[key]])),
      ads:envelope.platforms[platform].ads
    }])),
    rewarded:economy.androidEnergyV2?.simpleBonus};
  if(process.argv[2]) fs.writeFileSync(process.argv[2],JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));
} catch {
  console.error(JSON.stringify({ok:false,readOnly:true,error:'config_audit_failed_no_credentials_logged'}));
  process.exitCode=1;
}
