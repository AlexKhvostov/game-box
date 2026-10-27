import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {root,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
const stage=path.join(root,'tmp/main-ad-controls-228-20261027');
const before=JSON.parse(dpapi(fs.readFileSync(path.join(stage,'before-banner-unit.dpapi'),'utf8'),true));
const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
const after=await createRemoteConfig({credentials}).get();
const normalize=template=>{const t=structuredClone(template);delete t.version;return t;};
const expected=normalize(before.template),actual=normalize(after.template);
const parameterChanges=[];
for(const [name,value]of Object.entries(actual.parameters)){
 if(JSON.stringify(value)===JSON.stringify(expected.parameters[name]))continue;
 assert.ok(['android_config_v1','untouch_platforms_v1'].includes(name),name);
 const old=JSON.parse(expected.parameters[name].defaultValue.value),next=JSON.parse(value.defaultValue.value);
 if(name==='android_config_v1'){
  assert.equal(old.config.advertising.banner.unitId,'');old.config.advertising.banner.unitId='R-M-20184253-3';old.revision=next.revision;
 }else{
  assert.equal(old.common.advertising.banner.unitId,'');old.common.advertising.banner.unitId='R-M-20184253-3';
 }
 assert.deepEqual(next,old,name);
 expected.parameters[name]=value;parameterChanges.push(name);
}
assert.deepEqual(actual,expected);
assert.ok(parameterChanges.includes('android_config_v1')&&parameterChanges.includes('untouch_platforms_v1'));
const result={passed:true,beforeVersion:before.template.version.versionNumber,afterVersion:after.template.version.versionNumber,onlyBannerUnitChanged:true,bannerStillOff:true,otherFormatsTimingProviderAndQaUnchanged:true,parameterChanges};
fs.writeFileSync(path.join(stage,'rc77-delta-verification.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
