import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {defaults} from '../functions/_shared/core/policy.mjs';
import {patchScopedTemplate,readPlatformTemplate,materializePlatform} from '../functions/_shared/platform-config.mjs';
import {patchAndroidTemplate,readAndroidTemplate} from '../functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../functions/_shared/config-admin.mjs';
import {testDatabase} from './database.mjs';
const base=()=>({parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}},unrelated:{defaultValue:{value:'keep'}}}});
test('common gameplay and reward edits affect both; platform ads/Stars do not alter other platform',()=>{
  const shared=patchScopedTemplate(base(),defaults,'common',[{path:'economy.androidEnergyV2.simpleBonus.reward',value:37}]);
  for(const p of ['android','telegram'])assert.equal(materializePlatform(shared.envelope,p).config.economy.androidEnergyV2.simpleBonus.reward,37);
  const telegram=patchScopedTemplate(shared.template,shared.android,'telegram',[{path:'stars.pack100Price',value:31},{path:'ads.interstitialCooldownSec',value:99}]);
  assert.equal(telegram.envelope.platforms.telegram.stars.pack100Price,31);
  assert.deepEqual(telegram.android,shared.android);assert.equal(telegram.template.parameters.unrelated.defaultValue.value,'keep');
  assert.equal(materializePlatform(telegram.envelope,'telegram').config.economy.interstitialCooldownSec,99);
  const android=patchScopedTemplate(telegram.template,telegram.android,'android',[{path:'ads.interstitialCooldownSec',value:120}]);
  assert.equal(android.envelope.platforms.telegram.ads.interstitialCooldownSec,99);
  assert.equal(android.android.config.economy.interstitialCooldownSec,120);
});
test('wrong scope/unknown duplicate fields, sales enablement and external legacy drift are rejected',()=>{
  assert.throws(()=>patchScopedTemplate(base(),defaults,'telegram',[{path:'player.size',value:40}]));
  assert.throws(()=>patchScopedTemplate(base(),defaults,'common',[{path:'economy.interstitialCooldownSec',value:60}]));
  assert.throws(()=>patchScopedTemplate(base(),defaults,'telegram',[{path:'stars.salesEnabled',value:true}]),e=>e.code==='stars_acceptance_required');
  assert.throws(()=>patchScopedTemplate(base(),defaults,'telegram',[{path:'stars.tier2Price',value:50},{path:'stars.tier2Price',value:60}]));
  const next=patchScopedTemplate(base(),defaults,'telegram',[]);
  const changed=structuredClone(defaults);changed.config.player.size=30;
  assert.throws(()=>readPlatformTemplate(next.template,changed),e=>e.code==='platform_legacy_config_conflict');
});
test('old admin publication stays compatible after split; scoped settings remain isolated',()=>{
  const split=patchScopedTemplate(base(),defaults,'telegram',[{path:'stars.pack100Price',value:29}]);
  const old=patchAndroidTemplate(split.template,[{path:'player.size',value:34},{path:'economy.interstitialCooldownSec',value:100}]);
  const envelope=readPlatformTemplate(old.template,old.snapshot);
  assert.equal(envelope.common.player.size,34);assert.equal(envelope.platforms.telegram.stars.pack100Price,29);
  assert.equal(envelope.platforms.android.ads.interstitialCooldownSec,100);
});
test('grouped Android and platform parameters stay grouped, duplicate keys are rejected',()=>{
  const grouped={parameterGroups:{game:{parameters:base().parameters}}};
  const a=patchScopedTemplate(grouped,defaults,'telegram',[]);
  const param=a.template.parameters.untouch_platforms_v1;
  a.template.parameterGroups.platforms={parameters:{untouch_platforms_v1:param}};
  delete a.template.parameters.untouch_platforms_v1;
  const b=patchScopedTemplate(a.template,a.android,'telegram',[{path:'stars.pack100Price',value:44}]);
  assert.equal(b.template.parameters.untouch_platforms_v1,undefined);
  assert.equal(JSON.parse(b.template.parameterGroups.platforms.parameters.untouch_platforms_v1.defaultValue.value).platforms.telegram.stars.pack100Price,44);
  assert.equal(b.template.parameters.android_config_v1,undefined);
  const old=patchAndroidTemplate(b.template,[{path:'player.size',value:33}]);
  assert.equal(readPlatformTemplate(old.template,old.snapshot).common.player.size,33);
  old.template.parameters.untouch_platforms_v1=param;
  assert.throws(()=>readPlatformTemplate(old.template,old.snapshot),e=>e.code==='remote_config_duplicate_key');
});
const local=await testDatabase();after(()=>local.close());
await local.pg.exec(await (await import('node:fs/promises')).readFile(new URL('../migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8'));
await local.pg.exec(await (await import('node:fs/promises')).readFile(new URL('../migrations/20261019223954_telegram_platform_core.sql',import.meta.url),'utf8'));
const actor='12345678-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1)',[actor]);await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
let template=base(),etag='1';
const remote={get:async()=>({template,etag,initialized:true,...readAndroidTemplate(template)}),publishScoped:async(current,scope,patches)=>{
  assert.equal(current.etag,etag);template=patchScopedTemplate(template,current.snapshot,scope,patches).template;etag=String(Number(etag)+1);return{publishedVersion:etag};}};
