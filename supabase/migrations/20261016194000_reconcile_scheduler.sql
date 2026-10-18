create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
-- Scheduling is activated by the local operator only after the Edge worker
-- passes authentication/empty-batch acceptance. The credential is in Vault.
create function untouch.enqueue_play_reconcile() returns bigint
language sql security definer set search_path=''
as $$
  select net.http_post(
    url:='https://exinizzxqtjnysgibide.supabase.co/functions/v1/play-reconcile',
    headers:=jsonb_build_object('Content-Type','application/json',
      'Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='untouch_play_reconcile')),
    body:='{}'::jsonb,timeout_milliseconds:=60000
  );
$$;
revoke all on function untouch.enqueue_play_reconcile() from public,anon,authenticated,untouch_runtime;
