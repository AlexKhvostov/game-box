import {GoogleAuth} from 'google-auth-library';
import {env,credentials,authAdmin,identity} from '../_shared/runtime.mjs';
import {gameRuntime} from '../_shared/game-runtime.mjs';
import {createReconciler,reconcileAuthorized} from '../_shared/play-reconcile.mjs';
import {createInviteReconciler} from '../_shared/invite-reconcile.mjs';
let worker,inviteWorker;
Deno.serve(async request=>{
  const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
  if(request.method!=='POST')return new Response(JSON.stringify({ok:false,error:'method_invalid'}),{status:405,headers});
  if(!reconcileAuthorized(request.headers.get('authorization'),env('PLAY_RECONCILE_SECRET')))return new Response(JSON.stringify({ok:false,error:'unauthorized'}),{status:401,headers});
  try{
    if(!worker){
      const runtime=gameRuntime(),google=new GoogleAuth({credentials:credentials('PLAY_SERVICE_ACCOUNT_JSON'),scopes:['https://www.googleapis.com/auth/androidpublisher']});
      worker=createReconciler({...runtime,getIdentity:async uid=>{
        const {data,error}=await authAdmin().auth.admin.getUserById(uid);
        if(error?.status===404)return null;if(error||!data.user)throw Error('auth_lookup_unavailable');return identity(data.user);
      },listVoided:async({startTime,endTime,token})=>(await google.request({url:'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/purchases/voidedpurchases',method:'GET',timeout:10000,params:{type:1,maxResults:100,startTime:String(startTime),endTime:String(endTime),...(token?{token}:{})}})).data});
      inviteWorker=createInviteReconciler({...runtime,getIdentity:runtime.getIdentity});
    }
    // Independent leases; the invite budget does not extend the Play deadline.
    const [result,invites]=await Promise.all([worker(),inviteWorker()]);
    result.invites=invites;
    return new Response(JSON.stringify(result),{headers});
  }catch{console.error('play_reconcile_failed');return new Response(JSON.stringify({ok:false,error:'reconcile_unavailable'}),{status:503,headers});}
});
