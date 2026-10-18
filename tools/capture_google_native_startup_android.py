"""Observe the native chooser, then cancel. Never selects an owner's account."""
import json
from pathlib import Path
import subprocess
import time
import urllib.request

adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
devices = [x.split()[0] for x in subprocess.check_output([adb,'devices']).decode().splitlines()
           if '\tdevice' in x and not x.startswith('emulator-')]
assert len(devices) == 1
private = Path('.private/google-direct-20261013')
private.mkdir(parents=True, exist_ok=True)

def call(*args):
    return subprocess.check_output([adb,'-s',devices[0],*args])

def status():
    with urllib.request.urlopen('http://127.0.0.1:8877/',timeout=5) as response:
        return json.load(response)

record = {'isolatedPackage':True,'accountSelected':False,'tokenSentToServer':False}
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('forward','tcp:8877','tcp:8877')
    call('shell','input','keyevent','224')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:
            result = status()
            if result['nativeCalls'] == 1: break
        except OSError:
            pass
        time.sleep(.2)
    assert result['nativeCalls'] == 1, result
    time.sleep(2)
    window = call('shell','dumpsys','window','windows').decode(errors='replace')
    call('shell','uiautomator','dump','/sdcard/untouch-google-window.xml')
    xml = call('exec-out','cat','/sdcard/untouch-google-window.xml').decode(errors='replace')
    (private/'native.xml').write_text(xml,encoding='utf-8')
    (private/'native.png').write_bytes(call('exec-out','screencap','-p'))
    native = 'package="com.google.android.gms"' in xml
    record['nativeWindowObserved'] = native
    record['startupCallCount'] = result['nativeCalls']
    record['preliminaryAppOfferShown'] = 'google-startup-dialog' in xml
    if native:
        call('shell','input','keyevent','4')
    time.sleep(.8)
    result = status()
    assert result['guestNickname'] == 'Guest' and result['guestWallet'] == {'tokens':25,'lives':20}
    assert result['startupSeen'] and result['nativeCalls'] == 1
    record['afterCancel'] = result
    record['guestPreserved'] = True
    record['authCompleted'] = False
    record['limitation'] = 'QA package has its own Android package identity; no real account selection or backend connection.'
finally:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop','com.best4u.untouch')
    subprocess.run([adb,'-s',devices[0],'forward','--remove','tcp:8877'],capture_output=True)
    record['bothAppsStopped'] = True
    Path('docs/release-evidence/google-startup-20261013/direct-native-huawei.json').write_text(
        json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False))
