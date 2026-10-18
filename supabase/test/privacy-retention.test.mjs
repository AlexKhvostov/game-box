import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
const local=await testDatabase();after(()=>local.close());
await local.pg.exec('create table auth.audit_log_entries(id integer primary key,created_at timestamptz not null);');
await local.pg.exec(await fs.readFile(new URL('../migrations/20261018163744_android_privacy_retention.sql',import.meta.url),'utf8'));
test('privacy cleanup expires completed support/auth logs only, is idempotent and denies browser/runtime callers',async()=>{
  await local.pg.exec(`insert into untouch.support_actions(id,actor,target,kind,fingerprint,status,details,created_at,completed_at)
    select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000011','delete_user','hash',
    case when n=3 then 'pending' else 'completed' end,'{}',now()-interval '120 days',
    case when n=1 then now()-interval '91 days' when n=2 then now()-interval '89 days' else null end from generate_series(1,3) n;
    insert into auth.audit_log_entries values(1,now()-interval '31 days'),(2,now()-interval '29 days');
    insert into untouch.documents(path,parent,key,body) values('players/untouched','players','untouched','{"wallet":{"energy":50}}'),('purchases/hash','purchases','hash','{"deleted":true}');`);
  const result=(await local.pg.query('select untouch.cleanup_privacy_logs() as result')).rows[0].result;
  assert.deepEqual(result,{supportActions:1,authAudit:1});
  assert.equal((await local.pg.query('select count(*)::int as n from untouch.support_actions')).rows[0].n,2);
  assert.equal((await local.pg.query('select count(*)::int as n from untouch.documents')).rows[0].n,2);
  assert.deepEqual((await local.pg.query('select untouch.cleanup_privacy_logs() as result')).rows[0].result,{supportActions:0,authAudit:0});
  for(const role of ['anon','authenticated','untouch_runtime']){
    const permission=(await local.pg.query("select has_function_privilege($1,'untouch.cleanup_privacy_logs()','execute') as allowed",[role])).rows[0];assert.equal(permission.allowed,false);
  }
});
