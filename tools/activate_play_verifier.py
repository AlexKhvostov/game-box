"""Separate private Play activation, requiring explicit root GO; prepare is read-only."""
import argparse
import base64
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import secrets
import sys
import urllib.request
import urllib.error
import android_host_tools as host
import setup_play_verifier as installer

FILES = installer.FILES + ('api/config-data/published.json',)


def valid_catalog(catalog):
    expected = {'energy_100_v1','energy_250_v1','energy_500_v1','energy_1000_v1','energy_batteries_2_v1','energy_batteries_5_v1'}
    rows = catalog.get('catalog', [])
    return (catalog.get('oauthReady') is True and len(rows) == 6 and
            {row.get('productId') for row in rows} == expected and
            all(row.get('found') is True and type(row.get('httpStatus')) is int and row.get('httpStatus') == 200 and
                (not row['productId'].startswith('energy_batteries_') or
                 (row.get('weeklyBasePlanFound') is True and row.get('weeklyBasePlanActive') is True)) for row in rows))


def prepare(folder, installed_folder):
    host.check(not (folder / 'prepared.json').exists(), 'Use a fresh activation directory')
    installed = host.read_json(installed_folder / 'prepared.json')
    proofs = list(installed_folder.glob('verify_key-*.json'))
    host.check(proofs and host.read_json(proofs[-1]).get('ok'), 'Separate key verification required')
    catalog_files = list(installed_folder.glob('catalog-*.json'))
    host.check(catalog_files, 'Read-only Google catalog proof required before activation preparation')
    catalog = host.read_json(catalog_files[-1])
    host.check(valid_catalog(catalog),
               'All six catalog products and both weekly base plans must be ready')
    baseline = {key: value for key, value in installed['baseline'].items() if key != 'files'}
    baseline['files'] = {}
    records = []
    for name in FILES:
        data = host.remote(name)
        if name.endswith('mobile-closed-test.enabled'):
            host.check(data.strip() == b'on', 'Marker off; do not change it')
        target = folder / 'before' / (name + '.dpapi')
        target.parent.mkdir(parents=True, exist_ok=True)
        record = host.backup_bytes(target, data)
        baseline['files'][name.removeprefix('api/')] = record['sha256']
        records.append({'path': name, **record})
    host.check(host.public('api/mobile.php').get('playConfigured') is False, 'Play already activated; stop')
    host.check(host.denied('api/config-data/.play-activation-deny-check'), 'Private staging not denied')
    host.save(folder / 'prepared.json', {'baseline': baseline, 'backups': records,
             'operatorSha256': host.sha((host.ROOT / 'tools/play_verifier_activation_operator.php').read_bytes()),
             'catalogProofSha256': host.sha(catalog_files[-1].read_bytes()),
             'createdAtUtc': datetime.now(timezone.utc).isoformat()})
    return {'ok': True, 'action': 'prepare', 'dpapiBackups': len(records), 'roundtripVerified': True, 'configChanged': False}


