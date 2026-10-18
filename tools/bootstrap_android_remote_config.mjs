// Initialize only the new Android key. All unrelated Remote Config values,
// conditions and groups must survive byte-equivalent JSON structure.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
const file=path.join(process.env.LOCALAPPDATA,'Untouch/private/untouch-remote-config.dpapi');
function withoutAndroid(template){const next=structuredClone(template);delete next.version;delete next.parameters?.android_config_v1;for(const group of Object.values(next.parameterGroups??{}))delete group.parameters?.android_config_v1;return next;}
try{
  const encrypted=fs.readFileSync(file,'utf8');
  const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command','Add-Type -AssemblyName System.Security;$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());[Console]::Out.Write([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))'],{input:encrypted,encoding:'utf8',windowsHide:true});if(result.status!==0)throw Error('dpapi_failed');
  const remote=createRemoteConfig({credentials:JSON.parse(result.stdout)}),before=await remote.get();
  if(before.initialized){console.log(JSON.stringify({ok:true,alreadyInitialized:true,version:before.template.version?.versionNumber,revision:before.snapshot.revision}));}
  else if(!process.argv.includes('--publish'))console.log(JSON.stringify({ok:true,initialized:false,version:before.template.version?.versionNumber,unrelatedParameters:Object.keys(before.template.parameters??{}).length,readyToAddAndroid:true}));
  else{
    const published=await remote.publish(before,[]);const after=await remote.get();
    assert.deepEqual(withoutAndroid(after.template),withoutAndroid(before.template));
    if(!after.initialized)throw Error('publication_not_confirmed');
    console.log(JSON.stringify({ok:true,initialized:true,version:published.publishedVersion,revision:after.snapshot.revision,unrelatedParametersPreserved:true}));
  }
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.name}));process.exitCode=1;}
