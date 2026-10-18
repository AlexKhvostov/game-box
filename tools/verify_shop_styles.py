"""Actual phone windows with isolated fixture data; always stop after capture."""
import argparse
import io
import json
import re
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--out', required=True)
parser.add_argument('--quick', action='store_true')
parser.add_argument('--scroll-only', action='store_true')
parser.add_argument('--final-focus', action='store_true')
parser.add_argument('--daily-states', action='store_true')
args = parser.parse_args()
adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
def call(*parts):
    return subprocess.check_output([adb, '-s', args.device, *parts])
def show(screen, lang='ru', scale=1, state=None):
    params = dict(screen=screen, lang=lang, scale=scale,
                  age='unknown' if screen == 'age' else 'known')
    if state:
        params['state'] = state
    with urllib.request.urlopen('http://127.0.0.1:8877/show?'+urllib.parse.urlencode(params), timeout=25) as response:
        data = json.load(response)
    time.sleep(.4)
    name = f'{screen}-{lang}-{scale}' + (f'-{state}' if state else '')
    pixels = call('exec-out', 'screencap', '-p')
    frame = Image.open(io.BytesIO(pixels)).convert('RGB')
    assert max(frame.getextrema()[1]) > 50, 'Screen is asleep or blank'
    (out/(name+'.png')).write_bytes(pixels)
    (out/(name+'.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    assert not data['errors'], data['errors']
    print(name+' OK', flush=True)
    if screen == 'share':
        with urllib.request.urlopen('http://127.0.0.1:8877/export-share', timeout=25) as response:
            (out/(name+'-export.png')).write_bytes(response.read())
    if args.scroll_only or args.daily_states:
        screen_width, screen_height = frame.size
        call('shell', 'input', 'swipe', str(screen_width//2), str(screen_height*4//5),
             str(screen_width//2), str(screen_height*2//5), '600')
        time.sleep(.5)
        (out/(name+'-scrolled.png')).write_bytes(call('exec-out', 'screencap', '-p'))
        if args.daily_states and scale > 1:
            call('shell', 'input', 'swipe', str(screen_width//2), str(screen_height*4//5),
                 str(screen_width//2), str(screen_height*2//5), '600')
            time.sleep(.5)
            (out/(name+'-scrolled-2.png')).write_bytes(call('exec-out', 'screencap', '-p'))
    return data
original_awake = call('shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in').decode().strip()
try:
    call('shell', 'svc', 'power', 'stayon', 'usb')
    call('shell', 'input', 'keyevent', '224')
    time.sleep(1.2)
    call('shell', 'wm', 'dismiss-keyguard')
    width, height = map(int, re.findall(r'(\d+)x(\d+)', call('shell', 'wm', 'size').decode())[-1])
    call('shell', 'input', 'swipe', str(width//2), str(height*4//5), str(width//2), str(height//4), '400')
    time.sleep(1)
    policy = call('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    assert 'mIsShowing=true' not in policy, 'Phone must be unlocked by its owner'
    call('forward', 'tcp:8877', 'tcp:8877')
    call('shell', 'am', 'start', '-n', 'com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(40):
        try:
            with urllib.request.urlopen('http://127.0.0.1:8877/', timeout=2) as response:
                json.load(response)
            break
        except (OSError, ValueError):
            if attempt == 39:
                raise
            time.sleep(.25)
    results=[]
    screens = () if args.scroll_only or args.final_focus or args.daily_states else ('daily', 'rent') if args.quick else ('game', 'daily', 'purchases', 'rent', 'earn', 'plus',
      'lives', 'billing', 'googlePurchase', 'purchase', 'subscription', 'age', 'profile', 'ranking',
      'player', 'result', 'share', 'restore', 'reset')
    for screen in screens:
        results.append(show(screen))
    if args.daily_states:
        for language, scale, state in (('ru',1,None),('ru',1,'claimed'),('ru',1,'active'),
                                       ('ru',2,'claimed'),('en',2,'claimed')):
            results.append(show('daily', lang=language, scale=scale, state=state))
    elif args.final_focus:
        for screen in ('daily', 'purchases', 'rent', 'share', 'billing'):
            for language, scale in (('ru', 1), ('en', 2)):
                results.append(show(screen, lang=language, scale=scale))
    elif args.scroll_only:
        for screen in ('daily', 'rent', 'plus', 'lives', 'subscription'):
            results.append(show(screen, lang='en', scale=2))
    elif not args.quick:
        for screen in ('daily', 'purchases', 'rent', 'earn', 'plus', 'lives', 'billing', 'purchase', 'subscription'):
            results.append(show(screen, lang='en', scale=2))
        for screen, state in (('daily', 'claimed'), ('rent', 'active'), ('rent', 'poor'), ('plus', 'active')):
            results.append(show(screen, state=state))
    (out/'verification.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
finally:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch.uiprobe')
    call('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', original_awake)
    subprocess.run([adb, '-s', args.device, 'forward', '--remove', 'tcp:8877'], check=False, capture_output=True)
    print('Probe stopped.', flush=True)
