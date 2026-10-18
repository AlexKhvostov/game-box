"""Capture design-matched fixtures on an isolated native Android package.

Never opens the owner's app or presses a Google purchase/login confirmation.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
devices = [line.split()[0] for line in subprocess.check_output([str(ADB), 'devices']).decode().splitlines()
           if '\tdevice' in line and not line.startswith('emulator-')]
assert len(devices) == 1


def adb(*values):
    return subprocess.check_output([str(ADB), '-s', devices[0], *map(str, values)])


def state(screen=None, **query):
    path = 'http://127.0.0.1:8892/'
    if screen:
        query = {'balance': 7, 'percent': 95, **query, 'screen': screen}
        path += 'show?' + urllib.parse.urlencode(query)
    with urllib.request.urlopen(path, timeout=30) as response:
        result = json.load(response)
    assert not result['errors'], result['errors']
    assert result['syntheticPrices'] and result['allNetworkIntercepted']
    return result


def tap(data, key):
    rect = data['rectangles'][key]
    adb('shell', 'input', 'tap', round(rect['left'] + rect['width'] / 2),
        round(rect['top'] + rect['height'] / 2))
    time.sleep(.6)
    return state()


records = []


def save(name, data):
    assert not (out / (name + '.png')).exists(), 'Do not replace earlier evidence'
    (out / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
    (out / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    records.append({'name': name, 'errors': data['errors'], 'energy': data['energy'],
                    'charge': data['charge'], 'capacity': data['capacity']})
    print(name + ' PASS', flush=True)


try:
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('forward', 'tcp:8892', 'tcp:8892')
    adb('shell', 'input', 'keyevent', '224')
    assert 'mIsShowing=true' not in adb('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            state()
            break
        except OSError:
            if attempt == 59:
                raise
            time.sleep(.25)
    bounds = None
    for name, screen, query in [
        ('01-charge', 'charge', {}),
        ('02-tasks', 'tasks', {'linked': 'false', 'age': 'unknown'}),
        ('03-friends', 'friends', {}), ('04-buy', 'buy', {}),
        ('07-friends-empty', 'friends', {'friends': 0}),
        ('08-charge-two', 'charge', {'slots': 2}),
        ('09-charge-five', 'charge', {'slots': 5}),
        ('10-charge-full', 'charge', {'percent': 100}),
        ('12-charge-empty', 'charge', {'percent': 0, 'balance': 0}),
        ('13-subscriber-tasks', 'tasks', {'slots': 2}),
        ('14-achievements', 'achievements', {}), ('15-feedback', 'feedback', {}),
        ('14a-achievements-eight-seconds', 'achievements', {'bestTimeMs': 8000, 'riskUnlocked': 'false'}),
        ('14b-achievements-fourteen-seconds', 'achievements', {'bestTimeMs': 14000, 'riskUnlocked': 'false'}),
        ('14c-achievements-claimed', 'achievements', {'state': 'claimed'}),
        ('19-subscription', 'subscription', {}),
        ('20-subscription-two', 'subscription', {'slots': 2}),
        ('31-subscription-five', 'subscription', {'slots': 5}),
        ('27-helmet-off', 'helmet', {}), ('28-helmet-on', 'helmet', {'helmet': 'true'}),
        ('29-jump-off', 'jump', {}), ('30-jump-on', 'jump', {'jump': 'true'}),
        ('32-tasks-claimed', 'tasks', {'state': 'claimed'}),
        ('40-home', 'home', {'balance': 47}), ('41-home-empty', 'home', {'balance': 0}),
        ('42-home-large', 'home', {'balance': 12345678}),
        ('43-home-abilities', 'home', {'helmet': 'true', 'jump': 'true', 'balance': 47}),
        ('45-charge-mixed', 'charge', {'slots': 5, 'state': 'mixed', 'percent': 100}),
        ('46-subscription-pending', 'charge', {'slots': 2, 'state': 'pending'}),
    ]:
        data = state(screen, **query)
        if name in ['01-charge', '02-tasks', '03-friends', '04-buy']:
            current = data['rectangles']['energy-sheet']
            if bounds is None:
                bounds = current
            assert current == bounds, (name, current, bounds)
        save(name, data)
    save('05-friends-help', tap(state('friends'), 'energy-friends-info'))
    for index, amount in enumerate([100, 250, 500, 1000], 23):
        current = state('buy')
        key = f'energy-buy-energy_{amount}_v1'
        if key not in current['rectangles']:
            key = f'energy-pack-energy_{amount}_v1'
        confirmed = tap(current, key)
        assert 'energy-purchase-confirm' in confirmed['rectangles']
        save(f'{index:02d}-purchase-{amount}', confirmed)
    for name, extra in [('21-subscribe-two', 1), ('22-subscribe-five', 4)]:
        save(name, tap(state('subscription'), f'energy-subscribe-{extra}'))
    home = state('home', balance=47)
    opened = tap(home, 'hud-energy-card')
    assert opened['energy'] == 47 and 'energy-sheet' in opened['rectangles']
    save('44-home-opened-energy', opened)
    charged = state('charge')
    collected = tap(charged, 'energy-claim')
    assert collected['energy'] == 26 and collected['charge'] == 0
    save('11-collected-confirmed', collected)
    feedback = state('feedback')
    tap(feedback, 'energy-feedback-text')
    adb('shell', 'input', 'text', '1234567890123456789')
    time.sleep(.4)
    save('38-feedback-short', state())
    adb('shell', 'input', 'text', '0')
    time.sleep(.4)
    save('39-feedback-ready-keyboard', state())
    adb('shell', 'input', 'keyevent', '4')
    time.sleep(.5)
    save('16-feedback-ready', state())
    sent = tap(state(), 'energy-feedback-send')
    assert sent['energy'] == 27
    save('17-feedback-confirmed', sent)
    # Existing forms: inspect only, never press native sign-in or send a login.
    save('33-google-existing-form', tap(state('tasks', linked='false'), 'energy-task-google'))
    ad_result = tap(state('tasks'), 'energy-task-watch_ad')
    assert ad_result['energy'] == 7
    save('18-video-existing-gate', ad_result)
    (out / 'design-verification.json').write_text(json.dumps({
        'ok': True, 'states': len(records), 'cases': records,
        'physicalDevice': 'Huawei P30 Lite', 'mode': 'profile',
        'allApiIntercepted': True, 'syntheticPrices': True,
        'ownerAppOpened': False, 'realPayments': False, 'realMessages': False,
    }, ensure_ascii=False, indent=2), encoding='utf-8')
finally:
    adb('shell', 'am', 'force-stop', PACKAGE)
