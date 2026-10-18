-- Private support ledger. Admin actions are authorized by the Edge Function;
-- the browser receives no direct SQL/table privileges.
create table untouch.support_actions (
  id uuid primary key,
  actor uuid not null,
  target uuid not null,
  kind text not null check(kind in ('set_energy','delete_user')),
  fingerprint text not null,
  status text not null check(status in ('pending','completed')),
  details jsonb not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
alter table untouch.support_actions enable row level security;
revoke all on untouch.support_actions from public,anon,authenticated;
grant select,insert,update on untouch.support_actions to untouch_runtime;
create policy runtime_support on untouch.support_actions to untouch_runtime using(true) with check(true);
create index support_actions_target on untouch.support_actions(target,created_at desc);
create index players_updated on untouch.documents(updated_at desc,key) where parent='players';

-- A narrow private lookup avoids granting the runtime access to auth.users.
-- The function is unreachable to browser roles and exposes UUIDs only.
create function untouch.find_auth_users_by_email(user_email text)
returns table(id uuid) language sql stable security definer set search_path=''
as $$ select u.id from auth.users u where length(user_email) between 3 and 160
  and lower(u.email)=lower(user_email) limit 10 $$;
revoke all on function untouch.find_auth_users_by_email(text) from public,anon,authenticated;
grant execute on function untouch.find_auth_users_by_email(text) to untouch_runtime;
