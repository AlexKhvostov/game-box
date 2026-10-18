"""Scoped Android contract3 delivery; preserves private files, schema and Telegram."""
import argparse
import base64
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import secrets
import sys
import urllib.error
import urllib.request
import android_host_tools as host

ORDER = tuple('api/' + name for name in ('mobile_energy_bonus.php', 'mobile_energy.php',
    'mobile_wallet.php', 'mobile_store.php', 'mobile_invites.php', 'gameplay_config.php', 'mobile.php'))
PROTECTED = ('api/mobile_config.php', 'api/mobile-closed-test.enabled', 'api/.htaccess',
    'api/config-data/.htaccess', 'api/mobile_play.php', 'api/mobile_google.php',
    'api/energy_store.php', 'api/mobile_identity.php', 'api/tg_common.php')
PUBLISHED = 'api/config-data/published.json'


def now():
    return datetime.now(timezone.utc).isoformat()


def optional_remote(name):
    parent, base = name.rsplit('/', 1)
    row = host.inventory(parent).get(base)
    if row is None:
        return None
    host.check(row.get('type') == 'file', 'Remote path is not a regular file: ' + name)
    return host.download(name, int(row['size']))


def digest(data):
    return None if data is None else host.sha(data)


def package_check(package):
    manifest = host.read_json(package / 'manifest.json')
    host.check(set(manifest['files']) == set(ORDER), 'Exact seven-file package required')
    for name, expected in manifest['files'].items():
        host.check(host.sha((package / 'deploy' / name).read_bytes()) == expected, 'Frozen package changed')
    return {name: manifest['files'][name] for name in ORDER}, manifest['existingDependencies']


