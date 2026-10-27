"""Read-only QA evidence, plus explicit re-fetch of the published Firebase RC."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from urllib.request import urlopen

parser = argparse.ArgumentParser()
parser.add_argument('name')
parser.add_argument('--refresh', action='store_true')
parser.add_argument('--screenshot', action='store_true')
parser.add_argument('--banner', choices=['on', 'off'])
parser.add_argument('--automatic', choices=['on', 'off'])
args = parser.parse_args()
if not args.name.replace('-', '').replace('_', '').isalnum():
    raise ValueError('Invalid evidence name')
root = Path(__file__).resolve().parents[1]
evidence = root / 'docs/release-evidence/ad-formats-rc-qa225-20261027'
evidence.mkdir(parents=True, exist_ok=True)
url = 'http://127.0.0.1:19225' + ('/rc-refresh' if args.refresh else '/state')
with urlopen(url, timeout=25) as response:
    state = json.load(response)
(evidence / f'{args.name}.json').write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
assert state['rcKey'] == 'android_ad_formats_qa_v1'
assert state['rcReceivedAt'], 'No successful Firebase RC read'
assert not state['rcError'], state['rcError']
assert not state['errors'], state['errors']
for key in ['banner', 'automatic']:
    expected = getattr(args, key)
    if expected:
        assert state['advertising'][key]['enabled'] == (expected == 'on'), (key, state['advertising'])
if args.screenshot:
    adb = [os.environ.get('ADB_PATH', 'adb')]
    if os.environ.get('ANDROID_SERIAL'):
        adb += ['-s', os.environ['ANDROID_SERIAL']]
    focus = subprocess.check_output(adb + ['shell', 'dumpsys', 'window'], text=True, encoding='utf-8')
    current = [line for line in focus.splitlines() if 'mCurrentFocus=' in line]
    assert any('com.best4u.untouch.uiprobe.banner' in line for line in current), current
    (evidence / f'{args.name}.png').write_bytes(subprocess.check_output(adb + ['exec-out', 'screencap', '-p']))
print(json.dumps({key: state.get(key) for key in [
    'phase', 'rcKey', 'rcReceivedAt', 'rcRefreshes', 'bannerEnabled', 'bannerLoaded',
    'adEligible', 'automaticRequests', 'automaticShown', 'adPolicy', 'advertising', 'errors',
]}, ensure_ascii=False))
