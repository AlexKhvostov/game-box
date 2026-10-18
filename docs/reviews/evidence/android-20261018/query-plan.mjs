// Local synthetic data and plans only; elapsed time is not production latency.
import {testDatabase} from '../../../../supabase/test/database.mjs';
import {recordRankings} from '../../../../supabase/functions/_shared/record-ranking.mjs';
import {averageRanking} from '../../../../supabase/functions/_shared/average-ranking.mjs';
import {defaults} from '../../../../supabase/functions/_shared/core/policy.mjs';
const local=await testDatabase();
try {
  const stamp=Date.UTC(2026,9,18,12);
  await local.pg.query(`insert into untouch.documents(path,parent,key,body)
    select 'players/p'||n,'players','p'||n,jsonb_build_object('uid','p'||n,'nickname','Local '||n,'supportDisabled',false)
    from generate_series(1,200) n`);
  await local.pg.query(`insert into untouch.documents(path,parent,key,body)
    select 'scores/s'||n,'scores','s'||n,jsonb_build_object('uid','p'||(1+(n%200)),
      'platform','android','timeMs',1001+(n%60000),'createdAt',$1::bigint-n*1000,'attemptAt',$1::bigint-n*1000)
    from generate_series(1,10000) n`,[stamp]);
  await local.pg.exec('analyze untouch.documents');
  const captured=[];
  const db={pool:{query:async(text,values)=>{captured.push({text,values});return local.pool.query(text,values);}}};
  await recordRankings({db,uid:'p1',stamp});
  await averageRanking({db,config:defaults.config,uid:'p1',stamp});
  console.log('200 synthetic players, 10000 scores; PGlite EXPLAIN ANALYZE, not a live-server benchmark.');
  for(const [i,q] of captured.entries()) {
    console.log(i===0?'RECORD:':'AVERAGE:');
    const r=await local.pg.query('explain (analyze,buffers) '+q.text,q.values);
    console.log(r.rows.map(row=>row['QUERY PLAN']).join('\n'));
  }
} finally {await local.close();}
