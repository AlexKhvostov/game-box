"""Physical Android acceptance using actual game gestures and native SDK."""
import json, subprocess, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADB = 'C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe.analytics'
OUT = ROOT / 'docs/release-evidence/appmetrica-summary-20261024'
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output([ADB, *args], stderr=subprocess.STDOUT)

def get(path='/state', port=8879):
    return json.load(urllib.request.urlopen(f'http://127.0.0.1:{port}{path}', timeout=5))

def wait(check, timeout=30):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            value = get()
            if check(value): return value
        except (OSError, ValueError): pass
        time.sleep(.1)
    latest = get()
    (OUT / 'phone-timeout.json').write_text(json.dumps(latest, indent=2), encoding='utf-8')
    raise AssertionError('Phone game condition timed out: ' + json.dumps({k: latest.get(k) for k in ['playing', 'brake', 'errors']}))

try:
    adb('reverse', 'tcp:8883', 'tcp:8883')
    adb('forward', 'tcp:8879', 'tcp:8879')
    before = len(get(port=8883)['events'])
    adb('shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    wait(lambda s: s.get('brake') is not None and not s['playing'])
    # Move off the pedal while it charges, then deliberately wait after ready.
    adb('shell', 'input', 'tap', '540', '900')
    wait(lambda s: s['playing'])
    adb('shell', 'input', 'swipe', '540', '900', '820', '1180', '100')
    ready = wait(lambda s: s['brake']['ready'])
    assert ready['brake']['presses'] == 0
    time.sleep(2)
    before_press = get()
    adb('shell', 'input', 'swipe', '820', '1180', '540', '900', '150')
    pressed = wait(lambda s: s['brake']['presses'] == 1)
    assert not pressed['errors']
    # Second readiness left unused, so finish must record the censored wait.
    adb('shell', 'input', 'swipe', '540', '900', '820', '1180', '100')
    wait(lambda s: s['brake']['ready'])
    time.sleep(1)
    # Allow an actual game collision after probe-only initial invulnerability.
    adb('shell', 'input', 'tap', '820', '1180')
    wait(lambda s: not s['playing'], timeout=45)
    time.sleep(2)
    events = get(port=8883)['events'][before:]
    # Collector adds receipt time; event payload is the exact native SDK input.
    used = [e for e in events if e['name'] in ['ability_used', 'ability_available']]
    finishes = [e for e in events if e['name'] == 'game_finish']
    starts = [e for e in events if e['name'] == 'game_start']
    assert not used, used
    assert len(finishes) == len(starts) == 1, (starts, finishes)
    finish = finishes[0]['params']
    assert finish['run_id'] == starts[0]['params']['run_id']
    assert finish['analytics_schema_version'] == 2
    assert finish['brake_use_count'] == finish['brake_wait_count'] == 1, finish
    delay = finish['brake_first_wait_ms'] / 1000
    observed = before_press['brake']['readyAgeMs'] / 1000
    assert 1.8 < delay < observed + 1, (delay, observed)
    assert finish['brake_wait_sum_ms'] == finish['brake_first_wait_ms']
    assert finish['brake_ready_count'] >= 2 and finish['brake_ready_unused_at_finish'], finish
    assert finish['brake_ready_unused_ms'] >= 800, finish
    # Reset the isolated fixture AFTER a real collision: result HUD is disabled.
    get('/case?brake=1&meter=1')
    wait(lambda s: not s['playing'])
    # Open real windows from the home HUD, close with Android Back.
    for window, x in [('energy', 425), ('profile', 920), ('leaderboard', 620)]:
        adb('shell', 'input', 'tap', str(x), '155')
        time.sleep(1)
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        time.sleep(.6)
    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    time.sleep(8)
    events = get(port=8883)['events'][before:]
    summaries = [e['params'] for e in events if e['name'] == 'ui_summary']
    assert summaries, events
    for window in ['energy', 'profile', 'leaderboard']:
        assert sum(p.get(f'window_{window}_open_count', 0) for p in summaries) == 1, (window, summaries)
        assert sum(p.get(f'window_{window}_close_count', 0) for p in summaries) == 1, (window, summaries)
        assert sum(p.get(f'window_{window}_active_ms', 0) for p in summaries) > 0, (window, summaries)
    forbidden = ['feature_shown', 'feature_clicked', 'window_opened', 'window_closed', 'screen_view', 'page_selected']
    assert not [e for e in events if e['name'] in forbidden], events
    assert all(e['params']['analytics_schema_version'] == 2 for e in events)
    frames = pressed['frames']
    result = {'passed': True, 'isolated': True, 'realAccountUsed': False,
              'eventCount': len(events), 'readyWaitSec': delay,
              'windowsVerified': ['energy', 'profile', 'leaderboard'],
              'beforeGestureReadyAgeSec': observed,
              'finish': finish, 'uiSummaries': summaries, 'eventNames': [e['name'] for e in events],
              'frameCount': len(frames),
              'buildP95Us': sorted(f['buildUs'] for f in frames)[int((len(frames)-1)*.95)],
              'rasterP95Us': sorted(f['rasterUs'] for f in frames)[int((len(frames)-1)*.95)]}
    (OUT / 'phone-acceptance.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    (OUT / 'phone-home.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    # Pause invokes SDK flush; allow dispatch while gameplay is stopped.
    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    time.sleep(8)
    print(json.dumps(result))
finally:
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'force-stop', 'com.best4u.untouch')
