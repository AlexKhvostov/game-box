// Publish only the prepared admin frontend; preserve current Hosting config
// and every old file for cached clients and version rollback.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import {root} from './supabase_operator.mjs';
const stage='C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027';
const publish=process.argv.includes('--publish');
if(process.argv.slice(2).some(a=>a!=='--publish'))throw Error('argument_invalid');
const before=JSON.parse(fs.readFileSync(path.join(stage,'before-hosting.json'),'utf8'));
const site=before.site;assert.equal(site,'untouch-admin-game-box-b30d4');
const require=createRequire('D:/_P_R_O_J_E_C_T/game/square/Untouch/firebase-android/package.json');
const auth=require('firebase-tools/lib/auth'),account=auth.getGlobalDefaultAccount();
if(!account)throw Error('firebase_account_missing');
const {access_token}=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
async function call(resource,method='GET',body){
 const response=await fetch('https://firebasehosting.googleapis.com/v1beta1/'+resource,{method,headers:{Authorization:'Bearer '+access_token,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 if(!response.ok)throw Error('hosting_'+method+'_'+response.status);
 return response.json();
}
const channel=await call(`sites/${site}/channels/live`);
assert.equal(channel.release.version.name,before.version.name,'Hosting advanced since backup');
const mapping=Object.fromEntries(before.files.map(f=>[f.path,f.hash]));
const blobs=new Map(),raw=new Map();
const web=path.join(stage,'candidate-web');
function walk(dir,prefix=''){
 for(const item of fs.readdirSync(dir,{withFileTypes:true})){
  const relative=prefix+'/'+item.name;
  if(item.isDirectory())walk(path.join(dir,item.name),relative);
  else raw.set(relative,fs.readFileSync(path.join(dir,item.name)));
 }
}
walk(web);assert.equal(raw.size,4);
const js=[...raw].find(([name])=>name.endsWith('.js'))?.[1].toString();
for(const value of ['ads-banner','ads-automatic','ads-rewarded','Показывать баннер','После возврата','После N игр'])assert.ok(js?.includes(value),'Missing frontend field: '+value);
const changed=[];
for(const [name,body]of raw){
 if(name==='/favicon.svg'&&mapping[name]){
  const current=await fetch('https://'+site+'.web.app'+name,{cache:'no-store'});
  assert.ok(current.ok);raw.set(name,Buffer.from(await current.arrayBuffer()));
  continue;
 }
 const compressed=zlib.gzipSync(body,{level:9});
 const hash=crypto.createHash('sha256').update(compressed).digest('hex');
 mapping[name]=hash;blobs.set(hash,compressed);changed.push(name);
}
for(const file of before.files.filter(f=>!changed.includes(f.path)))assert.equal(mapping[file.path],file.hash);
let next;
if(publish){
 const ready=JSON.parse(fs.readFileSync(path.join(stage,'rc-published.json'),'utf8'));
 assert.ok(ready.passed&&(ready.published||ready.alreadyExplicit)&&ready.adminRoundtrip);
 next=await call(`sites/${site}/versions`,'POST',{config:before.version.config,labels:{purpose:'banner-unlock-20261027'}});
 const populated=await call(next.name+':populateFiles','POST',{files:mapping});
 for(const hash of populated.uploadRequiredHashes??[]){
  assert.ok(blobs.has(hash),'Existing Hosting blob missing; retain live version');
  const response=await fetch(populated.uploadUrl+'/'+hash,{method:'POST',headers:{Authorization:'Bearer '+access_token,'Content-Type':'application/octet-stream'},body:blobs.get(hash)});
  if(!response.ok)throw Error('hosting_blob_'+response.status);
 }
 await call(next.name+'?updateMask=status','PATCH',{status:'FINALIZED'});
 await call(`sites/${site}/releases?versionName=${encodeURIComponent(next.name)}`,'POST',{message:'Independent ad formats and clear parameter descriptions'});
 const live=await call(`sites/${site}/channels/live`);assert.equal(live.release.version.name,next.name);
 const version=await call(next.name);assert.deepEqual(version.config,before.version.config);
 for(const [name,body]of raw){
  const response=await fetch('https://'+site+'.web.app'+name,{cache:'no-store'});
  assert.ok(response.ok,name+':'+response.status);
  assert.ok(Buffer.from(await response.arrayBuffer()).equals(body),'HTTPS mismatch: '+name);
 }
}
const summary={passed:true,published:publish,previous:before.version.name,version:next?.name??null,site:'https://'+site+'.web.app',changed,existingFilesRetained:true,hostingConfigUnchanged:true,httpsVerified:publish};
fs.writeFileSync(path.join(stage,publish?'hosting-published.json':'hosting-preview.json'),JSON.stringify(summary,null,2));console.log(JSON.stringify(summary));
