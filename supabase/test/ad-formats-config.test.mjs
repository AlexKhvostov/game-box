import {test} from 'node:test';
import assert from 'node:assert/strict';
import {adFormatsConfig} from '../functions/_shared/ad-formats-config.mjs';
import {defaults,hash,validatePolicy} from '../functions/_shared/core/policy.mjs';
import {fields,sections,applyChanges,getValue,changesBetween} from '../functions/_shared/config-schema.mjs';
import {patchScopedTemplate,readPlatformTemplate,materializePlatform} from '../functions/_shared/platform-config.mjs';

test('banner game threshold publishes independently in game units and preserves time/other formats',()=>{
 const field=fields.find(f=>f.path==='advertising.banner.unlockAfterGames');
 assert.equal(field.default,100);assert.equal(field.unit,'игр');assert.equal(field.min,0);assert.equal(field.max,1000000);
 const template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}};
 const initial=patchScopedTemplate(template,defaults,'common',[]);
 const next=patchScopedTemplate(initial.template,initial.android,'common',[{path:field.path,value:150}]);
 for(const platform of ['android','telegram']){
  const ads=materializePlatform(next.envelope,platform).config.advertising;
  assert.equal(ads.banner.unlockAfterGames,150);assert.equal(ads.banner.installDelaySec,86400);assert.equal(ads.banner.enabled,false);
  assert.deepEqual(ads.automatic,adFormatsConfig().automatic);assert.deepEqual(ads.rewarded,adFormatsConfig().rewarded);
 }
 assert.deepEqual(next.android.config.economy,defaults.config.economy);
 assert.equal(applyChanges(next.android,[{path:field.path,value:0}]).advertising.banner.unlockAfterGames,0);
 for(const value of [-1,1.5,'100',true,1000001])assert.throws(()=>adFormatsConfig({banner:{unlockAfterGames:value}}));
});

test('three ad formats retain legacy behavior; reading does not mutate published revision',()=>{
 const before=structuredClone(defaults), oldHash=before.revision;
 assert.deepEqual(adFormatsConfig().automatic,{enabled:true,longAbsenceSec:300,resumeGraceSec:180});
 assert.equal(adFormatsConfig().banner.enabled,false);assert.equal(adFormatsConfig().rewarded.enabled,true);
 validatePolicy(before);assert.deepEqual(before,defaults);assert.equal(before.revision,oldHash);
 assert.equal(getValue(before.config,'advertising.banner.installDelaySec'),86400);
});
test('format switches/parameters are independent and preserve the existing pacing',()=>{
 const base=structuredClone(defaults), before=structuredClone(base.config.economy);
 const config=applyChanges(base,[{path:'advertising.banner.enabled',value:true},{path:'advertising.banner.installDelaySec',value:600},{path:'advertising.automatic.enabled',value:false}]);
 assert.equal(config.advertising.banner.enabled,true);assert.equal(config.advertising.automatic.enabled,false);assert.equal(config.advertising.rewarded.enabled,true);
 assert.deepEqual(config.economy,before);
 assert.deepEqual(changesBetween(base.config,config).map(c=>c.path),['advertising.banner.enabled','advertising.banner.installDelaySec','advertising.automatic.enabled']);
 const next=applyChanges({config},[{path:'advertising.rewarded.enabled',value:false}]);
 assert.deepEqual(next.advertising.banner,config.advertising.banner);assert.deepEqual(next.advertising.automatic,config.advertising.automatic);
 assert.equal(new Set(sections.filter(s=>s[0].startsWith('ads-')).map(s=>s[0])).size,3);
 assert.equal(fields.find(f=>f.path==='advertising.banner.enabled').section,'ads-banner');
});
test('malformed types, delays and banner IDs are rejected at the server boundary',()=>{
 for(const raw of [null,[],{automatic:{enabled:1}},{banner:{installDelaySec:-1}},{automatic:{resumeGraceSec:1.5}},{banner:{unitId:'javascript:alert(1)'}},{rewarded:{surprise:true}}])assert.throws(()=>adFormatsConfig(raw));
 const config=structuredClone(defaults.config);config.advertising={banner:{enabled:'yes'}};
 assert.throws(()=>validatePolicy({ok:true,config,revision:hash(config)}));
});
test('existing platform envelopes remain valid and explicit ad publication reaches Android/Telegram',()=>{
 const template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}};
 const initial=patchScopedTemplate(template,defaults,'common',[]);
 readPlatformTemplate(initial.template,initial.android);
 const next=patchScopedTemplate(initial.template,initial.android,'common',[{path:'advertising.automatic.resumeGraceSec',value:240}]);
 readPlatformTemplate(next.template,next.android);
 for(const platform of ['android','telegram'])assert.equal(materializePlatform(next.envelope,platform).config.advertising.automatic.resumeGraceSec,240);
 assert.equal(next.android.config.economy.interstitialCooldownSec,defaults.config.economy.interstitialCooldownSec);
});

test('independent banner and automatic OFF switches survive RC materialization',()=>{
 const template={parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}};
 const initial=patchScopedTemplate(template,defaults,'common',[]);
 const on=patchScopedTemplate(initial.template,initial.android,'common',[
  {path:'advertising.banner.enabled',value:true},
  {path:'advertising.automatic.enabled',value:true},
 ]);
 for(const format of ['banner','automatic']){
  const off=patchScopedTemplate(on.template,on.android,'common',[{path:`advertising.${format}.enabled`,value:false}]);
  readPlatformTemplate(off.template,off.android);
  const other=format==='banner'?'automatic':'banner';
  for(const platform of ['android','telegram']){
   const ads=materializePlatform(off.envelope,platform).config.advertising;
   assert.equal(ads[format].enabled,false);
   assert.equal(ads[other].enabled,true);
   assert.equal(ads.rewarded.enabled,true);
  }
  const legacy=JSON.parse(off.template.parameters.android_config_v1.defaultValue.value);
  assert.equal(legacy.config.advertising[format].enabled,false);
 }
});
