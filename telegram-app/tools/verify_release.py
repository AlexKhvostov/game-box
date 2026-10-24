"""Verify an immutable Vue release, portable ZIP and optional source checkpoint."""
from pathlib import Path
import argparse,hashlib,json,zipfile,datetime
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('release');parser.add_argument('--snapshot-sources',action='store_true');args=parser.parse_args()
release=(ROOT/args.release).resolve();assert release.is_relative_to((ROOT/'releases').resolve()),'Expected a workspace release'
manifest=json.loads((release/'manifest.json').read_text(encoding='utf-8-sig'));site=release/'site'
expected={r['path']:r for r in manifest['files']};assert len(expected)==len(manifest['files'])
assert set(expected)=={p.relative_to(site).as_posix() for p in site.rglob('*') if p.is_file()},'Static file set changed'
for name,row in expected.items():
 assert '\\' not in name and not name.startswith('/') and '..' not in Path(name).parts,'Nonportable path'
 data=(site/name).read_bytes();assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],name
 if Path(name).suffix in {'.js','.html','.json'}:
  text=data.decode('utf-8-sig')
  for bad in ['/qa-session','fixture-profile','visual_fixture_only','api.telegram.org','UNTOUCH_QA_BOT_TOKEN','TELEGRAM_WEBHOOK_SECRET']:assert bad not in text,(name,'private/fixture marker')
archives=list(release.glob('*.zip'));assert len(archives)==1,'Expected one complete ZIP'
with zipfile.ZipFile(archives[0]) as archive:
 names=archive.namelist();assert len(names)==len(expected) and set(names)==set(expected),'ZIP paths differ from manifest'
 for name in names:
  data=archive.read(name);row=expected[name];assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],name
source_path=release/'source-manifest.json'
if args.snapshot_sources:
 assert not source_path.exists(),'Never replace a source checkpoint'
 files=[]
 for directory in ['telegram-app/src','telegram-app/tools','telegram-app/public','telegram-app/config','telegram-app/qa','supabase/functions','admin-console/src']:
  files.extend(p for p in (ROOT/directory).rglob('*') if p.is_file() and p.suffix in {'.ts','.vue','.css','.mjs','.js','.json','.py','.ps1','.dart','.html','.svg','.png','.wav','.ttf','.woff','.woff2','.txt'})
 files.extend(ROOT/p for p in ['telegram-app/package.json','telegram-app/package-lock.json','telegram-app/vite.config.ts','telegram-app/tsconfig.json','tools/build_telegram_web.ps1','supabase/migrations/20261019223954_telegram_platform_core.sql','supabase/config.toml'])
 # Freeze the reviewed shared Dart inputs alongside a gameplay-changing build.
 files.extend(ROOT/p for p in ['lib/features/game/game_world.dart','lib/features/game/game_home_screen.dart','lib/features/game/arcade_hud.dart','lib/data/android_firebase_config.dart','lib/domain/gameplay_config.dart','lib/domain/replay_random.dart','lib/app/mobile_gameplay_tuning.dart','lib/domain/arcade_rules.dart','tools/build_android_replay.py','tools/replay/geometry.dart','tools/replay/session.dart','tools/replay/main.dart'])
 checkpoint={'buildId':manifest['buildId'],'kind':'source-hashes-only-no-secrets','hashNormalization':'raw-bytes','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(set(files))]}
 with source_path.open('x',encoding='utf-8') as target:json.dump(checkpoint,target,indent=2);target.write('\n')
source=json.loads(source_path.read_text(encoding='utf-8'));assert source['buildId']==manifest['buildId']
for row in source['files']:assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
report={'buildId':manifest['buildId'],'kind':'immutable-local-QA-not-production','manifestFiles':len(expected),'allHashesMatch':True,'zipPortablePosixPaths':True,'zipEntries':len(expected),'sourceFiles':len(source['files']),'sourceHashesMatch':True,'fixtureBypassAbsent':True,'botHostAndSecretNamesAbsent':True,'qa':manifest['qa'],'nativeAcceptance':False,'renderTouched':False,'paymentsEnabled':False}
verification=release/'verification.json'
if verification.exists():assert json.loads(verification.read_text(encoding='utf-8'))==report,'Verification changed'
else:
 with verification.open('x',encoding='utf-8') as target:json.dump(report,target,indent=2);target.write('\n')
print(json.dumps(report,indent=2))