def apply(folder, allowed):
    host.check(allowed, 'Activation requires explicit --allow-activation and root GO')
    host.check(not (folder/'activation-attempt.json').exists(), 'Previous activation attempt exists; reconcile before any retry')
    prepared = host.read_json(folder / 'prepared.json')
    template = (host.ROOT / 'tools/play_verifier_activation_operator.php').read_bytes()
    host.check(host.sha(template) == prepared['operatorSha256'], 'Operator changed after preparation')
    for name in FILES:
        relative = name.removeprefix('api/')
        backup = folder / 'before' / (name + '.dpapi')
        host.check(host.sha(host.crypt(backup.read_bytes(), True)) == prepared['baseline']['files'][relative], 'Backup verification failed')
        host.check(host.sha(host.remote(name)) == prepared['baseline']['files'][relative], 'Live baseline changed; stop')
    token = secrets.token_hex(32)
    endpoint = 'api/_play_activate_' + secrets.token_hex(12) + '.php'
    source = template.decode('utf-8-sig').replace('__TOKEN__', token).replace('__EXPIRES__', str(int(datetime.now(timezone.utc).timestamp()) + 1200)).replace('__BASELINE__', base64.b64encode(json.dumps(prepared['baseline']).encode()).decode()).encode()
    stage_id = secrets.token_hex(32)
    host.save(folder/'activation-attempt.json',{'stageId':stage_id,'baselinePrivateSha256':prepared['baseline']['files']['mobile_config.php'],'manualReconciliationOnFailure':True})
    ftp = host.connect(); uploaded = False
    try:
        uploaded = True
        ftp.storbinary('STOR ' + endpoint, io.BytesIO(source))
        host.check(host.remote(endpoint) == source, 'Activation operator readback failed')
        def post(payload):
            request = urllib.request.Request(host.ORIGIN + endpoint, data=json.dumps(payload).encode(),
                        headers={'Content-Type': 'application/json', 'X-Untouch-Test': token})
            try:
                with urllib.request.urlopen(request, timeout=110) as response: return json.load(response)
            except urllib.error.HTTPError as error:
                # Recoverable metadata only; never persist a stage's private candidate body on error.
                raw = error.read(16384)
                try: receipt = json.loads(raw)
                except (ValueError,UnicodeDecodeError): receipt = {}
                safe = {key: receipt.get(key) for key in ('ok','error','configWritten','candidateRetained','automaticRollback','manualReconciliationRequired')}
                safe.update(httpStatus=error.code,stageId=stage_id,phase=payload['action'])
                host.save(folder/'activation-recovery.json',safe)
                raise RuntimeError('Server activation failed; recovery receipt saved') from None
            except Exception:
                host.save(folder/'activation-recovery.json',{'stageId':stage_id,'phase':payload['action'],'responseLost':True,'manualReconciliationRequired':True,'doNotRetryBlindly':True})
                raise
        staged = post({'action':'stage','allowActivation':True,'stageId':stage_id})
        host.check(staged.get('ok') and staged.get('privateConfigUnchanged') is True and staged.get('durableCandidateSaved') is True, 'Candidate stage failed')
        candidate = base64.b64decode(staged.pop('candidateBase64'),validate=True)
        host.check(host.sha(candidate)==staged['candidateSha256'],'Candidate transport hash mismatch')
        staged.update(stageId=stage_id,localCandidateDpapiRoundtrip=False)
        host.save(folder/'candidate-staged.json',staged)
        record = host.backup_bytes(folder/'candidate-before-expose.dpapi',candidate)
        host.check(record['dpapiRoundtripVerified'],'Candidate backup roundtrip failed')
        staged.update(localCandidateDpapiRoundtrip=True)
        host.save(folder/'candidate-staged.json',staged)
        result = post({'action':'activate','allowActivation':True,'stageId':stage_id,'candidateSha256':staged['candidateSha256']})
        host.check(result.get('ok') and result.get('onlyRequiredPrivateKeysChanged') and result.get('playConfigured'), 'Activation proof failed; do not retry blindly')
        for name in FILES:
            expected = result['privateConfigSha256'] if name == 'api/mobile_config.php' else prepared['baseline']['files'][name.removeprefix('api/')]
            host.check(host.sha(host.remote(name)) == expected, 'Activation readback mismatch; inspect before retry')
        host.check(host.public('api/mobile.php').get('playConfigured') is True, 'Play health not ready')
        # The new private token key is only stored encrypted in this backup, never in stdout.
        record = host.backup_bytes(folder / 'private-after.dpapi', host.remote('api/mobile_config.php'))
        result['afterBackupRoundtripVerified'] = record['dpapiRoundtripVerified']
        host.save(folder / 'activated.json', result)
        return result
    finally:
        ftp.close()
        if uploaded:
            cleanup = host.connect()
            try:
                if endpoint.rsplit('/', 1)[1] in host.inventory('api'): cleanup.delete(endpoint)
                host.check(endpoint.rsplit('/', 1)[1] not in host.inventory('api'), 'Activation endpoint cleanup not confirmed')
            finally: cleanup.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('prepare', 'apply'), required=True)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--installed-directory', type=Path, default=host.ROOT / '.private/play-server-setup-20261015-prepare1')
    parser.add_argument('--allow-activation', action='store_true')
    args = parser.parse_args()
    folder = args.directory.resolve()
    host.check(folder.is_relative_to((host.ROOT / '.private').resolve()), 'Private output required')
    folder.mkdir(parents=True, exist_ok=True)
    host.CREDENTIALS = json.load(sys.stdin)
    result = prepare(folder, args.installed_directory) if args.mode == 'prepare' else apply(folder, args.allow_activation)
    print(json.dumps(result))


if __name__ == '__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'ok': False, 'errorType': type(error).__name__, 'error': 'Activation stopped; inspect private receipts and health before any retry'}))
        sys.exit(1)
