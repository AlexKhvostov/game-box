// One-time accounting of already granted rewards. Never changes energy/scores.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {operator,privateDirectory,dpapi} from './supabase_operator.mjs';
import {hash} from '../supabase/functions/_shared/core/policy.mjs';
const apply=process.argv.includes('--apply'),stamp=Date.now(),day=Math.floor((stamp+10800000)/86400000),start=day*86400000-10800000;
const legacy=hash({args:{},kind:'watch_ad'});let o,connection;
try{
 o=await operator();connection=await o.pool.connect();await connection.query('begin isolation level serializable');
 const players=(await connection.query("select path,key,body from untouch.documents where parent='players' order by path for update")).rows;
 const directory=path.join(privateDirectory,'rewarded-daily-limit-20261018');fs.mkdirSync(directory,{recursive:true});
 const backup=path.join(directory,'players-before.dpapi');if(!fs.existsSync(backup))fs.writeFileSync(backup,dpapi(JSON.stringify({at:stamp,players})),{flag:'wx'});
 const counts=[];
 for(const player of players){
  const result=await connection.query("select count(*)::integer n from untouch.documents where parent=$1 and (body->>'createdAt')::bigint >= $2 and (body->>'createdAt')::bigint < $3 and ((body->'response') ? 'adReward' or body->>'fingerprint'=$4)",['players/'+player.key+'/operations',start,start+86400000,legacy]);
  const used=result.rows[0].n,old=player.body.adRewardsDaily;
  const count=Math.max(used,old?.day===day ? old.count : 0);assert.ok(Number.isSafeInteger(count)&&count>=0);
  if(apply)await connection.query("update untouch.documents set body=jsonb_set(body,'{adRewardsDaily}',$2::jsonb,true) where path=$1",[player.path,JSON.stringify({day,count})]);
  counts.push(count);
 }
 await connection.query(apply?'commit':'rollback');
 console.log(JSON.stringify({ok:true,applied:apply,players:players.length,counts,timezone:'Europe/Minsk UTC+3',energyChanged:false,scoresChanged:false,encryptedBackup:true}));
}catch(e){await connection?.query('rollback').catch(()=>{});console.error(JSON.stringify({ok:false,error:e.code??e.message}));process.exitCode=1;}finally{connection?.release();await o?.close();}
