// Only derived cache writes in --live mode. No Auth/player/attempt/RC mutations.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {PostgresStore} from '../supabase/functions/_shared/postgres-store.mjs';
import {averageRanking,uncachedAverageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
import {runtimeSecrets,project,root} from './supabase_operator.mjs';
import databaseCa from '../supabase/functions/_shared/database-ca.mjs';

const live=process.argv.includes('--live');let resource,connection;
try{
  if(live){
    const require=createRequire(path.join(root,'supabase/package.json')),{Pool}=require('pg');
    const secrets=runtimeSecrets();
    const pool=new Pool({connectionString:`postgresql://untouch_runtime.${project}:${secrets.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`,ssl:{rejectUnauthorized:true,ca:databaseCa},max:1,connectionTimeoutMillis:10000});
    resource={pool,close:()=>pool.end()};
  }else{
    const {testDatabase}=await import('../supabase/test/database.mjs');resource=await testDatabase();
    await resource.pg.exec(await fs.readFile(new URL('../supabase/migrations/20261019205914_android_average_ranking_cache.sql',import.meta.url),'utf8'));
    const db=new PostgresStore(resource.pool);
    await db.collection('players').doc('fixture').set({nickname:'fixture'});
    for(let i=0;i<100;i++)await db.collection('scores').doc(`fixture_${i}`).set({uid:'fixture',platform:'android',timeMs:i%9?1000+i*139:500,createdAt:i});
  }
  connection=await resource.pool.connect();await connection.query('begin isolation level repeatable read');
  const config=live?(await connection.query("select after_snapshot->'config' as config from untouch.config_audit where status='published' order by completed_at desc,id desc limit 1")).rows[0]?.config:{};
  assert.ok(config,'published config required');
  const owners=await connection.query("select key from untouch.documents where parent='players' order by key limit 1");
  assert.ok(owners.rows.length);const uid=owners.rows[0].key,stamp=Date.now();let sql,args,recomputed;
  const db=new PostgresStore({query:async(text,values)=>{const result=await connection.query(text,values);if(text.includes('cache_recomputed')){sql=text;args=values;recomputed=result.rows[0].cache_recomputed;}return result;}});
  const fingerprint=async()=>(await connection.query("select md5(string_agg(path||body::text,E'\\n' order by path)) as hash,count(*)::integer as documents from untouch.documents")).rows[0];
  const before=await fingerprint();
  const old=await uncachedAverageRanking({db,config,uid,stamp});
  const first=await averageRanking({db,config,uid,stamp}),coldRecomputed=recomputed;
  assert.deepEqual(first,old);
  const cacheBefore=(await connection.query('select uid,score_revision::text,rules_key,updated_at::text from untouch.average_rank_cache order by uid')).rows;
  const start=performance.now(),warm=await averageRanking({db,config,uid,stamp}),warmMs=performance.now()-start;
  assert.deepEqual(warm,old);assert.equal(recomputed,0);
  assert.deepEqual((await connection.query('select uid,score_revision::text,rules_key,updated_at::text from untouch.average_rank_cache order by uid')).rows,cacheBefore);
  const plan=(await connection.query('explain(analyze,format json) '+sql,args)).rows[0]['QUERY PLAN'][0];
  const nodes=[];function walk(n){nodes.push(n);for(const p of n.Plans??[])walk(p);}walk(plan.Plan);
  const scoreScans=nodes.filter(n=>n['Relation Name']==='documents'&&n.Alias==='s').map(n=>({node:n['Node Type'],loops:n['Actual Loops'],rows:n['Actual Rows']}));
  assert.ok(scoreScans.length,'score scan identified');assert.ok(scoreScans.every(s=>s.loops===0),'warm cache must not scan scores');
  assert.deepEqual(await fingerprint(),before);
  const security=(await connection.query("select has_table_privilege('anon','untouch.average_rank_cache','select') as anon,has_table_privilege('authenticated','untouch.average_rank_cache','update') as authenticated")).rows[0];
  assert.deepEqual(security,{anon:false,authenticated:false});
  await connection.query('commit');
  console.log(JSON.stringify({ok:true,live,algorithm:warm.rules.algorithm,documents:before.documents,playersInTop:warm.rows.length,cacheRows:cacheBefore.length,coldRecomputed,warmRecomputed:0,warmMs,planExecutionMs:plan['Execution Time'],scoreScans,identicalToUncached:true,documentsUnchanged:true,cacheUnchangedOnRepeat:true,browserCacheAccess:false}));
}catch(error){
  await connection?.query('rollback').catch(()=>{});
  console.error(JSON.stringify({ok:false,live,error:error.code??error.message,...(!live?{detail:error.message.slice(0,350)}:{})}));process.exitCode=1;
}finally{connection?.release();await resource?.close();}
