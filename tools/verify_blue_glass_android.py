"""Capture the isolated UI probe. Never targets the production package/data."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PIL import Image
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ('docs/release-evidence/android-blue-glass-rev2-20261010'
              if '--revision2' in sys.argv else
              'docs/release-evidence/android-blue-glass-20261010')
ADB = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
WINDOWS = ('game', 'result', 'profile', 'ranking', 'player', 'lives', 'daily',
           'purchases', 'rent', 'earn', 'plus', 'age', 'restore', 'reset', 'share', 'billing')


def adb(*args):
    return subprocess.run([str(ADB), '-s', 'emulator-5554', *args], check=True,
                          capture_output=True).stdout


def capture(screen, language, width, height, scale=1, state=None):
    params = dict(screen=screen, lang=language, scale=scale,
                  age='unknown' if screen in ('age', 'ageGate') else 'known')
    if state:
        params['state'] = state
    url = 'http://127.0.0.1:8877/show?' + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=25) as response:
        result = json.load(response)
    name = f'{screen}-{language}-{width}x{height}-scaled-{scale}'
    if state:
        name += '-' + state
    (OUT / (name + '.json')).write_text(json.dumps(result, ensure_ascii=False,
                                                indent=2), encoding='utf-8')
    # Let Android's compositor present the completed Flutter frame as well.
    time.sleep(.5)
    for attempt in range(3):
        adb('shell', 'screencap', '-p', '/sdcard/untouch-blue-qa.png')
        adb('pull', '/sdcard/untouch-blue-qa.png', str(OUT / (name + '.png')))
        frame = Image.open(OUT / (name + '.png')).convert('RGB')
        frame.thumbnail((160, 350))
        surface = sum(r > 85 and g > 140 and b > 170
                      for r, g, b in frame.get_flattened_data()) / (frame.width * frame.height)
        if screen in ('game', 'notice') or surface >= .03:
            break
        time.sleep(1.5)
    else:
        raise RuntimeError(f'Expected a visible window in Android capture: {name}')
    print(name, 'OK' if not result['errors'] else result['errors'], flush=True)
    if result['errors']:
        raise RuntimeError(f'Flutter error in {name}')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cases = (
        (320, 560, (1, 2), WINDOWS),
        (390, 844, (1,), WINDOWS),
        (430, 932, (1,), WINDOWS),
        (320, 480, (1, 2), ('game', 'result', 'profile', 'daily', 'age', 'ranking')),
    )
    if '--refresh' in sys.argv:
        cases = (
            (320, 560, (1,), ('game', 'plus', 'age', 'ageGate')),
            (320, 560, (2,), WINDOWS),
            (390, 844, (1,), ('game', 'plus', 'age')),
            (430, 932, (1,), ('game', 'plus', 'age')),
            (320, 480, (1, 2), ('game', 'result', 'profile', 'daily', 'age', 'ranking')),
        )
    for width, height, scales, screens in cases:
        adb('shell', 'wm', 'size', f'{width * 2}x{height * 2}')
        adb('shell', 'wm', 'density', '320')
        for scale in scales:
            for language in ('ru', 'en'):
                for screen in screens:
                    capture(screen, language, width, height, scale)
    adb('shell', 'wm', 'size', '780x1688')
    for screen, state in (('game', 'active'), ('rent', 'active'), ('rent', 'poor'),
                          ('lives', 'poor'), ('daily', 'claimed'), ('plus', 'active'),
                          ('ranking', 'empty'), ('ranking', 'offline'), ('player', 'long')):
        for language in ('ru', 'en'):
            capture(screen, language, 390, 844, 1, state)
    if '--revision2' in sys.argv:
        for language in ('ru', 'en'):
            capture('ageGate', language, 390, 844)
            capture('notice', language, 390, 844)
    capture('game', 'ru', 390, 844)


if __name__ == '__main__':
    main()
