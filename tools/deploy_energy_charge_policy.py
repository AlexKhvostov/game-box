"""Reviewed seven-file Android charge8/DEFERRED operator; no private/schema writes."""
import argparse
import base64
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import secrets
import shutil
import sys
import urllib.error
import urllib.request
import android_host_tools as common

ROOT = common.ROOT
ORDER = ('api/mobile_energy.php', 'api/mobile_wallet.php', 'api/mobile_store.php',
         'api/mobile_play.php', 'api/mobile_play_notifications.php',
         'api/gameplay_config.php', 'admin/config-schema.json')
PROTECTED = ('api/mobile_config.php', 'api/mobile-closed-test.enabled',
             'api/.htaccess', 'api/config-data/.htaccess')
PUBLISHED = 'api/config-data/published.json'


def now():
    return datetime.now(timezone.utc).isoformat()


def package_check(package):
    manifest = common.read_json(package / 'manifest.json')
    common.check(set(row['path'] for row in manifest['files']) == set(ORDER)
                 and len(manifest['files']) == len(ORDER), 'Exact seven-file package required')
    freeze = common.read_json(ROOT / 'docs/release-evidence/play-deferred-20261015/source-sha256.json')
    accepted = {Path(row['Path']).resolve(): row['Hash'].lower() for row in freeze}
    for row in manifest['files']:
        data = (package / 'site' / row['path']).read_bytes()
        common.check(common.sha(data) == row['sha256'] and len(data) == row['bytes'], 'Package source changed')
        common.check(accepted.get((ROOT / 'telegram-web' / row['path']).resolve()) == row['sha256'], 'Package differs from accepted author freeze')
    return manifest


def package_create():
    freeze = common.read_json(ROOT / 'docs/release-evidence/play-deferred-20261015/source-sha256.json')
    hashes = {Path(row['Path']).resolve(): row['Hash'].lower() for row in freeze}
    build = 'android-charge8-deferred-' + datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
    target = ROOT / 'releases' / build
    target.mkdir(exist_ok=False)
    files = []
    for name in ORDER:
        source = ROOT / 'telegram-web' / name
        data = source.read_bytes()
        common.check(hashes.get(source.resolve()) == common.sha(data), 'Author freeze changed: ' + name)
        dest = target / 'site' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        files.append({'path': name, 'sha256': common.sha(data), 'bytes': len(data)})
    common.save(target / 'manifest.json', {'buildId': build, 'files': files, 'schemaChanges': False,
                'privateChanges': False, 'policy': {'version': 1, 'chargeHours': 8, 'effectiveAt': 'server activation time'}})
    print(json.dumps({'ok': True, 'package': str(target), 'files': len(files), 'published': False}))


