// Refund ONLY the known100-energy sandbox order from this acceptance run.
// Re-check Google purchaseType=0 before any mutation. No real order allowed.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {operator,root,privateDirectory} from './supabase_operator.mjs';
const {GoogleAuth}=createRequire(path.join(root,'supabase/package.json'))('google-auth-library');
let o;
try{
  o=await operator();
  const marker=path.join(privateDirectory,'untouch-play-sandbox-refund-20261016.json');
  if(fs.existsSync(marker))throw Error('Refund previously requested; inspect status instead of repeating');
  const rows=(await o.pool.query("select body from untouch.documents where parent='purchases' and body->>'uid'=$1 and body->>'productId'='energy_100_v1'",['dcf26f4e-0c23-4c10-9ac7-45b21c2294dc'])).rows;
  if(rows.length!==1)throw Error('Expected one exact sandbox receipt');
  const r=rows[0].body;
  if(r.revoked)throw Error('Receipt already revoked');
  const credentials=JSON.parse(fs.readFileSync(path.join(privateDirectory,'untouch-play-verifier-game-box-b30d4.json'),'utf8'));
  const client=await new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/androidpublisher']}).getClient();
  const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch';
  const {data}=await client.request({url:`${base}/purchases/products/energy_100_v1/tokens/${encodeURIComponent(r.token)}`,method:'GET'});
  if(data.purchaseType!==0||data.purchaseState!==0||data.orderId!==r.orderId)throw Error('Not the confirmed sandbox order');
  fs.writeFileSync(marker,JSON.stringify({requestedAt:new Date().toISOString(),sku:'energy_100_v1',testPurchaseVerified:true}),{flag:'wx'});
  await client.request({url:`${base}/orders/${encodeURIComponent(r.orderId)}:refund?revoke=true`,method:'POST'});
  const result={ok:true,accepted:true,sku:'energy_100_v1',testOnly:true,realCharge:0,checkedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(root,'docs/release-evidence/play-sandbox-feedback-20261016/test-refund-request.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}catch(error){console.error(JSON.stringify({ok:false,error:error.response? 'play_refund_rejected':error.message,status:error.response?.status}));process.exitCode=1;}
finally{await o?.close();}
