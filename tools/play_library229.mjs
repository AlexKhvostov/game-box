// Google library only. Never writes tracks, testers, countries or release notes.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {root,privateDirectory} from './supabase_operator.mjs';
const {GoogleAuth}=createRequire(path.join(root,'supabase/package.json'))('google-auth-library');
const dir='C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027';
const editFile=path.join(dir,'google-library-edit.json');
const packageName='com.best4u.untouch',version=229;
const api=`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}`;
const mode=process.argv[2]??'inspect';
const save=(name,data)=>fs.writeFileSync(path.join(dir,name),JSON.stringify(data,null,2),{flag:'wx'});
try {
 const credentials=JSON.parse(fs.readFileSync(path.join(privateDirectory,'untouch-play-verifier-game-box-b30d4.json'),'utf8'));
 const client=await new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/androidpublisher']}).getClient();
 const request=async(options)=>(await client.request({timeout:30000,...options})).data;
 if(mode==='inspect') {
  let edit;
  if(fs.existsSync(editFile))edit=JSON.parse(fs.readFileSync(editFile,'utf8'));
  else {edit=await request({url:api+'/edits',method:'POST',data:{}});save('google-library-edit.json',edit);}
  const base=api+'/edits/'+edit.id;
  const [tracks,bundles]=await Promise.all([request({url:base+'/tracks'}),request({url:base+'/bundles'})]);
  save('google-library-tracks-before.json',tracks);save('google-library-bundles-before.json',bundles);
  console.log(JSON.stringify({ok:true,mode,tracks:tracks.tracks?.map(t=>({track:t.track,releases:t.releases?.map(r=>({status:r.status,versionCodes:r.versionCodes}))})),bundleVersions:bundles.bundles?.map(b=>b.versionCode),targetAlreadyPresent:bundles.bundles?.some(b=>b.versionCode===version)}));
 } else if(mode==='upload') {
  const file=process.argv[3];if(!file?.endsWith('Untouch-1.0.228+229.aab'))throw Error('Unexpected artifact');
  const before=JSON.parse(fs.readFileSync(path.join(dir,'google-library-bundles-before.json'),'utf8'));
  if(before.bundles?.some(b=>b.versionCode===version))throw Error('Version already exists; do not overwrite');
  const edit=JSON.parse(fs.readFileSync(editFile,'utf8'));
  const sha=createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const data=await request({url:`https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${packageName}/edits/${edit.id}/bundles`,method:'POST',params:{uploadType:'media'},headers:{'Content-Type':'application/octet-stream','Content-Length':String(fs.statSync(file).size)},data:fs.createReadStream(file),timeout:180000});
  if(data.versionCode!==version||data.sha256!==sha)throw Error('Google artifact identity mismatch');
  save('google-library-upload.json',data);console.log(JSON.stringify({ok:true,uploaded:true,committed:false,sha256:sha,versionCode:version}));
 } else if(mode==='commit-library') {
  const uploaded=JSON.parse(fs.readFileSync(path.join(dir,'google-library-upload.json'),'utf8'));
  if(uploaded.versionCode!==version)throw Error('Missing reviewed bundle');
  const edit=JSON.parse(fs.readFileSync(editFile,'utf8')),base=api+'/edits/'+edit.id;
  const before=JSON.parse(fs.readFileSync(path.join(dir,'google-library-tracks-before.json'),'utf8'));
  const tracks=await request({url:base+'/tracks'});
  if(JSON.stringify(tracks)!==JSON.stringify(before))throw Error('Track state changed; stop');
  // Explicitly preserve an existing review; never cancel/re-submit it by default.
  const result=await request({url:base+':commit',method:'POST',params:{changesInReviewBehavior:'ERROR_IF_IN_REVIEW'}});
  save('google-library-commit.json',result);console.log(JSON.stringify({ok:true,libraryCommitted:true,tracksWritten:false,reviewSubmission:false,versionCode:version}));
 } else if(mode==='verify-library') {
  const edit=await request({url:api+'/edits',method:'POST',data:{}}),base=api+'/edits/'+edit.id;
  const [tracks,bundles]=await Promise.all([request({url:base+'/tracks'}),request({url:base+'/bundles'})]);
  const before=JSON.parse(fs.readFileSync(path.join(dir,'google-library-tracks-before.json'),'utf8'));
  if(JSON.stringify(tracks)!==JSON.stringify(before))throw Error('Tracks changed since baseline');
  const target=bundles.bundles?.find(b=>b.versionCode===version),uploaded=JSON.parse(fs.readFileSync(path.join(dir,'google-library-upload.json'),'utf8'));
  if(target?.sha256!==uploaded.sha256)throw Error('Stored bundle mismatch');
  const result={ok:true,versionCode:version,bundleStored:true,sha256:target.sha256,tracksUnchanged:true,reviewSubmission:false};
  save('google-library-final-verification.json',result);console.log(JSON.stringify(result));
 } else if(mode==='generated') {
  const result=await request({url:api+'/generatedApks/'+version});
  save('google-generated229.json',result);
  console.log(JSON.stringify({ok:true,versionCode:version,signingKeys:result.generatedApks?.map(g=>({certificate:g.certificateSha256Hash,unprotectedSplits:g.unprotectedGeneratedSplitApks?.length,universal:!!g.generatedUniversalApk}))}));
 } else throw Error('Unknown mode');
} catch(e) {
 const result={ok:false,mode,status:e.response?.status,error:e.response?.data?.error?.message??e.code??e.message};
 const target=path.join(dir,'google-library-'+mode+'-error-'+Date.now()+'.json');fs.writeFileSync(target,JSON.stringify(result,null,2));
 console.error(JSON.stringify(result));process.exitCode=1;
}
