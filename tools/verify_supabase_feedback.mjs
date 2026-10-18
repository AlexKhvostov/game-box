// Explicitly authorized on16Oct: one new disposable QA and exact-scope cleanup.
// No Play purchase, personal profile, email or externally delivered message.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {operator,root,project,privateDirectory,dpapi} from './supabase_operator.mjs';
import {createSupportAdmin} from '../supabase/functions/_shared/support-admin.mjs';
import {publishableKey} from '../admin-console/src/public-config.js';
const {createClient}=createRequire(path.join(root,'supabase/package.json'))('@supabase/supabase-js');
const manifest=path.join(privateDirectory,'supabase-feedback-qa.dpapi');
const nonce=()=>randomBytes(32).toString('hex');
let state,o,result={ok:false};
const save=()=>fs.writeFileSync(manifest,dpapi(JSON.stringify(state)));
async function api(body){
  const response=await fetch(`https://${project}.supabase.co/functions/v1/android-api`,{method:'POST',headers:{Authorization:`Bearer ${state.token}`,apikey:publishableKey,'Content-Type':'application/json'},body:JSON.stringify(body)});
  return{status:response.status,...await response.json()};
}
async function call(body){const value=await api(body);assert.equal(value.ok,true,JSON.stringify({status:value.status,error:value.error}));return value;}
const op=(kind,args={},operationId=nonce())=>({action:'wallet_operation',kind,args,operationId});
try{
  o=await operator();
  state=fs.existsSync(manifest)?JSON.parse(dpapi(fs.readFileSync(manifest,'utf8'),true)):{tag:randomBytes(24).toString('hex')};
  if(state.completed){console.log(JSON.stringify({ok:true,alreadyCompleted:true,created:1,deleted:1}));process.exitCode=0;}
  else{
    if(!state.id){
      const client=createClient(`https://${project}.supabase.co`,publishableKey,{auth:{persistSession:false,autoRefreshToken:false}});
      const {data,error}=await client.auth.signInAnonymously({options:{data:{untouch_qa_tag:state.tag}}});
      if(error)throw Error('QA anonymous sign-in failed');
      state.id=data.user.id;state.token=data.session.access_token;save();
    }
    const initial=await call({action:'guest'}),wallet=initial.profile.wallet;
    assert.equal(wallet.feedbackSpentEnergy,0);assert.equal(wallet.energyConfig.rewards.feedback,50);
    const revision=initial.profile.wallet.energyConfig.revision;
    const policy=(await o.pool.query('select snapshot from untouch.policy_revisions order by observed_at desc limit 1')).rows[0].snapshot;
    const rulesRevision=policy.revision;
    assert.equal((await api(op('energy_feedback',{comment:'QA: the game controls could be clearer.',feedbackSpentEnergy:999}))).error,'feedback_locked');
    for(let i=0;i<5;i++)await call(op('energy_hidden_tap'));
    const canceled=nonce();await call({action:'round_start',requestId:canceled,rulesRevision,helmet:true,jump:true,revision});await call({action:'round_cancel',requestId:canceled});
    for(let i=0;i<34;i++){
      const boosts=i<33,requestId=nonce();
      const start=await call({action:'round_start',requestId,rulesRevision,helmet:boosts,jump:boosts,revision});
      await call({action:'round_activate',requestId});
      if(i===0)await call({action:'round_activate',requestId});
      await call({action:'round_finish',roundId:start.roundId,timeMs:1,runDistance:0,riskCount:0,hadHelmet:boosts,hadJump:boosts});
      if(i===32){
        assert.equal((await call({action:'profile'})).profile.wallet.feedbackSpentEnergy,99);
        assert.equal((await api(op('energy_feedback',{comment:'QA: the game controls could be clearer.'}))).error,'feedback_locked');
      }
    }
    const before=(await call({action:'profile'})).profile.wallet;
    assert.equal(before.feedbackSpentEnergy,100);assert.equal(before.energy,50);
    const command=op('energy_feedback',{comment:'QA: controls could be clearer; this is an automated test, not user feedback.',rating:1});
    await Promise.all([call(command),call(command)]);
    await call(op('energy_feedback',{comment:'QA duplicate request must never grant another reward.'}));
    const after=(await call({action:'profile'})).profile.wallet;assert.equal(after.energy,100);
    const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0].id;
    const support=createSupportAdmin({db:o.pool,auth:o.auth});
    const detail=await support(actor,{action:'detail',userId:state.id});assert.equal(detail.feedback.length,1);assert.equal(detail.feedback[0].rating,1);
    result={ok:true,created:1,threshold:100,rejectedAt99:true,negativeRatingReward:50,feedbackRecords:1,canceledStartExcluded:true,activationReplayCountedOnce:true,duplicateReward:0,adminCanReadFeedback:true};
  }
}catch(error){result={ok:false,error:error.code??error.message};process.exitCode=1;}
finally{
  if(state?.id&&!state.completed&&o){
    try{
      const {data,error}=await o.auth.getUserById(state.id);
      assert.ok(!error&&data.user?.is_anonymous&&data.user.user_metadata?.untouch_qa_tag===state.tag,'Cleanup scope mismatch');
      const actor=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0].id;
      const support=createSupportAdmin({db:o.pool,auth:o.auth});
      const detail=await support(actor,{action:'delete_preview',userId:state.id});
      await support(actor,{action:'delete_user',userId:state.id,expectedVersion:detail.user.version,requestId:randomUUID(),confirmation:state.id,acceptSubscriptionNotice:true});
      assert.equal((await o.auth.getUserById(state.id)).data.user,null);
      const remaining=(await o.pool.query("select count(*)::integer as n from untouch.documents where path=$1 or body->>'uid'=$2",[`players/${state.id}`,state.id])).rows[0].n;
      assert.equal(remaining,0);state.completed=true;delete state.token;save();result.deleted=1;result.remainingQaDocuments=0;
    }catch(error){result.cleanupError=error.code??error.message;result.ok=false;process.exitCode=1;}
  }
  await o?.close();
  fs.mkdirSync(path.join(root,'docs/release-evidence/play-sandbox-feedback-20261016'),{recursive:true});
  fs.writeFileSync(path.join(root,'docs/release-evidence/play-sandbox-feedback-20261016/cloud-feedback.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
}
