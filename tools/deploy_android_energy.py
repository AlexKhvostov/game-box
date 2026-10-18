"""Scoped Android release operator. Credentials stay in memory; audit is read-only."""
import argparse
import base64
import ctypes
import copy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import ftplib
import hashlib
import io
import json
import secrets
import shutil
from pathlib import Path
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = 'https://untouch.ballaball.xyz/'
RELEASE = ROOT / 'releases/android-energy-server-20261015-0310'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode', choices=['audit', 'prepare', 'maintenance', 'public-verify'])
parser.add_argument('--directory', type=Path, required=True)
parser.add_argument('--action', choices=['inspect','backup','schema','activate','verify','rehearsal'])
parser.add_argument('--expected-revision')
parser.add_argument('--expected-non-android-hash')
args = parser.parse_args()
directory = args.directory.resolve()
assert directory.is_relative_to((ROOT / '.private').resolve())
credentials = json.load(sys.stdin)


def connect():
    context = ssl.create_default_context()
    context.maximum_version = ssl.TLSVersion.TLSv1_2
    client = ftplib.FTP_TLS(context=context, timeout=30)
    client.connect(credentials['host'], credentials['port'])
    client.auth()
    client.login(credentials['user'], credentials['password'])
    client.prot_p()
    client.cwd('/')
    return client


def listing(path):
    client = connect()
    try:
        return {name: facts for name, facts in client.mlsd(path)
                if facts.get('type') not in ('cdir', 'pdir')}
    finally:
        client.close()


def download(name, length):
    assert not name.startswith('/') and '..' not in name.split('/')
    url = 'ftp://' + credentials['host'] + '/' + urllib.parse.quote(name)
    cfg = ('url = ' + json.dumps(url) + '\nuser = ' +
           json.dumps(credentials['user'] + ':' + credentials['password']) + '\n')
    def chunk(start):
        end = min(length - 1, start + 16383)
        command = ['curl.exe', '--config', '-', '--ssl-reqd', '--tls-max', '1.2',
                   '--disable-epsv', '--silent', '--show-error', '--connect-timeout', '20',
                   '--max-time', '45', '--range', f'{start}-{end}']
        for attempt in range(3):
            result = subprocess.run(command, input=cfg.encode(), capture_output=True)
            if not result.returncode and len(result.stdout) == end - start + 1:
                return result.stdout
        raise RuntimeError('Incomplete FTPS read: ' + name)
    with ThreadPoolExecutor(max_workers=4) as pool:
        content = b''.join(pool.map(chunk, range(0, length, 16384)))
    assert len(content) == length
    return content


