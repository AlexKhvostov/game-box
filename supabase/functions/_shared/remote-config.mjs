import {GoogleAuth} from 'google-auth-library';
import {defaults,hash,validatePolicy,ApiError,requireThat} from './core/policy.mjs';
import {RC_KEY,applyChanges,changesBetween} from './config-schema.mjs';
import {averageRules} from './average-config.mjs';
import {PLATFORMS_RC_KEY,patchScopedTemplate,readPlatformTemplate,materializePlatform,configFieldScope} from './platform-config.mjs';

const PROJECT='game-box-b30d4';
const URL=`https://firebaseremoteconfig.googleapis.com/v1/projects/${PROJECT}/remoteConfig`;
export function parameterLocation(template){
  const matches=[];
  if(Object.hasOwn(template.parameters??{},RC_KEY))matches.push(template.parameters);
  for(const group of Object.values(template.parameterGroups??{}))if(Object.hasOwn(group.parameters??{},RC_KEY))matches.push(group.parameters);
  requireThat(matches.length<=1,'remote_config_duplicate_key',503);
  return matches[0]??null;
}
export function readAndroidTemplate(template){
  const parameter=parameterLocation(template)?.[RC_KEY];
  if(!parameter)return{snapshot:structuredClone(defaults),initialized:false};
  // Economic variants require server-assigned experiments. Never silently
  // flatten or overwrite an existing conditional Android economic policy.
  requireThat(!Object.keys(parameter.conditionalValues??{}).length,'android_conditional_policy_unsupported',409);
  let snapshot;try{snapshot=JSON.parse(parameter.defaultValue?.value);}catch{throw new ApiError('remote_config_json_invalid',503);}
  validatePolicy(snapshot);averageRules(snapshot.config);
  return{snapshot,initialized:true};
}
export function patchAndroidTemplate(template,patches){
  const split=Object.hasOwn(template.parameters??{},PLATFORMS_RC_KEY)||Object.values(template.parameterGroups??{}).some(g=>Object.hasOwn(g.parameters??{},PLATFORMS_RC_KEY));
  if(split){
    const before=readAndroidTemplate(template).snapshot;
    let next=template;
    for(const scope of ['common','android']){
      const filtered=patches.filter(p=>(configFieldScope(p.path)==='common'?'common':'android')===scope)
        .map(p=>scope==='android'?{path:p.path.replace('economy.','ads.'),value:p.value}:p);
      if(filtered.length)next=patchScopedTemplate(next,readAndroidTemplate(next).snapshot,scope,filtered).template;
    }
    const snapshot=readAndroidTemplate(next).snapshot;
    return{template:next,before,snapshot,changes:changesBetween(before.config,snapshot.config)};
  }
  const before=readAndroidTemplate(template),config=applyChanges(before.snapshot,patches);
  const snapshot=validatePolicy({ok:true,config,revision:hash(config)});
  const next=structuredClone(template);delete next.version;
  const location=parameterLocation(next)??(next.parameters??={});
  location[RC_KEY]={...(location[RC_KEY]??{}),defaultValue:{value:JSON.stringify(snapshot)},valueType:'JSON',
    description:location[RC_KEY]?.description??'Android Untouch: reviewed game settings. Managed by the Untouch admin console.'};
  return{template:next,before:before.snapshot,snapshot,changes:changesBetween(before.snapshot.config,config)};
}
export function createRemoteConfig({credentials,request=fetch,telegramStarsAccepted=false}={}){
  let auth;
  async function invoke(method,body,etag,validateOnly=false){
    requireThat(credentials?.project_id===PROJECT,'firebase_credentials_missing',503);
    auth??=new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/firebase.remoteconfig']});
    const token=await auth.getAccessToken();
    const response=await request(`${URL}${validateOnly?'?validateOnly=true':''}`,{
      method,signal:AbortSignal.timeout(15000),headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json',
        'Accept-Encoding':'gzip',...(etag?{'If-Match':etag}:{})},...(body?{body:JSON.stringify(body)}:{})});
    if(response.status===409||response.status===412)throw new ApiError('remote_config_conflict',409);
    if(!response.ok)throw new ApiError(response.status===403?'firebase_permission_denied':'remote_config_unavailable',503);
    return{template:await response.json(),etag:response.headers.get('etag')};
  }
  return{
    async get(){const result=await invoke('GET');requireThat(result.etag&&result.etag!=='*','remote_config_etag_missing',503);return{...result,...readAndroidTemplate(result.template)};},
    async getPlatform(platform){
      const result=await this.get();
      const envelope=readPlatformTemplate(result.template,result.snapshot);
      return{...result,snapshot:materializePlatform(envelope,platform),platformConfig:envelope.platforms[platform]};
    },
    async publishScoped(current,scope,patches){
      requireThat(typeof current.etag==='string'&&current.etag!=='*','remote_config_etag_missing',400);
      const candidate=patchScopedTemplate(current.template,current.snapshot,scope,patches,{telegramStarsAccepted});
      await invoke('PUT',candidate.template,current.etag,true);
      const result=await invoke('PUT',candidate.template,current.etag);
      return{...result,...candidate,publishedVersion:result.template.version?.versionNumber??null};
    },
    async publish(current,patches){
      requireThat(typeof current.etag==='string'&&current.etag.length<512&&current.etag!=='*','remote_config_etag_missing',400);
      const candidate=patchAndroidTemplate(current.template,patches);
      await invoke('PUT',candidate.template,current.etag,true);
      const result=await invoke('PUT',candidate.template,current.etag);
      return{...result,...candidate,publishedVersion:result.template.version?.versionNumber??null};
    }
  };
}
