// Synthetic local SQL equivalence + same-process baseline comparison.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {testDatabase} from '../supabase/test/database.mjs';
import {recordRankings} from '../supabase/functions/_shared/record-ranking.mjs';
import {averageRanking} from '../supabase/functions/_shared/average-ranking.mjs';
const baseline='b20debda0ecc9dd875a6498909357d84b182596e';
async function previous(file){
 let source=execFileSync('git',['show',`${baseline}:supabase/functions/_shared/${file}.mjs`],{encoding:'utf8'});
 source=source.replace("'./average-config.mjs'",JSON.stringify(new URL('../supabase/functions/_shared/average-config.mjs',import.meta.url).href));
 return import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
}
const oldRecord=(await previous('record-ranking')).recordRankings;
const oldAverage=(await previous('average-ranking')).averageRanking;
const local=await testDatabase();
try {
 const stamp=Date.UTC(2026,9,18,12);
 await local.pg.query(`insert into untouch.documents(path,parent,key,body)
 select 'players/p'||n,'players','p'||n,jsonb_build_object('uid','p'||n,'nickname','Local '||n,'supportDisabled',n%37=0)
 from generate_series(1,200) n`);
 await local.pg.query(`insert into untouch.documents(path,parent,key,body)
 select 'scores/s'||n,'scores','s'||n,jsonb_build_object('uid','p'||(1+(n%200)),
 'platform',case when n%101=0 then 'telegram' else 'android' end,
 'timeMs',case when n%13=0 then 1000 else 1001+(n%60000) end,
 'createdAt',$1::bigint-n*100000,'attemptAt',$1::bigint-(10000-n)*100000)
 from generate_series(1,10000) n`,[stamp]);
 await local.pg.exec('analyze untouch.documents');
 const db={pool:local.pool};
 const pairs=[['record',oldRecord,recordRankings,{}],['average',oldAverage,averageRanking,{config:{}}]];
 for(const [kind,before,after,extra] of pairs){
  const args={db,uid:'p1',stamp,...extra};
  const began=performance.now();const old=await before(args);const baselineMs=performance.now()-began;
  const start=performance.now();const current=await after(args);const currentMs=performance.now()-start;
  assert.deepEqual(current,old);
  console.log(JSON.stringify({kind,players:200,scores:10000,equivalent:true,baselineMs,currentMs,environment:'local PGlite, same indexes, not production'}));
 }
}finally{await local.close();}
