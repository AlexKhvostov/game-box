-- Count actual activated attempts, including historical ones; canceled starts
-- are refunded and do not count. New runtime increments only on first activate.
update untouch.documents as player
set body=jsonb_set(player.body,'{wallet,feedbackSpentEnergy}',to_jsonb(coalesce((
  select sum((round.body->>'cost')::bigint)
  from untouch.documents as round
  where round.parent='rounds' and round.body->>'uid'=player.key
    and jsonb_typeof(round.body->'activatedAt')='number'
    and coalesce((round.body->>'canceled')::boolean,false)=false
),0))),updated_at=now()
where player.parent='players' and not (player.body->'wallet' ? 'feedbackSpentEnergy');
