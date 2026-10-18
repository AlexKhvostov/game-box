"""Physical geometry/countdown acceptance using the isolated native energy probe."""
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/release-evidence/energy-bonus30-hidden20-20261016/centering'
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe.simpleenergy'


def main():
    devices = [line.split()[0] for line in subprocess.check_output([str(ADB), 'devices']).decode().splitlines()
               if '\tdevice' in line and not line.startswith('emulator-')]
    assert len(devices) == 1, 'One authorized physical phone required'

    def adb(*args):
        return subprocess.check_output([str(ADB), '-s', devices[0], *map(str, args)])

    def state(**query):
        path = 'show?' + urllib.parse.urlencode(query) if query else ''
        with urllib.request.urlopen('http://127.0.0.1:8897/' + path, timeout=10) as response:
            data = json.load(response)
        assert not data['errors'], data['errors']
        return data

    def tap(data, key):
        rect = data['rectangles'][key]
        adb('shell', 'input', 'tap', round(rect['left'] + rect['width'] / 2), round(rect['top'] + rect['height'] / 2))
        time.sleep(.25)
        return state()

    records = []

    def save(name, data):
        (OUT / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
        (OUT / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p'))

    OUT.mkdir(exist_ok=True)
    assert 'tcp:8897' not in adb('forward', '--list').decode(), 'Acceptance port already owned'
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
    adb('forward', 'tcp:8897', 'tcp:8897')
    try:
        adb('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
        for attempt in range(60):
            try:
                state()
                break
            except OSError:
                if attempt == 59:
                    raise
                time.sleep(.15)
        for tier in [1, 2, 5]:
            for cooling in [False, True]:
                data = state(screen='energy', slots=tier, state='cooldown' if cooling else 'ready')
                orb = data['rectangles']['simple-bonus-orb']
                value = data['rectangles']['simple-bonus-value']
                error = abs(orb['left'] + orb['width'] / 2 - value['left'] - value['width'] / 2)
                assert error < 1.5, error
                assert data['starts'] == 0
                name = ('cooldown' if cooling else 'ready') + '-' + str(tier * 30)
                save(name, data)
                records.append({'name': name, 'digitCenterErrorPhysicalPx': error})
        data = state(screen='energy', balance=50)
        data = tap(data, 'simple-bonus-orb')
        assert data['energy'] == 80 and data['wallet']['simpleBonus']['nextAt'] > 0
        save('after-claim30', data)
        def seconds(data):
            timer = next(text for text in data['texts'] if re.fullmatch(r'0[78]:[0-5]\d:[0-5]\d', text))
            h, m, s = map(int, timer.split(':'))
            return h * 3600 + m * 60 + s
        first = seconds(data)
        assert 28780 < first <= 28800
        time.sleep(2.2)
        data = state()
        second = seconds(data)
        assert second < first and first - second < 8
        save('timer-advances', data)
        data = tap(data, 'simple-bonus-orb')
        assert data['energy'] == 80
        data = tap(data, 'simple-energy-close')
        data = tap(data, 'hud-energy-card')
        assert data['energy'] == 80 and seconds(data) <= second and data['starts'] == 0
        save('reopened-same-countdown', data)
        result = {'ok': True, 'geometry': records, 'claimEnergy': 30, 'balance': 80,
                  'firstSeconds': first, 'laterSeconds': second, 'repeatCredit': False,
                  'reopenPreservesCountdown': True, 'serverAndPricesSynthetic': True, 'realRounds': 0}
        (OUT / 'physical-summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(result))
    finally:
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
        adb('forward', '--remove', 'tcp:8897')


if __name__ == '__main__':
    main()
