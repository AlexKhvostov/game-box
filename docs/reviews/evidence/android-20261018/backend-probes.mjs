// Isolated in-memory PostgreSQL only. No production connections or messages.
import assert from 'node:assert/strict';
import {testDatabase} from '../../../../supabase/test/database.mjs';
import {PostgresStore} from '../../../../supabase/functions/_shared/postgres-store.mjs';
import {createEngine} from '../../../../supabase/functions/_shared/core/engine.mjs';
import {defaults,hash} from '../../../../supabase/functions/_shared/core/policy.mjs';
const local=await testDatabase();
try {
  let stamp=1800000000000;
  const db=new PostgresStore(local.pool), engine=createEngine({db,now:()=>stamp});
  const uid='audit_local_only';
  const call=(action,args={})=>engine.execute(uid,{action,...args});
  await call('guest');
  const requestId=hash('audit-run');
  const r=await call('round_start',{requestId,rulesRevision:defaults.revision});
  await call('round_activate',{requestId});
  const answer=await call('round_finish',{roundId:r.roundId,timeMs:1,runDistance:10000000,riskCount:10000,hadJump:false,hadHelmet:false});
  assert.ok(answer.energyReward>10000);
  console.log(JSON.stringify({probe:'R06 impossible 1ms result accepted',energyReward:answer.energyReward,energy:answer.profile.wallet.energy,score:answer.score}));
  const video=await call('wallet_operation',{operationId:hash('audit-video'),kind:'watch_ad',args:{}});
  assert.equal(video.profile.wallet.energy-answer.profile.wallet.energy,40);
  console.log(JSON.stringify({probe:'R07 watch_ad accepted without ad-session proof',reward:40}));
} finally {await local.close();}
