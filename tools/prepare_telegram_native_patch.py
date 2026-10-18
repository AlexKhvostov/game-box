"""Freeze an accepted Telegram baseline plus six sources; package a bounded patch.

No credentials, network calls, runtime publications or rolling-pointer updates.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / 'releases/telegram-neon-v1.0.69_20261014_210147_890'
APPROVED = {'index.html', 'js/main.js', 'js/game-world.js',
            'js/launch.js', 'css/neon-launch.css', 'api/launch.php'}
NEW = {'js/launch.js', 'css/neon-launch.css', 'api/launch.php'}
ACL = 'api/config-data/.htaccess'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify(release):
    manifest = read(release / 'manifest.json')
    expected = {item['path']: item for item in manifest['files']}
    actual = {p.relative_to(release / 'site').as_posix()
              for p in (release / 'site').rglob('*') if p.is_file()}
    if actual != set(expected):
        raise RuntimeError('Manifest/file set mismatch')
    for name, item in expected.items():
        path = release / 'site' / name
        if path.stat().st_size != item['bytes'] or sha(path) != item['sha256']:
            raise RuntimeError('Immutable file mismatch: ' + name)
    return manifest, expected


def normalized_js(path):
    return re.sub(r'\?v=v\d+\.\d+\.\d+_\d+_\d+_\d+', '',
                  path.read_text(encoding='utf-8-sig'))


parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['stage', 'patch'])
parser.add_argument('--freeze', type=pathlib.Path, required=True)
parser.add_argument('--source', type=pathlib.Path)
parser.add_argument('--output', type=pathlib.Path, required=True)
parser.add_argument('--version', default='1.0.70')
parser.add_argument('--baseline-release', type=pathlib.Path, default=BASE)
args = parser.parse_args()
BASE = args.baseline_release.resolve()
if BASE.parent != ROOT / 'releases':
    raise RuntimeError('Expected an immutable baseline release under releases/')
freeze = read(args.freeze)
if set(freeze) != APPROVED:
    raise RuntimeError('Freeze must describe exactly six approved sources')
for name, digest in freeze.items():
    if sha(ROOT / 'telegram-web' / name) != digest:
        raise RuntimeError('Approved source changed: ' + name)
base, baseline = verify(BASE)
output = args.output.resolve()
allowed_root = ROOT / ('tmp' if args.mode == 'stage' else 'releases')
if output.parent != allowed_root or output.exists():
    raise RuntimeError('Expected a new isolated output directory')

if args.mode == 'stage':
    shutil.copytree(BASE / 'site', output)
    for name in sorted(APPROVED):
        dest = output / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'telegram-web' / name, dest)
    acl_source = BASE / 'site' / ACL
    if not acl_source.is_file():
        acl_source = ROOT / 'releases/v1.0.69_20261014_210147_890/site' / ACL
    old_full = read(acl_source.parents[3] / 'manifest.json')
    acl_record = next(item for item in old_full['files'] if item['path'] == ACL)
    if sha(acl_source) != acl_record['sha256']:
        raise RuntimeError('Old immutable ACL mismatch')
    dest = output / ACL
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(acl_source, dest)
    print(json.dumps({'stage': str(output), 'base': base['buildId'],
                      'approvedSources': freeze}, indent=2))
else:
    if args.source is None:
        raise RuntimeError('Specify immutable official build')
    source = args.source.resolve()
    if not source.is_relative_to(ROOT / 'releases'):
        raise RuntimeError('Expected official versioned release')
    manifest, built = verify(source)
    if manifest['version'] != args.version or manifest.get('artifact') != 'telegram-native-launch':
        raise RuntimeError('Unexpected build identity')
    if set(built) != set(baseline) | NEW | {ACL}:
        raise RuntimeError('Unexpected full-build scope')
    changed = []
    for name, item in sorted(built.items()):
        if name == ACL:
            acl_reference = BASE / 'site' / ACL
            if not acl_reference.is_file():
                acl_reference = ROOT / 'releases/v1.0.69_20261014_210147_890/site' / ACL
            if item['sha256'] != sha(acl_reference):
                raise RuntimeError('Unexpected runtime ACL change')
            continue
        old = baseline.get(name)
        if old and old['sha256'] == item['sha256']:
            continue
        if name not in APPROVED | {'release.json', 'version.json'}:
            if not (name.startswith('js/') and name.endswith('.js') and old and
                    normalized_js(source / 'site' / name) == normalized_js(BASE / 'site' / name)):
                raise RuntimeError('Unauthorized semantic change: ' + name)
        if name in APPROVED:
            actual = source / 'site' / name
            original = ROOT / 'telegram-web' / name
            if name.endswith('.js'):
                same = normalized_js(actual) == normalized_js(original)
            elif name == 'index.html':
                clean = lambda p: re.sub(r'\?v=v\d+\.\d+\.\d+_\d+_\d+_\d+', '', p.read_text(encoding='utf-8-sig'))
                same = clean(actual) == clean(original)
            else:
                same = sha(actual) == freeze[name]
            if not same:
                raise RuntimeError('Approved source/build mismatch: ' + name)
        changed.append(item)
    output.mkdir()
    for item in changed:
        dest = output / 'site' / item['path']
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / 'site' / item['path'], dest)
    result = {key: manifest[key] for key in ['version', 'buildId', 'createdAt', 'gitRevision', 'artifact']}
    result.update(sourceFullRelease=source.name, baselineRelease=BASE.name,
                  sourceFullManifestSHA256=sha(source / 'manifest.json'),
                  baselineManifestSHA256=sha(BASE / 'manifest.json'),
                  acceptedSources=freeze, files=changed,
                  expectedBeforeHashes={item['path']: baseline.get(item['path'], {}).get('sha256') for item in changed})
    (output / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    archive = output / ('untouch-telegram-native-' + manifest['buildId'] + '.zip')
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as zipped:
        for item in changed:
            zipped.write(output / 'site' / item['path'], item['path'])
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None or set(zipped.namelist()) != {i['path'] for i in changed}:
            raise RuntimeError('Patch ZIP scope/CRC mismatch')
        for item in changed:
            if hashlib.sha256(zipped.read(item['path'])).hexdigest() != item['sha256']:
                raise RuntimeError('Patch ZIP SHA mismatch')
    (output / 'archive.sha256').write_text(sha(archive) + '\n', encoding='ascii')
    print(json.dumps({'release': str(output), 'buildId': manifest['buildId'],
                      'changedFiles': len(changed), 'bytes': sum(i['bytes'] for i in changed),
                      'archiveSHA256': sha(archive)}, indent=2))
