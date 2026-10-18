// Authorized QA: exactly two disposable anonymous Auth accounts, no email or
// payments. Persist only a DPAPI-protected cleanup manifest outside the repo.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {randomUUID,randomBytes} from 'node:crypto';
import {createRequire} from 'node:module';
import {operator,root,privateDirectory,dpapi,project} from './supabase_operator.mjs';
import {createSupportAdmin} from '../supabase/functions/_shared/support-admin.mjs';
import {createRemoteConfig} from '../supabase/functions/_shared/remote-config.mjs';
import {publishableKey} from '../admin-console/src/public-config.js';
const require=createRequire(path.join(root,'supabase/package.json'));
const {createClient}=require('@supabase/supabase-js');
const fresh=process.argv.includes('--fresh');
const manifest=path.join(privateDirectory,fresh?'supabase-cloud-qa-fresh.dpapi':'supabase-cloud-qa.dpapi');
const accountLimit=fresh?1:2;
const nonce=()=>randomBytes(32).toString('hex');
let o,state;
function save(){fs.writeFileSync(manifest,dpapi(JSON.stringify(state)));}
async function api(token,body,name='android-api',origin){
  const response=await fetch(`https://${project}.supabase.co/functions/v1/${name}`,{method:'POST',headers:{Authorization:`Bearer ${token}`,apikey:publishableKey,'Content-Type':'application/json',...(origin?{Origin:origin}:{})},body:JSON.stringify(body)});
  const data=await response.json();return{status:response.status,...data};
}
try{
  o=await operator();
  const administrator=(await o.pool.query('select id from untouch.admin_users where enabled order by created_at limit 1')).rows[0]?.id;
  assert.ok(administrator,'verified_owner_role_required');
  const support=createSupportAdmin({db:o.pool,auth:o.auth});
  if(fs.existsSync(manifest))state=JSON.parse(dpapi(fs.readFileSync(manifest,'utf8'),true));
  else{state={tag:randomBytes(20).toString('hex'),accounts:[],completed:false};save();}
  assert.equal(state.accounts.length<=2,true);
  if(state.completed){console.log(JSON.stringify({ok:true,alreadyCompleted:true,created:2,deleted:2}));}
  else{
    while(state.accounts.length<accountLimit){
      const client=createClient(`https://${project}.supabase.co`,publishableKey,{auth:{persistSession:false,autoRefreshToken:false}});
      const {data,error}=await client.auth.signInAnonymously({options:{data:{untouch_qa_tag:state.tag}}});
      if(error)throw Error(`anonymous_${error.code??error.status}`);
      assert.equal(data.user.is_anonymous,true);
      state.accounts.push({id:data.user.id,token:data.session.access_token});save();
    }
    const [player]=state.accounts,authOnly=state.accounts[1]??{id:randomUUID()};
    if(!state.playChecked){
      const start=await api(player.token,{action:'guest',energy:999999,owner:`supabase:${authOnly.id}`});
      assert.equal(start.ok,true,JSON.stringify({status:start.status,error:start.error}));assert.equal(start.profile.id,`supabase:${player.id}`);assert.equal(start.profile.wallet.energy,50);
      const repeated=await api(player.token,{action:'guest'});assert.equal(repeated.profile.wallet.energy,50);
      const operationId=nonce();
      const duplicate=await Promise.all(Array.from({length:6},()=>api(player.token,{action:'wallet_operation',kind:'energy_hidden_tap',args:{},operationId})));
      assert.equal(duplicate.every(item=>item.ok),true,JSON.stringify(duplicate.map(item=>({status:item.status,error:item.error}))));
      assert.equal((await api(player.token,{action:'profile'})).profile.wallet.energy,70);
      const bonus=await api(player.token,{action:'wallet_operation',kind:'energy_bonus_claim',args:{},operationId:nonce()});
      assert.equal(bonus.profile.wallet.energy,100);assert.equal(bonus.profile.wallet.simpleBonus.nextAt-bonus.serverNow,28800000);
      const guard=await api(player.token,{action:'list'},'support-admin');assert.equal(guard.status,403);assert.equal(guard.error,'admin_required');
      assert.equal((await api(player.token,{action:'get'},'remote-config-admin')).status,403);
      assert.equal((await api(player.token,{action:'get'},'remote-config-admin','https://untrusted.example')).status,403);
      const credentials=JSON.parse(dpapi(fs.readFileSync(path.join(privateDirectory,'untouch-remote-config.dpapi'),'utf8'),true));
      const remote=await createRemoteConfig({credentials}).get();
      const requestId=nonce();
      const run=await api(player.token,{action:'round_start',requestId,rulesRevision:remote.snapshot.revision});assert.equal(run.ok,true);
      const cancel=await api(player.token,{action:'round_cancel',requestId});assert.equal(cancel.profile.wallet.energy,100);
      const secondCancel=await api(player.token,{action:'round_cancel',requestId});assert.equal(secondCancel.profile.wallet.energy,100);
      const scoreRequest=nonce();const scoreRun=await api(player.token,{action:'round_start',requestId:scoreRequest,rulesRevision:remote.snapshot.revision});
      assert.equal((await api(player.token,{action:'round_activate',requestId:scoreRequest})).ok,true);
      const finishCommand={action:'round_finish',roundId:scoreRun.roundId,timeMs:1,runDistance:0,riskCount:0};
      const finish=await api(player.token,finishCommand);assert.equal(finish.ok,true);
      assert.equal((await api(player.token,finishCommand)).profile.wallet.energy,99);
      assert.equal((await api(player.token,{action:'scores',period:'all'})).scores.some(row=>row.uid===player.id&&row.platform==='android'),true);
      state.playChecked=true;save();
      console.log(JSON.stringify({stage:'cloud_game',ok:true,initial:50,duplicateGrant:70,bonus:100,round:99,adminDenied:true,corsDenied:true,serializableParallelRequests:6}));
    }
    if(!state.supportChecked){
      const detail=await support(administrator,{action:'detail',userId:player.id});
      const change={action:'set_energy',userId:player.id,requestId:randomUUID(),expectedVersion:detail.user.version,energy:123,reason:'testing'};
      assert.equal((await support(administrator,change)).after,123);assert.equal((await support(administrator,change)).replayed,true);
      assert.equal((await api(player.token,{action:'profile'})).profile.wallet.energy,123);
      if(!fresh)assert.equal((await support(administrator,{action:'detail',userId:authOnly.id})).user.status,'not_started');
      state.supportChecked=true;save();console.log(JSON.stringify({stage:'cloud_support',ok:true,manualEnergy:123,idempotent:true,authOnlyListed:true}));
    }
    for(const account of state.accounts){
      if(account.deleted)continue;
      const {data,error}=await o.auth.getUserById(account.id);
      assert.ok(!error&&data.user?.is_anonymous&&data.user.user_metadata?.untouch_qa_tag===state.tag,'cleanup_scope_verification_failed');
      const detail=await support(administrator,{action:'delete_preview',userId:account.id});assert.equal(detail.deleteAllowed,true);
      account.deletion??={requestId:randomUUID(),expectedVersion:detail.user.version};save();
      await support(administrator,{action:'delete_user',userId:account.id,...account.deletion,confirmation:account.id,acceptSubscriptionNotice:true});
      assert.equal((await o.auth.getUserById(account.id)).data.user,null);
      assert.equal((await o.pool.query("select count(*)::int as n from untouch.documents where path=$1 or body->>'uid'=$2",[`players/${account.id}`,account.id])).rows[0].n,0);
      account.deleted=true;delete account.token;save();
    }
    state.completed=true;save();console.log(JSON.stringify({ok:true,created:state.accounts.length,deleted:state.accounts.length,gameDataRemaining:0,realPayments:0}));
  }
}catch(error){console.error(JSON.stringify({ok:false,error:error.code??error.message,detail:error.code==='ERR_ASSERTION'?error.message.slice(0,1200):undefined,cleanupManifestSaved:!!state,created:state?.accounts.length??0}));process.exitCode=1;}
finally{await o?.close();}
