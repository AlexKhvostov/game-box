import {hash,validatePolicy,requireThat} from './core/policy.mjs';
import {fields as commonFields,applyChanges as applyCommonChanges,getValue,setValue} from './config-schema.mjs';
export const PLATFORMS_RC_KEY='untouch_platforms_v1';
import {adKeys,configFieldScope,platformFields,initialPlatformSettings} from './platform-config-schema.mjs';
export {configFieldScope,platformFields,initialPlatformSettings};
function location(template,key){
  const found=[template.parameters,...Object.values(template.parameterGroups??{}).map(g=>g.parameters)].filter(v=>v&&Object.hasOwn(v,key));
  requireThat(found.length<=1,'remote_config_duplicate_key',503);return found[0]??null;
}
export function readPlatformTemplate(template,legacySnapshot){
  const param=location(template,PLATFORMS_RC_KEY)?.[PLATFORMS_RC_KEY];
  if(!param)return{schemaVersion:1,common:structuredClone(legacySnapshot.config),platforms:initialPlatformSettings(legacySnapshot.config)};
  requireThat(!Object.keys(param.conditionalValues??{}).length,'platform_conditional_policy_unsupported',409);
  let value;try{value=JSON.parse(param.defaultValue?.value);}catch{}
  requireThat(value?.schemaVersion===1&&value.platforms?.android&&value.platforms?.telegram,'platform_policy_invalid',503);
  validatePolicy({ok:true,config:value.common,revision:hash(value.common)});
  for(const p of ['android','telegram'])value.platforms[p]=validatePlatformSettings(p,value.platforms[p]);
  // Detect Firebase-console edits to the compatibility snapshot rather than overwrite silently.
  const materialized=materializePlatform(value,'android');
  requireThat(JSON.stringify(materialized.config)===JSON.stringify(legacySnapshot.config),'platform_legacy_config_conflict',409);
  return value;
}
export function validatePlatformSettings(platform,config){
  requireThat(config&&typeof config==='object'&&!Array.isArray(config),'platform_policy_invalid',400);
  // Older published envelopes have no automatic-ad switch. Read them as OFF
  // without rewriting Remote Config or changing Android's compatibility JSON.
  // An explicitly supplied undefined/null is still an invalid patch value.
  if(platform==='telegram'&&config.ads&&typeof config.ads==='object'&&!Array.isArray(config.ads)&&!Object.hasOwn(config.ads,'interstitialEnabled')){
    config=structuredClone(config);config.ads.interstitialEnabled=false;
  }
  for(const f of platformFields[platform]??[]){
    const v=getValue(config,f.path);
    requireThat(typeof v===f.type,'platform_policy_invalid',400);
    if(f.type==='number')requireThat(Number.isSafeInteger(v)&&v>=f.min&&v<=f.max,'platform_policy_invalid',400);
    if(f.type==='string')requireThat(v.length<=120&&/^[A-Za-z0-9_-]*$/.test(v),'platform_policy_invalid',400);
  }
  return config;
}
export function materializePlatform(envelope,platform){
  requireThat(['android','telegram'].includes(platform),'platform_invalid',400);
  const config=structuredClone(envelope.common),settings=envelope.platforms[platform];
  for(const k of adKeys)config.economy[k]=settings.ads[k];
  return validatePolicy({ok:true,config,revision:hash(config)});
}
export function scopedView(envelope,scope){
  requireThat(['common','android','telegram'].includes(scope),'platform_invalid',400);
  const config=structuredClone(scope==='common'?envelope.common:validatePlatformSettings(scope,envelope.platforms[scope]));
  return {ok:true,config,revision:hash({scope,config})};
}
export function patchScopedTemplate(template,legacySnapshot,scope,patches,{telegramStarsAccepted=false}={}){
  const before=readPlatformTemplate(template,legacySnapshot),next=structuredClone(before);
  requireThat(Array.isArray(patches)&&patches.length<=300,'config_invalid',400);
  if(scope==='common'){
    requireThat(patches.every(p=>configFieldScope(p?.path)==='common'),'config_scope_invalid',400);
    next.common=applyCommonChanges({config:next.common},patches);
  }else{
    requireThat(['android','telegram'].includes(scope),'platform_invalid',400);
    const seen=new Set();
    for(const p of patches){
      requireThat(platformFields[scope].some(f=>f.path===p?.path)&&!seen.has(p.path),'config_scope_invalid',400);
      seen.add(p.path);setValue(next.platforms[scope],p.path,p.value);
    }
    validatePlatformSettings(scope,next.platforms[scope]);
    // Actual sales are a separate, explicitly deferred integration acceptance.
    requireThat(next.platforms.telegram.stars.salesEnabled===false||before.platforms.telegram.stars.salesEnabled===true||telegramStarsAccepted===true,'stars_acceptance_required',409);
  }
  const android=materializePlatform(next,'android');materializePlatform(next,'telegram');
  const result=structuredClone(template);delete result.version;
  const params=location(result,PLATFORMS_RC_KEY)??(result.parameters??={});
  params[PLATFORMS_RC_KEY]={defaultValue:{value:JSON.stringify(next)},valueType:'JSON',description:'Untouch common gameplay and platform services'};
  const androidParams=location(result,'android_config_v1')??(result.parameters??={});
  androidParams.android_config_v1={...androidParams.android_config_v1,defaultValue:{value:JSON.stringify(android)},valueType:'JSON'};
  const view=scopedView(next,scope),old=scopedView(before,scope);
  const changes=patches.filter(p=>JSON.stringify(getValue(old.config,p.path))!==JSON.stringify(getValue(view.config,p.path)))
    .map(p=>({path:p.path,label:scope==='common'?commonFields.find(f=>f.path===p.path)?.label:platformFields[scope].find(f=>f.path===p.path)?.label,before:getValue(old.config,p.path),after:getValue(view.config,p.path),scope}));
  return{template:result,envelope:next,before:old,snapshot:view,android,changes};
}