const admin=createConfigAdmin({db:local.pool,remote});
test('admin scoped drafts, preview confirmation, stale etag and audited publication',async()=>{
  const patches=[{path:'stars.pack100Price',value:32}];
  await admin(actor,{action:'save_draft',scope:'telegram',baseEtag:etag,patches});
  assert.equal((await admin(actor,{action:'get',scope:'common'})).draft,null);
  assert.deepEqual((await admin(actor,{action:'get',scope:'telegram'})).draft.patches,patches);
  const preview=await admin(actor,{action:'preview',scope:'telegram',baseEtag:etag,patches});
  await assert.rejects(admin(actor,{action:'publish',scope:'common',baseEtag:etag,patches,confirmRevision:preview.snapshot.revision}));
  const first=etag;await admin(actor,{action:'publish',scope:'telegram',baseEtag:etag,patches,confirmRevision:preview.snapshot.revision});
  await assert.rejects(admin(actor,{action:'publish',scope:'telegram',baseEtag:first,patches,confirmRevision:preview.snapshot.revision}),e=>e.code==='remote_config_conflict');
  assert.equal((await admin(actor,{action:'get',scope:'telegram'})).snapshot.config.stars.pack100Price,32);
  const rows=await local.pg.query('select status,changes from untouch.config_audit');assert.equal(rows.rows[0].status,'published');assert.equal(rows.rows[0].changes[0].scope,'telegram');
});

test('new enemy curve and brake parameters stay common across Android and Telegram materialization',()=>{
 const shared=patchScopedTemplate(base(),defaults,'common',[{path:'enemyPace.growthMultiplier',value:60},{path:'enemyPace.brakeCooldownSec',value:9}]);
 for(const platform of ['android','telegram']){const c=materializePlatform(shared.envelope,platform).config;assert.equal(c.enemyPace.growthMultiplier,60);assert.equal(c.enemyPace.brakeCooldownSec,9);assert.equal(c.enemyPace.brakeRewindSec,6);}
 assert.throws(()=>patchScopedTemplate(shared.template,shared.android,'telegram',[{path:'enemyPace.brakeRewindSec',value:7}]));
});

test('brake and meter toggles are independent shared parameters for both platform snapshots',()=>{
 const shared=patchScopedTemplate(base(),defaults,'common',[{path:'enemyPace.brakeEnabled',value:false},{path:'enemyPace.speedBarEnabled',value:true}]);
 for(const platform of ['android','telegram']){const pace=materializePlatform(shared.envelope,platform).config.enemyPace;assert.equal(pace.brakeEnabled,false);assert.equal(pace.speedBarEnabled,true);}
});
