-- Reserved for future verified Telegram integration. No Telegram data import
-- or public linking endpoint is enabled by this migration.
create table untouch.external_identities (
  provider text not null check(provider in ('telegram')),
  subject text not null check(subject ~ '^[1-9][0-9]{0,19}$'),
  uid uuid not null references auth.users(id) on delete cascade,
  username text check(length(username)<=64),
  display_name text check(length(display_name)<=200),
  updated_at timestamptz not null default now(),
  primary key(provider,subject),
  unique(provider,uid)
);
create index external_identities_uid on untouch.external_identities(uid);
alter table untouch.external_identities enable row level security;
revoke all on untouch.external_identities from public,anon,authenticated;
grant select,insert,update,delete on untouch.external_identities to untouch_runtime;
create policy runtime_external_identities on untouch.external_identities to untouch_runtime using(true) with check(true);
