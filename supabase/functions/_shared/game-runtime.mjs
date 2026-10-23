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
  const loadPolicy=createPolicyLoader({pool,remote});
  const engine=createEngine({db,getPolicy:loadPolicy,identityForUid:getIdentity,verifyPlay:(uid,sku,token)=>{requireThat(credentials('PLAY_SERVICE_ACCOUNT_JSON'),'play_verification_unavailable',503);return play.verify(uid,sku,token);},
  googleLinkedForUid:async uid=>{
    const {data,error}=await authAdmin().auth.admin.getUserById(uid);requireThat(!error&&data.user,'auth_lookup_unavailable',503);return identity(data.user).googleLinked;
  }});
  async function getIdentity(uid){
    const player=(await db.collection('players').doc(uid).get()).data();
    if(player?.platform==='telegram'){
      const mapped=await pool.query("select username from untouch.external_identities where provider='telegram' and uid=$1::uuid and bot_id is not null",[uid]);
      return mapped.rows.length?{platform:'telegram',telegramVerified:true,googleLinked:false,username:mapped.rows[0].username}:null;
    }
    const {data,error}=await authAdmin().auth.admin.getUserById(uid);
    if(error?.status===404)return null;requireThat(!error&&data.user,'auth_lookup_unavailable',503);return identity(data.user);
  }
  async function acknowledge(receipt){
    if(!receipt?.token||receipt.acknowledged||receipt.revoked||receipt.supersededBy)return;
    try{await play.acknowledge(receipt.productId,receipt.token);await db.collection('purchases').doc(hash(receipt.token)).update({acknowledged:true});}
    catch(error){if(error.code==='purchase_canceled')await engine.revokePurchase(receipt.uid,receipt.token);else throw error;}
  }
  return runtime={engine,db,pool,play,acknowledge,getIdentity,platformSettings:loadPolicy.platformSettings};
}
