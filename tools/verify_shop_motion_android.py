"""Physical, isolated shop transitions: frame timings and actual touch input."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.request

p = argparse.ArgumentParser()
p.add_argument('--device', required=True)
p.add_argument('--out', required=True)
p.add_argument('--expect-restore-hidden', action='store_true')
a = p.parse_args()
out = Path(a.out)
out.mkdir(parents=True, exist_ok=True)
adb = str(Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe')

def call(*args):
    return subprocess.check_output([adb, '-s', a.device, *args])

def request(path=''):
    with urllib.request.urlopen('http://127.0.0.1:8877/' + path, timeout=25) as r:
        result = json.load(r)
    assert not result.get('errors'), result.get('errors')
    return result

def tap(data, index):
    target = data['targets'][f'shop-tab-{index}']
    call('shell', 'input', 'tap', str(round(target['x'])), str(round(target['y'])))
    time.sleep(.40)

def stats(values):
    values = sorted(values)
    def at(q):
        return values[round((len(values)-1)*q)] if values else 0
    return dict(p50=at(.5), p95=at(.95), max=at(1),
                over16_7=sum(v>16.7 for v in values), over33_4=sum(v>33.4 for v in values))

results = []
try:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch')
    call('shell', 'input', 'keyevent', '224')
    policy = call('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    assert 'mIsShowing=true' not in policy, 'Phone must be unlocked by its owner'
    call('forward', 'tcp:8877', 'tcp:8877')
    call('shell', 'am', 'start', '-n', 'com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            request(); break
        except OSError:
            if attempt == 59: raise
            time.sleep(.25)
    conditions = {name:call('shell',*args).decode(errors='replace') for name,args in {
        'battery':('dumpsys','battery'), 'size':('wm','size'), 'density':('wm','density'),
        'lowPower':('settings','get','global','low_power'), 'fontScale':('settings','get','system','font_scale'),
        'model':('getprop','ro.product.model'), 'refresh':('dumpsys','SurfaceFlinger','--latency'),
    }.items()}
    (out/'conditions.json').write_text(json.dumps(conditions,indent=2),encoding='utf-8')
    data=request('show?screen=daily&state=claimed&age=known&lang=ru')
    (out/'initial.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'daily.png').write_bytes(call('exec-out','screencap','-p'))
    for label,sequence in [('cold-taps',[1,2,3,0]),('warm-taps-1',[1,2,3,0,2,0]),('warm-taps-2',[1,2,3,0,2,0]),('swipes-1',[1,2,3,2,1,0]),('swipes-2',[1,2,3,2,1,0])]:
        request('clear-frames')
        observed=[]
        current=0
        for index in sequence:
            if label.startswith('swipes'):
                y=round(data['targets']['shop-tab-0']['y']+260)
                call('shell','input','swipe',*map(str,([900,y,180,y] if index>current else [180,y,900,y])), '650')
                time.sleep(.85)  # Wait for the PageView settling after release.
            else:
                tap(data,index)
            current=index
            state=request()
            if state['shopTab'] != index:
                (out/'failed-input.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
                (out/'failed-input.png').write_bytes(call('exec-out','screencap','-p'))
                raise AssertionError((label,index,state['shopTab'],data['targets']))
            observed.append(index)
        time.sleep(.25)  # Flush batched FrameTiming callbacks, outside gesture.
        raw=request('?raw=true')
        (out/(label+'-raw.json')).write_text(json.dumps(raw,ensure_ascii=False,indent=2),encoding='utf-8')
        frames=raw['frames']
        result=dict(label=label,frameCount=len(frames),observed=observed,
                    **{key:stats([f[key+'Us']/1000 for f in frames]) for key in ['build','raster','total']})
        results.append(result)
        (out/'summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(result),flush=True)
    for state in ['linked','normal']:
        profile=request('show?screen=profile&state='+state+'&age=known&lang=ru')
        if a.expect_restore_hidden:
            assert profile['googleRestoreCount'] == (0 if state == 'linked' else 1)
        (out/('profile-'+state+'.png')).write_bytes(call('exec-out','screencap','-p'))
        (out/('profile-'+state+'.json')).write_text(json.dumps(profile,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
finally:
    for package in ['com.best4u.untouch.uiprobe','com.best4u.untouch']:
        subprocess.run([adb,'-s',a.device,'shell','am','force-stop',package],capture_output=True)
    subprocess.run([adb,'-s',a.device,'forward','--remove','tcp:8877'],capture_output=True)
    print('Both apps stopped.',flush=True)
