import {privateCli} from './supabase_private_cli.mjs';
import {runtimeSecrets,project} from './supabase_operator.mjs';
try{
  const {reconcile}=runtimeSecrets();
  const endpoint=`https://${project}.supabase.co/functions/v1/play-reconcile`;
  const unauthorized=await fetch(endpoint,{method:'POST'});
  if(unauthorized.status!==401)throw Error('cron_authentication_check_failed');
  const check=await fetch(endpoint,{method:'POST',headers:{Authorization:`Bearer ${reconcile}`}});
  const result=await check.json();if(!check.ok||!result.ok)throw Error('cron_worker_check_failed');
  // Generated base64url secret is the only interpolation. It is transmitted
  // through the official CLI's private named pipe, never an argv or SQL file.
  if(!/^[A-Za-z0-9_-]{64}$/.test(reconcile))throw Error('cron_secret_invalid');
  await privateCli(['db','query','--file'],`do $$ declare existing uuid; begin select id into existing from vault.secrets where name='untouch_play_reconcile';if existing is null then perform vault.create_secret('${reconcile}','untouch_play_reconcile');else perform vault.update_secret(existing,'${reconcile}');end if;end $$;`);
  const schedule=await privateCli(['db','query','--file'],"select cron.schedule('untouch-play-reconcile','* * * * *','select untouch.enqueue_play_reconcile();') as job_id;");
  if(!schedule.includes('job_id'))throw Error('cron_schedule_unconfirmed');
  console.log(JSON.stringify({ok:true,unauthorizedStatus:401,worker:result,schedule:'every minute',secretInVault:true}));
}catch(error){console.error(JSON.stringify({ok:false,error:error.message,diagnostic:error.diagnostic}));process.exitCode=1;}
