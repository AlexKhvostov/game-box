import {Buffer} from 'node:buffer';
import {averageRules, averageAlgorithm} from './average-config.mjs';
import {hash, requireThat} from './core/policy.mjs';

/** Authenticated, read-only history. Every mean and the summary use one SQL
 * snapshot, including context older than the requested page. Never use a
 * client-supplied owner or a client-calculated aggregate. */
export async function attemptHistory({db, config, uid, stamp, cursor, limit = 100}) {
  requireThat(Number.isInteger(limit) && limit >= 1 && limit <= 200, 'attempt_history_limit_invalid', 400);
  const rules = averageRules(config);
  const rulesKey = `${averageAlgorithm}:${rules.windowSize}:${rules.previousWeightPercent}:${rules.minDurationMs}:${rules.minAttempts}`;
  let before = null;
  if (cursor != null) {
    requireThat(typeof cursor === 'string' && cursor.length <= 2048 && /^[A-Za-z0-9_-]+$/.test(cursor), 'attempt_history_cursor_invalid', 400);
    try { before = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')); }
    catch { requireThat(false, 'attempt_history_cursor_invalid', 400); }
    requireThat(before?.v === 1 && before.u === uid && typeof before.r === 'string' && /^\d+$/.test(before.r)
      && typeof before.k === 'string' && typeof before.d === 'string' && /^[a-f0-9]{32}$/.test(before.d)
      && Number.isSafeInteger(before.b?.at) && before.b.at >= 0 && typeof before.b?.id === 'string'
      && /^[A-Za-z0-9_-]{1,128}$/.test(before.b.id), 'attempt_history_cursor_invalid', 400);
    requireThat(before.k === rulesKey, 'attempt_history_changed', 409);
  }
  const result = await db.pool.query(`
    with owner as materialized (
      select body from untouch.documents where parent='players' and key=$1
        and not coalesce((body->>'supportDisabled')::boolean,false)
    ), own as materialized (
      select s.key,s.body,coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) as played_at,
        row_number() over(order by coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint),s.key)::integer as number
      from untouch.documents s where s.parent='scores' and s.body->>'uid'=$1
        and s.body->>'platform' in ('android','telegram') and (s.body->>'timeMs')::numeric >= 0
        and exists(select 1 from owner)
    ), meta as (
      select count(*)::integer as total_count,
        count(*) filter(where (body->>'timeMs')::numeric > $2)::integer as eligible_count,
        md5(coalesce((select body->>'nickname' from owner),'')||':'||coalesce(string_agg(jsonb_build_array(key,played_at,body->'timeMs',body->'runDistance',body->'riskCount',body->'hadJump',body->'hadHelmet')::text,',' order by played_at,key),'')) as checksum,
        coalesce((select revision from untouch.average_score_revisions where uid=$1),0)::text as revision
      from own
    ), page as materialized (
      select * from own where $4::bigint is null or (played_at,key)<($4::bigint,$5::text)
      order by played_at desc,key desc limit ($3::integer+1)
    ), requested as materialized (
      select * from page order by played_at desc,key desc limit $3
    ), latest as (select key from own order by played_at desc,key desc limit 1),
    best as (select key from own order by (body->>'timeMs')::numeric desc,played_at,key limit 1),
    targets as (select key from requested union select key from latest union select key from best),
    calculated as materialized (
      select o.key,o.played_at,
        jsonb_build_object('id',o.key,'number',o.number,'createdAt',o.played_at,
          'timeMs',(o.body->>'timeMs')::integer,
          'runDistance',coalesce((o.body->>'runDistance')::integer,0),
          'riskCount',coalesce((o.body->>'riskCount')::integer,0),
          'hadJump',coalesce((o.body->>'hadJump')::boolean,false),
          'hadHelmet',coalesce((o.body->>'hadHelmet')::boolean,false),
          'included',(o.body->>'timeMs')::numeric > $2,
          'averageMs',a.average_ms,'windowCount',a.used_count) as value
      from own o join targets t using(key)
      cross join lateral (
        select sqrt(sum(time_ms*time_ms*power($6::numeric,age-1))/sum(power($6::numeric,age-1))) as average_ms,
          count(*)::integer as used_count
        from (
          select (s.body->>'timeMs')::numeric as time_ms,
            row_number() over(order by coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) desc,s.key desc) as age
          from (
            select s.body,s.key from untouch.documents s where s.parent='scores' and s.body->>'uid'=$1
              and s.body->>'platform' in ('android','telegram') and (s.body->>'timeMs')::numeric > $2
              and (coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint),s.key)<=(o.played_at,o.key)
            order by coalesce((s.body->>'attemptAt')::bigint,(s.body->>'createdAt')::bigint) desc,s.key desc limit $7
          ) s
        ) window_scores
      ) a
    )
    select m.*,(select count(*) > $3 from page) as has_more,
      exists(select 1 from owner) as owner_exists,
      ($4::bigint is null or exists(select 1 from own where played_at=$4 and key=$5)) as cursor_exists,
      (select body->>'nickname' from owner) as nickname,
      coalesce((select jsonb_agg(c.value order by c.played_at desc,c.key desc) from calculated c join requested r using(key)),'[]'::jsonb) as rows,
      (select value from calculated join latest using(key)) as latest,
      (select value from calculated join best using(key)) as best
    from meta m`, [uid, rules.minDurationMs, limit, before?.b.at ?? null, before?.b.id ?? null, rules.previousWeightPercent / 100, rules.windowSize]);
  const value = result.rows[0];
  requireThat(value.owner_exists, 'profile_disabled', 403);
  if (before) {
    requireThat(value.revision === before.r && value.checksum === before.d, 'attempt_history_changed', 409);
    requireThat(value.cursor_exists, 'attempt_history_cursor_invalid', 400);
  }
  const owner = `supabase:${uid}`;
  const rows = value.rows;
  const last = rows.at(-1);
  const nextCursor = value.has_more && last ? Buffer.from(JSON.stringify({v:1,u:uid,r:value.revision,k:rulesKey,d:value.checksum,b:{at:last.createdAt,id:last.id}})).toString('base64url') : null;
  return {ok:true,source:'supabase',serverNow:stamp,
    average:{rules:{...rules,algorithm:averageAlgorithm},rows:[],mine:{userId:owner,playerName:value.nickname ?? '',
      averageMs:value.latest?.averageMs ?? null,usedCount:value.latest?.windowCount ?? 0,
      eligibleCount:value.eligible_count,totalAttempts:value.total_count,place:null}},
    history:{userId:owner,snapshot:hash({uid,revision:value.revision,rules:rulesKey,checksum:value.checksum}),
      totalCount:value.total_count,rows,nextCursor,best:value.best ?? null}};
}
