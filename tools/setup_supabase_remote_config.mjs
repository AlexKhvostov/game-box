// Explicitly authorized by Alexey: dedicated Remote Config Admin only.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import {privateCli} from './supabase_private_cli.mjs';
const root=path.dirname(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')));
const require=createRequire(path.join(root,'firebase-android/package.json'));
const auth=require('firebase-tools/lib/auth');
const project='game-box-b30d4',accountId='untouch-remote-config',email=`${accountId}@${project}.iam.gserviceaccount.com`;
const directory=path.join(process.env.LOCALAPPDATA,'Untouch/private');
const backup=path.join(directory,'untouch-remote-config.dpapi');
function dpapi(value,decrypt=false){
  const code=decrypt?"$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());[Console]::Out.Write([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))":"$b=[Text.Encoding]::UTF8.GetBytes([Console]::In.ReadToEnd());[Console]::Out.Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))";
  const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command','Add-Type -AssemblyName System.Security;'+code],{input:value,encoding:'utf8',windowsHide:true});
  if(result.status!==0)throw Error('dpapi_failed');return result.stdout;
}
try{
  let service;
  if(fs.existsSync(backup))service=JSON.parse(dpapi(fs.readFileSync(backup,'utf8'),true));
  else{
    const account=auth.getGlobalDefaultAccount();if(!account)throw Error('firebase_login_missing');
    const token=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
    async function call(url,method='GET',body){const response=await fetch(url,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const data=await response.json();if(!response.ok)throw Error(`google_${response.status}_${data.error?.status??'error'}: ${data.error?.message?.slice(0,350)??new URL(url).pathname}`);return data;}
    const base=`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts`;
    const accounts=await call(base);
    if(!accounts.accounts?.some(item=>item.email===email))await call(base,'POST',{accountId,serviceAccount:{displayName:'Untouch Android Remote Config',description:'Read and publish Android settings through the Supabase admin backend.'}});
    const policyUrl=`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
    const policy=await call(`${policyUrl}:getIamPolicy`,'POST',{options:{requestedPolicyVersion:3}});
    const role='roles/cloudconfig.admin',member=`serviceAccount:${email}`;
    let binding=policy.bindings?.find(item=>item.role===role&&!item.condition);
    if(!binding){binding={role,members:[]};(policy.bindings??=[]).push(binding);}
    if(!binding.members.includes(member)){binding.members.push(member);await call(`${policyUrl}:setIamPolicy`,'POST',{policy});}
    const key=await call(`${base}/${email}/keys`,'POST',{privateKeyType:'TYPE_GOOGLE_CREDENTIALS_FILE',keyAlgorithm:'KEY_ALG_RSA_2048'});
    const raw=Buffer.from(key.privateKeyData,'base64').toString('utf8');service=JSON.parse(raw);
    fs.mkdirSync(directory,{recursive:true});const encrypted=dpapi(raw);if(dpapi(encrypted,true)!==raw)throw Error('dpapi_roundtrip_failed');fs.writeFileSync(backup,encrypted,{flag:'wx'});
  }
  if(service.client_email!==email||service.project_id!==project)throw Error('unexpected_service_account');
  await privateCli(['secrets','set','--env-file'],`FIREBASE_SERVICE_ACCOUNT_JSON='${JSON.stringify(service)}'\n`);
  console.log(JSON.stringify({ok:true,account:email,role:'roles/cloudconfig.admin',uploadedTo:'exinizzxqtjnysgibide',localBackup:'Windows DPAPI outside repository'}));
}catch(error){console.error(JSON.stringify({ok:false,error:error.message,diagnostic:error.diagnostic}));process.exitCode=1;}
