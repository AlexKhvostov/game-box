-- Preserve every existing identity and UID; separate accounts by verified bot.
-- Fail without changing anything if a legacy identity has no trusted bot ID.
alter table untouch.external_identities alter column bot_id set not null;
alter table untouch.external_identities drop constraint external_identities_pkey;
alter table untouch.external_identities add primary key(provider,subject,bot_id);
