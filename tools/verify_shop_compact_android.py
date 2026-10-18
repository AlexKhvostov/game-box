"""Measure/capture compact shop on physical Android using isolated synthetic data."""
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
assert len(devices)==1
out=Path('docs/release-evidence/shop-compact-20261013/physical')
out.mkdir(parents=True,exist_ok=True)

def call(*args):
    return subprocess.check_output([adb,'-s',devices[0],*args])

def snapshot(screen=None, **params):
    url='http://127.0.0.1:8877/'
    if screen:
        params.update(screen=screen,age='known')
        url+='show?'+urllib.parse.urlencode(params)
    with urllib.request.urlopen(url,timeout=30) as response:
        result=json.load(response)
    assert not result['errors'],result['errors']
    assert result['roundStarts']==0
    return result

def capture(name,result):
    window=call('shell','dumpsys','window').decode(errors='replace')
    focused='\n'.join(line for line in window.splitlines() if 'mCurrentFocus' in line or 'mFocusedApp' in line)
    assert 'com.best4u.untouch.uiprobe' in focused, 'Probe is not foreground; capture rejected'
    (out/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
    (out/(name+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(name+' passed',flush=True)

size_original=call('shell','wm','size').decode()
override=re.search(r'Override size: (\d+x\d+)',size_original)
font=call('shell','settings','get','system','font_scale').decode().strip()
cases=[]
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','input','keyevent','224')
    assert 'mIsShowing=true' not in call('shell','dumpsys','window','policy').decode(errors='replace')
    call('forward','tcp:8877','tcp:8877')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(80):
        try:
            snapshot();break
        except OSError:
            if attempt==79:raise
            time.sleep(.2)
    for size in ['normal','short']:
        if size=='short':
            density=int(re.findall(r'\d+',call('shell','wm','density').decode())[-1])/160
            call('shell','wm','size',f'{round(320*density)}x{round(480*density)}')
            time.sleep(.7)
        for lang,scale in [('ru',1),('en',2)]:
            result=snapshot('purchases',lang=lang,scale=scale,state='rich')
            capture(f'{size}-packs-{lang}-font{scale}',result)
            area=result['shopGeometry']['shop-tab-content']
            balance=result['shopGeometry']['shop-crystal-balance']
            bonus=result['shopGeometry']['shop-gift-material']
            assert abs(balance['height']-bonus['height'])<.5
            assert bonus['left']-balance['left']-balance['width']>20
            for pack in ['pack_s','pack_m','pack_l','pack_xl']:
                card=result['shopGeometry']['crystal-package-'+pack]
                assert card['top']>=area['top']-.5
                assert card['top']+card['height']<=area['top']+area['height']+.5, (pack,card,area)
            for price in ['$0.99','$1.99','$3.99','$9.99']:
                assert price in result['visibleTexts']
            cases.append(result)
            for state in ['rich','claimed']:
                result=snapshot('daily',lang=lang,scale=scale,state=state)
                geometry=result['shopGeometry']
                plus=geometry['daily-plus-card']
                row=geometry['daily-row-1']
                assert plus['width']>row['width']+20
                capture(f'{size}-daily-{lang}-font{scale}-{state}',result);cases.append(result)
            result=snapshot('daily',lang=lang,scale=scale,state='rich')
            area=result['shopGeometry']['shop-tab-content']
            plus=result['shopGeometry']['daily-plus-card']
            # Stay clear of Android's bottom system Home gesture area.
            call('shell','input','swipe','540',str(round(area['top']+area['height']-180)),
                 '540',str(round(plus['top']+plus['height']+70)),'350')
            time.sleep(.5)
            result=snapshot();assert 'daily-row-7' in result['shopGeometry']
            capture(f'{size}-daily-bottom-{lang}-font{scale}',result);cases.append(result)
    (out/'verification.json').write_text(json.dumps({'ok':True,'states':len(cases),'errors':[],
        'fourPacksEntirelyVisible':True,'bonusMatchesBalanceHeight':True,
        'dailyNarrowerThanPlus':True,'realPurchasesClaimsOrRounds':False,
        'fixturesOnly':True,'originalMainVersion':112},indent=2),encoding='utf-8')
finally:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','wm','size',override.group(1) if override else 'reset')
    call('shell','settings','put','system','font_scale',font)
    call('shell','settings','put','global','stay_on_while_plugged_in','2')
    subprocess.run([adb,'-s',devices[0],'forward','--remove','tcp:8877'],capture_output=True)
    print('Both games stopped; display/font restored, USB stay-awake2 kept.',flush=True)
