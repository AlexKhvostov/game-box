import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {defaults} from '../functions/_shared/core/policy.mjs';
import {initialPlatformSettings,platformFields} from '../functions/_shared/platform-config-schema.mjs';
import {PLATFORMS_RC_KEY,patchScopedTemplate,readPlatformTemplate,scopedView,validatePlatformSettings,materializePlatform} from '../functions/_shared/platform-config.mjs';
import {readAndroidTemplate,patchAndroidTemplate} from '../functions/_shared/remote-config.mjs';
import {createConfigAdmin} from '../functions/_shared/config-admin.mjs';
import {testDatabase} from './database.mjs';

const flag='ads.interstitialEnabled';
const base=()=>({parameters:{android_config_v1:{defaultValue:{value:JSON.stringify(defaults)}}}});
function legacyPlatformTemplate(){
  const envelope={schemaVersion:1,common:structuredClone(defaults.config),platforms:initialPlatformSettings(defaults.config)};
  envelope.platforms.telegram.ads.enabled=true;
  envelope.platforms.telegram.ads.rewardedBlockId='55424';
  envelope.platforms.telegram.ads.interstitialBlockId='int-55425';
  delete envelope.platforms.telegram.ads.interstitialEnabled;
  return{...base(),parameters:{...base().parameters,[PLATFORMS_RC_KEY]:{defaultValue:{value:JSON.stringify(envelope)}}}};
}

test('new and old RC both default automatic Telegram ads OFF without changing rewarded or compatibility JSON',()=>{
  assert.equal(initialPlatformSettings(defaults.config).telegram.ads.interstitialEnabled,false);
  const legacy=legacyPlatformTemplate(),original=structuredClone(legacy);
  const envelope=readPlatformTemplate(legacy,defaults);
  assert.equal(envelope.platforms.telegram.ads.interstitialEnabled,false);
  assert.equal(envelope.platforms.telegram.ads.enabled,true);
  assert.equal(envelope.platforms.telegram.ads.rewardedBlockId,'55424');
  assert.equal(scopedView(envelope,'telegram').config.ads.interstitialEnabled,false);
  assert.deepEqual(materializePlatform(envelope,'android'),defaults);
  assert.deepEqual(legacy,original);
  assert.equal(Object.hasOwn(JSON.parse(legacy.parameters[PLATFORMS_RC_KEY].defaultValue.value).platforms.telegram.ads,'interstitialEnabled'),false);
  assert.equal(Object.hasOwn(envelope.platforms.android.ads,'interstitialEnabled'),false);
});

test('Telegram switch is scoped, strictly boolean and independent of rewarded/master ads',()=>{
  const legacy=legacyPlatformTemplate();
  const enabled=patchScopedTemplate(legacy,defaults,'telegram',[{path:flag,value:true}]);
  assert.deepEqual(enabled.changes,[{path:flag,label:'Автоматическая полноэкранная реклама',before:false,after:true,scope:'telegram'}]);
  assert.deepEqual(enabled.android,defaults);
  assert.equal(enabled.envelope.platforms.telegram.ads.enabled,true);
  assert.equal(enabled.envelope.platforms.telegram.ads.rewardedBlockId,'55424');
  const off=patchScopedTemplate(enabled.template,enabled.android,'telegram',[{path:flag,value:false}]);
  assert.equal(off.snapshot.config.ads.interstitialEnabled,false);
  assert.equal(off.snapshot.config.ads.enabled,true);
  const acceptedStars=patchScopedTemplate(legacy,defaults,'telegram',[{path:'stars.salesEnabled',value:true}],{telegramStarsAccepted:true});
  const independent=patchScopedTemplate(acceptedStars.template,acceptedStars.android,'telegram',[{path:flag,value:true}]);
  assert.equal(independent.snapshot.config.stars.salesEnabled,true);
  assert.equal(independent.snapshot.config.ads.interstitialEnabled,true);
  for(const scope of ['common','android'])assert.throws(()=>patchScopedTemplate(legacy,defaults,scope,[{path:flag,value:true}]),e=>['config_scope_invalid','config_invalid'].includes(e.code));
  for(const value of [null,undefined,0,1,'true','false',[],{}]){
    assert.throws(()=>patchScopedTemplate(legacy,defaults,'telegram',[{path:flag,value}]),e=>e.code==='platform_policy_invalid');
  }
  assert.throws(()=>patchScopedTemplate(legacy,defaults,'telegram',[{path:flag,value:false},{path:flag,value:true}]),e=>e.code==='config_scope_invalid');
  const input=initialPlatformSettings(defaults.config).telegram;
  delete input.ads.interstitialEnabled;
  assert.equal(validatePlatformSettings('telegram',input).ads.interstitialEnabled,false);
  assert.equal(Object.hasOwn(input.ads,'interstitialEnabled'),false);
});

