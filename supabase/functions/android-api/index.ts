import {handler,identity,authAdmin} from '../_shared/runtime.mjs';
import {prepareGoogleUnlink} from '../_shared/google-unlink.mjs';
import {gameRuntime} from '../_shared/game-runtime.mjs';
import {hash} from '../_shared/core/policy.mjs';
Deno.serve(handler(async ({user,body})=>{
  if(body.action==='prepare_google_unlink')return prepareGoogleUnlink(user,authAdmin().auth.admin);
  const {engine,db,acknowledge}=gameRuntime();
  const result=await engine.execute(user.id,body,identity(user));
  if(body.action==='play_verify'){
    const receipt=(await db.collection('purchases').doc(hash(body.purchaseToken)).get()).data();
    // A committed grant is never rolled back because Google's acknowledgement
    // response was lost. The scheduled reconciler retries pending receipts.
    try{await acknowledge(receipt);}catch{console.warn('play_acknowledgement_pending');}
  }
  return result;
}));
