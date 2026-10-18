// Read-only Google Play proof. Never print receipt tokens or service keys.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {operator,root,privateDirectory} from './supabase_operator.mjs';
const {GoogleAuth}=createRequire(path.join(root,'supabase/package.json'))('google-auth-library');
let o;
try{
  o=await operator();
  const owner='dcf26f4e-0c23-4c10-9ac7-45b21c2294dc';
  const credentials=JSON.parse(fs.readFileSync(path.join(privateDirectory,'untouch-play-verifier-game-box-b30d4.json'),'utf8'));
  const client=await new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/androidpublisher']}).getClient();
  const records=(await o.pool.query("select body from untouch.documents where parent='purchases' and body->>'uid'=$1",[owner])).rows;
  const checks=[];
  for(const {body:r}of records){
    const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/purchases/';
    const subscription=r.kind==='energy_subscription';
    const url=subscription?`${base}subscriptionsv2/tokens/${encodeURIComponent(r.token)}`:`${base}products/${encodeURIComponent(r.productId)}/tokens/${encodeURIComponent(r.token)}`;
    const {data}=await client.request({url,method:'GET'});
    checks.push(subscription?{sku:r.productId,test:!!data.testPurchase,state:data.subscriptionState,acknowledgement:data.acknowledgementState,
      expiry:data.lineItems?.find(l=>l.productId===r.productId)?.expiryTime,
      autoRenewing:data.lineItems?.find(l=>l.productId===r.productId)?.autoRenewingPlan?.autoRenewEnabled,
      serverAcknowledged:r.acknowledged===true}:
      {sku:r.productId,test:data.purchaseType===0,purchaseState:data.purchaseState,consumed:data.consumptionState===1,acknowledgementState:data.acknowledgementState,serverAcknowledged:r.acknowledged===true});
  }
  const result={checkedAt:new Date().toISOString(),readOnly:true,checks};
  const directory=path.join(root,'docs/release-evidence/play-sandbox-feedback-20261016');fs.mkdirSync(directory,{recursive:true});
  const name=process.argv[2]??'play-status';if(!/^[a-z0-9-]+$/.test(name))throw Error('Invalid evidence name');
  fs.writeFileSync(path.join(directory,name+'.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??'play_status_failed',status:error.response?.status}));process.exitCode=1;}
finally{await o?.close();}
