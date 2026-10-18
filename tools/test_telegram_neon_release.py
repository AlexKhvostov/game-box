"""Read-only independent review of a prepared Telegram release. No FTP/HTTP."""
import argparse, hashlib, json, re, zipfile
from pathlib import Path, PurePosixPath
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
parser.add_argument('release', type=Path)
parser.add_argument('--version', default='1.0.69')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
release = args.release.resolve()
out = root / 'docs/release-evidence/telegram-neon-release-20261014'
out.mkdir(parents=True, exist_ok=True)
checks, failures = [], []
def check(name, fn):
    try:
        value = fn()
        checks.append({'name': name, 'status': 'PASS', 'value': value})
    except Exception as error:
        failures.append({'name': name, 'error': str(error)})
        checks.append({'name': name, 'status': 'FAIL', 'error': str(error)})
def need(condition, message):
    if not condition:
        raise AssertionError(message)
def read_json(file): return json.loads(file.read_text(encoding='utf-8-sig'))
def sha(file): return hashlib.sha256(file.read_bytes()).hexdigest()
accepted = read_json(root / 'docs/release-evidence/telegram-final-parity-20261014/source-freeze.json')['acceptedHashes']
check('accepted95-current-source', lambda: need(all(sha(root/x['path']) == x['sha256'] for x in accepted), 'Accepted source drift'))
manifest = read_json(release / 'manifest.json')
site = release / 'site'
identity = read_json(site / 'release.json')
check('version-build-identity', lambda: need(manifest['version'] == identity['version'] == args.version and manifest['buildId'] == identity['buildId'] and manifest['buildId'].startswith('v'+args.version+'_'), 'Version/buildId mismatch'))
check('public-version-json', lambda: need(read_json(site/'version.json')['version'] == args.version, 'Stale version.json'))
protected = {'bot_config.php','db_config.php','mobile_config.php','scores.json','scores_steps_v1.flag','rc_economy_cache.json','webhook_last.json','admin_guard.json','invite_photo_file_id.json'}
expected_api = {'api/scores.php','api/tg_common.php','api/mobile_store.php'}
paths = [x['path'] for x in manifest['files']]
def scope():
    need(len(set(paths)) == len(paths), 'Duplicate manifest paths')
    for name in paths:
        p = PurePosixPath(name)
        need(not p.is_absolute() and '..' not in p.parts and '\\' not in name, 'Unsafe path: '+name)
        need(p.name not in protected, 'Protected path packaged: '+name)
        need(p.parts[0] not in ('landing','admin','.private','privacy','delete-account'), 'Unrelated site path: '+name)
        if p.parts[0] == 'api': need(name in expected_api, 'Unapproved API: '+name)
        need(not (p.parts[:2] == ('api','config-data')), 'Published server data packaged')
    need(set(x for x in paths if x.startswith('api/')) == expected_api, 'Profile API set incomplete')
    return {'paths':len(paths),'api':sorted(expected_api)}
check('bounded-upload-scope', scope)
def required_client_set():
    required=[]
    for entry in accepted:
        name=entry['path']; relative=name[13:] if name.startswith('telegram-web/') else name if name.startswith('assets/') else None
        if relative and (relative.startswith(('js/','css/','assets/','config/')) or relative=='index.html'):
            required.append(relative)
    need(set(required).issubset(paths), 'Accepted client/assets missing: '+str(sorted(set(required)-set(paths))))
    return len(required)
check('complete-accepted-client-set', required_client_set)
def files_exact():
    present = set()
    for file in site.rglob('*'):
        need(not file.is_symlink(), 'Symlink in site')
        if file.is_file(): present.add(file.relative_to(site).as_posix())
    need(present == set(paths), 'Site/manifest file-set differs')
    for item in manifest['files']:
        file = site / item['path']
        need(file.stat().st_size == item['bytes'], 'Size mismatch: '+item['path'])
        need(sha(file) == item['sha256'], 'Hash mismatch: '+item['path'])
    return len(present)
