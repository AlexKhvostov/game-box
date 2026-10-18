"""Isolated physical UI checks, with no owner wallet operations."""
import argparse
import json
import re
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--device', required=True)
p.add_argument('--out', required=True)
p.add_argument('--guard-only', action='store_true')
a = p.parse_args()
adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
out = Path(a.out)
out.mkdir(parents=True, exist_ok=True)

def call(*args):
    return subprocess.check_output([adb, '-s', a.device, *args])

def state(path='', **params):
    url = 'http://127.0.0.1:8877/'+path
    if params:
        url += '?'+urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as response:
        result = json.load(response)
    assert not result['errors'], result['errors']
    return result

def show(screen, **params):
    return state('show', screen=screen, age='unknown' if screen in ['age', 'ageGate'] else 'known', **params)

def capture(name, result):
    (out/(name+'.png')).write_bytes(call('exec-out', 'screencap', '-p'))
    (out/(name+'.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(name+' OK', flush=True)

def tap_outside():
    # Below Android's status bar, above the highest game sheet.
    call('shell', 'input', 'tap', '8', '100')
    time.sleep(.3)
    return state()

original = call('shell', 'wm', 'size').decode()
override = re.search(r'Override size: (\d+x\d+)', original)
checks = []
try:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch')
    call('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', '2')
    call('shell', 'input', 'keyevent', '224')
    policy = call('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    assert 'mIsShowing=true' not in policy, 'Owner must unlock phone'
    call('forward', 'tcp:8877', 'tcp:8877')
    call('shell', 'am', 'start', '-n', 'com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            state()
            break
        except OSError:
            if attempt == 59:
                raise
            time.sleep(.25)
    for screen in [] if a.guard_only else ['lives', 'daily', 'purchases', 'rent', 'earn', 'profile', 'ranking',
                   'player', 'age', 'ageGate', 'plus', 'share', 'billing', 'testGrant',
                   'purchase', 'subscription', 'restore', 'reset', 'result']:
        result = show(screen, state='linked', lang='ru')
        before = (result['tokens'], result['lives'], result['age'])
        if screen == 'result':
            assert result['resultCloseIcons'] == 0
            assert result['resultReplayHeight'] >= 60
        assert result['modalCanPop'] or result['resultOverlayCount'] == 1, screen
        after = tap_outside()
        assert not after['modalCanPop'] and after['resultOverlayCount'] == 0, screen
        assert (after['tokens'], after['lives'], after['age']) == before, screen
        checks.append({'screen': screen, 'outsideClosed': True, 'noResourceChange': True})
        (out/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
        print(screen+' outside close OK', flush=True)
    # No owner data in these screenshots: all values are fixture data.
    for screen, variant in [] if a.guard_only else [('rent', 'rich'), ('rent', 'poor'), ('lives', 'rich'),
                            ('lives', 'poor'), ('result', 'rich'), ('game', 'active')]:
        result = show(screen, state=variant, lang='ru')
        if screen in ['rent', 'lives']:
            assert result['costBadges']
            assert all(b['available'] == (variant == 'rich') for b in result['costBadges'])
        capture(screen+'-'+variant, result)
    density = int(re.findall(r'\d+', call('shell', 'wm', 'density').decode())[-1])/160
    call('shell', 'wm', 'size', f'{round(320*density)}x{round(480*density)}')
    time.sleep(.6)
    for screen in [] if a.guard_only else ['game', 'rent', 'lives', 'result']:
        result = show(screen, state='active', lang='en', scale=2)
        area = result['hudGeometry']['arcade-play-area']
        field = result['hudGeometry']['arcade-game-field']
        ratio = (field['top']-area['top'])/area['height']
        assert ratio <= .20001, ratio
        result['measuredHudShare'] = ratio
        capture('short-'+screen+'-en-2', result)
    call('shell', 'wm', 'size', override.group(1) if override else 'reset')
    time.sleep(.6)
    for kind in ['missing', 'tiny', 'offscreen']:
        result = show('game', state='active', lang='ru')
        if kind == 'missing':
            state('clear-enemies')
        else:
            state('fault-geometry', kind=kind)
        before = result['lives']
        point = result['gameFieldCenter']
        call('shell', 'input', 'tap', str(round(point['x'])), str(round(point['y'])))
        time.sleep(.3)
        result = state()
        assert result['geometryErrors'] == 1, kind
        assert result['gameTimeMs'] == 0 and result['roundStarts'] == 0, kind
        assert result['lives'] == before, kind
        capture('guard-'+kind, result)
        checks.append({'geometryFault':kind,'timerZero':True,'serverNotCalled':True,'lifeUnchanged':True})
    result = show('game', state='active', lang='ru')
    assert result['geometryErrors'] == 0
    point = result['gameFieldCenter']
    call('shell', 'input', 'tap', str(round(point['x'])), str(round(point['y'])))
    time.sleep(.15)
    result = state('clear-enemies')
    assert result['gameTimeMs'] > 0
    result = state('jump')
    jump = next(v for k,v in result['abilityStates'].items() if 'jump' in k)
    assert jump['active'] and jump['progress'] < .5
    capture('jump-cooldown-start', result)
    time.sleep(1)
    result = state()
    later = next(v for k,v in result['abilityStates'].items() if 'jump' in k)
    assert later['progress'] > jump['progress']
    capture('jump-cooldown-progress', result)
    # Actual GameHomeScreen damage path after fixture startup invulnerability.
    while state()['gameTimeMs'] < 10500:
        time.sleep(.5)
    result = state('hit-helmet')
    helmet = next(v for k,v in result['abilityStates'].items() if 'helmet' in k)
    assert helmet['active'] and helmet['broken'], helmet
    capture('helmet-broken-enabled', result)
    result = state('clear-enemies')
    checks.append({'helmetStillEnabledAfterActualHit': True})
    (out/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
finally:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch.uiprobe')
    call('shell', 'am', 'force-stop', 'com.best4u.untouch')
    call('shell', 'wm', 'size', override.group(1) if override else 'reset')
    call('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', '2')
    subprocess.run([adb, '-s', a.device, 'forward', '--remove', 'tcp:8877'],capture_output=True)
    print('Both games stopped, device size restored, USB awake retained.', flush=True)
