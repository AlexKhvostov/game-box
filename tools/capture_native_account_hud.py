"""Physical native UI checks; isolated package and synthetic account only."""
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/release-evidence/native-account-hud-20261016/physical/account'
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe.simpleenergy'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    devices = [line.split()[0] for line in subprocess.check_output([str(ADB), 'devices']).decode().splitlines() if '\tdevice' in line and not line.startswith('emulator-')]
    assert len(devices) == 1
    def adb(*args):
        return subprocess.check_output([str(ADB), '-s', devices[0], *map(str, args)])
    def state(**query):
        path = 'show?' + urllib.parse.urlencode(query) if query else ''
        with urllib.request.urlopen('http://127.0.0.1:8897/' + path, timeout=25) as response:
            return json.load(response)
    def start():
        adb('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
        for attempt in range(80):
            try:
                return state()
            except OSError:
                if attempt == 79:
                    raise
                time.sleep(.15)
    def tap(data, key):
        for _ in range(6):
            if key in data['rectangles']:
                break
            r = data['rectangles'].get('profile-content')
            if not r:
                time.sleep(.4)
            else:
                x = round(r['left'] + r['width']/2)
                adb('shell','input','swipe',x,round(r['top']+r['height']*.8),x,round(r['top']+r['height']*.35),180)
                time.sleep(.2)
            data = state()
        r = data['rectangles'][key]
        adb('shell', 'input', 'tap', round(r['left'] + r['width']/2), round(r['top'] + r['height']/2))
        time.sleep(.4)
        return state()
    records = []
    def save(name, data):
        assert not data['errors'], data['errors']
        assert data['starts'] == 0, 'Dialogs must never start a round'
        (OUT / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
        (OUT / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
        records.append(name)
        print(name, 'PASS', flush=True)
    failure = None
    try:
        adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
        adb('forward', 'tcp:8897', 'tcp:8897')
        cases = [
            ('profile-linked', dict(screen='profile')),
            ('profile-guest', dict(screen='profile', linked='false')),
            ('profile-en', dict(screen='profile', lang='en')),
            ('profile-large', dict(screen='profile', scale=2)),
            ('google-offer', dict(screen='google', linked='false')),
            ('disconnect', dict(screen='disconnect')),
            ('restore', dict(screen='restore')),
            ('reset-warning', dict(screen='reset')),
            ('hud-off', dict(screen='home')),
            ('hud-on', dict(screen='home', helmet='true', jump='true')),
            ('hud-large', dict(screen='home', helmet='true', jump='true', scale=2)),
            ('packs-price-button', dict(screen='packs')),
        ]
        for name, query in cases:
            start()
            data = state(**query)
            save(name, data)
            if name == 'google-offer':
                data = tap(data, 'google-startup-connect')
                assert 'google-startup-message' in data['rectangles']
                save('google-retry', data)
            adb('shell', 'am', 'force-stop', PACKAGE)
        start()
        data = state(screen='profile')
        data = tap(data, 'profile-support-expand')
        assert 'profile-help-content' in data['rectangles']
        save('help', data)
        adb('shell', 'input', 'keyevent', '4')
        time.sleep(.3)
        data = state()
        assert 'profile-content' in data['rectangles']
        data = tap(data, 'profile-age-edit')
        assert 'age-under18' in data['rectangles'] and 'age-adult18plus' in data['rectangles']
        save('age-two-answers', data)
        data = tap(data, 'age-under18')
        data = tap(data, 'age-continue')
        assert 'До 18 лет' in data['texts']
        save('age-saved', data)
        adb('shell', 'am', 'force-stop', PACKAGE)
        start()
        data = state(screen='profile')
        data = tap(data, 'inviter-info')
        assert 'inviter-info-dialog' in data['rectangles']
        save('inviter-info', data)
    except Exception as error:
        failure = type(error).__name__ + ': ' + str(error)
    finally:
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
        adb('forward', '--remove', 'tcp:8897')
    report = dict(ok=failure is None, failure=failure, records=records, syntheticAccount=True, realGoogleOrPayments=False, gamesStopped=True)
    (OUT / 'acceptance.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    if failure:
        raise RuntimeError(failure)

if __name__ == '__main__':
    main()