def public(name):
    request = urllib.request.Request(ORIGIN + name + '?energy_audit=20261015',
                                    headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def protect(data):
    class Blob(ctypes.Structure):
        _fields_ = [('size', ctypes.c_ulong), ('data', ctypes.POINTER(ctypes.c_ubyte))]
    buffer = ctypes.create_string_buffer(data)
    source = Blob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    encrypted = Blob()
    crypt = ctypes.windll.crypt32
    if not crypt.CryptProtectData(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(encrypted)):
        raise ctypes.WinError()
    try:
        result = ctypes.string_at(encrypted.data, encrypted.size)
    finally:
        ctypes.windll.kernel32.LocalFree(encrypted.data)
    sealed = ctypes.create_string_buffer(result)
    source2 = Blob(len(result), ctypes.cast(sealed, ctypes.POINTER(ctypes.c_ubyte)))
    decrypted = Blob()
    if not crypt.CryptUnprotectData(ctypes.byref(source2), None, None, None, None, 1, ctypes.byref(decrypted)):
        raise ctypes.WinError()
    try:
        assert ctypes.string_at(decrypted.data, decrypted.size) == data, 'DPAPI backup verification failed'
    finally:
        ctypes.windll.kernel32.LocalFree(decrypted.data)
    return result


if args.mode == 'public-verify':
    before = json.loads((directory / 'preflight/effective-config.json').read_text(encoding='utf-8-sig'))['config']
    after = public('api/config.php')
    health = public('api/mobile.php')
    (directory / 'effective-after.json').write_text(json.dumps(after, ensure_ascii=False, indent=2), encoding='utf-8')
    left, right = copy.deepcopy(before), copy.deepcopy(after['config'])
    left['economy'].pop('androidEnergyV2', None)
    right['economy'].pop('androidEnergyV2', None)
    if left != right:
        def differences(a, b, path=''):
            if isinstance(a, dict) and isinstance(b, dict):
                return [item for key in sorted(set(a) | set(b))
                        for item in differences(a.get(key), b.get(key), path + '.' + key)]
            return [] if a == b else [{'path': path.lstrip('.'), 'before': a, 'after': b}]
        delta = differences(left, right)
        (directory / 'non-android-diff.json').write_text(json.dumps(delta, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({'nonAndroidDifferences': delta}, ensure_ascii=False))
        raise RuntimeError('Non-Android config changed')
    block = after['config']['economy']['androidEnergyV2']
    assert block['enabled'] and block['batteryCapacity'] == 20 and block['chargeHours'] == 12
    assert health['ok'] and health['schemaReady'] and not health['playConfigured']
    result = {'ok': True, 'checkedAt': datetime.now(timezone.utc).isoformat(), 'energyEnabled': True,
              'onlyChanged': 'economy.androidEnergyV2', 'batteryCapacity': 20, 'chargeHours': 12,
              'nonAndroidConfigUnchanged': True, 'wallsKillPlayer': after['config']['game']['wallsKillPlayer'],
              'riskRewardEvery': after['config']['economy']['riskRewardEvery'],
              'runRewardEvery': after['config']['economy']['runRewardEvery'],
              'playConfigured': False, 'effectiveRevision': after['revision']}
    output = ROOT / 'docs/release-evidence/android-energy-live-20261015'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'live-config-verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    (directory / 'effective-after.json').write_text(json.dumps(after, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result))


if args.mode == 'prepare':
    audit = json.loads((directory / 'preflight/audit.json').read_text(encoding='utf-8-sig'))
    assert audit['readOnly'] and not audit['energyEnabled']
    archive = json.loads((RELEASE / 'manifest-sha256.json').read_text(encoding='utf-8-sig'))
    release_id = 'android-energy-free-api-' + datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    target = ROOT / 'releases' / release_id
    target.mkdir(exist_ok=False)
    before = {row['path']: row.get('sha256') for row in audit['files']}
    files, expected = [], {}
    for row in archive['files']:
        if not row['path'].startswith('deploy/'):
            continue
        name = row['path'][7:]
        source = RELEASE / row['path']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == row['sha256']
        assert name in before
        dest = target / 'site' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        files.append({'path': name, 'sha256': row['sha256'], 'bytes': row['bytes']})
        expected[name] = before[name]
    assert len(files) == 11
    manifest = {'buildId': release_id, 'artifact': 'android-energy-free-api',
                'files': files, 'expectedBeforeHashes': expected,
                'configIncluded': False, 'credentialsIncluded': False}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (directory / 'prepared-release.json').write_text(json.dumps({'path': str(target)}, indent=2), encoding='utf-8')
    print(json.dumps({'ok': True, 'release': str(target), 'files': len(files), 'published': False}))


if args.mode == 'maintenance':
    assert args.action
    if args.action in ['schema', 'activate', 'rehearsal']:
        receipt = json.loads((directory / 'database-backup-receipt.json').read_text(encoding='utf-8-sig'))
        sealed = directory / 'database-before.dpapi'
        assert sealed.is_file() and hashlib.sha256(sealed.read_bytes()).hexdigest() == receipt['encryptedSha256']
        assert receipt['dpapiRoundtripVerified']
    if args.action == 'activate':
        assert args.expected_revision and args.expected_non_android_hash
    template_name = 'android_energy_live_rehearsal.php' if args.action == 'rehearsal' else 'android_energy_live_maintenance.php'
    template = (ROOT / 'tools' / template_name).read_text(encoding='utf-8-sig')
    assert '__TOKEN__' in template
    token = secrets.token_hex(32)
    endpoint = 'api/_android_energy_release_' + secrets.token_hex(12) + '.php'
    source = template.replace('__TOKEN__', token).replace('__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1800)).encode()
    client = connect()
    uploaded = False
    try:
        uploaded = True
        client.storbinary('STOR ' + endpoint, io.BytesIO(source))
        payload = {'action': args.action}
        if args.expected_revision:
            payload['expectedPublicationRevision'] = args.expected_revision
        if args.expected_non_android_hash:
            payload['expectedNonAndroidConfigSha256'] = args.expected_non_android_hash
        request = urllib.request.Request(ORIGIN + endpoint, data=json.dumps(payload).encode(),
                    headers={'X-Untouch-Test': token, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
        assert result.get('ok'), 'Server maintenance rejected action'
        if args.action == 'backup':
            assert not (directory / 'database-before.dpapi').exists(), 'Do not overwrite DB backup'
            backup = result['backup']
            data = base64.b64decode(backup['payloadBase64'], validate=True)
            assert len(data) == backup['bytes'] and hashlib.sha256(data).hexdigest() == backup['sha256']
            encrypted = protect(data)
            (directory / 'database-before.dpapi').write_bytes(encrypted)
            receipt = {key: value for key, value in backup.items() if key != 'payloadBase64'}
            receipt.update(encryptedSha256=hashlib.sha256(encrypted).hexdigest(),
                           dpapiRoundtripVerified=True, createdAt=datetime.now(timezone.utc).isoformat())
            (directory / 'database-backup-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            print(json.dumps({'ok': True, 'action': 'backup', 'encrypted': True,
                              'dpapiRoundtripVerified': True, 'tables': backup['tables']}, ensure_ascii=False))
        else:
            path = directory / (args.action + '-' + datetime.now(timezone.utc).strftime('%H%M%S') + '.json')
            path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
            print(json.dumps(result, ensure_ascii=False))
    finally:
        client.close()
        if uploaded:
            cleanup = connect()
            try:
                cleanup.delete(endpoint)
                assert endpoint.rsplit('/',1)[1] not in [name for name, _ in cleanup.mlsd('api')]
                print('Temporary maintenance endpoint removed and absence verified', flush=True)
            finally:
                cleanup.close()


if args.mode == 'audit':
    target = directory / 'preflight'
    target.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((RELEASE / 'manifest-sha256.json').read_text(encoding='utf-8-sig'))
    deploy = [row for row in manifest['files'] if row['path'].startswith('deploy/')]
    api = listing('api')
    admin = listing('admin')
    config_data = listing('api/config-data')
    inventories = {'api': api, 'admin': admin, 'api/config-data': config_data}
    extras = ['api/tg_common.php', 'api/mobile_google.php', 'api/mobile_identity.php',
              'api/mobile_beta.php', 'api/mobile_google_nickname.php', 'api/mobile_pace.php',
              'api/mobile_play_rtdn.php', 'api/admin.php', 'api/config.php', 'api/.htaccess',
              'api/config-data/published.json']
    names = sorted(set([row['path'][7:] for row in deploy] + extras))
    records = []
    for name in names:
        parent, base = name.rsplit('/', 1)
        facts = inventories[parent].get(base)
        if facts is None:
            records.append({'path': name, 'exists': False})
            continue
        assert facts['type'] == 'file'
        data = download(name, int(facts['size']))
        dest = target / 'site' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        row = {'path': name, 'exists': True, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        local = ROOT / 'telegram-web' / name
        row['matchesWorkspace'] = local.is_file() and hashlib.sha256(local.read_bytes()).hexdigest() == row['sha256']
        records.append(row)
        print('Read-only backup:', name, flush=True)
    for row in deploy:
        data = (RELEASE / row['path']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
    config = public('api/config.php')
    health = public('api/mobile.php')
    (target / 'effective-config.json').write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')
    (target / 'mobile-health.json').write_text(json.dumps(health, indent=2), encoding='utf-8')
    result = {'readOnly': True, 'createdAt': datetime.now(timezone.utc).isoformat(),
              'files': records, 'deployFiles': len(deploy),
              'privateConfigExists': 'mobile_config.php' in api,
              'energyEnabled': config['config']['economy'].get('androidEnergyV2', {}).get('enabled', False),
              'health': health}
    (target / 'audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'ok': True, 'readOnly': True, 'files': len(records), 'energyEnabled': result['energyEnabled'],
                      'health': health}, ensure_ascii=False))
