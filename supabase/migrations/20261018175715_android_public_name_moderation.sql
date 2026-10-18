-- Private moderation uses the existing administrator ledger and document store.
-- No browser table grants, new public endpoints or wallet privileges are added.
alter table untouch.support_actions drop constraint support_actions_kind_check;
alter table untouch.support_actions add constraint support_actions_kind_check
  check(kind in ('set_energy','delete_user','public_name_moderation'));

create index public_reports_queue on untouch.documents((body->>'status'),((body->>'createdAt')::bigint),key)
  where parent='publicReports';

create or replace function untouch.cleanup_privacy_logs()
returns jsonb language plpgsql security invoker set search_path='' as $$
declare support_count integer; auth_count integer; report_count integer;
begin
  delete from untouch.support_actions
    where status='completed' and completed_at < now()-interval '90 days';
  get diagnostics support_count = row_count;
  delete from auth.audit_log_entries where created_at < now()-interval '30 days';
  get diagnostics auth_count = row_count;
  delete from untouch.documents where parent='publicReports'
    and (body->>'createdAt')::bigint < (extract(epoch from (now()-interval '90 days'))*1000)::bigint;
  get diagnostics report_count = row_count;
  return jsonb_build_object('supportActions',support_count,'authAudit',auth_count,'publicReports',report_count);
end $$;
revoke all on function untouch.cleanup_privacy_logs() from public,anon,authenticated,untouch_runtime;