test('old Android publication retains Telegram switch and unchanged compatibility rules',()=>{
  const enabled=patchScopedTemplate(legacyPlatformTemplate(),defaults,'telegram',[{path:flag,value:true}]);
  const old=patchAndroidTemplate(enabled.template,[{path:'player.size',value:34}]);
  const result=readPlatformTemplate(old.template,old.snapshot);
  assert.equal(result.platforms.telegram.ads.interstitialEnabled,true);
  assert.equal(result.common.player.size,34);
  assert.equal(Object.hasOwn(old.snapshot.config.economy,'interstitialEnabled'),false);
});

test('shared admin schema renders the default-off switch only in Telegram',()=>{
  const field=platformFields.telegram.find(f=>f.path===flag);
  assert.equal(field.type,'boolean');assert.equal(field.default,false);assert.equal(field.readOnly,false);
  assert.equal(field.section,'platform');assert.match(field.help,/не влияет|Не влияет/);
  assert.equal(platformFields.android.some(f=>f.path===flag),false);
});

const local=await testDatabase();after(()=>local.close());
await local.pg.exec(await readFile(new URL('../migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8'));
await local.pg.exec(await readFile(new URL('../migrations/20261019223954_telegram_platform_core.sql',import.meta.url),'utf8'));
const actor='12345678-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1)',[actor]);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
let template=legacyPlatformTemplate(),etag='1',publications=0;
const remote={get:async()=>({template,etag,initialized:true,...readAndroidTemplate(template)}),
  publishScoped:async(current,scope,patches)=>{
    assert.equal(current.etag,etag);template=patchScopedTemplate(template,current.snapshot,scope,patches).template;
    publications++;etag=String(Number(etag)+1);return{publishedVersion:etag};
  }};
const admin=createConfigAdmin({db:local.pool,remote});

test('draft/preview are read-only; explicit confirmation records one scoped boolean change and clean gameplay revisions',async()=>{
  const old=structuredClone(template);
  const get=await admin(actor,{action:'get',scope:'telegram'});
  assert.equal(get.snapshot.config.ads.interstitialEnabled,false);
  const patches=[{path:flag,value:true}];
  await admin(actor,{action:'save_draft',scope:'telegram',baseEtag:etag,patches});
  const preview=await admin(actor,{action:'preview',scope:'telegram',baseEtag:etag,patches});
  assert.equal(preview.snapshot.config.ads.interstitialEnabled,true);
  assert.equal(preview.snapshot.config.ads.enabled,true);
  assert.equal(preview.changes.length,1);
  assert.equal(publications,0);assert.deepEqual(template,old);
  await assert.rejects(admin(actor,{action:'publish',scope:'telegram',baseEtag:etag,patches,confirmRevision:'wrong'}),e=>e.code==='preview_required');
  assert.equal(publications,0);
  await admin(actor,{action:'publish',scope:'telegram',baseEtag:etag,patches,confirmRevision:preview.snapshot.revision});
  assert.equal(publications,1);
  assert.equal(readPlatformTemplate(template,readAndroidTemplate(template).snapshot).platforms.telegram.ads.interstitialEnabled,true);
  assert.deepEqual(readAndroidTemplate(template).snapshot,defaults);
  const audit=(await local.pg.query('select status,changes from untouch.config_audit')).rows;
  assert.equal(audit.length,1);assert.equal(audit[0].status,'published');
  assert.deepEqual(audit[0].changes,[{path:flag,label:'Автоматическая полноэкранная реклама',before:false,after:true,scope:'telegram'}]);
  const revisions=(await local.pg.query('select snapshot from untouch.policy_revisions')).rows;
  assert.ok(revisions.length>0);
  for(const {snapshot} of revisions)assert.equal(Object.hasOwn(snapshot.config.economy,'interstitialEnabled'),false);
});
