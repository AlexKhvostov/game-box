-- Independent verified Telegram identities. No import from legacy Telegram/MySQL.
-- Auth users remain the Google/administrator directory; Telegram has no fake email.
alter table untouch.external_identities drop constraint external_identities_uid_fkey;
alter table untouch.external_identities add column bot_id text check(bot_id ~ '^[0-9]{5,15}$');

create table untouch.config_scoped_drafts (
  actor uuid not null references auth.users(id) on delete cascade,
  scope text not null check(scope in ('common','android','telegram')),
  base_etag text not null,patches jsonb not null,updated_at timestamptz not null default now(),
  primary key(actor,scope)
);
alter table untouch.config_scoped_drafts enable row level security;
revoke all on untouch.config_scoped_drafts from public,anon,authenticated;
grant select,insert,update,delete on untouch.config_scoped_drafts to untouch_runtime;
create policy runtime_scoped_drafts on untouch.config_scoped_drafts to untouch_runtime using(true) with check(true);

-- Expand derived counts and invalidation to both game platforms. Existing source
-- migrations remain immutable, and Android-only profiles/scores remain intact.
lock table untouch.documents in share row exclusive mode;
create or replace function untouch.track_attempt_counts() returns trigger language plpgsql set search_path='' as $$
begin
  if TG_OP='UPDATE' and old.parent is not distinct from new.parent
    and (old.body->>'platform',old.body->>'uid',old.body->>'timeMs') is not distinct from
        (new.body->>'platform',new.body->>'uid',new.body->>'timeMs') then return new; end if;
  if TG_OP<>'INSERT' and old.parent='scores' and old.body->>'platform' in ('android','telegram') then
    perform untouch.adjust_attempt_count(old.body->>'uid',(old.body->>'timeMs')::numeric,-1);
  end if;
  if TG_OP<>'DELETE' and new.parent='scores' and new.body->>'platform' in ('android','telegram') then
    perform untouch.adjust_attempt_count(new.body->>'uid',(new.body->>'timeMs')::numeric,1);
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;
do $$ declare score record; begin
  for score in select body from untouch.documents where parent='scores' and body->>'platform'='telegram' loop
    perform untouch.adjust_attempt_count(score.body->>'uid',(score.body->>'timeMs')::numeric,1);
  end loop;
end $$;

create or replace function untouch.track_average_revision() returns trigger language plpgsql set search_path='' as $$
declare old_uid text; new_uid text; owner_uid text;
begin
  if TG_OP='UPDATE' and (old.parent,old.key) is not distinct from (new.parent,new.key)
    and (old.body->>'platform',old.body->>'uid',old.body->>'timeMs',old.body->>'attemptAt',old.body->>'createdAt')
      is not distinct from
        (new.body->>'platform',new.body->>'uid',new.body->>'timeMs',new.body->>'attemptAt',new.body->>'createdAt') then return new; end if;
  if TG_OP<>'INSERT' and old.parent='scores' and old.body->>'platform' in ('android','telegram') then old_uid:=old.body->>'uid'; end if;
  if TG_OP<>'DELETE' and new.parent='scores' and new.body->>'platform' in ('android','telegram') then new_uid:=new.body->>'uid'; end if;
  for owner_uid in select distinct v.uid from (values(old_uid),(new_uid)) v(uid) where v.uid is not null order by v.uid loop
    insert into untouch.average_score_revisions(uid,revision) values(owner_uid,1)
    on conflict(uid) do update set revision=untouch.average_score_revisions.revision+1;
  end loop;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;
-- Force recalculation against the expanded score set without removing history.
update untouch.average_rank_cache set rules_key='pre-platform:'||rules_key;
create index scores_platform_record on untouch.documents
 ((body->>'uid'),((body->>'timeMs')::bigint) desc,((body->>'createdAt')::bigint) desc,key desc)
 where parent='scores' and body->>'platform' in ('android','telegram');
