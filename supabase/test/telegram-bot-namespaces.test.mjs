import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {testDatabase} from './database.mjs';
const platform=await fs.readFile(new URL('../migrations/20261019223954_telegram_platform_core.sql',import.meta.url),'utf8');
const averages=await fs.readFile(new URL('../migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8');
const migration=await fs.readFile(new URL('../migrations/20261022085951_telegram_bot_namespaces.sql',import.meta.url),'utf8');
test('Bot namespace migration preserves existing UIDs and permits independent accounts per bot',async()=>{
  const local=await testDatabase();try{
    await local.pg.exec(averages);await local.pg.exec(platform);
    await local.pg.exec("insert into untouch.external_identities(provider,subject,uid,bot_id) values('telegram','100001','00000000-0000-4000-8000-000000000001','8819798973')");
    const before=(await local.pool.query('select * from untouch.external_identities')).rows;
    await local.pg.exec(migration);
    assert.deepEqual((await local.pool.query('select * from untouch.external_identities')).rows,before);
    await local.pg.exec("insert into untouch.external_identities(provider,subject,uid,bot_id) values('telegram','100001','00000000-0000-4000-8000-000000000002','8773345829')");
    assert.equal((await local.pool.query('select count(*)::integer as n from untouch.external_identities')).rows[0].n,2);
    await assert.rejects(local.pg.exec("insert into untouch.external_identities(provider,subject,uid,bot_id) values('telegram','100001','00000000-0000-4000-8000-000000000003','8773345829')"));
    await assert.rejects(local.pg.exec("insert into untouch.external_identities(provider,subject,uid,bot_id) values('telegram','100002','00000000-0000-4000-8000-000000000001','8773345829')"));
    const access=await local.pool.query("select relrowsecurity as rls,has_table_privilege('anon','untouch.external_identities','select') as anon_read,has_table_privilege('authenticated','untouch.external_identities','select') as user_read from pg_class where oid='untouch.external_identities'::regclass");
    assert.deepEqual(access.rows[0],{rls:true,anon_read:false,user_read:false});
  }finally{await local.close();}
});
test('Missing verified bot ID aborts the migration instead of assigning a bot or deleting identities',async()=>{
  const local=await testDatabase();try{
    await local.pg.exec(averages);await local.pg.exec(platform);
    await local.pg.exec("insert into untouch.external_identities(provider,subject,uid) values('telegram','100001','00000000-0000-4000-8000-000000000001')");
    await local.pg.exec('begin');
    await assert.rejects(local.pg.exec(migration));
    await local.pg.exec('rollback');
    assert.equal((await local.pool.query('select bot_id from untouch.external_identities')).rows[0].bot_id,null);
  }finally{await local.close();}
});
