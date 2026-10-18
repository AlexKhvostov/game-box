-- Private expression indexes exactly match the Android ranking queries.
-- No player records, grants, RLS policies or existing indexes are removed.
create index if not exists android_scores_owner_best on untouch.documents
  ((body->>'uid'), ((body->>'timeMs')::bigint) desc,
   ((body->>'createdAt')::bigint) desc, key desc)
  where parent='scores' and body->>'platform'='android';
create index if not exists android_scores_owner_recent on untouch.documents
  ((body->>'uid'), (coalesce((body->>'attemptAt')::bigint,(body->>'createdAt')::bigint)) desc,key desc)
  where parent='scores' and body->>'platform'='android';
create index if not exists android_invitations_unpaid on untouch.documents(key)
  where parent='invitations' and body->>'rewardedAt' is null;