create index scores_platform_history on untouch.documents
 ((body->>'uid'),(coalesce((body->>'attemptAt')::bigint,(body->>'createdAt')::bigint)) desc,key desc)
 where parent='scores' and body->>'platform' in ('android','telegram');

-- Platform filter applies BEFORE pagination. Private runtime only.
-- Private directory: filter and sort BEFORE pagination, without per-row Auth HTTP calls.
create function untouch.support_directory_v3(options jsonb)
returns jsonb language sql stable security definer set search_path='' as $$
with ids as (
 select id::text as id from auth.users union select key from untouch.documents where parent='players' union select uid::text from untouch.external_identities where provider='telegram' and bot_id is not null
), directory as (
 select d.id,p.body,u.created_at,
 g.identity_data as google,coalesce(p.body->>'platform',case when e.uid is not null then 'telegram' else 'android' end) as platform,e.username as telegram_username,
 case when p.body->>'supportDisabled'='true' then 'deleting' when p.body is null then 'not_started' when u.id is null and e.uid is null then 'auth_missing' else 'active' end as status,
 coalesce(p.body->>'nickname',g.identity_data->>'full_name','Аккаунт без игрового профиля') as nickname,
 coalesce((p.body->'wallet'->>'energy')::numeric,0) as energy,
 coalesce((p.body->>'completedGames')::bigint,0) as games,
 coalesce((p.body->>'lastActiveAt')::bigint,(p.body->>'createdAt')::bigint,0) as activity,
 case when p.body->'wallet'->'energySubscription' is null or p.body->'wallet'->'energySubscription'='null'::jsonb then 'none'
 when (p.body->'wallet'->'energySubscription'->>'expiresAt')::numeric > (options->>'now')::numeric then 'active'
 when coalesce(p.body->'wallet'->'energySubscription'->>'endConfirmed','false')<>'true' then 'pending' else 'expired' end as subscription
 from ids d left join auth.users u on u.id::text=d.id
 left join untouch.documents p on p.path='players/'||d.id left join untouch.external_identities e on e.uid::text=d.id and e.provider='telegram' and e.bot_id is not null
 left join lateral (select coalesce(i.identity_data,'{}'::jsonb) as identity_data from auth.identities i where i.user_id=u.id and i.provider='google' limit 1) g on true
), filtered as (
 select * from directory where
 (coalesce(options->>'search','')='' or id=options->>'search' or lower(google->>'email')=lower(options->>'search') or lower(telegram_username)=lower(options->>'search') or position(lower(options->>'search') in lower(nickname))>0)
 and (coalesce(options->>'platform','all')='all' or platform=options->>'platform')
 and (options->>'connection'='all' or (options->>'connection'='google' and google is not null) or (options->>'connection'='guest' and google is null and platform='android') or (options->>'connection'='telegram' and platform='telegram'))
 and (options->>'status'='all' or status=options->>'status')
 and (options->>'subscription'='all' or subscription=options->>'subscription' or (options->>'subscription'='without' and subscription in ('none','expired')))
), page as (
 select * from filtered order by
 case when options->>'sort'='nickname' and options->>'direction'='asc' then lower(nickname) end asc,
 case when options->>'sort'='nickname' and options->>'direction'='desc' then lower(nickname) end desc,
 case when options->>'direction'='asc' then case options->>'sort' when 'energy' then energy when 'games' then games when 'activity' then activity end end asc,
 case when options->>'direction'='desc' then case options->>'sort' when 'energy' then energy when 'games' then games when 'activity' then activity end end desc,
 case when options->>'sort'='created' and options->>'direction'='asc' then created_at end asc nulls last,
 case when options->>'sort'='created' and options->>'direction'='desc' then created_at end desc nulls last,
 id asc limit 26 offset (options->>'offset')::integer
)
select jsonb_build_object('total',(select count(*) from filtered),'rows',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'::jsonb))
$$;
revoke all on function untouch.support_directory_v3(jsonb) from public,anon,authenticated;
grant execute on function untouch.support_directory_v3(jsonb) to untouch_runtime;
