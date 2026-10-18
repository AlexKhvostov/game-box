import {averageRules} from './average-config.mjs';

// One SQL snapshot: filter BEFORE row numbering, retain the newest N per owner,
// normalize exponential weights, then rank only qualified, visible players.
// Values are server-confirmed scores; callers cannot submit an aggregate.
export async function averageRanking({db,config,uid,stamp}){
  const rules=averageRules(config);
  const result=await db.pool.query(`
    with totals as (
      select body->>'uid' as uid,count(*)::integer as total_count
      from untouch.documents where parent='scores' and body->>'platform'='android' group by body->>'uid'
    ), ordered as (
      select s.body->>'uid' as uid, (s.body->>'timeMs')::numeric as time_ms,
        coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) as played_at,
        row_number() over (partition by s.body->>'uid' order by
          coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) desc,s.key desc) as age,
        count(*) over (partition by s.body->>'uid') as eligible_count,
        p.body->>'nickname' as nickname
      from untouch.documents s join untouch.documents p
        on p.parent='players' and p.key=s.body->>'uid'
      where s.parent='scores' and s.body->>'platform'='android'
        and (s.body->>'timeMs')::numeric > $1
        and coalesce((p.body->>'supportDisabled')::boolean,false)=false
    ), aggregates as (
      select uid,max(nickname) as nickname,
        sum(time_ms*power($2::numeric,age-1))/sum(power($2::numeric,age-1)) as average_ms,
        count(*)::integer as used_count,max(eligible_count)::integer as eligible_count,max(played_at) as last_at
      from ordered where age <= $3 group by uid
    ), ranked as (
      select *,row_number() over(order by average_ms desc,uid asc)::integer as place
      from aggregates where eligible_count >= $4
    )
    select coalesce((select jsonb_agg(jsonb_build_object(
      'userId','supabase:'||uid,'playerName',nickname,'averageMs',average_ms,
      'usedCount',used_count,'eligibleCount',eligible_count,'totalAttempts',t.total_count,'lastAt',last_at,'place',place) order by place)
      from ranked r join totals t using(uid) where place<=200),'[]'::jsonb) as rows,
      (select jsonb_build_object('userId','supabase:'||p.key,'playerName',p.body->>'nickname',
        'averageMs',a.average_ms,'usedCount',coalesce(a.used_count,0),
        'eligibleCount',coalesce(a.eligible_count,0),'totalAttempts',coalesce(t.total_count,0),'place',r.place)
        from untouch.documents p left join aggregates a on a.uid=p.key
        left join ranked r on r.uid=p.key left join totals t on t.uid=p.key
        where p.parent='players' and p.key=$5 and coalesce((p.body->>'supportDisabled')::boolean,false)=false) as mine`,
      [rules.minDurationMs,rules.previousWeightPercent/100,rules.windowSize,rules.minAttempts,uid]);
  const value=result.rows[0];
  return {ok:true,source:'supabase',rules,rows:value.rows,
    mine:value.mine??{averageMs:null,usedCount:0,eligibleCount:0,totalAttempts:0,place:null},serverNow:stamp};
}
