"""Capture the guarded, isolated native UI kit; never interacts with real accounts."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--directory', type=Path, default=ROOT / 'docs/design/neon-ui-kit-20261015')
parser.add_argument('--only', nargs='*')
parser.add_argument('--resume', action='store_true')
args = parser.parse_args()
OUT = args.directory.resolve()
catalog = json.loads((OUT / 'catalog.json').read_text(encoding='utf-8-sig'))
assert catalog['syntheticOnly'] is True
BASE = catalog['controlBase']
assert BASE == 'http://127.0.0.1:8894'
screens = OUT / 'screens'
screens.mkdir(parents=True, exist_ok=True)
artifact_path = OUT / 'capture-build.json'
artifact = json.loads(artifact_path.read_text(encoding='utf-8')) if artifact_path.is_file() else {}
devices = [line.split()[0] for line in subprocess.check_output([str(ADB), 'devices']).decode().splitlines()
           if '\tdevice' in line and not line.startswith('emulator-')]
assert len(devices) == 1, 'Exactly one physical test device required'


def adb(*values):
    return subprocess.check_output([str(ADB), '-s', devices[0], *map(str, values)])


def state(row=None):
    path = '/state'
    if row:
        path = '/show?' + urllib.parse.urlencode({'screen': row['screen'], **row.get('params', {})})
    try:
        with urllib.request.urlopen(BASE + path, timeout=45) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'{path}: HTTP {error.code}: {detail}') from error
    assert not result.get('errors'), result.get('errors')
    assert result.get('allApiIntercepted') is True or result.get('allNetworkIntercepted') is True
    return result


def check(row, data):
    keys = data.get('rectangles', {})
    for key in row.get('expectedKeys', []):
        assert key in keys, f"{row['id']}: missing key {key}"
    text = '\n'.join(data.get('texts', data.get('visibleTexts', [])))
    for expected in row.get('expectedTexts', []):
        assert expected in text, f"{row['id']}: missing text {expected}"


records = []
try:
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('forward', 'tcp:8894', 'tcp:8894')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
    for attempt in range(80):
        try:
            state()
            break
        except OSError:
            if attempt == 79:
                raise
            time.sleep(.25)
    for row in catalog['screens']:
        if args.only and row['id'] not in args.only:
            continue
        assert re.fullmatch(r'[a-z0-9][a-z0-9-]*', row['id'])
        target = screens / (row['id'] + '.png')
        if args.resume and target.is_file() and (screens / (row['id'] + '.json')).is_file():
            saved = json.loads((screens / (row['id'] + '.json')).read_text(encoding='utf-8'))
            check(row, saved)
            records.append({'id': row['id'], 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'resumed': True})
            continue
        assert not target.exists(), 'Do not overwrite earlier captures: ' + row['id']
        before = state(row)
        assert before.get('renderComplete') is True, row['id'] + ': render incomplete'
        assert before.get('currentScreen') == row['screen'], row['id'] + ': wrong scene'
        check(row, before)
        png = adb('exec-out', 'screencap', '-p')
        after = state()
        assert after.get('renderComplete') is True
        check(row, after)
        for key in ['currentScreen', 'revisionToken']:
            if key in before:
                assert before[key] == after[key], f'{row["id"]}: changed scene during capture'
        assert png.startswith(b'\x89PNG\r\n\x1a\n')
        target.write_bytes(png)
        before['captureArtifact'] = artifact
        (screens / (row['id'] + '.json')).write_text(json.dumps(before, ensure_ascii=False, indent=2), encoding='utf-8')
        records.append({'id': row['id'], 'sha256': hashlib.sha256(png).hexdigest(), 'errors': []})
        print(row['id'] + ' PASS', flush=True)
    (OUT / ('capture-verification-partial.json' if args.only else 'capture-verification.json')).write_text(json.dumps({
        'ok': True, 'completed': len(records), 'catalogueCount': len(catalog['screens']), 'device': 'Huawei P30 Lite',
        'allApiIntercepted': True, 'syntheticData': True, 'syntheticPrices': True, 'ownerAppOpened': False,
        'realPayments': False, 'realMessages': False, 'realGoogleActions': False, 'cases': records,
    }, ensure_ascii=False, indent=2), encoding='utf-8')
finally:
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
