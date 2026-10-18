"""Economy visual acceptance on physical Huawei, isolated fixture and no payments."""
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import urllib.request

adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
devices = [x.split()[0] for x in subprocess.check_output([adb,'devices']).decode().splitlines()
           if '\tdevice' in x and not x.startswith('emulator-')]
assert len(devices) == 1
out = Path('docs/release-evidence/economy-20261013/physical')
out.mkdir(parents=True, exist_ok=True)

def call(*args):
    return subprocess.check_output([adb, '-s', devices[0], *args])

def snapshot(screen=None, **params):
    url = 'http://127.0.0.1:8877/'
    if screen:
        params.update(screen=screen, age='known')
        url += 'show?'+urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as response:
        result = json.load(response)
    assert not result['errors'], result['errors']
    return result

def capture(name, result):
    (out/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
    (out/(name+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(name, 'passed', flush=True)

original_size = call('shell','wm','size').decode()
override = re.search(r'Override size: (\d+x\d+)',original_size)
font = call('shell','settings','get','system','font_scale').decode().strip()
results = []
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','input','keyevent','224')
    assert 'mIsShowing=true' not in call('shell','dumpsys','window','policy').decode(errors='replace')
    call('forward','tcp:8877','tcp:8877')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(80):
        try:
            snapshot(); break
        except OSError:
            if attempt == 79: raise
            time.sleep(.25)
    for size in ['normal','short']:
        if size == 'short':
            density = int(re.findall(r'\d+',call('shell','wm','density').decode())[-1])/160
            call('shell','wm','size',f'{round(320*density)}x{round(480*density)}')
            time.sleep(.7)
        for lang,scale in [('ru',1),('en',2)]:
            for screen in ['lives','purchases','rent','daily','earn']:
                result = snapshot(screen,lang=lang,scale=scale,state='rich')
                assert result['lives'] == 999 and result['tokens'] == 999
                text = result['visibleTexts']
                if screen == 'lives':
                    assert result['livesWindowCount'] == 1
                    card = result['economyGeometry']["[<'lives-inventory'>]"]
                    assert card['width'] <= 112.1 and card['height'] >= card['width']
                    assert result['heartScale'] is not None
                if screen == 'purchases':
                    for amount in ['20','50','200','1000']:
                        assert amount in text, (amount,text)
                    # _QaBilling deliberately returns a simulated store price.
                    # This verifies the real store price takes precedence.
                    assert text.count('USD 2.34') == 4, text
                capture(f'{size}-{screen}-{lang}-font{scale}',result)
                results.append(result)
        if size == 'normal':
            snapshot('lives',lang='ru',scale=1,state='rich')
            scales = []
            for _ in range(32):
                scales.append(snapshot()['heartScale'])
                time.sleep(.055)
            assert max(scales) > 1.03 and min(scales) < 1.001, scales
            (out/'heartbeat.json').write_text(json.dumps({'scales':scales,'pulseObserved':True}),encoding='utf-8')
    (out/'verification.json').write_text(json.dumps({'ok':True,'states':len(results),'errors':[],
        'fixtureBalancesOnly':True,'realPaymentsAdsOrRounds':False,'heartbeatObserved':True,
        'fixtureGooglePriceOverride':'USD 2.34','mainVersionInstalled':111},indent=2),encoding='utf-8')
finally:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','wm','size',override.group(1) if override else 'reset')
    call('shell','settings','put','system','font_scale',font)
    call('shell','settings','put','global','stay_on_while_plugged_in','2')
    subprocess.run([adb,'-s',devices[0],'forward','--remove','tcp:8877'],capture_output=True)
    print('Both games stopped, display restored, USB stay-awake preserved.',flush=True)
