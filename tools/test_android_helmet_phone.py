"""Physical Huawei acceptance in the isolated QA package; no account/API writes."""
import json, time, subprocess, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ADB='C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.helmet'
EVIDENCE=ROOT/'docs/release-evidence/android-helmet-20261024'
EVIDENCE.mkdir(parents=True,exist_ok=True)
checks=[]
def adb(*args):return subprocess.check_output([ADB,*args],stderr=subprocess.STDOUT)
def state(path='/state'):
    return json.load(urllib.request.urlopen('http://127.0.0.1:8883'+path,timeout=5))
def wait_for(predicate,timeout=8):
    until=time.monotonic()+timeout
    while time.monotonic()<until:
        try:
            s=state()
            assert not s['errors'],s['errors']
            if predicate(s):return s
        except (OSError,ValueError):pass
        time.sleep(.04)
    raise AssertionError('phone state timeout')
def capture(name):(EVIDENCE/name).write_bytes(adb('exec-out','screencap','-p'))
def start(seconds,safe=True):
    state('/case?cooldown='+str(seconds)+'&safe='+str(int(safe)))
    s=wait_for(lambda s:s['field'] and not s['playing'])
    f=s['field'];d=s['dpr']
    adb('shell','input','tap',str(round((f['x']+f['w']/2)*d)),str(round((f['y']+f['h']/2)*d)))
    return wait_for(lambda s:s['playing'] and s['helmet'])
def hit():
    state('/hit');s=wait_for(lambda s:s['helmet'] and not s['helmet']['ready'])
    state('/quiet');return s
try:
    adb('forward','tcp:8883','tcp:8883')
    adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
    wait_for(lambda s:s['field'],30)
    start(1);hit();ready=wait_for(lambda s:s['helmet']['ready'])
    checks.append({'case':'one-second-smoke','passed':True})
    start(30);capture('phone-ready.png');hit();capture('phone-broken.png')
    adb('shell','input','keyevent','KEYCODE_HOME')
    time.sleep(.3);before=state()['helmet']['remainingMs']
    time.sleep(1.2);after=state()['helmet']['remainingMs']
    assert before==after,(before,after)
    adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
    checks.append({'case':'background-pauses-charge','passed':True,'remainingBefore':before,'remainingAfter':after})
    half=wait_for(lambda s:14000<s['helmet']['remainingMs']<16000,22)
    capture('phone-half-charge.png')
    ready=wait_for(lambda s:s['helmet']['ready'],20)
    capture('phone-restored.png')
    checks.append({'case':'thirty-active-seconds-recharge','passed':True,'ready':ready['helmet']})
    second=hit();assert second['helmet']['remainingMs']>29000
    time.sleep(.42);state('/hit')
    wait_for(lambda s:not s['playing'])
    checks.append({'case':'repeated-shield-then-hit-during-charge-kills','passed':True})
    start(0);hit();time.sleep(1.1)
    s=state();assert not s['helmet']['ready'] and s['helmet']['remainingMs']==0
    capture('phone-zero-spent.png')
    checks.append({'case':'zero-one-use-no-recharge','passed':True})
    start(30,False)
    for a,b,c,d in [(540,900,800,1100),(800,1100,270,1100),(270,1100,750,700)]:
        adb('shell','input','swipe',str(a),str(b),str(c),str(d),'100')
    s=state();assert not s['errors']
    frames=s['frames'];checks.append({'case':'ordinary-difficulty-fast-input-smoke','passed':True,'frames':len(frames),'buildP95Us':sorted(f['buildUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None,'rasterP95Us':sorted(f['rasterUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None})
    (EVIDENCE/'phone-checks.json').write_text(json.dumps({'ok':True,'mode':'release; isolated package; controlled contacts for timing, ordinary-difficulty input smoke separately','checks':checks},indent=2),encoding='utf-8')
    print(json.dumps({'ok':True,'checks':len(checks)}))
finally:
    adb('shell','am','force-stop',PACKAGE)
    adb('forward','--remove','tcp:8883')
