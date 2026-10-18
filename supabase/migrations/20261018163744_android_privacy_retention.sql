-- Private housekeeping. No player, progress, receipt or pending support row
-- is removed. The caller's privileges apply; browser/runtime roles cannot run it.
create function untouch.cleanup_privacy_logs()
returns jsonb language plpgsql security invoker set search_path='' as $$
declare support_count integer; auth_count integer;
begin
  delete from untouch.support_actions
    where status='completed' and completed_at < now()-interval '90 days';
  get diagnostics support_count = row_count;
  delete from auth.audit_log_entries where created_at < now()-interval '30 days';
  get diagnostics auth_count = row_count;
  return jsonb_build_object('supportActions',support_count,'authAudit',auth_count);
end $$;
revoke all on function untouch.cleanup_privacy_logs() from public,anon,authenticated,untouch_runtime;
create index support_actions_retention on untouch.support_actions(completed_at)
  where status='completed';
