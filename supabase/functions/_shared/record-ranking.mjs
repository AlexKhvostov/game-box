// Public fields only. Rank the best confirmed Android attempt per visible owner
// BEFORE truncating, so the separate own row retains its actual global place.
export async function recordRankings({db,uid,stamp,period='allPeriods'}) {
  const date=new Date(stamp);
  const starts={all:0,day:Date.UTC(date.getUTCFullYear(),date.getUTCMonth(),date.getUTCDate()),
    week:stamp-7*86400000,month:Date.UTC(date.getUTCFullYear(),date.getUTCMonth(),1),year:Date.UTC(date.getUTCFullYear(),0,1)};
  if(period!=='allPeriods'&&!Object.hasOwn(starts,period)) {
    const error=new Error('period_invalid');error.code=error.message;error.status=400;throw error;
  }
  const windows=Object.entries(starts).filter(([key])=>period==='allPeriods'||key===period);
  const result=await db.pool.query(`
    with windows as (select key as period,value::bigint as since from jsonb_each_text($1::jsonb)),
    best as (
      select w.period,s.key,s.body,p.body as profile
      from untouch.documents p cross join windows w
      cross join lateral (
        select s.key,s.body from untouch.documents s
        where s.parent='scores' and s.body->>'platform'='android'
          and s.body->>'uid'=p.key and (s.body->>'timeMs')::bigint>=1
          and (s.body->>'createdAt')::bigint>=w.since
        order by (s.body->>'timeMs')::bigint desc,(s.body->>'createdAt')::bigint desc,s.key desc
        limit 1
      ) s
      where p.parent='players' and coalesce((p.body->>'supportDisabled')::boolean,false)=false
    ), ranked as (
      select *,row_number() over(partition by period order by
        (body->>'timeMs')::bigint desc,(body->>'createdAt')::bigint desc,body->>'uid')::integer as place
      from best
    )
    select period,jsonb_agg(jsonb_build_object(
      'id',key,'userId','supabase:'||(body->>'uid'),'playerName',case when coalesce((profile->>'publicNameRestricted')::boolean,false) then 'Игрок' else profile->>'nickname' end,
      'googleName',case when not coalesce((profile->>'publicNameRestricted')::boolean,false) and (profile->>'googleLinked')::boolean and not (profile->>'hideGoogleAccount')::boolean
        then profile->>'publicGoogleName' else null end,
      'timeMs',body->'timeMs','createdAt',body->'createdAt','runDistance',body->'runDistance',
      'riskCount',body->'riskCount','hadJump',body->'hadJump','hadHelmet',body->'hadHelmet','place',place
    ) order by place) as rows
    from ranked where place<=200 or body->>'uid'=$2 group by period`,[JSON.stringify(Object.fromEntries(windows)),uid]);
  const periods=Object.fromEntries(windows.map(([key])=>[key,[]]));
  for(const row of result.rows)periods[row.period]=row.rows;
  return period==='allPeriods'?{ok:true,source:'supabase',periods,serverNow:stamp}
    :{ok:true,source:'supabase',scores:periods[period],serverNow:stamp};
}
