// Cache only the per-player aggregate. Rank, profile visibility and names are
// always current. All reads/calculations/write-back share one SQL snapshot.
export async function cachedAverageRanking({db,rules,uid,stamp}){
  const key=`weighted-v1:${rules.windowSize}:${rules.previousWeightPercent}:${rules.minDurationMs}:${rules.minAttempts}`;
  const result=await db.pool.query(`
    with owners as materialized (
      select p.key as uid,p.path as owner_path,p.body,
        coalesce(v.revision,0) as score_revision
      from untouch.documents p left join untouch.average_score_revisions v on v.uid=p.key
      where p.parent='players' and coalesce((p.body->>'supportDisabled')::boolean,false)=false
    ), cached as materialized (
      select c.* from owners p join untouch.average_rank_cache c
        on c.uid=p.uid and c.owner_path=p.owner_path
        and c.score_revision=p.score_revision and c.rules_key=$6
    ), missing as materialized (
      select p.* from owners p where not exists(select 1 from cached c where c.uid=p.uid)
    ), fresh as materialized (
      select p.uid,p.owner_path,p.score_revision,s.average_ms,s.used_count,s.last_at,
        coalesce(t.attempts,0)::integer as total_count,
        (coalesce(t.attempts,0)-untouch.attempt_count_through(p.uid,$1::integer))::integer as eligible_count
      from missing p left join untouch.attempt_counts t on t.uid=p.uid and t.node=65536
      cross join lateral (
        select sum(time_ms*power($2::numeric,age-1))/sum(power($2::numeric,age-1)) as average_ms,
          count(*)::integer as used_count,max(played_at) as last_at
        from (
          select (recent.body->>'timeMs')::numeric as time_ms,
            coalesce((recent.body->>'attemptAt')::bigint,(recent.body->>'createdAt')::bigint) as played_at,
            row_number() over(order by coalesce((recent.body->>'attemptAt')::bigint,(recent.body->>'createdAt')::bigint) desc,recent.key desc) as age
          from (
            select s.body,s.key from untouch.documents s
            where s.parent='scores' and s.body->>'platform'='android' and s.body->>'uid'=p.uid
              and (s.body->>'timeMs')::numeric > $1
            order by coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) desc,s.key desc limit $3
          ) recent
        ) ordered
      ) s
    ), saved as (
      insert into untouch.average_rank_cache(uid,owner_path,rules_key,score_revision,average_ms,used_count,eligible_count,total_count,last_at)
      select uid,owner_path,$6,score_revision,average_ms,used_count,eligible_count,total_count,last_at from fresh
      on conflict(uid) do update set owner_path=excluded.owner_path,rules_key=excluded.rules_key,
        score_revision=excluded.score_revision,average_ms=excluded.average_ms,used_count=excluded.used_count,
        eligible_count=excluded.eligible_count,total_count=excluded.total_count,last_at=excluded.last_at,
        updated_at=clock_timestamp()
      where untouch.average_rank_cache.score_revision<=excluded.score_revision
      returning uid
    ), values_now as (
      select uid,average_ms,used_count,eligible_count,total_count,last_at from cached
      union all select uid,average_ms,used_count,eligible_count,total_count,last_at from fresh
    ), aggregates as (
      select v.*,p.body,
        case when coalesce((p.body->>'publicNameRestricted')::boolean,false) then 'Игрок' else p.body->>'nickname' end as nickname
      from values_now v join owners p using(uid)
    ), ranked as (
      select *,row_number() over(order by average_ms desc,uid asc)::integer as place
      from aggregates where eligible_count >= $4
    )
    select coalesce((select jsonb_agg(jsonb_build_object(
      'userId','supabase:'||uid,'playerName',nickname,'averageMs',average_ms,
      'usedCount',used_count,'eligibleCount',eligible_count,'totalAttempts',total_count,'lastAt',last_at,'place',place) order by place)
      from ranked where place<=200),'[]'::jsonb) as rows,
      (select jsonb_build_object('userId','supabase:'||a.uid,'playerName',a.body->>'nickname',
        'averageMs',a.average_ms,'usedCount',a.used_count,'eligibleCount',a.eligible_count,
        'totalAttempts',a.total_count,'place',r.place)
        from aggregates a left join ranked r using(uid) where a.uid=$5) as mine,
      (select count(*)::integer from saved) as cache_recomputed`,
    [rules.minDurationMs,rules.previousWeightPercent/100,rules.windowSize,rules.minAttempts,uid,key]);
  const value=result.rows[0];
  return {ok:true,source:'supabase',rules,rows:value.rows,
    mine:value.mine??{averageMs:null,usedCount:0,eligibleCount:0,totalAttempts:0,place:null},serverNow:stamp};
}
