// Local operator utilities: credentials are only decrypted in memory.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import databaseCa from '../supabase/functions/_shared/database-ca.mjs';
export const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
export const project='exinizzxqtjnysgibide';
export const privateDirectory=path.join(process.env.LOCALAPPDATA,'Untouch/private');
export function dpapi(value,decrypt=false){
  const code=decrypt?"$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());[Console]::Out.Write([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))":"$b=[Text.Encoding]::UTF8.GetBytes([Console]::In.ReadToEnd());[Console]::Out.Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))";
  const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command','Add-Type -AssemblyName System.Security;'+code],{input:value,encoding:'utf8',windowsHide:true});
  if(result.status!==0)throw Error('dpapi_failed');return result.stdout;
}
export function runtimeSecrets(){return JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'supabase-runtime.dpapi'),'utf8'),true));}
export async function operator(){
  const {default:pg}=await import(pathToFileURL(path.join(root,'supabase/node_modules/pg/lib/index.js')).href);
  const require=createRequire(path.join(root,'supabase/package.json'));
  const {createClient}=require('@supabase/supabase-js');
  const binary=path.join(root,'supabase/node_modules/@supabase/cli-windows-x64/bin/supabase.exe');
  const result=spawnSync(binary,['projects','api-keys','--project-ref',project,'--reveal','--output','json'],{encoding:'utf8',windowsHide:true,maxBuffer:2e6});
  if(result.status!==0)throw Error('operator_keys_unavailable');
  const parsed=JSON.parse(result.stdout),keys=Array.isArray(parsed)?parsed:parsed.api_keys??parsed.data;
  const key=keys?.find(item=>item.name==='service_role')?.api_key;
  if(!key)throw Error('operator_key_missing');
  const secrets=runtimeSecrets();
  const pool=new pg.Pool({connectionString:`postgresql://untouch_runtime.${project}:${secrets.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`,ssl:{rejectUnauthorized:true,ca:databaseCa},max:4,connectionTimeoutMillis:10000});
  const client=createClient(`https://${project}.supabase.co`,key,{auth:{persistSession:false,autoRefreshToken:false}});
  return{pool,auth:client.auth.admin,close:()=>pool.end()};
}
