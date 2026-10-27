import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {root} from './supabase_operator.mjs';
const stage=path.join(root,'.private/ad-formats-deploy');
const dir=slug=>path.join(stage,'candidate',slug,'functions/_shared');
const before=await import(pathToFileURL(path.join(stage,'production/remote-config-admin/functions/_shared/config-schema.mjs')).href);
const after=await import(pathToFileURL(path.join(dir('remote-config-admin'),'config-schema.mjs')).href);
assert.equal(after.fields.length,before.fields.length+7);
for(const field of before.fields){
 const next=after.fields.find(f=>f.path===field.path);assert.ok(next,field.path);
 for(const key of ['type','min','max','step','default','readOnly','hidden'])assert.deepEqual(next[key],field[key],field.path+':'+key);
 if(!field.path.startsWith('economy.interstitial'))assert.equal(next.section,field.section);
}
assert.ok(after.fields.some(f=>f.path.endsWith('simpleBonus.inviteMinimumEnergy')));
const fields=after.fields.filter(f=>f.path.startsWith('advertising.'));
assert.equal(fields.length,7);
const old=structuredClone(after.defaultsSnapshot);
const patches=[{path:'advertising.banner.enabled',value:true},{path:'advertising.automatic.enabled',value:false}];
const next=after.applyChanges(old,patches);
assert.deepEqual(next.economy,old.config.economy);
assert.deepEqual(after.changesBetween(old.config,next).map(c=>c.path),patches.map(p=>p.path));
assert.equal(next.advertising.rewarded.enabled,true);
assert.throws(()=>after.applyChanges(old,[{path:'advertising.banner.enabled',value:1}]));
for(const slug of ['android-api','telegram-api']){
 const engine=fs.readFileSync(path.join(dir(slug),'core/engine.mjs'),'utf8');
 assert.ok(engine.includes("policy.config.advertising?.rewarded?.enabled!==false&&b.videoReward>0"));
 const {validatePolicy}=await import(pathToFileURL(path.join(dir(slug),'core/policy.mjs')).href);
 assert.equal(typeof validatePolicy,'function');
 const file=path.join(root,'supabase/test/rewarded-quota.test.mjs');
 let source=fs.readFileSync(file,'utf8');
 for(const [relative,target]of [
  ['../functions/_shared/core/engine.mjs',path.join(dir(slug),'core/engine.mjs')],
  ['../functions/_shared/core/policy.mjs',path.join(dir(slug),'core/policy.mjs')],
  ['../functions/_shared/config-schema.mjs',path.join(dir(slug),'config-schema.mjs')],
  ['../functions/_shared/postgres-store.mjs',path.join(dir(slug),'postgres-store.mjs')],
  ['./database.mjs',path.join(root,'supabase/test/database.mjs')],
 ])source=source.replace(relative,pathToFileURL(target).href);
 fs.writeFileSync(path.join(stage,`ad-release-${slug}.generated.mjs`),source);
}
const summary={passed:true,previousFields:before.fields.length,fields:after.fields.length,independentAdFields:fields.length,existingFieldTypesRangesDefaultsUnchanged:true,inviteMinimumRetained:true,engineRewardedGateBothPlatforms:true};
fs.writeFileSync(path.join(stage,'candidate-validation.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));
