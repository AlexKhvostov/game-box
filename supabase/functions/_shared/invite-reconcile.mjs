import {randomUUID} from 'node:crypto';

// Durable cursor and lease: independent from opening the invitations screen.
// A failed candidate is retained and revisited after wrapping the cursor.
export function createInviteReconciler({db,pool,engine,getIdentity,now=Date.now,batchSize=10}) {
  const ref=db.collection('system').doc('invite-reconcile');
  return async function run() {
    const owner=randomUUID(),began=now();
    const state=await db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data()??{};
      if((old.leaseUntil??0)>began)return null;
      const next={...old,leaseOwner:owner,leaseUntil:began+120000};tx.set(ref,next);return next;
    });
    if(!state)return {ok:true,skipped:'already_running'};
    const result={ok:true,checked:0,failed:0};
    try {
      const page=await pool.query("select key,body from untouch.documents where parent='invitations' and body->>'rewardedAt' is null and key>$1 order by key limit $2",[state.cursor??'',batchSize]);
      let processed=0;
      for(const row of page.rows) {
        if(now()-began>=15000)break;
        state.cursor=row.key;processed++;
        try {
          const identity=await getIdentity(row.key);
          if(identity?.googleLinked)await engine.execute(row.key,{action:'profile'},{...identity,background:true});
          result.checked++;
        }catch {result.failed++;}
      }
      if(page.rows.length<batchSize&&processed===page.rows.length)state.cursor='';
      state.lastRunAt=now();state.lastResult=result;
      return result;
    } finally {
      await db.runTransaction(async tx=>{
        const current=(await tx.get(ref)).data();
        if(current?.leaseOwner!==owner)throw Error('invite_reconcile_lease_lost');
        tx.set(ref,{...state,leaseUntil:0,leaseOwner:null});
      });
    }
  };
}