def protected_call(directory, payload, backup=False):
    token = secrets.token_hex(32)
    name = 'api/_charge_policy_operator_' + secrets.token_hex(12) + '.php'
    template = ROOT / 'tools' / ('android_energy_live_maintenance.php' if backup else 'energy_charge_policy_live_operator.php')
    source = template.read_text(encoding='utf-8-sig').replace('__TOKEN__', token).replace(
        '__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1200)).encode()
    ftp = common.connect()
    attempted = False
    try:
        attempted = True  # Register before STOR, including partial-upload failure.
        ftp.storbinary('STOR ' + name, io.BytesIO(source))
        common.check(common.remote(name) == source, 'Operator readback mismatch')
        request = urllib.request.Request(common.ORIGIN + name, data=json.dumps(payload).encode(),
                    headers={'X-Untouch-Test': token, 'Content-Type': 'application/json'})
        mutating = not backup and payload.get('action') in ('publish', 'activate')
        if mutating:
            attempt = directory / ('request-attempted-' + payload['action'] + '.json')
            common.check(not attempt.exists(), 'Prior write request: inspect current server state before any retry')
            common.save(attempt, {'action': payload['action'], 'createdAtUtc': now(), 'recovery': 'keep_forward'})
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            result = json.loads(error.read())
            # Never save arbitrary HTTP bodies, private config or DB rows.
            receipt = {key: result.get(key) for key in ('ok', 'error', 'published', 'configWritten', 'chargePolicy', 'recovery')}
            common.save(directory / 'partial-recovery.json', receipt)
            raise RuntimeError('Operator rejected; inspect sanitized partial-recovery.json, no automatic retry')
        except Exception:
            if mutating:
                common.save(directory / 'partial-recovery.json', {'ok': False, 'error': 'operator_response_unconfirmed',
                            'configWritten': 'unknown', 'recovery': 'inspect_current_state_keep_forward_no_retry'})
            raise
        common.check(result.get('ok') is True, 'Operator unsuccessful')
        return result
    finally:
        ftp.close()
        if attempted:
            cleanup = common.connect()
            try:
                if name.rsplit('/', 1)[1] in common.inventory('api'):
                    cleanup.delete(name)
                common.check(name.rsplit('/', 1)[1] not in common.inventory('api'), 'Operator cleanup not verified')
            finally:
                cleanup.close()


def fresh(audit):
    elapsed = (datetime.now(timezone.utc) - datetime.fromisoformat(audit['createdAtUtc'])).total_seconds()
    common.check(0 <= elapsed <= 1800, 'Baseline expired; create a new audit/backup directory')


def current_guards(audit, expected):
    fresh(audit)
    for name, digest in audit['protectedHashes'].items():
        common.check(common.sha(common.remote(name)) == digest, 'Protected baseline changed: ' + name)
    for name, digest in expected.items():
        common.check(common.sha(common.remote(name)) == digest, 'Runtime baseline changed: ' + name)


def db_validate(directory):
    receipt = common.read_json(directory / 'database-backup-receipt.json')
    encrypted = (directory / 'database-before.dpapi').read_bytes()
    common.check(receipt.get('dpapiRoundtripVerified') is True and common.sha(encrypted) == receipt['encryptedSha256'], 'DB backup receipt invalid')
    plain = common.crypt(encrypted, True)
    common.check(common.sha(plain) == receipt['sha256'] and len(plain) == receipt['bytes'], 'DB roundtrip invalid')
    audit = common.read_json(directory / 'audit.json')
    common.check(len(audit['files']) == len(ORDER + PROTECTED + (PUBLISHED,)) and
                 {row['path'] for row in audit['files']} == set(ORDER + PROTECTED + (PUBLISHED,)), 'Complete file backup inventory required')
    for row in audit['files']:
        encrypted = (directory / 'files' / (row['path'] + '.dpapi')).read_bytes()
        common.check(row.get('dpapiRoundtripVerified') is True and common.sha(encrypted) == row['encryptedSha256'], 'File backup receipt invalid')
        plain = common.crypt(encrypted, True)
        common.check(len(plain) == row['bytes'] and common.sha(plain) == row['sha256'], 'File backup roundtrip invalid')


def payload_for(audit, expected, activated=None):
    return {'publicationRevision': (activated or audit['inspection'])['publicationRevision'],
            'baselineCreatedAt': int(datetime.fromisoformat(audit['createdAtUtc']).timestamp() * 1000),
            'unchangedConfigSha256': audit['inspection']['unchangedConfigSha256'],
            'protectedHashes': audit['protectedHashes'], 'expectedFiles': expected}


def stage_apply(directory, package, audit, expected_new):
    current_guards(audit, audit['expectedBeforeHashes'])
    nonce = secrets.token_hex(12)
    staged = {}
    ftp = common.connect()
    try:
        for index, name in enumerate(ORDER):
            basename = '_cp_stage_' + nonce + '_' + str(index) + ('.json' if name.endswith('.json') else '.php')
            data = (package / 'site' / name).read_bytes()
            common.check(common.sha(data) == expected_new[name], 'Package source changed immediately before STOR')
            staged[name] = {'name': basename, 'sha256': common.sha(data)}
            ftp.storbinary('STOR api/config-data/' + basename, io.BytesIO(data))
            common.check(common.remote('api/config-data/' + basename) == data, 'Staged readback mismatch')
        payload = payload_for(audit, audit['expectedBeforeHashes'])
        payload.update(action='publish', staged=staged)
        result = protected_call(directory, payload)
        common.save(directory / 'published.json', result)
        common.check(result.get('published') == expected_new, 'Published hashes mismatch; keep forward')
    finally:
        ftp.close()
        cleanup = common.connect()
        try:
            for row in staged.values():
                if row['name'] in common.inventory('api/config-data'):
                    cleanup.delete('api/config-data/' + row['name'])
            common.check(not any(name.startswith('_cp_stage_' + nonce + '_') for name in common.inventory('api/config-data')), 'Staging cleanup not verified')
        finally:
            cleanup.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['package', 'audit', 'backup', 'apply', 'activate', 'verify'])
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--package', type=Path)
    parser.add_argument('--allow-write', action='store_true')
    args = parser.parse_args()
    if args.mode == 'package':
        package_create()
        return
    if args.mode in ('apply', 'activate'):
        common.check(args.allow_write, 'Explicit root GO and --allow-write required before network')
    common.check(args.directory is not None and args.package is not None, 'Directory/package required')
    directory, package = args.directory.resolve(), args.package.resolve()
    common.check(directory.is_relative_to((ROOT / '.private').resolve()), 'Use project private directory')
    common.check(package.is_relative_to((ROOT / 'releases').resolve()), 'Use immutable release package')
    directory.mkdir(parents=True, exist_ok=True)
    manifest = package_check(package)
    common.CREDENTIALS = json.load(sys.stdin)
    expected_new = {row['path']: row['sha256'] for row in manifest['files']}
    if args.mode == 'audit':
        common.check(not (directory / 'audit.json').exists(), 'Use fresh audit directory')
        records, hashes = [], {}
        for name in ORDER + PROTECTED + (PUBLISHED,):
            data = common.remote(name)
            dest = directory / 'files' / (name + '.dpapi')
            dest.parent.mkdir(parents=True, exist_ok=True)
            record = common.backup_bytes(dest, data)
            records.append({'path': name, **record})
            hashes[name] = record['sha256']
            if name.endswith('mobile-closed-test.enabled'):
                common.check(data.strip() == b'on', 'Marker off; stop without modifying it')
        common.check(common.denied('api/mobile_config.php') and common.denied(PUBLISHED), 'HTTP private protection missing')
        protection = common.crypt((directory / 'files/api/config-data/.htaccess.dpapi').read_bytes(), True)
        common.check(b'Require all denied' in protection and b'Deny from all' in protection, 'Staging protection missing')
        inspection = protected_call(directory, {'action': 'inspect'})
        health = common.public('api/mobile.php')
        common.check(health.get('ok') is True and health.get('schemaReady') is True and health.get('playConfigured') is True and inspection.get('playConfigured') is True, 'Live Play/health not ready')
        common.save(directory / 'audit.json', {'createdAtUtc': now(), 'package': str(package), 'files': records,
                     'expectedBeforeHashes': {name: hashes[name] for name in ORDER},
                     'protectedHashes': {name: hashes[name] for name in PROTECTED},
                     'publishedConfigSha256': hashes[PUBLISHED], 'inspection': inspection, 'health': health})
        print(json.dumps({'ok': True, 'readOnly': True, 'filesEncrypted': len(records), 'playConfigured': True}))
        return
    audit = common.read_json(directory / 'audit.json')
    common.check(audit['package'] == str(package), 'Package differs from audit')
    fresh(audit)
    if args.mode == 'backup':
        current_guards(audit, audit['expectedBeforeHashes'])
        common.check(common.sha(common.remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Published config changed')
        result = protected_call(directory, {'action': 'backup'}, backup=True)
        backup = result['backup']
        plain = base64.b64decode(backup['payloadBase64'], validate=True)
        common.check(len(plain) == backup['bytes'] and common.sha(plain) == backup['sha256'], 'DB snapshot invalid')
        record = common.backup_bytes(directory / 'database-before.dpapi', plain)
        common.save(directory / 'database-backup-receipt.json', {**record, 'createdAtUtc': now(), 'tables': backup['tables']})
        current_guards(audit, audit['expectedBeforeHashes'])
        common.check(common.sha(common.remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Config changed during backup')
        print(json.dumps({'ok': True, 'readOnly': True, 'dpapiRoundtripVerified': True, 'tables': backup['tables']}))
        return
    db_validate(directory)
    common.check(not (directory / 'partial-recovery.json').exists(), 'Prior partial failure: manual forward review required, no blind retry')
    if args.mode == 'apply':
        common.check(not (directory / 'published.json').exists(), 'Runtime publication already attempted')
        common.check(common.sha(common.remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Published config changed')
        stage_apply(directory, package, audit, expected_new)
        current_guards(audit, expected_new)
        print(json.dumps({'ok': True, 'runtimePublished': 7, 'configWritten': False}))
        return
    current_guards(audit, expected_new)
    common.check((directory / 'published.json').exists(), 'Runtime publish receipt required')
    if args.mode == 'activate':
        common.check(not (directory / 'activated.json').exists(), 'Activation already attempted')
        common.check(common.sha(common.remote(PUBLISHED)) == audit['publishedConfigSha256'], 'Published config changed before activation')
        payload = payload_for(audit, expected_new)
        payload['action'] = 'activate'
        result = protected_call(directory, payload)
        common.save(directory / 'activated.json', result)  # Durable before postchecks.
        common.check(result.get('configWritten') is True, 'Policy not written')
        record = common.backup_bytes(directory / 'published-after.dpapi', common.remote(PUBLISHED))
        common.save(directory / 'published-after-receipt.json', record)
        print(json.dumps(result))
        return
    activated = common.read_json(directory / 'activated.json')
    payload = payload_for(audit, expected_new, activated)
    payload['action'] = 'verify'
    result = protected_call(directory, payload)
    current_guards(audit, expected_new)
    health = common.public('api/mobile.php')
    common.check(health.get('ok') is True and health.get('schemaReady') is True and health.get('playConfigured') is True, 'Post health failed, keep forward')
    config = common.public('api/config.php')['config']
    before = audit['inspection']['config']
    for item in (config, before):
        item['economy']['androidEnergyV2'].pop('chargePolicy', None)
        item['economy']['androidEnergyV2'].pop('revision', None)
    common.check(config == before, 'Unrelated public configuration changed')
    common.save(directory / 'verified.json', {**result, 'health': health, 'verifiedAtUtc': now()})
    print(json.dumps({'ok': True, 'verified': True, 'runtimeFiles': 7, 'chargeHours': 8, 'privateUnchanged': True, 'otherConfigUnchanged': True, 'schemaChanged': False}))


if __name__ == '__main__':
    main()
