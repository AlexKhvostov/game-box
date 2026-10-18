// Read-only final acceptance: no receipt tokens or personal fields in evidence.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {operator,root,privateDirectory,dpapi} from './supabase_operator.mjs';
let o;
try {
  o=await operator();
  const owner='dcf26f4e-0c23-4c10-9ac7-45b21c2294dc';
  const player=(await o.pool.query("select body from untouch.documents where parent='players' and key=$1",[owner])).rows[0].body;
  const receipts=(await o.pool.query("select body from untouch.documents where parent='purchases' and body->>'uid'=$1",[owner])).rows.map(r=>r.body);
  const find=sku=>receipts.filter(r=>r.productId===sku);
  assert.equal(player.wallet.energy,869);
  assert.equal(player.wallet.energySubscription,null);
  for(const sku of ['energy_100_v1','energy_500_v1','energy_batteries_2_v1','energy_batteries_5_v1']) assert.equal(find(sku).length,1);
  assert.equal(find('energy_100_v1')[0].revoked,true);
  assert.equal(find('energy_500_v1')[0].consumed,true);
  assert.equal(find('energy_500_v1')[0].acknowledged,true);
  assert.equal(find('energy_250_v1').length,0);
  for(const sku of ['energy_batteries_2_v1','energy_batteries_5_v1']) assert.equal(find(sku)[0].endConfirmed,true);
  const state=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'supabase-feedback-qa.dpapi'),'utf8'),true));
  assert.equal(state.completed,true);
  assert.equal((await o.auth.getUserById(state.id)).data.user,null);
  const remaining=(await o.pool.query("select count(*)::integer as n from untouch.documents where path=$1 or body->>'uid'=$2",[`players/${state.id}`,state.id])).rows[0].n;
  assert.equal(remaining,0);
  const result={ok:true,checkedAt:new Date().toISOString(),readOnly:true,energy:player.wallet.energy,feedbackSpentEnergy:player.wallet.feedbackSpentEnergy,activeSubscription:null,
    approved100Receipts:1,refunded100Revoked:true,declined250Receipts:0,pending500Receipts:1,pending500Consumed:true,
    subscription2EndConfirmed:true,subscription5EndConfirmed:true,qaAuthDeleted:true,remainingQaDocuments:remaining};
  fs.writeFileSync(path.join(root,'docs/release-evidence/play-sandbox-feedback-20261016/final-cloud-state.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message}));process.exitCode=1;}
finally{await o?.close();}
