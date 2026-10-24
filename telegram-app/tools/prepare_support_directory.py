"""Build a new reviewed SQL directory version from the immutable v2 source."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
target=ROOT/'supabase/migrations/20261019223954_telegram_platform_core.sql'
s=(ROOT/'supabase/migrations/20261019181735_admin_users_filters.sql').read_text(encoding='utf-8')
s=s[:s.index('alter table untouch.support_actions')]
s=s.replace('support_directory_v2','support_directory_v3')
s=s.replace("select id::text as id from auth.users union select key from untouch.documents where parent='players'", "select id::text as id from auth.users union select key from untouch.documents where parent='players' union select uid::text from untouch.external_identities where provider='telegram' and bot_id is not null")
s=s.replace('g.identity_data as google,',"g.identity_data as google,coalesce(p.body->>'platform',case when e.uid is not null then 'telegram' else 'android' end) as platform,e.username as telegram_username,")
s=s.replace("when u.id is null then 'auth_missing'", "when u.id is null and e.uid is null then 'auth_missing'")
s=s.replace("left join untouch.documents p on p.path='players/'||d.id", "left join untouch.documents p on p.path='players/'||d.id left join untouch.external_identities e on e.uid::text=d.id and e.provider='telegram' and e.bot_id is not null")
s=s.replace("lower(google->>'email')=lower(options->>'search')", "lower(google->>'email')=lower(options->>'search') or lower(telegram_username)=lower(options->>'search')")
s=s.replace("and (options->>'connection'='all'", "and (coalesce(options->>'platform','all')='all' or platform=options->>'platform')\n and (options->>'connection'='all'")
s=s.replace("(options->>'connection'='guest' and google is null)", "(options->>'connection'='guest' and google is null and platform='android') or (options->>'connection'='telegram' and platform='telegram')")
old=target.read_text(encoding='utf-8')
if 'create function untouch.support_directory_v3' in old:raise SystemExit('Directory already prepared; original retained')
target.write_text(old+'\n-- Platform filter applies BEFORE pagination. Private runtime only.\n'+s,encoding='utf-8')
print('New v3 directory appended; original v2 migration unchanged')
