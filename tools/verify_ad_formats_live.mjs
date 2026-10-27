import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {root,project} from './supabase_operator.mjs';
const base=`https://${project}.supabase.co/functions/v1/`;
const tests=[
 {name:'admin_requires_login',slug:'remote-config-admin',body:{action:'get',scope:'common'},expected:401},
 {name:'admin_rejects_foreign_origin',slug:'remote-config-admin',body:{action:'get',scope:'common'},origin:'https://example.com',expected:403},
 {name:'android_profile_requires_login',slug:'android-api',body:{action:'profile'},expected:401},
 {name:'telegram_profile_requires_init_data',slug:'telegram-api',body:{action:'profile'},expected:401},
];
const results=await Promise.all(tests.map(async test=>{
 const response=await fetch(base+test.slug,{method:'POST',headers:{'Content-Type':'application/json',...(test.origin?{Origin:test.origin}:{})},body:JSON.stringify(test.body)});
 const body=await response.json();assert.equal(response.status,test.expected,test.name);assert.equal(body.ok,false);
 return{name:test.name,status:response.status,error:body.error,passed:true};
}));
const summary={checkedAt:new Date().toISOString(),passed:true,checks:results};
fs.writeFileSync(path.join(root,'.private/ad-formats-deploy/live-auth-checks.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));
