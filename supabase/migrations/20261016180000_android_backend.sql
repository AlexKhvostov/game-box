-- New Android-only data. No imports and no access to legacy Telegram/MySQL.
create schema if not exists untouch;
revoke all on schema untouch from public, anon, authenticated;

create table if not exists untouch.documents (
  path text primary key check (length(path) between 3 and 768),
  parent text not null,
  key text not null check (length(key) between 1 and 128),
  body jsonb not null check (jsonb_typeof(body) = 'object'),
  updated_at timestamptz not null default now(),
  unique(parent,key)
);
alter table untouch.documents enable row level security;
create index if not exists documents_parent on untouch.documents(parent,key);
create index if not exists scores_ranking on untouch.documents
  ((body->'timeMs') desc, (body->'createdAt') desc, key desc) where parent='scores';
create index if not exists invitations_owner on untouch.documents
  ((body->'inviterUid'), (body->'boundAt') desc, key desc) where parent='invitations';
create index if not exists invitations_pending on untouch.documents
  ((body->'inviterUid'), (body->'rewardedAt'), key) where parent='invitations';
create index if not exists purchases_owner on untouch.documents
  ((body->'uid'), (body->'kind')) where parent='purchases';

create table if not exists untouch.admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists untouch.config_drafts (
  actor uuid primary key references auth.users(id) on delete cascade,
  base_etag text not null,
  patches jsonb not null,
  updated_at timestamptz not null default now()
);
create table if not exists untouch.config_audit (
  id uuid primary key,
  actor uuid not null,
  status text not null check(status in ('pending','published','failed')),
  base_etag text not null,
  base_version text,
  published_version text,
  before_snapshot jsonb not null,
  after_snapshot jsonb not null,
  changes jsonb not null,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create table if not exists untouch.policy_revisions (
  revision text primary key,
  snapshot jsonb not null,
  observed_at timestamptz not null default now()
);
alter table untouch.admin_users enable row level security;
alter table untouch.config_drafts enable row level security;
alter table untouch.config_audit enable row level security;
alter table untouch.policy_revisions enable row level security;
revoke all on all tables in schema untouch from public, anon, authenticated;

-- NOLOGIN until deployment sets a generated password outside source/output.
-- The runtime role cannot grant itself admin or edit audit actors/permissions.
do $$ begin
  if not exists (select from pg_roles where rolname='untouch_runtime') then
    create role untouch_runtime nologin;
  end if;
end $$;
grant usage on schema untouch to untouch_runtime;
grant select,insert,update,delete on untouch.documents,untouch.config_drafts to untouch_runtime;
grant select on untouch.admin_users to untouch_runtime;
grant select,insert,update on untouch.config_audit to untouch_runtime;
grant select,insert on untouch.policy_revisions to untouch_runtime;
-- RLS is still enforced for this restricted direct SQL login.
create policy runtime_documents on untouch.documents to untouch_runtime using(true) with check(true);
create policy runtime_admin_read on untouch.admin_users for select to untouch_runtime using(true);
create policy runtime_drafts on untouch.config_drafts to untouch_runtime using(true) with check(true);
create policy runtime_audit on untouch.config_audit to untouch_runtime using(true) with check(true);
create policy runtime_policy_read on untouch.policy_revisions for select to untouch_runtime using(true);
create policy runtime_policy_insert on untouch.policy_revisions for insert to untouch_runtime with check(true);

-- Convenience views stay in the private schema, never in PostgREST's public API.
create view untouch.players as select key as id,body from untouch.documents where parent='players';
create view untouch.scores as select key as id,body from untouch.documents where parent='scores';
create view untouch.purchases as select key as id,body from untouch.documents where parent='purchases';
revoke all on untouch.players,untouch.scores,untouch.purchases from public,anon,authenticated;
