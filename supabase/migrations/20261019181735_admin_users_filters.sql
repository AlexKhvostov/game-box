-- Private directory: filter and sort BEFORE pagination, without per-row Auth HTTP calls.
create function untouch.support_directory_v2(options jsonb)
returns jsonb language sql stable security definer set search_path='' as $$
with ids as (
 select id::text as id from auth.users union select key from untouch.documents where parent='players'
), directory as (
 select d.id,p.body,u.created_at,
 g.identity_data as google,
 case when p.body->>'supportDisabled'='true' then 'deleting' when p.body is null then 'not_started' when u.id is null then 'auth_missing' else 'active' end as status,
 coalesce(p.body->>'nickname',g.identity_data->>'full_name','Аккаунт без игрового профиля') as nickname,
 coalesce((p.body->'wallet'->>'energy')::numeric,0) as energy,
 coalesce((p.body->>'completedGames')::bigint,0) as games,
 coalesce((p.body->>'lastActiveAt')::bigint,(p.body->>'createdAt')::bigint,0) as activity,
 case when p.body->'wallet'->'energySubscription' is null or p.body->'wallet'->'energySubscription'='null'::jsonb then 'none'
 when (p.body->'wallet'->'energySubscription'->>'expiresAt')::numeric > (options->>'now')::numeric then 'active'
 when coalesce(p.body->'wallet'->'energySubscription'->>'endConfirmed','false')<>'true' then 'pending' else 'expired' end as subscription
 from ids d left join auth.users u on u.id::text=d.id
 left join untouch.documents p on p.path='players/'||d.id
 left join lateral (select coalesce(i.identity_data,'{}'::jsonb) as identity_data from auth.identities i where i.user_id=u.id and i.provider='google' limit 1) g on true
), filtered as (
 select * from directory where
 (coalesce(options->>'search','')='' or id=options->>'search' or lower(google->>'email')=lower(options->>'search') or position(lower(options->>'search') in lower(nickname))>0)
 and (options->>'connection'='all' or (options->>'connection'='google' and google is not null) or (options->>'connection'='guest' and google is null))
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
revoke all on function untouch.support_directory_v2(jsonb) from public,anon,authenticated;
grant execute on function untouch.support_directory_v2(jsonb) to untouch_runtime;
alter table untouch.support_actions drop constraint support_actions_kind_check;
alter table untouch.support_actions add constraint support_actions_kind_check check(kind in ('set_energy','delete_user','public_name_moderation','set_nickname'));
