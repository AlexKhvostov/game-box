-- Supabase's default extension policies target PUBLIC. Our jobs belong only
-- to postgres, and application users never need to inspect scheduler tables.
revoke all on schema cron from public,anon,authenticated;
revoke all on all tables in schema cron from public,anon,authenticated;
-- Extension tables belong to the managed supabase_admin role. Their default
-- PUBLIC policies cannot be altered by postgres; schema/table ACLs deny users.
