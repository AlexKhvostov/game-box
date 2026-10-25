"""Huawei release QA: synthetic two-pointer events through the actual UI listener.
Separate package/local wallet; no production API, real funds or owner game data.
"""
import json, time, subprocess, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ADB='C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.jumpready'
OUT=ROOT/'docs/release-evidence/jump-ready-runtime-20261024'
OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def adb(*args):return subprocess.check_output([ADB,*args],stderr=subprocess.STDOUT)
def state(path='/state'):
    return json.load(urllib.request.urlopen('http://127.0.0.1:8884'+path,timeout=5))
def wait(predicate, timeout=8):
    until=time.monotonic()+timeout
    while time.monotonic()<until:
        try:
            s=state()
            assert not s['errors'],s['errors']
            if predicate(s):return s
        except (OSError,ValueError):pass
        time.sleep(.025)
    raise AssertionError('phone state timeout')
def capture(name):(OUT/name).write_bytes(adb('exec-out','screencap','-p'))
def start(cooldown=2):
    state('/case?cooldown=30&jumpCooldown='+str(cooldown))
    s=wait(lambda s:s['field'] and not s['playing'])
    f=s['field'];d=s['dpr']
    adb('shell','input','tap',str(round((f['x']+f['w']/2)*d)),str(round((f['y']+f['h']/2)*d)))
    s=wait(lambda s:s['playing'] and s['jump'])
    state('/quiet');assert s['jump']['ageMs'] is None
    return s
try:
    adb('forward','tcp:8884','tcp:8884')
    adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
    wait(lambda s:s['field'],30)
    start();capture('phone-initial-ready.png')
    s=state('/jump');assert s['jump']['flightMs']>0 and s['jump']['ageMs'] is None
    wait(lambda s:500<s['jump']['cooldownMs']<1100);capture('phone-charging.png')
    s=wait(lambda s:s['jump']['ageMs'] is not None and 80<s['jump']['ageMs']<280)
    capture('phone-flash.png')
    assert s['helmet']['ready']
    wait(lambda s:s['jump']['ageMs'] is not None and s['jump']['ageMs']>=420)
    capture('phone-ready.png');checks.append({'case':'two-second-jump-ready-with-helmet','passed':True})
    state('/jump');wait(lambda s:s['jump']['ageMs'] is not None and s['jump']['ageMs']<150)
    adb('shell','input','keyevent','KEYCODE_HOME');time.sleep(.2)
    before=state()['jump']['ageMs'];time.sleep(.6);after=state()['jump']['ageMs']
    assert before==after,(before,after)
    adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
    wait(lambda s:s['jump']['ageMs'] is not None and s['jump']['ageMs']>420)
    checks.append({'case':'visual-clock-pauses-in-background','passed':True,'ageBefore':before,'ageAfter':after})
    start(0);s=state('/jump');assert s['jump']['flightMs']>0 and s['jump']['ageMs'] is None
    time.sleep(.08);s=state();assert s['jump']['flightMs']>0 and s['jump']['ageMs'] is None
    wait(lambda s:s['jump']['ageMs'] is not None)
    checks.append({'case':'zero-cooldown-waits-for-flight','passed':True})
    start();state('/hit');wait(lambda s:not s['helmet']['ready']);state('/quiet')
    state('/jump');wait(lambda s:s['jump']['ageMs'] is not None and s['jump']['ageMs']>420)
    s=state();assert not s['helmet']['ready'] and 0<s['helmet']['progress']<1
    capture('phone-ready-helmet-charging.png');checks.append({'case':'lemon-jump-with-dim-cyan-recharging-helmet','passed':True})
    s=state();assert not s['errors'];frames=s['frames']
    checks.append({'case':'release-frame-smoke','frames':len(frames),
        'buildP95Us':sorted(f['buildUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None,
        'rasterP95Us':sorted(f['rasterUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None})
    (OUT/'phone-checks.json').write_text(json.dumps({'ok':True,'device':'Huawei P30 Lite',
        'mode':'isolated arm64 release; controlled contacts and synthetic UI pointers; not a manual two-finger UX test',
        'checks':checks,'errors':s['errors']},indent=2),encoding='utf-8')
    print(json.dumps({'ok':True,'checks':len(checks)}))
finally:
    adb('shell','am','force-stop',PACKAGE)
    adb('forward','--remove','tcp:8884')
