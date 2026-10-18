import {database,credentials,authAdmin,identity} from './runtime.mjs';
import {PostgresStore} from './postgres-store.mjs';
import {createEngine} from './core/engine.mjs';
import {createPlayVerifier} from './core/play.mjs';
import {hash,requireThat} from './core/policy.mjs';
import {createRemoteConfig} from './remote-config.mjs';
import {createPolicyLoader} from './policy-loader.mjs';
let runtime;
export function gameRuntime(){
  if(runtime)return runtime;
  const pool=database(),db=new PostgresStore(pool),remote=createRemoteConfig({credentials:credentials('FIREBASE_SERVICE_ACCOUNT_JSON')});
  const play=createPlayVerifier({credentials:credentials('PLAY_SERVICE_ACCOUNT_JSON')});
  const engine=createEngine({db,getPolicy:createPolicyLoader({pool,remote}),verifyPlay:(uid,sku,token)=>{requireThat(credentials('PLAY_SERVICE_ACCOUNT_JSON'),'play_verification_unavailable',503);return play.verify(uid,sku,token);},
  googleLinkedForUid:async uid=>{
    const {data,error}=await authAdmin().auth.admin.getUserById(uid);requireThat(!error&&data.user,'auth_lookup_unavailable',503);return identity(data.user).googleLinked;
  }});
  async function acknowledge(receipt){
    if(!receipt?.token||receipt.acknowledged||receipt.revoked||receipt.supersededBy)return;
    try{await play.acknowledge(receipt.productId,receipt.token);await db.collection('purchases').doc(hash(receipt.token)).update({acknowledged:true});}
    catch(error){if(error.code==='purchase_canceled')await engine.revokePurchase(receipt.uid,receipt.token);else throw error;}
  }
  return runtime={engine,db,pool,play,acknowledge};
}
