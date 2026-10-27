"""Play actual isolated QA rounds with automatic ads OFF; no policy/time overrides."""
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.request import urlopen
import xml.etree.ElementTree as ET

adb = [os.environ.get('ADB_PATH', 'adb')]
if os.environ.get('ANDROID_SERIAL'):
    adb += ['-s', os.environ['ANDROID_SERIAL']]
package = 'com.best4u.untouch.uiprobe.banner'
evidence = Path(__file__).resolve().parents[1] / 'docs/release-evidence/ad-formats-rc-qa225-20261027'
def state():
    with urlopen('http://127.0.0.1:19225/state', timeout=5) as response:
        value = json.load(response)
    assert not value['advertising']['automatic']['enabled'], 'This round test requires RC automatic OFF'
    assert not value['errors'], value['errors']
    return value
def tap(x, y):
    focus = subprocess.check_output(adb + ['shell', 'dumpsys', 'window'], text=True, encoding='utf-8')
    assert any('mCurrentFocus=' in line and package + '/com.best4u.untouch.MainActivity' in line for line in focus.splitlines()), 'QA game must be foreground before input'
    subprocess.run(adb + ['shell', 'input', 'tap', str(int(x)), str(int(y))], check=True, capture_output=True)
def wait_phase(phase, seconds=15):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        current = state()
        if current['phase'] == phase:
            return current
        time.sleep(.2)
    raise RuntimeError('Expected phase: ' + phase)
def dismiss_result():
    subprocess.run(adb + ['shell', 'uiautomator', 'dump', '/data/local/tmp/qa225-window.xml'], check=True, capture_output=True)
    tree = ET.fromstring(subprocess.check_output(adb + ['shell', 'cat', '/data/local/tmp/qa225-window.xml']))
    buttons = [n for n in tree.iter('node') if n.get('package') == package and n.get('content-desc') == 'Ещё раз']
    assert len(buttons) == 1, 'Expected actual visible Again button'
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', buttons[0].get('bounds')))
    tap((x1+x2)/2, (y1+y2)/2)
    return wait_phase('idle', 6)

try:
    current = state()
    while len(current['attempts']) < 11:
        if current['phase'] == 'result':
            current = dismiss_result()
        assert current['phase'] == 'idle'
        left, top, right, bottom = current['field']
        tap((left+right)/2, (top+bottom)/2)
        current = wait_phase('result')
        print(json.dumps({'completed': len(current['attempts']), 'requests': current['automaticRequests']}), flush=True)
    current = dismiss_result()
    assert current['automaticRequests'] == 0
    (evidence / '07-after-11-off.json').write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding='utf-8')
    print('PASS: 11 actual QA rounds; automatic SDK requests = 0', flush=True)
except Exception:
    subprocess.run(adb + ['shell', 'am', 'force-stop', package], capture_output=True)
    raise
