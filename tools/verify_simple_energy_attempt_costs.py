"""Native attempt debit with explicit foreground/modal transition checks."""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/release-evidence/native-account-hud-20261016/physical/costs'
ADB = Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe.simpleenergy'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    devices = [s.split()[0] for s in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in s and not s.startswith('emulator-')]
    assert len(devices) == 1
    def adb(*args):
        return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
    def state(path=''):
        return json.load(urllib.request.urlopen('http://127.0.0.1:8897/'+path,timeout=20))
    def tap(data,key):
        r=data['rectangles'][key]
        adb('shell','input','tap',round(r['left']+r['width']/2),round(r['top']+r['height']/2))
        time.sleep(.8)
        return state()
    records=[]
    failure=None
    try:
        adb('shell','am','force-stop','com.best4u.untouch')
        adb('forward','tcp:8897','tcp:8897')
        for helmet,jump,cost in [(False,False,1),(True,False,2),(True,True,3)]:
            adb('shell','am','force-stop',PACKAGE)
            adb('shell','am','start','-W','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
            time.sleep(2)
            data=state(f'show?screen=home&helmet={str(helmet).lower()}&jump={str(jump).lower()}')
            before=data['energy']
            data=tap(data,'hud-energy-plus')
            assert 'simple-energy-window' in data['rectangles'], 'Energy modal must open before Back'
            assert data['starts']==0 and data['energy']==before
            adb('shell','input','keyevent','4')
            time.sleep(.8)
            data=state()
            assert 'simple-energy-window' not in data['rectangles']
            data=tap(data,'arcade-game-field')
            assert data['energy']==before-cost and data['starts']==1 and not data['errors'], data
            name=f'game-cost-{cost}'
            (OUT/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
            (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
            records.append(dict(name=name,cost=cost,energy=data['energy'],starts=data['starts']))
            print(name,'PASS',flush=True)
    except Exception as error:
        failure=type(error).__name__+': '+str(error)
    finally:
        adb('shell','am','force-stop',PACKAGE)
        adb('shell','am','force-stop','com.best4u.untouch')
        adb('forward','--remove','tcp:8897')
    (OUT/'acceptance.json').write_text(json.dumps(dict(ok=failure is None,failure=failure,records=records,gamesStopped=True),indent=2),encoding='utf-8')
    if failure:raise RuntimeError(failure)

if __name__=='__main__':main()
