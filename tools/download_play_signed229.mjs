// Official read-only Generated APKs API; never commits or publishes an edit.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {root,privateDirectory} from './supabase_operator.mjs';
const {GoogleAuth}=createRequire(path.join(root,'supabase/package.json'))('google-auth-library');
const expected='a1282130e301ebabb44f8804f4a6f69ae98d3de9e464f56a034c9da0f1f0d701';
const stamp=new Date().toISOString().replace(/[-:]/g,'').replace(/\..*/, '').replace('T','_');
const runDirectory=path.join('C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027','signed-download',stamp);
fs.mkdirSync(runDirectory,{recursive:true});
const evidence=path.join(runDirectory,'download-summary.json');
const summary={ok:false,versionCode:229,source:'official Google Play Developer API Generated APKs',published:false,playProtectionSettingsChanged:false};
try{
 const credentials=JSON.parse(fs.readFileSync(path.join(privateDirectory,'untouch-play-verifier-game-box-b30d4.json'),'utf8'));
 const client=await new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/androidpublisher']}).getClient();
 const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/generatedApks/229';
 const {data}=await client.request({url:base,method:'GET'});
 fs.writeFileSync(path.join(runDirectory,'generated-apks-229.json'),JSON.stringify(data,null,2),{flag:'wx'});
 const group=data.generatedApks?.find(g=>g.certificateSha256Hash.toLowerCase().replaceAll(':','')===expected);
 if(!group)throw Error('matching_play_certificate_not_available');
 const dest=path.join('C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027','signed-apks-'+stamp);
 fs.mkdirSync(dest);
 const variant=group.targetingInfo.variant.filter(v=>(v.targeting?.sdkVersionTargeting?.value?.[0]?.min??1)<=29).sort((a,b)=>(b.targeting?.sdkVersionTargeting?.value?.[0]?.min??1)-(a.targeting?.sdkVersionTargeting?.value?.[0]?.min??1))[0].variantNumber;
 const wanted=new Set(['','config.arm64_v8a','config.xxhdpi','config.ru','config.en']);
 const selected=group.unprotectedGeneratedSplitApks?.filter(a=>a.variantId===variant&&a.moduleName==='base'&&wanted.has(a.splitId??''));
 if(selected?.length!==5)throw Error('exact_device_unprotected_splits_not_available');
 const files=await Promise.all(selected.map(async apk=>{
  const file=path.join(dest,(apk.splitId??'base')+'.apk');if(fs.existsSync(file))throw Error('preserve_existing_artifact');
  // The JSON RPC response is empty. alt=media requests the actual APK bytes.
  const result=await client.request({url:base+'/downloads/'+encodeURIComponent(apk.downloadId)+':download',params:{alt:'media'},method:'GET',responseType:'arraybuffer',timeout:60000});
  const bytes=Buffer.from(result.data??[]);
  if(bytes.length<100||bytes.subarray(0,4).toString('hex')!=='504b0304')throw Error('invalid_or_empty_apk_media');
  fs.writeFileSync(file,bytes,{flag:'wx'});
  return{path:file,splitId:apk.splitId??'base',bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};
 }));
 Object.assign(summary,{ok:true,files,variant,androidApi:29,abi:'arm64-v8a',density:'xxhdpi',languages:['ru','en'],certificate:expected,unprotectedOfficialDistributionBuild:true,apkSignaturesStillRequireIndependentVerification:true});
 console.log(JSON.stringify({evidence,...summary}));
}catch(e){Object.assign(summary,{error:e.response?.data?.error?.message??e.message,status:e.response?.status});console.error(JSON.stringify(summary));process.exitCode=1;
}finally{fs.writeFileSync(evidence,JSON.stringify(summary,null,2),{flag:'wx'});}
