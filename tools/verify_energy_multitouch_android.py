"""Inject actual Android multitouch into the isolated energy probe; never owner game."""
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ADB = Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
OUT = ROOT/'docs/release-evidence/energy-v2-20261015/physical'
PACKAGE = 'com.best4u.untouch.uiprobe'
devices = [line.split()[0] for line in subprocess.check_output([str(ADB),'devices']).decode().splitlines()
           if '\tdevice' in line and not line.startswith('emulator-')]
assert len(devices) == 1
def call(*args):
    return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
def snapshot(path=''):
    return json.load(urllib.request.urlopen('http://127.0.0.1:8892/'+path,timeout=20))
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('forward','tcp:8892','tcp:8892')
    call('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
    for attempt in range(50):
        try:
            snapshot();break
        except OSError:
            if attempt == 49:raise
            time.sleep(.2)
    before = snapshot('show?screen=home&helmet=true&jump=true')
    assert not before['errors']
    focus = call('shell','dumpsys','activity','activities').decode(errors='replace')
    assert any(PACKAGE in line for line in focus.splitlines()
               if 'mResumedActivity' in line or 'ResumedActivity' in line)
    rect = before['rectangles']['arcade-game-field']
    x,y=round(rect['left']+rect['width']/2),round(rect['top']+rect['height']/2)
    call('push',ROOT/'.private/android-energy-20261015/gesture/classes.dex','/data/local/tmp/untouch-energy-input.dex')
    output = call('shell',f'CLASSPATH=/data/local/tmp/untouch-energy-input.dex app_process /data/local/tmp InputSequence ISOLATED_ENERGY_PROBE {x} {y}').decode()
    assert 'ANDROID_MULTITOUCH_SENT' in output
    after = snapshot()
    assert not after['errors']
    assert after['starts'] == before['starts']+1
    assert after['energy'] == before['energy']-3
    assert after['gameplay']['helmetEquipped']
    assert after['gameplay']['jumpCooldownMs']>0
    assert after['gameplay']['timeMs']>0
    (OUT/'47-native-two-fingers.png').write_bytes(call('exec-out','screencap','-p'))
    # Another jump in this same paid run, after cooldown, has no new debit.
    time.sleep(1.1)
    call('shell',f'CLASSPATH=/data/local/tmp/untouch-energy-input.dex app_process /data/local/tmp InputSequence ISOLATED_ENERGY_PROBE {x} {y}')
    repeated = snapshot()
    assert not repeated['errors'] and repeated['energy'] == after['energy']
    assert repeated['starts'] == after['starts']
    assert repeated['gameplay']['jumpCooldownMs']>0
    # Two separate taps have no simultaneous second pointer and must not jump.
    taps_before = snapshot('show?screen=home&jump=true')
    call('shell','input','tap',x,y)
    time.sleep(.35)
    call('shell','input','tap',x,y)
    taps_after = snapshot()
    assert not taps_after['errors']
    assert taps_after['energy'] == 45 and taps_after['starts'] == taps_before['starts']+1
    assert taps_after['gameplay']['jumpCooldownMs'] == 0
    report={'ok':True,'mode':'actual Android injected MotionEvents on Huawei',
      'before':before,'after':after,'repeatedJump':repeated,
      'separateTaps':taps_after,'oneAttemptCost':3,
      'secondSimultaneousFingerActivatedJump':True,'extraJumpDebit':False,
      'twoSeparateTapsDoNotJump':True,
      'ownerPackageNeverStarted':True,'physicalHumanFingers':False}
    (OUT/'native-multitouch.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'ok':True,'energy':after['energy'],'jumpCooldownMs':after['gameplay']['jumpCooldownMs']},ensure_ascii=False))
finally:
    call('shell','am','force-stop',PACKAGE)
    call('shell','am','force-stop','com.best4u.untouch')
