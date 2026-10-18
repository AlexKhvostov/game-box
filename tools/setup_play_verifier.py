"""Scoped Play key preparation/install. No private config activation or purchases."""
import argparse
import base64
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import re
import secrets
import sys
import urllib.request
import android_host_tools as host

FILES = ('api/mobile_config.php', 'api/mobile-closed-test.enabled', 'api/.htaccess',
         'api/config-data/.htaccess', 'api/mobile_play.php', 'api/mobile_beta.php',
         'api/mobile_google.php')
DEFAULT_KEY = Path.home() / 'AppData/Local/Untouch/private/untouch-play-verifier-game-box-b30d4.json'


def validate_key(data):
    key = json.loads(data)
    host.check(key.get('type') == 'service_account' and key.get('project_id') == 'game-box-b30d4', 'Service account metadata invalid')
    host.check(key.get('token_uri') == 'https://oauth2.googleapis.com/token', 'OAuth target invalid')
    host.check(key.get('client_email') == 'untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com', 'Unexpected verifier service account')
    host.check(key.get('private_key', '').startswith('-----BEGIN PRIVATE KEY-----'), 'Key format invalid')
    host.check(1000 < len(data) < 16000, 'Key length invalid')


def prepare(folder, inspection, key_path):
    host.check(not (folder / 'prepared.json').exists(), 'Use a new preparation folder')
    probe = host.read_json(inspection)
    host.check(all(probe.get(name) is True for name in ('safeCandidate', 'outsideDocumentRoot', 'outsideActualSiteRoot', 'candidateWritable')), 'Storage inspection invalid')
    host.check(probe.get('symlinkRejected') is False, 'Storage symlink rejected')
    key_path = key_path.resolve()
    host.check(not key_path.is_relative_to(host.ROOT.resolve()), 'Source key must stay outside repository')
    key_data = key_path.read_bytes()
    validate_key(key_data)
    key_receipt = host.backup_bytes(folder / 'service-account.dpapi', key_data)
    hashes = {}
    backups = []
    for name in FILES:
        data = host.remote(name)
        if name.endswith('mobile-closed-test.enabled'):
            host.check(data.strip() == b'on', 'Closed-test marker is off; stop without changing it')
        target = folder / 'before' / (name + '.dpapi')
        target.parent.mkdir(parents=True, exist_ok=True)
        record = host.backup_bytes(target, data)
        hashes[name.removeprefix('api/')] = record['sha256']
        backups.append({'path': name, **record})
    host.check(host.denied('api/config-data/.play-setup-deny-check'), 'Protected staging not denied')
    health = host.public('api/mobile.php')
    host.check(health.get('ok') and health.get('playConfigured') is False, 'Play already configured; stop')
    baseline = {'files': hashes, 'candidateDirectorySha256': host.sha(probe['candidateDirectory'].encode()), 'keySha256': key_receipt['sha256']}
    host.save(folder / 'prepared.json', {'baseline': baseline, 'keyBackup': key_receipt,
              'backups': backups, 'candidateDirectory': probe['candidateDirectory'],
              'sourceKeyPath': str(key_path), 'playConfigured': False,
              'operatorSha256': host.sha((host.ROOT / 'tools/play_verifier_setup_operator.php').read_bytes()),
              'preparedAtUtc': datetime.now(timezone.utc).isoformat()})
    return {'ok': True, 'action': 'prepare', 'encryptedBackups': len(backups) + 1,
            'dpapiRoundtripVerified': True, 'outsideDocumentRoot': True,
            'keyTransferred': False, 'privateConfigChanged': False, 'playActivated': False}


def run_endpoint(folder, mode, allow_install):
    prepared = host.read_json(folder / 'prepared.json')
    template = (host.ROOT / 'tools/play_verifier_setup_operator.php').read_bytes()
    host.check(host.sha(template) == prepared['operatorSha256'], 'Operator changed after preparation')
    baseline = prepared['baseline']
    for name in FILES:
        host.check(host.sha(host.remote(name)) == baseline['files'][name.removeprefix('api/')], 'Live baseline changed; stop and audit again')
    # Verify the encrypted backup again before any write (including endpoint upload).
    key_data = host.crypt((folder / 'service-account.dpapi').read_bytes(), True)
    host.check(host.sha(key_data) == baseline['keySha256'], 'Key backup mismatch')
    validate_key(key_data)
    payload = {'action': mode}
    if mode == 'install_key':
        host.check(allow_install, 'Key transfer needs explicit --allow-install')
        payload.update(allowInstall=True, keyBase64=base64.b64encode(key_data).decode())
    token = secrets.token_hex(32)
    endpoint = 'api/_play_setup_' + secrets.token_hex(12) + '.php'
    source = template.decode('utf-8-sig').replace('__TOKEN__', token).replace('__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1200)).replace('__BASELINE__', base64.b64encode(json.dumps(baseline).encode()).decode()).encode()
    ftp = host.connect()
    uploaded = False
    try:
        uploaded = True  # register before STOR, including partial-write failures
        ftp.storbinary('STOR ' + endpoint, io.BytesIO(source))
        host.check(host.remote(endpoint) == source, 'Operator readback mismatch')
        request = urllib.request.Request(host.ORIGIN + endpoint, data=json.dumps(payload).encode(),
                    headers={'Content-Type': 'application/json', 'X-Untouch-Test': token})
        with urllib.request.urlopen(request, timeout=110) as response:
            result = json.load(response)
        host.check(result.get('ok') and result.get('playActivated') is False and result.get('privateConfigUnchanged') is True, 'Setup proof rejected')
        for name in FILES:
            host.check(host.sha(host.remote(name)) == baseline['files'][name.removeprefix('api/')], 'Post-operation baseline changed')
        host.check(host.public('api/mobile.php').get('playConfigured') is False, 'Unexpected payment activation')
        host.save(folder / (mode + '-' + datetime.now(timezone.utc).strftime('%H%M%S') + '.json'), result)
        return result
    finally:
        ftp.close()
        if uploaded:
            cleanup = host.connect()
            try:
                if endpoint.rsplit('/', 1)[1] in host.inventory('api'):
                    cleanup.delete(endpoint)
                host.check(endpoint.rsplit('/', 1)[1] not in host.inventory('api'), 'Operator cleanup not confirmed')
            finally:
                cleanup.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('prepare', 'install_key', 'verify_key', 'catalog'), required=True)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--inspection', type=Path, default=host.ROOT / '.private/play-server-setup-20261015-inspect1/storage-inspection.json')
    parser.add_argument('--key-path', type=Path, default=DEFAULT_KEY)
    parser.add_argument('--allow-install', action='store_true')
    args = parser.parse_args()
    folder = args.directory.resolve()
    host.check(folder.is_relative_to((host.ROOT / '.private').resolve()), 'Output must be private')
    folder.mkdir(parents=True, exist_ok=True)
    host.CREDENTIALS = json.load(sys.stdin)
    result = prepare(folder, args.inspection, args.key_path) if args.mode == 'prepare' else run_endpoint(folder, args.mode, args.allow_install)
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'ok': False, 'errorType': type(error).__name__, 'error': 'Play setup stopped; inspect private receipts; no config activation'}))
        sys.exit(1)
