import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
import {createConfigAdmin} from '../functions/_shared/config-admin.mjs';
import {patchAndroidTemplate,readAndroidTemplate} from '../functions/_shared/remote-config.mjs';
import {ApiError} from '../functions/_shared/core/policy.mjs';
import {createPolicyLoader} from '../functions/_shared/policy-loader.mjs';
const local=await testDatabase();after(()=>local.close());
const actor='12345678-1234-4234-8234-123456789abc',other='22345678-1234-4234-8234-123456789abc';
await local.pg.query('insert into auth.users(id) values($1),($2)',[actor,other]);
await local.pg.query('insert into untouch.admin_users(id) values($1)',[actor]);
let etag='"v1"',template={parameters:{legacy:{defaultValue:{value:'preserve'}}},version:{versionNumber:'1'}},writes=0;
const remote={get:async()=>({etag,template:structuredClone(template),...readAndroidTemplate(template)}),publish:async(current,patches)=>{
  if(current.etag!==etag)throw new ApiError('remote_config_conflict',409);
  template=patchAndroidTemplate(template,patches).template;template.version={versionNumber:String(++writes+1)};etag=`"v${writes+1}"`;return{publishedVersion:template.version.versionNumber};
}};
const execute=createConfigAdmin({db:local.pool,remote});
const patches=[{path:'economy.androidEnergyV2.simpleBonus.reward',value:35}];
test('authorization comes only from private admin membership, not supplied actor metadata',async()=>{
  await assert.rejects(execute(other,{action:'get',admin:true}),e=>e.code==='admin_required');assert.equal(writes,0);
});
test('draft is isolated from live config and requires exact base ETag',async()=>{
  await execute(actor,{action:'save_draft',baseEtag:etag,patches});
  const current=await execute(actor,{action:'get'});assert.deepEqual(current.draft.patches,patches);
  assert.equal(current.snapshot.config.economy.androidEnergyV2.simpleBonus.reward,30);assert.equal(writes,0);
  await assert.rejects(execute(actor,{action:'save_draft',baseEtag:'"stale"',patches}),e=>e.code==='remote_config_conflict');
});
test('publishing requires matching preview revision, records audit, preserves legacy config, rejects replay',async()=>{
  const base=etag;const preview=await execute(actor,{action:'preview',baseEtag:base,patches});
  await assert.rejects(execute(actor,{action:'publish',baseEtag:base,patches,confirmRevision:'forged'}),e=>e.code==='preview_required');assert.equal(writes,0);
  const result=await execute(actor,{action:'publish',baseEtag:base,patches,confirmRevision:preview.snapshot.revision});assert.equal(result.published,true);assert.equal(writes,1);
  assert.equal(template.parameters.legacy.defaultValue.value,'preserve');
  const audit=await execute(actor,{action:'history'});assert.equal(audit.history[0].status,'published');assert.equal(audit.history[0].changes[0].after,35);
  await assert.rejects(execute(actor,{action:'publish',baseEtag:base,patches,confirmRevision:preview.snapshot.revision}),e=>e.code==='remote_config_conflict');assert.equal(writes,1);
  assert.equal((await execute(actor,{action:'get'})).draft,null);
});

test('successful admin publication invalidates warm policy immediately; a draft leaves live policy unchanged',async()=>{
  let reads=0;const load=createPolicyLoader({pool:local.pool,remote:{get:async()=>{reads++;return remote.get();}}});
  assert.equal((await load()).config.economy.androidEnergyV2.simpleBonus.reward,35);
  await load();assert.equal(reads,1);
  const changes=[{path:'economy.androidEnergyV2.simpleBonus.reward',value:36}];
  await execute(actor,{action:'save_draft',baseEtag:etag,patches:changes});
  assert.equal((await load()).config.economy.androidEnergyV2.simpleBonus.reward,35);assert.equal(reads,1);
  const preview=await execute(actor,{action:'preview',baseEtag:etag,patches:changes});
  await execute(actor,{action:'publish',baseEtag:etag,patches:changes,confirmRevision:preview.snapshot.revision});
  assert.equal((await load()).config.economy.androidEnergyV2.simpleBonus.reward,36);assert.equal(reads,2);
});
