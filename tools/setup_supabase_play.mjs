// Reuse the existing app-scoped Google Play verifier. No new IAM/Play access,
// key rotation, live purchase, or change to the former server.
import fs from 'node:fs';
import path from 'node:path';
import {privateCli} from './supabase_private_cli.mjs';
try{
  const file=path.join(process.env.LOCALAPPDATA,'Untouch/private/untouch-play-verifier-game-box-b30d4.json');
  const key=JSON.parse(fs.readFileSync(file,'utf8'));
  if(key.type!=='service_account'||key.project_id!=='game-box-b30d4'||key.client_email!=='untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com'||key.token_uri!=='https://oauth2.googleapis.com/token')throw Error('unexpected_play_account');
  await privateCli(['secrets','set','--env-file'],`PLAY_SERVICE_ACCOUNT_JSON='${JSON.stringify(key)}'\n`);
  console.log(JSON.stringify({ok:true,existingVerifierReused:true,uploadedTo:'exinizzxqtjnysgibide',iamChanged:false,oldServerChanged:false}));
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message,diagnostic:error.diagnostic}));process.exitCode=1;}
