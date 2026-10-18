-- Include both Auth accounts that have not started a game and profiles whose
-- Auth deletion succeeded while game-data cleanup is still pending.
create function untouch.support_directory(search_text text, skip_rows integer)
returns table(id text,created_at timestamptz,total bigint)
language sql stable security definer set search_path=''
as $$
  with directory as (
    select u.id::text as id,u.created_at as stamp from auth.users u
    union all
    select p.key,p.updated_at from untouch.documents p where p.parent='players'
  ), ids as (select d.id,min(d.stamp) as stamp from directory d group by d.id)
  select d.id,d.stamp,count(*) over()
  from ids d
  left join auth.users u on u.id::text=d.id
  left join untouch.documents p on p.path='players/'||d.id
  where length(search_text)<=160 and skip_rows between 0 and 100000
    and (search_text='' or d.id=search_text or lower(u.email)=lower(search_text)
      or position(lower(search_text) in lower(p.body->>'nickname'))>0)
  order by d.stamp desc,d.id limit 26 offset skip_rows
$$;
revoke all on function untouch.support_directory(text,integer) from public,anon,authenticated;
grant execute on function untouch.support_directory(text,integer) to untouch_runtime;
