// OAuth secret stays in the user's private directory and the child process
// environment. Never include config diff/push output in logs: it may contain it.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const clientId='332169968823-veig9smr7ujjo7729uh9oh1q84dk21ej.apps.googleusercontent.com';
const project='exinizzxqtjnysgibide';
try{
  const directory=path.join(process.env.LOCALAPPDATA,'Untouch/private');
  const file=['supabase-google-client.json','supabase-google-client.json.json'].map(name=>path.join(directory,name)).find(file=>fs.existsSync(file));
  if(!file)throw Error('google_client_file_missing');
  const source=JSON.parse(fs.readFileSync(file,'utf8')),client=source.web??source;
  if(client.client_id!==clientId||typeof client.client_secret!=='string'||client.client_secret.length<20)throw Error('google_client_invalid');
  if(!client.redirect_uris?.includes(`https://${project}.supabase.co/auth/v1/callback`))throw Error('callback_not_confirmed');
  const workdir=path.join(root,'.private/supabase-transition'),config=path.join(workdir,'supabase/config.toml');
  let text=fs.readFileSync(config,'utf8');
  if(!text.includes('[auth.external.google]')){
    text+=`\n[auth.external.google]\nenabled = true\nclient_id = "${clientId}"\nsecret = "env(UNTOUCH_GOOGLE_CLIENT_SECRET)"\nskip_nonce_check = false\n`;
    fs.writeFileSync(config,text);
  }
  const binary=path.join(root,'supabase/node_modules/@supabase/cli-windows-x64/bin/supabase.exe');
  const run=command=>spawnSync(binary,['config',command,'--workdir',workdir,'--project-ref',project,'--yes','--output-format','json'],{encoding:'utf8',windowsHide:true,env:{...process.env,UNTOUCH_GOOGLE_CLIENT_SECRET:client.client_secret},maxBuffer:2e6});
  const diff=run('diff');if(diff.status!==0)throw Error('google_config_diff_failed');
  // Refuse unexpected resource changes without exposing credentials.
  const diffText=diff.stdout+diff.stderr;
  if(/\[storage|\[db|\[auth\.email|\[auth\.mfa/.test(diffText))throw Error('unexpected_config_diff');
  const push=run('push');if(push.status!==0)throw Error('google_config_push_failed');
  const {publishableKey}=await import('../admin-console/src/public-config.js');
  let verified=false;
  for(let attempt=0;attempt<6;attempt++){
    const response=await fetch(`https://${project}.supabase.co/auth/v1/settings`,{headers:{apikey:publishableKey}});
    const settings=await response.json();
    if(response.ok&&settings.external?.google===true&&settings.external?.anonymous_users===true){verified=true;break;}
    await new Promise(resolve=>setTimeout(resolve,2000));
  }
  if(!verified)throw Error('google_provider_verification_failed');
  console.log(JSON.stringify({ok:true,googleEnabled:true,anonymousEnabled:true,callbackConfirmed:true,secretLogged:false}));
}catch(error){console.error(JSON.stringify({ok:false,error:error.message}));process.exitCode=1;}
