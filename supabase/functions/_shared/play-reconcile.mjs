import {randomUUID,timingSafeEqual} from 'node:crypto';
import {Buffer} from 'node:buffer';
import {hash,requireThat} from './core/policy.mjs';
export function reconcileAuthorized(header,secret){
  if(!secret||secret.length<40||typeof header!=='string')return false;
  const expected=Buffer.from(`Bearer ${secret}`),received=Buffer.from(header);
  return expected.length===received.length&&timingSafeEqual(expected,received);
}
export function createReconciler({db,pool,engine,acknowledge,getIdentity,listVoided,now=Date.now,batchSize=10}){
  const stateRef=db.collection('system').doc('play-reconcile');
  return async function run(){
    const owner=randomUUID(),began=now(),deadline=began+45000;
    const state=await db.runTransaction(async tx=>{
      const before=(await tx.get(stateRef)).data()??{};
      if((before.leaseUntil??0)>began)return null;
      const next={...before,leaseOwner:owner,leaseUntil:began+120000};tx.set(stateRef,next);return next;
    });
    if(!state)return{ok:true,skipped:'already_running'};
    const result={ok:true,checked:0,acknowledged:0,revoked:0,failed:0,voidedFailed:false};
    try{
      const page=await pool.query("select key,body from untouch.documents where parent='purchases' and key>$1 and body ? 'token' and coalesce(body->>'revoked','false')<>'true' and not (body ? 'supersededBy') and (body->>'kind'='energy_subscription' or coalesce(body->>'acknowledged','false')<>'true') order by key limit $2",[state.cursor??'',batchSize]);
      let processed=0;
      for(const row of page.rows){
        if(now()>=deadline)break;
        const receipt=row.body;state.cursor=row.key;processed++;
        try{
          const identity=await getIdentity(receipt.uid);if(!identity)continue;
          await engine.execute(receipt.uid,{action:'play_verify',productId:receipt.productId,purchaseToken:receipt.token},{...identity,background:true});
          const updated=(await db.collection('purchases').doc(row.key).get()).data();
          await acknowledge(updated);result.checked++;if(!receipt.acknowledged)result.acknowledged++;
        }catch(error){
          if(error.code==='purchase_canceled'){
            try{await engine.revokePurchase(receipt.uid,receipt.token);result.revoked++;}catch{result.failed++;}
          }else result.failed++;
        }
      }
      if(page.rows.length<batchSize&&processed===page.rows.length)state.cursor='';
      const count=await pool.query("select count(*)::int as n from untouch.documents where parent='purchases' and body ? 'token' and coalesce(body->>'revoked','false')<>'true'");
      if(count.rows[0].n&&now()<deadline){
        try{
          const windowEnd=state.voidedPage?state.voidedEnd:now();
          const windowStart=Math.max(now()-30*86400000+60000,(state.voidedThrough??now()-29*86400000)-3600000);
          const response=await listVoided({startTime:windowStart,endTime:windowEnd,token:state.voidedPage??null});
          for(const voided of response.voidedPurchases??[]){
            const receipt=(await db.collection('purchases').doc(hash(voided.purchaseToken)).get()).data();
            // Subscription renewals share tokens. An old refunded order must
            // never revoke a newer paid renewal using the same purchase token.
            if(!receipt?.uid||receipt.revoked||receipt.supersededBy||receipt.token!==voided.purchaseToken||receipt.orderId!==voided.orderId)continue;
            await engine.revokePurchase(receipt.uid,receipt.token);result.revoked++;
          }
          state.voidedPage=response.tokenPagination?.nextPageToken??null;
          state.voidedEnd=windowEnd;
          if(!state.voidedPage)state.voidedThrough=windowEnd;
        }catch{result.voidedFailed=true;}
      }
      state.lastRunAt=now();state.lastResult=result;return result;
    }finally{
      await db.runTransaction(async tx=>{
        const current=(await tx.get(stateRef)).data();
        requireThat(current?.leaseOwner===owner,'reconcile_lease_lost',409);
        tx.set(stateRef,{...state,leaseUntil:0,leaseOwner:null});
      });
    }
  };
}
