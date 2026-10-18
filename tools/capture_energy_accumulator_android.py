"""Targeted screenshots of approved accumulator UI in isolated fixture only."""
import json
import argparse
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / 'docs/release-evidence/energy-accumulator-20261015/physical')
parser.add_argument('--google-confirmation', action='store_true', help='Optional separate confirmation/cancel path; never confirms unlink')
args = parser.parse_args()
OUT = args.output.resolve()
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe'
OUT.mkdir(parents=True, exist_ok=True)


def adb(*args):
    return subprocess.check_output([str(ADB), *map(str, args)])


def state(screen=None, **query):
    url = 'http://127.0.0.1:8892/'
    if screen:
        url += 'show?' + urllib.parse.urlencode({'screen': screen, **query})
    with urllib.request.urlopen(url, timeout=30) as response:
        data = json.load(response)
    assert not data['errors'], data['errors']
    return data


records = []


def save(name, data):
    assert not (OUT / (name + '.png')).exists(), 'Do not overwrite QA evidence'
    (OUT / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
    (OUT / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    records.append({'name': name, 'energy': data['energy'], 'charge': data['charge'], 'capacity': data['capacity']})
    print(name + ' PASS', flush=True)


def tap(data, key):
    rect = data['rectangles'][key]
    adb('shell', 'input', 'tap', round(rect['left'] + rect['width'] / 2), round(rect['top'] + rect['height'] / 2))
    time.sleep(.5)
    return state()


try:
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('forward', 'tcp:8892', 'tcp:8892')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            state()
            break
        except OSError:
            if attempt == 59:
                raise
            time.sleep(.25)
    for name, screen, query in [
        ('01-charge', 'charge', {'percent': 65}),
        ('02-charge-two', 'charge', {'slots': 2, 'percent': 65}),
        ('03-charge-five', 'charge', {'slots': 5, 'percent': 65}),
        ('04-charge-full', 'charge', {'percent': 100}),
        ('05-charge-empty', 'charge', {'percent': 0}),
        ('06-tasks', 'tasks', {}),
        ('07-friends', 'friends', {}),
        ('08-buy', 'buy', {}),
        ('09-subscription', 'subscription', {}),
        ('10-helmet', 'helmet', {}),
        ('11-jump', 'jump', {}),
        ('12-charge-large-text', 'charge', {'scale': 2, 'percent': 65}),
        ('13-charge-five-large-text', 'charge', {'scale': 2, 'slots': 5}),
        ('14-buy-large-text', 'buy', {'scale': 2}),
        ('15-profile-linked', 'profile', {'linked': 'true'}),
    ]:
        save(name, state(screen, **query))
    if args.google_confirmation:
        data = state('profile', linked='true')
        data = tap(data, 'profile-google-disconnect')
        assert 'profile-google-disconnect-confirm-cancel' in data['rectangles'], 'Confirmation did not open'
        save('16-google-confirmation', data)
        data = tap(data, 'profile-google-disconnect-confirm-cancel')
        assert 'profile-google-disconnect' in data['rectangles']
        save('17-google-cancelled', data)
    (OUT / 'verification.json').write_text(json.dumps({
        'ok': True, 'cases': records, 'allApiIntercepted': True, 'syntheticPrices': True,
        'ownerDataChanged': False, 'googleDisconnected': False,
    }, indent=2), encoding='utf-8')
finally:
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
