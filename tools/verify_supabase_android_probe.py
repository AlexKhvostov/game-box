"""Real Huawei Flutter UI → Supabase cloud. Never touches production data."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.supabase'
OUT=ROOT/'.private/supabase-transition/physical'

def main(apk):
    OUT.mkdir(parents=True,exist_ok=True)
    devices=[line.split()[0] for line in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in line and not line.startswith('emulator-')]
    assert len(devices)==1,'Exactly one authorized physical phone is required'
    def adb(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
    def state(path=''):
        with urllib.request.urlopen('http://127.0.0.1:8898/'+path,timeout=40) as response:return json.load(response)
    def ready():
        for _ in range(40):
            try:return state()
            except OSError:time.sleep(.5)
        raise RuntimeError('Physical probe did not initialize')
    def start():
        adb('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        return ready()
    records=[]
    def save(name,data):
        assert not data['errors'],data['errors']
        (OUT/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
        records.append({'name':name,'energy':data['energy'],'attempts':data['attempts'],'serverClock':data['serverClock']})
    def tap(data,key):
        r=data['rectangles'][key]
        adb('shell','input','tap',round(r['left']+r['width']/2),round(r['top']+r['height']/2))
    baseline={'usbAwake':adb('shell','settings','get','global','stay_on_while_plugged_in').decode().strip(),
              'mainVersion':[line.strip() for line in adb('shell','dumpsys','package','com.best4u.untouch').decode().splitlines() if 'versionCode=' in line or 'versionName=' in line]}
    reverse=adb('reverse','--list').decode()
    assert 'tcp:5001' not in reverse and 'tcp:9099' not in reverse,'Another test already owns emulator ports'
    failure=None
    try:
        adb('shell','am','force-stop','com.best4u.untouch');adb('shell','am','force-stop',PACKAGE)
        adb('install','-r',str(Path(apk).resolve()))
        adb('forward','tcp:8898','tcp:8898')
        initial=start();assert initial['owner'].startswith('supabase:');assert initial['serverClock'];assert initial['rankingOnline'];assert initial['energy']==50;assert initial['configSource']=='firebase-remote-config';save('01-home',initial)
        data=state('energy');save('02-energy-before',data);before=data['energy'];owner=data['owner']
        for _ in range(4):tap(data,'energy-hidden-title')
        data=state();assert data['energy']==before
        tap(data,'energy-hidden-title');
        for _ in range(30):
            time.sleep(.5);data=state()
            if data['energy']==before+20:break
        assert data['energy']==before+20;save('03-hidden20',data)
        bonusReady=data['bonusNextAt']==0
        expected=before+20+(30 if bonusReady else 0)
        tap(data,'simple-bonus-orb')
        for _ in range(30):
            time.sleep(.5);data=state()
            if data['energy']==expected:break
        assert data['energy']==expected
        assert (28700000 if bonusReady else 0) < data['bonusRemainingMs'] <= 28800000
        save('04-bonus30' if bonusReady else '04-existing-cooldown',data)
        tap(data,'simple-bonus-orb');time.sleep(.3);assert state()['energy']==expected
        adb('shell','am','force-stop',PACKAGE)
        data=start();assert data['owner']==owner and data['energy']==expected;save('05-restart',data)
        # The round itself is initiated by the real field touch, not an API shortcut.
        r=data['rectangles']['arcade-game-field'];x=round(r['left']+r['width']/2);y=round(r['top']+r['height']/2)
        adb('shell','input','swipe',x,y,x,y,2200);time.sleep(2)
        for _ in range(15):
            data=state('sync')
            if data['attempts']>initial['attempts'] and data['pending']==0:break
            time.sleep(.5)
        assert data['attempts']>initial['attempts'],'A physical round must finish'
        assert data['pending']==0,'Finished result must reach Firebase'
        save('06-round-result',data)
    except Exception as error:
        failure=type(error).__name__+': '+str(error)
    finally:
        adb('shell','am','force-stop',PACKAGE);adb('shell','am','force-stop','com.best4u.untouch')

        adb('forward','--remove','tcp:8898')
        report={'ok':failure is None,'failure':failure,'records':records,'baseline':baseline,
                'backend':'Supabase cloud','physicalDevice':True,'productionCloudTested':True,
                'realGoogleOrPayments':False,'syntheticWallet':False,'mainGameReplaced':False,'gamesStopped':True}
        (OUT/'acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if k not in ('baseline',)},ensure_ascii=False))
    if failure:raise RuntimeError(failure)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('apk',type=Path);parser.add_argument('--output',type=Path);args=parser.parse_args()
    if args.output:OUT=args.output.resolve()
    main(args.apk)

