// Isolated QA parameter only. Credentials stay in memory; backups use DPAPI.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {privateDirectory,dpapi,root} from './supabase_operator.mjs';
import {adFormatsConfig} from '../supabase/functions/_shared/ad-formats-config.mjs';

export const qaKey='android_ad_formats_qa_v1';
export function patchQaTemplate(template,patch={}){
 for(const group of Object.values(template.parameterGroups??{}))if(Object.hasOwn(group.parameters??{},qaKey))throw Error('qa_key_in_group');
 const current=template.parameters?.[qaKey];
 if(Object.keys(current?.conditionalValues??{}).length)throw Error('qa_conditions_unsupported');
 const policy=adFormatsConfig(current?JSON.parse(current.defaultValue.value):{
  banner:{enabled:false,installDelaySec:0},automatic:{enabled:false},rewarded:{enabled:true}
 });
 for(const [key,value]of Object.entries(patch)){
  if(!['banner','automatic'].includes(key)||typeof value!=='boolean')throw Error('qa_patch_invalid');
  policy[key].enabled=value;
 }
 const next=structuredClone(template);delete next.version;
 (next.parameters??={})[qaKey]={defaultValue:{value:JSON.stringify(policy)},valueType:'JSON',description:'Isolated Untouch DEMO QA: banner/automatic switches. Main game ignores this parameter.'};
 if(unrelated(template)!==unrelated(next))throw Error('unrelated_rc_change');
 return{template:next,policy};
}
export function unrelated(template){
 const copy=structuredClone(template);delete copy.version;
 if(copy.parameters){delete copy.parameters[qaKey];if(!Object.keys(copy.parameters).length)delete copy.parameters;}
 return JSON.stringify(copy);
}
async function main(){
 const patch={};let publish=false;
 for(const arg of process.argv.slice(2)){
  if(arg==='--publish'){publish=true;continue;}
  const match=/^--(banner|automatic)=(on|off)$/.exec(arg);
  if(!match)throw Error('qa_argument_invalid');
  patch[match[1]]=match[2]==='on';
 }
 const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
 if(credentials.project_id!=='game-box-b30d4')throw Error('wrong_firebase_project');
 const require=createRequire(path.join(root,'supabase/package.json'));
 const {GoogleAuth}=require('google-auth-library');
 const auth=new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/firebase.remoteconfig']});
 const token=await auth.getAccessToken();
 async function invoke(method,body,etag,validate=false){
  const response=await fetch('https://firebaseremoteconfig.googleapis.com/v1/projects/game-box-b30d4/remoteConfig'+(validate?'?validateOnly=true':''),{
   method,signal:AbortSignal.timeout(20000),headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json','Accept-Encoding':'gzip',...(etag?{'If-Match':etag}:{})},...(body?{body:JSON.stringify(body)}:{})
  });
  if(!response.ok)throw Error(`qa_rc_http_${response.status}`);
  return{template:await response.json(),etag:response.headers.get('etag')};
 }
 const before=await invoke('GET');
 if(!before.etag||before.etag==='*')throw Error('qa_etag_missing');
 const candidate=patchQaTemplate(before.template,patch);
 let verified=before;
 if(publish){
  const backupDir=path.join(root,'.private/qa-ad-formats-rc');fs.mkdirSync(backupDir,{recursive:true});
  fs.writeFileSync(path.join(backupDir,`${Date.now()}-before.dpapi`),dpapi(JSON.stringify(before)),{flag:'wx'});
  await invoke('PUT',candidate.template,before.etag,true);
  await invoke('PUT',candidate.template,before.etag);
  verified=await invoke('GET');
  if(unrelated(before.template)!==unrelated(verified.template))throw Error('qa_unrelated_verification_failed');
  if(verified.template.parameters?.[qaKey]?.defaultValue.value!==JSON.stringify(candidate.policy))throw Error('qa_publication_verification_failed');
 }
 console.log(JSON.stringify({ok:true,published:publish,key:qaKey,policy:candidate.policy,version:verified.template.version?.versionNumber,unrelatedParametersUnchanged:true,encryptedBackup:publish}));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
 main().catch(error=>{console.error(JSON.stringify({ok:false,error:error.message}));process.exitCode=1;});
}
