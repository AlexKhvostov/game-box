"""Physical, isolated Energy V2 acceptance. No production wallet, payment or mail."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/release-evidence/energy-v2-20261015/physical'
ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe'
ENDPOINT = 'http://127.0.0.1:8892/'


def main():
    global OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--output', type=Path, help='Separate evidence directory; preserve earlier release captures')
    args = parser.parse_args()
    if args.output is not None:
        OUT = args.output.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    devices = [line.split()[0] for line in subprocess.check_output([str(ADB), 'devices']).decode().splitlines()
               if '\tdevice' in line and not line.startswith('emulator-')]
    assert len(devices) == 1, 'Exactly one authorized physical Android required'
    def call(*values):
        return subprocess.check_output([str(ADB), '-s', devices[0], *map(str, values)])
    def state(screen=None, **values):
        url = ENDPOINT
        if screen is not None:
            values['screen'] = screen
            url += 'show?' + urllib.parse.urlencode(values)
        with urllib.request.urlopen(url, timeout=30) as response:
            data = json.load(response)
        assert not data['errors'], data['errors']
        assert data['allNetworkIntercepted'] and data['syntheticPrices']
        return data
    records = []
    def capture(name, data):
        (OUT / (name + '.png')).write_bytes(call('exec-out', 'screencap', '-p'))
        (OUT / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
        records.append({'name': name, 'energy': data['energy'], 'charge': data['charge'],
                        'capacity': data['capacity'], 'errors': data['errors']})
        print(name, 'PASS', flush=True)
    def tap(data, key):
        rect = data['rectangles'][key]
        call('shell', 'input', 'tap', round(rect['left'] + rect['width'] / 2),
             round(rect['top'] + rect['height'] / 2))
        time.sleep(.6)
        return state()
    size = call('shell', 'wm', 'size').decode()
    override = re.search(r'Override size: (\d+x\d+)', size)
    font = call('shell', 'settings', 'get', 'system', 'font_scale').decode().strip()
    try:
        call('shell', 'am', 'force-stop', 'com.best4u.untouch')
        call('forward', 'tcp:8892', 'tcp:8892')
        call('shell', 'input', 'keyevent', '224')
        assert 'mIsShowing=true' not in call('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
        call('shell', 'am', 'start', '-n', PACKAGE + '/com.best4u.untouch.MainActivity')
        for attempt in range(80):
            try:
                state(); break
            except (OSError, ValueError):
                if attempt == 79: raise
                time.sleep(.25)
        initial = state('home')
        capture('40-home', initial)
        primary_rect = None
        for name in ['charge', 'tasks', 'friends', 'buy']:
            data = state(name)
            assert data['energy'] == 47
            rect = data['rectangles']['energy-sheet']
            if primary_rect is None: primary_rect = rect
            assert rect == primary_rect, (name, rect, primary_rect)
            capture({'charge':'01-charge','tasks':'02-tasks','friends':'03-friends','buy':'04-buy'}[name], data)
        if args.quick: return
        for name, screen, values in [
            ('07-friends-empty','friends',{'friends':0}),
            ('08-charge-two','charge',{'slots':2}),
            ('09-charge-five','charge',{'slots':5,'percent':45}),
            ('10-charge-full','charge',{'percent':100}),
            ('12-charge-empty','charge',{'percent':0}),
            ('13-subscriber-tasks','tasks',{'slots':2}),
            ('14-achievements','achievements',{}),
            ('15-feedback','feedback',{}),
            ('19-subscription','subscription',{}),
            ('20-subscription-two','subscription',{'slots':2}),
            ('21-subscription-five','subscription',{'slots':5}),
            ('27-helmet-off','helmet',{}),
            ('28-helmet-on','helmet',{'helmet':'true'}),
            ('29-jump-off','jump',{}),
            ('30-jump-on','jump',{'jump':'true'}),
            ('32-tasks-claimed','tasks',{'state':'claimed'}),
            ('41-home-empty','home',{'balance':0}),
            ('42-home-large','home',{'balance':12345678}),
            ('43-home-abilities','home',{'helmet':'true','jump':'true'}),
            ('45-mixed-new-batteries','charge',{'slots':5,'percent':100,'state':'mixed'}),
            ('46-subscription-verification','charge',{'slots':2,'state':'pending'}),
        ]:
            capture(name, state(screen, **values))
        charged = state('charge')
        collected = tap(charged, 'energy-claim')
        assert collected['energy'] == 66 and collected['charge'] == 0
        capture('11-collected-confirmed', collected)
        friends = state('friends')
        fixed = friends['rectangles']['energy-friends-fixed']
        info = tap(friends, 'energy-friends-info')
        capture('05-friends-info', info)
        call('shell', 'input', 'keyevent', '4')
        time.sleep(.5)
        friends = state()
        rows = friends['rectangles']['energy-friends-list']
        x = round(rows['left'] + rows['width'] / 2)
        call('shell', 'input', 'swipe', x, round(rows['top'] + rows['height'] * .85),
             x, round(rows['top'] + rows['height'] * .1), 420)
        time.sleep(.5)
        scrolled = state()
        assert scrolled['rectangles']['energy-friends-fixed'] == fixed
        assert any(s['pixels'] > 0 for s in scrolled['scrolls']), scrolled['scrolls']
        capture('06-friends-scrolled', scrolled)
        feedback = state('feedback')
        tap(feedback, 'energy-feedback-text')
        call('shell', 'input', 'text', '1234567890123456789')
        time.sleep(.4)
        capture('38-feedback-19', state())
        call('shell', 'input', 'text', '0')
        time.sleep(.4)
        capture('39-feedback-20', state())
        call('shell', 'input', 'keyevent', '4')
        time.sleep(.5)
        feedback = tap(state(), 'energy-feedback-send')
        assert feedback['energy'] == 67
        capture('17-feedback-confirmed', feedback)
        density = int(re.findall(r'\d+', call('shell', 'wm', 'density').decode())[-1]) / 160
        for width in [320, 390]:
            for height in [760, 568, 480]:
                call('shell', 'wm', 'size', f'{round(width*density)}x{round(height*density)}')
                time.sleep(.65)
                for scale in [1, 1.2]:
                    baseline = None
                    for screen in ['charge','tasks','friends','buy']:
                        data = state(screen, scale=scale)
                        rect = data['rectangles']['energy-sheet']
                        if baseline is None: baseline = rect
                        assert baseline == rect
                        capture(f'matrix-{width}x{height}-font{scale}-{screen}', data)
        call('shell', 'wm', 'size', override.group(1) if override else 'reset')
        call('shell', 'settings', 'put', 'system', 'font_scale', '2.0')
        time.sleep(.8)
        for screen in ['charge','tasks','friends','buy','helmet','jump','subscription','feedback']:
            # 2.0 comes from the actual Android setting as well as the explicit
            # fixture text scaler, then passes through the production GameViewport.
            capture('system-font200-' + screen, state(screen, scale=2.0))
        (OUT/'verification.json').write_text(json.dumps({'ok':True,'states':len(records),
          'cases':records,'physicalDevice':'Huawei P30 Lite','mode':'profile',
          'realPayments':False,'realMail':False,'productionWalletAccess':False,
          'allApiIntercepted':True,'prices':'synthetic QA only'}, ensure_ascii=False, indent=2), encoding='utf-8')
    finally:
        call('shell', 'am', 'force-stop', PACKAGE)
        call('shell', 'am', 'force-stop', 'com.best4u.untouch')
        call('shell', 'wm', 'size', override.group(1) if override else 'reset')
        call('shell', 'settings', 'put', 'system', 'font_scale', font)
        call('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', '2')


if __name__ == '__main__':
    main()
