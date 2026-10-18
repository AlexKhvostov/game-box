"""Physical isolated fixture; preserve device settings and always stop both apps."""
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
a = p.parse_args()
adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)

def call(*args):
    return subprocess.check_output([adb, '-s', a.device, *args])

def snapshot(screen=None, **params):
    url='http://127.0.0.1:8877/'
    if screen is not None:
        params.update(screen=screen, age='unknown' if screen=='age' else 'known')
        url+='show?'+urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as response:
        result=json.load(response)
    assert not result['errors'], result['errors']
    return result

def capture(name, result):
    (out/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
    (out/(name+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(name+' OK',flush=True)

def check_hud(result):
    area=result['hudGeometry']['arcade-play-area']
    field=result['hudGeometry']['arcade-game-field']
    ratio=(field['top']-area['top'])/area['height']
    assert ratio<=.20001, ratio
    assert abs(field['height']-field['width'])<.1
    result['measuredHudShare']=ratio

original=call('shell','wm','size').decode()
override=re.search(r'Override size: (\d+x\d+)',original)
font=call('shell','settings','get','system','font_scale').decode().strip()
results=[]
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','settings','put','global','stay_on_while_plugged_in','2')
    call('shell','input','keyevent','224')
    policy=call('shell','dumpsys','window','policy').decode(errors='replace')
    assert 'mIsShowing=true' not in policy,'Phone must be unlocked by its owner'
    call('forward','tcp:8877','tcp:8877')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            snapshot();break
        except OSError:
            if attempt==59:raise
            time.sleep(.25)
    for size in ['normal','short']:
        if size=='short':
            density=int(re.findall(r'\d+',call('shell','wm','density').decode())[-1])/160
            call('shell','wm','size',f'{round(320*density)}x{round(480*density)}')
            time.sleep(1)
        for state,scale,lang in [('rich',1,'ru'),('active',1,'ru'),('active',2,'en')]:
            result=snapshot('game',state=state,scale=scale,lang=lang)
            check_hud(result);capture(f'{size}-hud-{state}-{lang}-{scale}',result);results.append(result)
        result=snapshot('game',state='active',lang='ru',scale=1)
        center=result['gameFieldCenter']
        call('shell','input','tap',str(round(center['x'])),str(round(center['y'])))
        time.sleep(1.3)
        result=snapshot();assert result['gameTimeMs']>0
        check_hud(result);capture(f'{size}-playing',result);results.append(result)
        for screen in (['lives','daily','purchases','rent','earn','profile','ranking','age','restore','reset','plus','billing','purchase','subscription','player','share','result'] if size=='normal' else ['lives','profile','daily','ranking']):
            result=snapshot(screen,lang='ru',scale=1)
            if screen!='result':
                colors=result['barrierColors']
                assert colors and all(color==0xB8061B2D for color in colors),(screen,colors)
            capture(f'{size}-{screen}',result);results.append(result)
        if size=='normal':
            for button, expected in [('lives',None),('crystals',0),('ranking',None),('account',None)]:
                result=snapshot('game',lang='ru',scale=1)
                target=result['targets']['hud-'+button+'-card']
                call('shell','input','tap',str(round(target['x'])),str(round(target['y'])))
                time.sleep(.7)
                result=snapshot();assert result['barrierColors'],button
                if button=='lives':assert result['livesWindowCount']==1
                if expected is not None:assert result['shopTab']==expected
                capture('normal-tap-'+button,result);results.append(result)
    (out/'verification.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
finally:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','wm','size',override.group(1) if override else 'reset')
    call('shell','settings','put','system','font_scale',font)
    call('shell','settings','put','global','stay_on_while_plugged_in','2')
    subprocess.run([adb,'-s',a.device,'forward','--remove','tcp:8877'],capture_output=True)
    print('Both apps stopped; device settings restored.',flush=True)
