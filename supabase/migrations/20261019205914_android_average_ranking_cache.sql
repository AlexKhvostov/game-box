-- Derived, private values only. Existing attempts/profiles/config stay intact.
-- No backfill or extra average calculation in the round-finish transaction.
lock table untouch.documents in share row exclusive mode;
create table untouch.average_score_revisions (
  uid text primary key,
  revision bigint not null check(revision > 0)
);
create table untouch.average_rank_cache (
  uid text primary key,
  owner_path text not null references untouch.documents(path) on delete cascade,
  rules_key text not null,
  score_revision bigint not null check(score_revision >= 0),
  average_ms numeric,
  used_count integer not null check(used_count >= 0),
  eligible_count integer not null check(eligible_count >= 0),
  total_count integer not null check(total_count >= 0),
  last_at bigint,
  updated_at timestamptz not null default clock_timestamp()
);
create index average_rank_cache_owner on untouch.average_rank_cache(owner_path);
alter table untouch.average_score_revisions enable row level security;
alter table untouch.average_rank_cache enable row level security;
revoke all on untouch.average_score_revisions,untouch.average_rank_cache from public,anon,authenticated;
grant select,insert,update on untouch.average_score_revisions,untouch.average_rank_cache to untouch_runtime;
create policy runtime_average_revisions on untouch.average_score_revisions to untouch_runtime using(true) with check(true);
create policy runtime_average_cache on untouch.average_rank_cache to untouch_runtime using(true) with check(true);

create function untouch.track_average_revision() returns trigger language plpgsql set search_path='' as $$
declare old_uid text; new_uid text; owner_uid text;
begin
  if TG_OP='UPDATE' and (old.parent,old.key) is not distinct from (new.parent,new.key)
    and (old.body->>'platform',old.body->>'uid',old.body->>'timeMs',old.body->>'attemptAt',old.body->>'createdAt')
      is not distinct from
        (new.body->>'platform',new.body->>'uid',new.body->>'timeMs',new.body->>'attemptAt',new.body->>'createdAt')
    then return new; end if;
  if TG_OP<>'INSERT' and old.parent='scores' and old.body->>'platform'='android' then old_uid:=old.body->>'uid'; end if;
  if TG_OP<>'DELETE' and new.parent='scores' and new.body->>'platform'='android' then new_uid:=new.body->>'uid'; end if;
  -- Stable owner order avoids opposite lock ordering if ownership is corrected.
  for owner_uid in select distinct v.uid from (values(old_uid),(new_uid)) v(uid) where v.uid is not null order by v.uid loop
    insert into untouch.average_score_revisions(uid,revision) values(owner_uid,1)
    on conflict(uid) do update set revision=untouch.average_score_revisions.revision+1;
  end loop;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;
create trigger documents_average_revision after insert or update or delete on untouch.documents
for each row execute function untouch.track_average_revision();
revoke all on function untouch.track_average_revision() from public,anon,authenticated;
grant execute on function untouch.track_average_revision() to untouch_runtime;
