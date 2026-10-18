import fs from 'node:fs';
import path from 'node:path';
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {privateCli} from './supabase_private_cli.mjs';
import databaseCa from '../supabase/functions/_shared/database-ca.mjs';
const project='exinizzxqtjnysgibide',directory=path.join(process.env.LOCALAPPDATA,'Untouch/private'),backup=path.join(directory,'supabase-runtime.dpapi');
function protect(value,decrypt=false){const operation=decrypt?'Unprotect':'Protect';const code=decrypt?`$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());[Console]::Out.Write([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::${operation}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))`:`$b=[Text.Encoding]::UTF8.GetBytes([Console]::In.ReadToEnd());[Console]::Out.Write([Convert]::ToBase64String([Security.Cryptography.ProtectedData]::${operation}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)))`;const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command','Add-Type -AssemblyName System.Security;'+code],{input:value,encoding:'utf8',windowsHide:true});if(result.status!==0)throw Error('dpapi_failed');return result.stdout;}
try{
  let values;
  if(fs.existsSync(backup))values=JSON.parse(protect(fs.readFileSync(backup,'utf8'),true));
  else{values={password:randomBytes(48).toString('base64url'),reconcile:randomBytes(48).toString('base64url')};const raw=JSON.stringify(values),encrypted=protect(raw);if(protect(encrypted,true)!==raw)throw Error('dpapi_roundtrip_failed');fs.mkdirSync(directory,{recursive:true});fs.writeFileSync(backup,encrypted,{flag:'wx'});}
  // Only a fixed, previously migrated role; passwords are generated, never
  // interpolated from a user/HTTP input. Named pipe prevents argv disclosure.
  await privateCli(['db','query','--file'],`alter role untouch_runtime login password '${values.password}';`);
  const uri=`postgresql://untouch_runtime.${project}:${values.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`;
  await privateCli(['secrets','set','--env-file'],`UNTOUCH_DATABASE_URL='${uri}'\nPLAY_RECONCILE_SECRET='${values.reconcile}'\nADMIN_ALLOWED_ORIGINS='http://127.0.0.1:4173,http://localhost:4173,https://untouch-admin-game-box-b30d4.web.app,https://untouch-admin-game-box-b30d4.firebaseapp.com'\n`);
  const root=path.dirname(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')));
  const {default:pg}=await import(pathToFileURL(path.join(root,'supabase/node_modules/pg/lib/index.js')).href);
  const pool=new pg.Pool({connectionString:uri,ssl:{rejectUnauthorized:true,ca:databaseCa},max:1,connectionTimeoutMillis:10000});
  try{const result=await pool.query("select current_user as role,has_table_privilege(current_user,'untouch.documents','select') as can_read,has_table_privilege(current_user,'untouch.admin_users','insert') as can_promote");if(result.rows[0].role!=='untouch_runtime'||result.rows[0].can_read!==true||result.rows[0].can_promote!==false)throw Error('runtime_permissions_invalid');console.log(JSON.stringify({ok:true,role:result.rows[0].role,tlsVerified:true,secretsUploaded:true,canPromoteAdministrator:false}));}finally{await pool.end();}
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message,diagnostic:error.diagnostic}));process.exitCode=1;}
