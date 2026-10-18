"""Huawei queue/restart check with an isolated API transport outage.

The radio/network is unchanged; only the probe's game API transport refuses
requests. Online requests use the actual Supabase server.
"""
import json
from pathlib import Path
import subprocess
import time
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.supabase'
OUT=ROOT/'.private/supabase-transition/physical'
def main():
    devices=[r.split()[0] for r in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in r and not r.startswith('emulator-')]
    assert len(devices)==1
    def adb(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*args])
    def state(route=''):
        with urllib.request.urlopen('http://127.0.0.1:8898/'+route,timeout=40) as response:return json.load(response)
    def start():
        adb('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        for _ in range(60):
            try:return state()
            except OSError:time.sleep(.5)
        raise RuntimeError('probe_start_failed')
    failure=None;records=[]
    try:
        adb('shell','am','force-stop',PACKAGE);adb('forward','tcp:8898','tcp:8898')
        before=start();data=state('energy');balance=data['energy'];owner=data['owner']
        data=state('offline/on');assert data['simulatedApiOutage']
        rect=data['rectangles']['energy-hidden-title'];x=str(round(rect['left']+rect['width']/2));y=str(round(rect['top']+rect['height']/2))
        for _ in range(5):adb('shell','input','tap',x,y)
        time.sleep(4);data=state();assert data['energy']==balance;assert not data['errors']
        records.append({'stage':'api_unavailable','energy':data['energy']})
        adb('shell','am','force-stop',PACKAGE)
        after=start();assert after['owner']==owner and after['energy']==balance+20 and not after['errors']
        assert state('sync')['energy']==balance+20;assert state('sync')['energy']==balance+20
        records.append({'stage':'restart_and_retry','energy':after['energy']})
        (OUT/'08-recovered-once.png').write_bytes(adb('exec-out','screencap','-p'))
    except Exception as error:failure=f'{type(error).__name__}: {error}'
    finally:
        adb('shell','am','force-stop',PACKAGE);adb('shell','am','force-stop','com.best4u.untouch');adb('forward','--remove','tcp:8898')
        report={'ok':failure is None,'failure':failure,'records':records,'physicalDevice':True,'backend':'Supabase cloud','outage':'probe API transport only, radio unchanged','gamesStopped':True}
        (OUT/'offline-acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
    if failure:raise RuntimeError(failure)
if __name__=='__main__':main()
