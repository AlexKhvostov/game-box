"""Physical retry/restart check in the already installed isolated Firebase APK."""
import json
from pathlib import Path
import subprocess
import time
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.firebase'
OUT=ROOT/'.private/firebase-transition-20261016/physical'
def main():
    devices=[r.split()[0] for r in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in r and not r.startswith('emulator-')]
    assert len(devices)==1
    def adb(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
    def state(route=''):
        with urllib.request.urlopen('http://127.0.0.1:8898/'+route,timeout=30) as r:return json.load(r)
    def start():
        adb('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        for _ in range(40):
            try:return state()
            except OSError:time.sleep(.5)
        raise RuntimeError('Probe restart failed')
    failure=None;records=[]
    try:
        assert 'tcp:5001' not in adb('reverse','--list').decode()
        adb('shell','am','force-stop','com.best4u.untouch');adb('shell','am','force-stop',PACKAGE)
        for port in (5001,9099):adb('reverse','tcp:'+str(port),'tcp:'+str(port))
        adb('forward','tcp:8898','tcp:8898')
        before=start();data=state('energy');balance=data['energy'];owner=data['owner']
        adb('reverse','--remove','tcp:5001')
        # adb removes a listener, while existing HTTP keep-alive sockets can
        # survive briefly. Let the idle connection close before testing outage.
        time.sleep(20)
        r=data['rectangles']['energy-hidden-title'];x=round(r['left']+r['width']/2);y=round(r['top']+r['height']/2)
        for _ in range(5):adb('shell','input','tap',x,y)
        time.sleep(7)
        offline=state()
        (OUT/'offline-observed.json').write_text(json.dumps(offline,ensure_ascii=False,indent=2),encoding='utf-8')
        assert offline['energy']==balance,f'Offline credit appeared: {balance} -> {offline["energy"]}'
        assert not offline['errors'],offline['errors']
        (OUT/'07-offline-pending.png').write_bytes(adb('exec-out','screencap','-p'));records.append({'stage':'offline','energy':offline['energy']})
        adb('shell','am','force-stop',PACKAGE)
        adb('reverse','tcp:5001','tcp:5001')
        resumed=start();assert resumed['owner']==owner and resumed['energy']==balance+20 and not resumed['errors']
        (OUT/'08-recovered-once.png').write_bytes(adb('exec-out','screencap','-p'));records.append({'stage':'afterRestart','energy':resumed['energy']})
        assert state('sync')['energy']==balance+20;assert state('sync')['energy']==balance+20
    except Exception as error:failure=type(error).__name__+': '+str(error)
    finally:
        adb('shell','am','force-stop',PACKAGE);adb('shell','am','force-stop','com.best4u.untouch')
        for port in (5001,9099):
            try:adb('reverse','--remove','tcp:'+str(port))
            except subprocess.CalledProcessError:pass
        adb('forward','--remove','tcp:8898')
        report={'ok':failure is None,'failure':failure,'backend':'local Firebase emulators','physicalDevice':True,'records':records,'mainGameReplaced':False,'gamesStopped':True}
        (OUT/'offline-acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
    if failure:raise RuntimeError(failure)
if __name__=='__main__':main()
