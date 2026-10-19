// Read source documents; write only disposable derived average cache rows.
// Outputs aggregate diagnostics, never player IDs, names, wallets or tokens.
import assert from 'node:assert/strict';
import path from 'node:path';
import {createRequire} from 'node:module';
import {root,project,runtimeSecrets} from './supabase_operator.mjs';
import databaseCa from '../supabase/functions/_shared/database-ca.mjs';
import {PostgresStore} from '../supabase/functions/_shared/postgres-store.mjs';
import {averageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
import {averageRules,averageAlgorithm} from '../supabase/functions/_shared/average-config.mjs';

const require=createRequire(path.join(root,'supabase/package.json')),{Pool}=require('pg');
const secrets=runtimeSecrets(),pool=new Pool({connectionString:`postgresql://untouch_runtime.${project}:${secrets.password}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres`,ssl:{rejectUnauthorized:true,ca:databaseCa},max:1,connectionTimeoutMillis:10000});
let connection;
try{
  connection=await pool.connect();await connection.query('begin isolation level repeatable read');
  const config=(await connection.query("select after_snapshot->'config' as config from untouch.config_audit where status='published' order by completed_at desc,id desc limit 1")).rows[0].config,rules=averageRules(config);
  const fingerprint=async()=>(await connection.query("select md5(string_agg(path||body::text,E'\\n' order by path)) as hash from untouch.documents")).rows[0].hash;
  const before=await fingerprint();
  const players=(await connection.query("select key as uid,body from untouch.documents where parent='players' order by key")).rows;
  const scores=(await connection.query("select key,body from untouch.documents where parent='scores' and body->>'platform'='android'")).rows;
  const expected=[];
  for(const player of players){
    if([true,'true'].includes(player.body.supportDisabled))continue;
    const eligible=scores.filter(s=>s.body.uid===player.uid&&Number(s.body.timeMs)>rules.minDurationMs)
      .sort((a,b)=>Number(b.body.attemptAt??b.body.createdAt)-Number(a.body.attemptAt??a.body.createdAt)||(a.key<b.key?1:a.key>b.key?-1:0));
    if(eligible.length<rules.minAttempts)continue;
    const used=eligible.slice(0,rules.windowSize);let sum=0,squares=0,weights=0;
    used.forEach((s,i)=>{const t=Number(s.body.timeMs),w=(rules.previousWeightPercent/100)**i;sum+=t*w;squares+=t*t*w;weights+=w;});
    expected.push({uid:player.uid,rms:Math.sqrt(squares/weights),linear:sum/weights,used:used.length,eligible:eligible.length});
  }
  const sorted=expected.toSorted((a,b)=>b.rms-a.rms||(a.uid<b.uid?-1:1));
  const linear=expected.toSorted((a,b)=>b.linear-a.linear||(a.uid<b.uid?-1:1));
  let recomputed;
  const db=new PostgresStore({query:async(text,args)=>{const r=await connection.query(text,args);if(text.includes('cache_recomputed'))recomputed=r.rows[0].cache_recomputed;return r;}});
  const args={db,config,uid:players[0].uid,stamp:Date.now()},board=await averageRanking(args),coldRecomputed=recomputed;
  assert.equal(board.rules.algorithm,averageAlgorithm);assert.equal(board.rows.length,Math.min(200,sorted.length));
  for(const [i,row] of board.rows.entries()){
    const e=sorted[i];assert.equal(row.userId,`supabase:${e.uid}`);assert.equal(row.place,i+1);
    assert.ok(Math.abs(row.averageMs-e.rms)<1e-6);assert.equal(row.usedCount,e.used);assert.equal(row.eligibleCount,e.eligible);
  }
  assert.deepEqual(await averageRanking(args),board);assert.equal(recomputed,0);assert.equal(await fingerprint(),before);
  const keys=(await connection.query("select distinct c.rules_key from untouch.average_rank_cache c join untouch.documents p on p.path=c.owner_path where coalesce((p.body->>'supportDisabled')::boolean,false)=false")).rows.map(r=>r.rules_key);
  assert.ok(keys.every(k=>k.startsWith(averageAlgorithm+':')));
  await connection.query('commit');
  console.log(JSON.stringify({ok:true,algorithm:averageAlgorithm,rules,profiles:players.length,scores:scores.length,ranked:sorted.length,verifiedRows:board.rows.length,coldRecomputed,warmRecomputed:0,rankChanges:sorted.filter((p,i)=>linear[i]?.uid!==p.uid).length,maxIncreaseMs:Math.max(0,...expected.map(p=>p.rms-p.linear)),activeCacheKeysRms:true,documentsUnchanged:true,independentOracle:true}));
}catch(error){await connection?.query('rollback').catch(()=>{});console.error(JSON.stringify({ok:false,error:error.code??'verification_failed'}));process.exitCode=1;}
finally{connection?.release();await pool.end();}
