import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {testDatabase} from './database.mjs';
const local=await testDatabase();after(()=>local.close());
test('anonymous and authenticated roles cannot read or write private game/admin data',async()=>{
  for(const role of ['anon','authenticated']){
    await local.pg.exec(`set role ${role}`);
    for(const sql of ['select * from untouch.documents',"insert into untouch.documents values('players/test','players','test','{}',now())",'select * from untouch.config_audit','select * from untouch.admin_users'])await assert.rejects(local.pg.query(sql),error=>error.code==='42501');
    await local.pg.exec('reset role');
  }
});
test('runtime role can update game data, cannot promote an administrator or access auth.users',async()=>{
  await local.pg.exec('set role untouch_runtime');
  await local.pg.query("insert into untouch.documents(path,parent,key,body) values('players/test','players','test','{}')");
  assert.equal((await local.pg.query('select * from untouch.documents')).rows.length,1);
  await assert.rejects(local.pg.query("insert into untouch.admin_users(id) values('00000000-0000-0000-0000-000000000001')"),e=>e.code==='42501');
  await assert.rejects(local.pg.query('select * from auth.users'),e=>e.code==='42501');
  await local.pg.exec('reset role');
});