def protected_call(directory, payload, backup=False):
    token = secrets.token_hex(32)
    name = 'api/_simple_energy_operator_' + secrets.token_hex(12) + '.php'
    template = host.ROOT / 'tools' / ('android_energy_live_maintenance.php' if backup else 'simple_energy_live_operator.php')
    source = template.read_text(encoding='utf-8-sig').replace('__TOKEN__', token).replace(
        '__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1200)).encode()
    ftp = host.connect()
    attempted = False
    cleanup_receipt = directory / ('operator-cleanup-' + name.rsplit('/', 1)[1] + '.json')
    try:
        host.save(cleanup_receipt, {'remotePath': name, 'removed': False, 'createdAtUtc': now()})
        attempted = True
        ftp.storbinary('STOR ' + name, io.BytesIO(source))
        host.check(host.remote(name) == source, 'Operator readback mismatch')
        action = payload['action']
        mutating = action in ('publish', 'activate')
        if mutating:
            path = directory / ('request-attempted-' + action + '.json')
            host.check(not path.exists(), 'Prior write request: inspect server state before retry')
            host.save(path, {'action': action, 'createdAtUtc': now(), 'recovery': 'keep_forward'})
        request = urllib.request.Request(host.ORIGIN + name, data=json.dumps(payload).encode(),
            headers={'X-Untouch-Test': token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            result = json.loads(error.read())
            host.save(directory / 'partial-recovery.json', {key: result.get(key) for key in
                ('ok', 'error', 'published', 'configWritten', 'recovery')})
            raise RuntimeError('Operator rejected; inspect sanitized partial-recovery.json')
        except Exception:
            if mutating:
                host.save(directory / 'partial-recovery.json', {'error': 'response_unconfirmed',
                    'recovery': 'inspect_current_state_keep_forward_no_retry'})
            raise
        host.check(result.get('ok') is True, 'Operator unsuccessful')
        return result
    finally:
        ftp.close()
        if attempted:
            cleanup = host.connect()
            try:
                if name.rsplit('/', 1)[1] in host.inventory('api'):
                    cleanup.delete(name)
                host.check(name.rsplit('/', 1)[1] not in host.inventory('api'), 'Operator cleanup not verified')
                host.save(cleanup_receipt, {'remotePath': name, 'removed': True, 'verifiedAtUtc': now()})
            finally:
                cleanup.close()


def fresh(audit):
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(audit['createdAtUtc'])).total_seconds()
    host.check(0 <= age <= 1800, 'Baseline expired; obtain a new audit and backup')


def guards(audit, expected):
    fresh(audit)
    for name, expected_hash in {**audit['protectedHashes'], **expected}.items():
        host.check(digest(optional_remote(name)) == expected_hash, 'Remote baseline changed: ' + name)


def validate_backups(directory, audit):
    for row in audit['files']:
        if not row['exists']:
            continue
        encrypted = (directory / 'files' / (row['path'] + '.dpapi')).read_bytes()
        host.check(host.sha(encrypted) == row['encryptedSha256'], 'Encrypted backup changed')
        plain = host.crypt(encrypted, True)
        host.check(host.sha(plain) == row['sha256'] and len(plain) == row['bytes'], 'File backup roundtrip failed')
    receipt = host.read_json(directory / 'database-backup-receipt.json')
    encrypted = (directory / 'database-before.dpapi').read_bytes()
    host.check(host.sha(encrypted) == receipt['encryptedSha256'], 'DB backup changed')
    plain = host.crypt(encrypted, True)
    host.check(host.sha(plain) == receipt['sha256'] and len(plain) == receipt['bytes'], 'DB backup roundtrip failed')


def payload_for(audit, expected, activated=None):
    return {'publicationRevision': (activated or audit['inspection'])['publicationRevision'],
        'baselineCreatedAt': int(datetime.fromisoformat(audit['createdAtUtc']).timestamp() * 1000),
        'unchangedConfigSha256': audit['inspection']['unchangedConfigSha256'],
        'protectedHashes': audit['protectedHashes'], 'expectedFiles': expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['audit', 'backup', 'apply', 'activate', 'verify'])
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--allow-write', action='store_true')
    args = parser.parse_args()
    host.check(args.mode not in ('apply', 'activate') or args.allow_write, 'Explicit --allow-write required')
    directory, package = args.directory.resolve(), args.package.resolve()
    host.check(directory.is_relative_to((host.ROOT / '.private').resolve()), 'Use a project private directory')
    host.check(package.is_relative_to((host.ROOT / 'releases').resolve()), 'Use immutable release package')
    expected, dependencies = package_check(package)
    host.CREDENTIALS = json.load(sys.stdin)
    host.connect = host.CurlFTPS
    host.download = host.curl_download
    directory.mkdir(parents=True, exist_ok=True)
    if args.mode == 'audit':
        host.check(not (directory / 'audit.json').exists(), 'Use fresh audit directory')
        records, hashes = [], {}
        for name in ORDER + PROTECTED + (PUBLISHED,):
            data = optional_remote(name)
            host.check(data is not None or name == ORDER[0], 'Required remote file absent: ' + name)
            record = {'path': name, 'exists': data is not None}
            if data is not None:
                destination = directory / 'files' / (name + '.dpapi')
                if destination.exists():
                    encrypted = destination.read_bytes()
                    host.check(host.crypt(encrypted, True) == data, 'Interrupted audit baseline changed: ' + name)
                    record.update(bytes=len(data), sha256=host.sha(data), encryptedSha256=host.sha(encrypted), dpapiRoundtripVerified=True)
                else:
                    record.update(host.backup_bytes(destination, data))
            records.append(record)
            hashes[name] = digest(data)
            print('Backed up:', name, flush=True)
        for name, expected_hash in dependencies.items():
            host.check(hashes[name] == expected_hash, 'Unreviewed server dependency: ' + name)
        host.check(host.denied('api/mobile_config.php') and host.denied(PUBLISHED), 'Private HTTP protection missing')
        protection = host.crypt((directory / 'files/api/config-data/.htaccess.dpapi').read_bytes(), True)
        host.check(b'Require all denied' in protection and b'Deny from all' in protection, 'Staging protection missing')
        inspection = protected_call(directory, {'action': 'inspect'})
        health = host.public('api/mobile.php')
        host.check(health.get('ok') and health.get('schemaReady') and health.get('playConfigured') and inspection.get('receiptsReady'), 'Live schema/Play not ready')
        host.save(directory / 'audit.json', {'createdAtUtc': now(), 'package': str(package), 'files': records,
            'expectedBeforeHashes': {name: hashes[name] for name in ORDER},
            'protectedHashes': {name: hashes[name] for name in PROTECTED},
            'publishedConfigSha256': hashes[PUBLISHED], 'inspection': inspection, 'health': health})
        print(json.dumps({'ok': True, 'readOnly': True, 'files': len(records)}))
        return
    audit = host.read_json(directory / 'audit.json')
    host.check(audit['package'] == str(package), 'Package differs from audit')
    fresh(audit)
    if args.mode == 'backup':
        guards(audit, audit['expectedBeforeHashes'])
        host.check(digest(optional_remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Config changed before DB backup')
        backup = protected_call(directory, {'action': 'backup'}, backup=True)['backup']
        plain = base64.b64decode(backup['payloadBase64'], validate=True)
        host.check(len(plain) == backup['bytes'] and host.sha(plain) == backup['sha256'], 'DB snapshot invalid')
        record = host.backup_bytes(directory / 'database-before.dpapi', plain)
        host.save(directory / 'database-backup-receipt.json', {**record, 'createdAtUtc': now(), 'tables': backup['tables']})
        print(json.dumps({'ok': True, 'dpapiRoundtripVerified': True, 'tables': backup['tables']}))
        return
    validate_backups(directory, audit)
    host.check(not (directory / 'partial-recovery.json').exists(), 'Unconfirmed prior mutation: inspect forward state first')
    if args.mode == 'apply':
        guards(audit, audit['expectedBeforeHashes'])
        host.check(digest(optional_remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Config changed before runtime delivery')
        staged = {}
        nonce = secrets.token_hex(12)
        ftp = host.connect()
        try:
            for index, name in enumerate(ORDER):
                data = (package / 'deploy' / name).read_bytes()
                host.check(host.sha(data) == expected[name], 'Frozen source changed')
                stage = '_sb_stage_' + nonce + '_' + str(index) + '.php'
                staged[name] = {'name': stage, 'sha256': expected[name]}
                host.save(directory / 'staging-cleanup.json', {'staged': staged, 'removed': False})
                ftp.storbinary('STOR api/config-data/' + stage, io.BytesIO(data))
                host.check(host.remote('api/config-data/' + stage) == data, 'Staging readback mismatch')
            payload = payload_for(audit, audit['expectedBeforeHashes'])
            payload.update(action='publish', staged=staged)
            result = protected_call(directory, payload)
            host.save(directory / 'published.json', result)
            host.check(result.get('published') == expected, 'Published hashes mismatch')
        finally:
            ftp.close()
            cleanup = host.connect()
            try:
                for row in staged.values():
                    if row['name'] in host.inventory('api/config-data'):
                        cleanup.delete('api/config-data/' + row['name'])
                host.check(not any(name.startswith('_sb_stage_' + nonce + '_') for name in host.inventory('api/config-data')), 'Staging cleanup not verified')
                host.save(directory / 'staging-cleanup.json', {'staged': staged, 'removed': True, 'verifiedAtUtc': now()})
            finally:
                cleanup.close()
        print(json.dumps({'ok': True, 'runtimePublished': 7, 'configWritten': False}))
        return
    guards(audit, expected)
    host.check((directory / 'published.json').exists(), 'Runtime publication receipt required')
    if args.mode == 'activate':
        host.check(digest(optional_remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Config changed before activation')
        payload = payload_for(audit, expected)
        payload['action'] = 'activate'
        result = protected_call(directory, payload)
        host.save(directory / 'activated.json', result)
        host.check(result.get('configWritten') is True, 'Bonus policy not written')
        host.save(directory / 'published-after-receipt.json', host.backup_bytes(directory / 'published-after.dpapi', host.remote(PUBLISHED)))
        print(json.dumps(result))
        return
    activated = host.read_json(directory / 'activated.json')
    payload = payload_for(audit, expected, activated)
    payload['action'] = 'verify'
    result = protected_call(directory, payload)
    config = host.public('api/config.php')['config']
    before = audit['inspection']['config']
    for item in (config, before):
        item['economy']['androidEnergyV2'].pop('simpleBonus', None)
    host.check(config == before, 'Unrelated configuration changed')
    health = host.public('api/mobile.php')
    host.check(health.get('ok') and health.get('schemaReady') and health.get('playConfigured'), 'Live health/Play failed')
    host.save(directory / 'verified.json', {**result, 'health': health, 'verifiedAtUtc': now()})
    print(json.dumps({'ok': True, 'verified': True, 'runtimeFiles': 7, 'privateUnchanged': True, 'otherConfigUnchanged': True, 'schemaChanged': False}))


if __name__ == '__main__':
    main()
