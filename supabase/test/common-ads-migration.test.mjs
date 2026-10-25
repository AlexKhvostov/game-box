import {test} from 'node:test';
import assert from 'node:assert/strict';
import {defaults} from '../functions/_shared/core/policy.mjs';
import {adKeys,initialPlatformSettings,configFieldScope,platformFields} from '../functions/_shared/platform-config-schema.mjs';
import {materializePlatform,readPlatformTemplate,patchScopedTemplate,PLATFORMS_RC_KEY} from '../functions/_shared/platform-config.mjs';

function legacy(){
  const envelope={schemaVersion:1,common:structuredClone(defaults.config),platforms:initialPlatformSettings(defaults.config)};
  for(const p of ['android','telegram'])for(const k of adKeys)envelope.platforms[p].ads[k]=defaults.config.economy[k];
  for(const p of ['android','telegram'])envelope.platforms[p].ads.interstitialCooldownSec=220;
  Object.assign(envelope.platforms.telegram.ads,{enabled:true,interstitialEnabled:false,rewardedBlockId:'55424',interstitialBlockId:'int-55425'});
  const snapshot=materializePlatform(envelope,'android');
  const template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(snapshot)}},[PLATFORMS_RC_KEY]:{defaultValue:{value:JSON.stringify(envelope)}}}};
  return{envelope,snapshot,template};
}
test('migration preserves effective old-client snapshots and provider switches exactly',()=>{
  const old=legacy(),before=structuredClone(old.template);
  const next=patchScopedTemplate(old.template,old.snapshot,'common',[]);
  assert.equal(next.envelope.schemaVersion,2);
  assert.deepEqual(old.template,before);
  for(const p of ['android','telegram']){
    assert.deepEqual(materializePlatform(next.envelope,p),materializePlatform(old.envelope,p));
    for(const k of adKeys)assert.equal(Object.hasOwn(next.envelope.platforms[p].ads,k),false);
  }
  assert.equal(next.envelope.platforms.telegram.ads.interstitialEnabled,false);
  assert.equal(next.envelope.platforms.telegram.ads.rewardedBlockId,'55424');
  assert.deepEqual(readPlatformTemplate(next.template,next.android),next.envelope);
});
test('different legacy platform rules require an explicit resolution before migration',()=>{
  const old=legacy();old.envelope.platforms.telegram.ads.interstitialCooldownSec=300;
  old.template.parameters[PLATFORMS_RC_KEY].defaultValue.value=JSON.stringify(old.envelope);
  assert.throws(()=>patchScopedTemplate(old.template,old.snapshot,'common',[]),e=>e.code==='ad_rules_merge_conflict');
});
test('a common edit reaches both platforms without re-enabling automatic Telegram ads',()=>{
  const old=legacy(),next=patchScopedTemplate(old.template,old.snapshot,'common',[{path:'economy.interstitialMinLives',value:7}]);
  for(const p of ['android','telegram'])assert.equal(materializePlatform(next.envelope,p).config.economy.interstitialMinLives,7);
  assert.equal(next.envelope.platforms.telegram.ads.interstitialEnabled,false);
  for(const k of adKeys){
    assert.equal(configFieldScope(`economy.${k}`),'common');
    for(const p of ['android','telegram'])assert.equal(platformFields[p].some(f=>f.path===`ads.${k}`),false);
  }
});
test('schema2 rejects a second conflicting copy of common rules inside a platform',()=>{
  const old=legacy(),next=patchScopedTemplate(old.template,old.snapshot,'common',[]);
  next.envelope.platforms.telegram.ads.interstitialCooldownSec=300;
  next.template.parameters[PLATFORMS_RC_KEY].defaultValue.value=JSON.stringify(next.envelope);
  assert.throws(()=>readPlatformTemplate(next.template,next.android),e=>e.code==='platform_policy_invalid');
});
