-- Exact count for every allowed integer threshold (0..60000), independent of
-- history length. Sparse Fenwick tree: <=17 writes/score, <=16 reads/player.
-- Durations above 60000 share a terminal bucket; original scores stay intact.
lock table untouch.documents in share row exclusive mode;
create table untouch.attempt_counts (
  uid text not null,
  node integer not null check(node between 1 and 65536),
  attempts bigint not null check(attempts >= 0),
  primary key(uid,node)
);
create index attempt_counts_roots on untouch.attempt_counts(uid) where node=65536;
alter table untouch.attempt_counts enable row level security;
revoke all on untouch.attempt_counts from public,anon,authenticated;
grant select,insert,update on untouch.attempt_counts to untouch_runtime;
create policy runtime_attempt_counts on untouch.attempt_counts to untouch_runtime using(true) with check(true);

create function untouch.adjust_attempt_count(owner_uid text,duration numeric,delta integer)
returns void language plpgsql set search_path='' as $$
declare bucket integer := least(60001,greatest(0,ceil(duration)))::integer+1;
begin
  if owner_uid is null or duration is null then return; end if;
  while bucket<=65536 loop
    -- UPDATE first: a negative INSERT would violate CHECK before ON CONFLICT.
    update untouch.attempt_counts set attempts=attempts+delta where uid=owner_uid and node=bucket;
    if not found then
      insert into untouch.attempt_counts(uid,node,attempts) values(owner_uid,bucket,delta)
      on conflict(uid,node) do update set attempts=untouch.attempt_counts.attempts+excluded.attempts;
    end if;
    bucket:=bucket+(bucket & -bucket);
  end loop;
end $$;
create function untouch.attempt_count_through(owner_uid text,threshold integer)
returns bigint language plpgsql stable set search_path='' as $$
declare bucket integer:=threshold+1; result bigint:=0; amount bigint;
begin
  if threshold<0 then return 0; end if;
  if threshold>60000 then raise exception 'attempt threshold out of range'; end if;
  while bucket>0 loop
    select attempts into amount from untouch.attempt_counts where uid=owner_uid and node=bucket;
    result:=result+coalesce(amount,0);bucket:=bucket-(bucket & -bucket);
  end loop;
  return result;
end $$;

-- Backfill once under the table lock, before enabling the trigger.
do $$ declare score record; begin
  for score in select body from untouch.documents where parent='scores' and body->>'platform'='android' loop
    perform untouch.adjust_attempt_count(score.body->>'uid',(score.body->>'timeMs')::numeric,1);
  end loop;
end $$;
create function untouch.track_attempt_counts() returns trigger language plpgsql set search_path='' as $$
begin
  if TG_OP='UPDATE' and old.parent is not distinct from new.parent
    and (old.body->>'platform',old.body->>'uid',old.body->>'timeMs') is not distinct from
        (new.body->>'platform',new.body->>'uid',new.body->>'timeMs') then return new; end if;
  if TG_OP<>'INSERT' and old.parent='scores' and old.body->>'platform'='android' then
    perform untouch.adjust_attempt_count(old.body->>'uid',(old.body->>'timeMs')::numeric,-1);
  end if;
  if TG_OP<>'DELETE' and new.parent='scores' and new.body->>'platform'='android' then
    perform untouch.adjust_attempt_count(new.body->>'uid',(new.body->>'timeMs')::numeric,1);
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;
create trigger documents_attempt_counts after insert or update or delete on untouch.documents
for each row execute function untouch.track_attempt_counts();
revoke all on function untouch.adjust_attempt_count(text,numeric,integer),untouch.attempt_count_through(text,integer),untouch.track_attempt_counts() from public,anon,authenticated;
grant execute on function untouch.adjust_attempt_count(text,numeric,integer),untouch.attempt_count_through(text,integer),untouch.track_attempt_counts() to untouch_runtime;
