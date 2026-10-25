// One-file Hosting patch. Retain every live file hash and the live config.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import {createRequire} from 'node:module';
const root=path.resolve(import.meta.dirname,'..');
const require=createRequire(path.join(root,'firebase-android/package.json'));
const auth=require('firebase-tools/lib/auth');
const site='untouch-android-game-box-b30d4';
const outIndex=process.argv.indexOf('--out');
const out=outIndex<0?path.join(root,'docs/release-evidence/android-privacy-performance-20261025'):path.resolve(root,process.argv[outIndex+1]);
fs.mkdirSync(out,{recursive:true});
const account=auth.getGlobalDefaultAccount();
if(!account)throw Error('Firebase login missing');
const {access_token}=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
async function call(resource,method='GET',body){
 const response=await fetch('https://firebasehosting.googleapis.com/v1beta1/'+resource,{method,headers:{Authorization:'Bearer '+access_token,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const data=await response.json();if(!response.ok)throw Error('Hosting '+response.status+' '+(data.error?.message??resource));return data;
}
const channel=await call(`sites/${site}/channels/live`);
const previous=channel.release.version.name;
const version=await call(previous);
let token='',files=[];
do{const page=await call(previous+'/files?pageSize=1000'+(token?'&pageToken='+encodeURIComponent(token):''));files.push(...page.files??[]);token=page.nextPageToken??'';}while(token);
if(!files.some(f=>f.path==='/privacy/index.html')||files.length<3)throw Error('Incomplete live inventory');
fs.writeFileSync(path.join(out,'firebase-hosting-before.json'),JSON.stringify({previous,config:version.config,files},null,2));
if(!process.argv.includes('--publish')){console.log(JSON.stringify({prepared:true,previous,files:files.length}));process.exit(0);}
const body=fs.readFileSync(path.join(root,'supabase/hosting/privacy/index.html'));
const compressed=zlib.gzipSync(body,{level:9});
const hash=crypto.createHash('sha256').update(compressed).digest('hex');
const next=await call(`sites/${site}/versions`,'POST',{config:version.config,labels:{purpose:'consent-privacy-20261025'}});
const mapping=Object.fromEntries(files.map(f=>[f.path,f.hash]));mapping['/privacy/index.html']=hash;
const populated=await call(next.name+':populateFiles','POST',{files:mapping});
for(const needed of populated.uploadRequiredHashes??[]){
 if(needed!==hash)throw Error('Unexpected missing existing file; preserve live version');
 const response=await fetch(populated.uploadUrl+'/'+hash,{method:'POST',headers:{Authorization:'Bearer '+access_token,'Content-Type':'application/octet-stream'},body:compressed});
 if(!response.ok)throw Error('Hosting upload '+response.status);
}
await call(next.name+'?updateMask=status','PATCH',{status:'FINALIZED'});
const latest=await call(`sites/${site}/channels/live`);
if(latest.release.version.name!==previous)throw Error('Live hosting changed concurrently; new version not released');
const released=await call(`sites/${site}/channels/live/releases?versionName=`+encodeURIComponent(next.name),'POST',{message:'Adult opt-in analytics and separate ad-data consent RU/EN; all other live hashes preserved'});
const after=await call(next.name+'/files?pageSize=1000');
if(after.nextPageToken)throw Error('Unexpected inventory pagination');
const changed=after.files.filter(f=>mapping[f.path]!==files.find(old=>old.path===f.path)?.hash).map(f=>f.path);
if(changed.length!==1||changed[0]!=='/privacy/index.html'||after.files.length!==files.length)throw Error('Hosting file inventory mismatch');
const response=await fetch(`https://${site}.web.app/privacy/?privacy=20261025`);
const live=Buffer.from(await response.arrayBuffer());
if(!response.ok||!live.equals(body))throw Error('HTTPS privacy readback mismatch');
fs.writeFileSync(path.join(out,'privacy-live-after-firebase.html'),live);
const result={passed:true,previous,current:next.name,files:files.length,changed,configUnchanged:true,httpsSha256:crypto.createHash('sha256').update(live).digest('hex'),release:released.name};
fs.writeFileSync(path.join(out,'firebase-hosting-patch.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