# Reject protected paths before reading any packaged contents.
if not any(x['name']=='bounded-upload-scope' for x in failures):
    check('manifest-site-bytes-sha', files_exact)
    def archive_exact():
        archives = list(release.glob('untouch-telegram-neon-*.zip'))
        need(len(archives)==1 and archives[0].name == 'untouch-telegram-neon-'+manifest['buildId']+'.zip', 'Expected exactly the canonical release ZIP')
        with zipfile.ZipFile(archives[0]) as archive:
            need(archive.testzip() is None, 'ZIP integrity error')
            names = [x.filename for x in archive.infolist() if not x.is_dir()]
            need(len(names)==len(set(names)) and set(names)==set(paths), 'ZIP/manifest paths differ')
            hashes={x['path']:x['sha256'] for x in manifest['files']}
            for name in names:
                need(hashlib.sha256(archive.read(name)).hexdigest()==hashes[name], 'ZIP hash mismatch: '+name)
        return {'file':archives[0].name,'sha256':sha(archives[0]),'bytes':archives[0].stat().st_size,'paths':len(paths)}
    check('zip-exact-manifest-including-dotfiles', archive_exact)
    def normalized(text):
        return text.lstrip('\ufeff').replace('\r\n','\n')
    for entry in accepted:
        file = entry['path']
        relative = file[13:] if file.startswith('telegram-web/') else file if file.startswith('assets/') else None
        if relative is None or relative not in paths: continue
        def match(file=file, relative=relative):
            source=root/file; target=site/relative
            if relative.endswith('.js') or relative=='index.html':
                expected = normalized(source.read_text(encoding='utf-8-sig'))
                if relative.endswith('.js'):
                    expected = re.sub(r"from '(\./[^']+?\.js)(\?v=[^']*)?'",lambda m: "from '"+m.group(1)+"?v="+manifest['buildId']+"'",expected)
                else:
                    expected = re.sub(r"((?:href|src)=[\x22\x27])((?:css|js)/[^\x22\x27\s]+?\.(?:css|js))(?:\?v=[^\x22\x27\s]*)?([\x22\x27])",lambda m:m.group(1)+m.group(2)+'?v='+manifest['buildId']+m.group(3),expected)
                need(expected == normalized(target.read_text(encoding='utf-8-sig')), 'Code differs beyond exact builder stamp: '+relative)
            else: need(sha(source)==sha(target), 'Accepted bytes differ: '+relative)
        check('accepted-package/'+relative, match)
    def stamped():
        build_id=manifest['buildId'];index=(site/'index.html').read_text(encoding='utf-8-sig'); refs=[]
        for value in re.findall(r'(?:href|src)=[\x22\x27]([^\x22\x27]+)',index):
            if value.startswith(('css/','js/')) and value.split('?')[0].endswith(('.css','.js')):
                need(value.endswith('?v='+build_id), 'Unstamped entry: '+value);refs.append(value)
        for file in (site/'js').glob('*.js'):
            text=file.read_text(encoding='utf-8-sig')
            for relative in re.findall(r"from '(\./[^']+?\.js(?:\?v=[^']*)?)'",text):
                need(relative.endswith('?v='+build_id), 'Unstamped module: '+file.name+' '+relative)
                need((file.parent/relative.split('?')[0]).is_file(), 'Missing imported module')
        need('neon-messages-fit.js?v='+build_id in (site/'js/game-toast.js').read_text(encoding='utf-8-sig'),'Messages helper missing from import')
        need('src="js/neon-messages-fit.js' not in index, 'Duplicate messages initializer')
        return {'entryReferences':len(refs),'moduleFiles':len(list((site/'js').glob('*.js')))}
    check('all-entry-import-stamps-and-single-messages-init', stamped)
result={'updated':datetime.now(timezone.utc).isoformat(),'kind':'Read-only local release review; no FTP/HTTP or production writes','release':str(release),'version':args.version,'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':len(failures)},'checks':checks,'failures':failures}
(out/'release-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result['summary'],ensure_ascii=False))
for error in failures: print(json.dumps(error,ensure_ascii=False))
raise SystemExit(bool(failures))

