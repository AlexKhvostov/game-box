// Add explicit independent formats through the existing audited admin workflow.
// Preserve every existing economy/provider value and every other RC parameter.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {privateDirectory,dpapi,root,project,runtimeSecrets} from './supabase_operator.mjs';
import databaseCa from '../supabase/functions/_shared/database-ca.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {adFormatsConfig} from '../supabase/functions/_shared/ad-formats-config.mjs';
const stage=path.join(root,'.private/ad-formats-deploy');
const shared=path.join(stage,'candidate/remote-config-admin/functions/_shared');
const {createPlatformConfigAdmin}=await import(pathToFileURL(path.join(shared,'platform-config-admin.mjs')).href);
const {readPlatformTemplate,patchScopedTemplate,materializePlatform}=await import(pathToFileURL(path.join(shared,'platform-config.mjs')).href);
const publish=process.argv.includes('--publish');
if(process.argv.slice(2).some(a=>a!=='--publish'))throw Error('argument_invalid');
const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
const remote=createRemoteConfig({credentials});
const current=await remote.get(),before=readPlatformTemplate(current.template,current.snapshot);
const policy=adFormatsConfig(before.common.advertising);
const patches=Object.entries(policy).flatMap(([format,values])=>Object.entries(values).map(([key,value])=>({path:`advertising.${format}.${key}`,value})));
const candidate=patchScopedTemplate(current.template,current.snapshot,'common',patches);
function withoutAds(config){const result=structuredClone(config);delete result.advertising;return result;}
function otherParameters(template){const result=structuredClone(template);delete result.version;for(const params of [result.parameters,...Object.values(result.parameterGroups??{}).map(g=>g.parameters)])if(params){delete params.untouch_platforms_v1;delete params.android_config_v1;}return result;}
assert.deepEqual(withoutAds(candidate.envelope.common),withoutAds(before.common));
assert.deepEqual(candidate.envelope.platforms,before.platforms);
assert.deepEqual(otherParameters(candidate.template),otherParameters(current.template));
for(const platform of ['android','telegram'])assert.deepEqual(withoutAds(materializePlatform(candidate.envelope,platform).config),withoutAds(materializePlatform(before,platform).config));
const require=createRequire(path.join(root,'supabase/package.json'));
const {Pool}=require('pg');const secret=runtimeSecrets();
const pool=new Pool({connectionString:`postgresql://untouch_runtime.${project}:${secret.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`,ssl:{rejectUnauthorized:true,ca:databaseCa},max:2,connectionTimeoutMillis:10000});
try{
 const actor=(await pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;
 assert.ok(actor,'enabled_admin_required');
 const execute=createPlatformConfigAdmin({db:pool,remote});
 const preview=await execute(actor,{action:'preview',scope:'common',baseEtag:current.etag,patches});
 assert.deepEqual(preview.snapshot.config.advertising,policy);
 let result;
 const alreadyExplicit=JSON.stringify(before.common.advertising)===JSON.stringify(policy);
 if(publish&&!alreadyExplicit){
  const ready=JSON.parse(fs.readFileSync(path.join(stage,'deployed-functions.json'),'utf8'));
  assert.ok(ready.passed&&ready.functions.length===3&&ready.functions.every(f=>f.sourceMatches&&f.verifyJwtUnchanged));
  fs.writeFileSync(path.join(stage,`before-publish-${Date.now()}.dpapi`),dpapi(JSON.stringify(current)),{flag:'wx'});
  result=await execute(actor,{action:'publish',scope:'common',baseEtag:current.etag,patches,confirmRevision:preview.snapshot.revision});
 }
 const actual=publish?await remote.get():current;
 const envelope=publish?readPlatformTemplate(actual.template,actual.snapshot):candidate.envelope;
 assert.deepEqual(envelope.common.advertising,policy);
 assert.deepEqual(withoutAds(envelope.common),withoutAds(before.common));
 assert.deepEqual(envelope.platforms,before.platforms);
 if(publish)assert.deepEqual(otherParameters(actual.template),otherParameters(current.template));
 const roundtrip=publish?await execute(actor,{action:'get',scope:'common'}):preview;
 assert.deepEqual(roundtrip.snapshot.config.advertising,policy);
 const report={passed:true,published:!!result,alreadyExplicit,checkedAt:new Date().toISOString(),previousVersion:current.template.version?.versionNumber,version:actual.template.version?.versionNumber,advertising:policy,existingEconomyAndProviderRulesUnchanged:true,otherParametersIncludingQaUnchanged:true,adminRoundtrip:true,playerDataWritten:false};
 fs.writeFileSync(path.join(stage,publish?'rc-published.json':'rc-preview.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await pool.end();}
