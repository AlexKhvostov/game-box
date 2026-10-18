"""Native Flutter capture/interaction acceptance on an isolated physical package.
All server data/prices in this probe are synthetic. This is not a Play/SDK test.
"""
import json
import argparse
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request
import http.client

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/release-evidence/android-simple-energy-20261016/physical'
ADB = Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch.uiprobe.simpleenergy'
URL = 'http://127.0.0.1:8897/'

def run():
    OUT.mkdir(parents=True, exist_ok=True)
    devices=[x.split()[0] for x in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in x and not x.startswith('emulator-')]
    assert len(devices)==1,'One authorized physical device required'
    def adb(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
    def state(**query):
        path='show?'+urllib.parse.urlencode(query) if query else ''
        # A forwarded socket can briefly outlive the force-stopped process.
        # Only isolated read/reset GETs are retried; no claim/input is repeated.
        for attempt in range(4):
            try:
                with urllib.request.urlopen(URL+path,timeout=20)as response:return json.load(response)
            except (OSError, http.client.RemoteDisconnected):
                if attempt == 3:raise
                time.sleep(.2)
    def start():
        adb('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        for i in range(60):
            try:return state()
            except OSError:
                if i==59:raise
                time.sleep(.15)
    records=[]
    def save(name,data):
        assert not data['errors'],data['errors']
        (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
        (OUT/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        records.append({'name':name,'energy':data['energy'],'starts':data['starts'],'cost':data['attemptCost'],'errors':data['errors'],'scrolls':data['scrolls']})
        print(name,'PASS',flush=True)
    def tap(data,key):
        r=data['rectangles'][key];adb('shell','input','tap',round(r['left']+r['width']/2),round(r['top']+r['height']/2))
        time.sleep(.25);return state()
    scenarios=[
        ('h01-50',dict(screen='home',balance=50)),('h01-1500',dict(screen='home',balance=1500)),('h01-99999',dict(screen='home',balance=99999)),
        ('e01-ready',dict(screen='energy')),('e01-ready-x2',dict(screen='energy',slots=2)),('e01-ready-x5',dict(screen='energy',slots=5)),
        ('e01-cooldown',dict(screen='energy',state='cooldown')),('e01-cooldown-x2',dict(screen='energy',slots=2,state='cooldown')),('e01-cooldown-x5',dict(screen='energy',slots=5,state='cooldown')),
        ('e02-free',dict(screen='subscription')),('e02-x2',dict(screen='subscription',slots=2)),('e02-x5',dict(screen='subscription',slots=5)),
        ('e03-video',dict(screen='video')),('e03-cooldown',dict(screen='video',state='video-cooldown')),
        ('e04-friends',dict(screen='friends')),('e04-many',dict(screen='friends',friends=100)),('e04-empty',dict(screen='friends',friends=0)),
        ('e05-packs',dict(screen='packs')),('a01-helmet-off',dict(screen='helmet')),('a01-helmet-on',dict(screen='helmet',helmet='true')),
        ('a02-jump-off',dict(screen='jump')),('a02-jump-on',dict(screen='jump',jump='true')),
        ('e01-99999',dict(screen='energy',balance=99999)),('e01-large-text',dict(screen='energy',scale=2)),('a01-large-text',dict(screen='helmet',scale=2)),
    ]
    adb('shell','am','force-stop','com.best4u.untouch')
    adb('forward','tcp:8897','tcp:8897')
    baseline={'size':adb('shell','wm','size').decode(),'density':adb('shell','wm','density').decode(),'font':adb('shell','settings','get','system','font_scale').decode().strip(),'usbAwake':adb('shell','settings','get','global','stay_on_while_plugged_in').decode().strip()}
    failure=None
    try:
        for name,query in scenarios:
            start();data=state(**query);save(name,data)
            assert data['starts']==0,'Opening UI cannot start an attempt'
            adb('shell','am','force-stop',PACKAGE)
        start();data=state(screen='energy');before=data['energy']
        data=tap(data,'simple-bonus-orb');time.sleep(.2);data=state()
        assert data['energy']==before+20 and data['starts']==0
        save('e01-after-claim',data)
        data=tap(data,'simple-bonus-orb');assert data['energy']==before+20
        data=tap(data,'simple-energy-packs');assert 'Купить энергию' in data['texts']
        adb('shell','input','keyevent','4');time.sleep(.3);data=state();assert 'simple-bonus-orb' in data['rectangles']
        adb('shell','input','keyevent','4');time.sleep(.3);assert 'simple-energy-window' not in state()['rectangles']
        adb('shell','am','force-stop',PACKAGE)
        start();data=state(screen='energy',state='error');data=tap(data,'simple-bonus-orb');assert data['energy']==50;save('e01-network-error',data)
        adb('shell','am','force-stop',PACKAGE)
        start();data=state(screen='energy',state='claim-pending');data=tap(data,'simple-bonus-orb');save('e01-network-pending',data)
        time.sleep(3.2);data=state();assert data['energy']==70;save('e01-pending-confirmed',data)
        adb('shell','am','force-stop',PACKAGE)
        for helmet,jump,cost in [(False,False,1),(True,False,2),(True,True,3)]:
            start();data=state(screen='home',helmet=str(helmet).lower(),jump=str(jump).lower());before=data['energy']
            data=tap(data,'hud-energy-plus');assert data['starts']==0 and data['energy']==before
            adb('shell','input','keyevent','4');time.sleep(.2);data=state()
            data=tap(data,'arcade-game-field');assert data['energy']==before-cost and data['starts']==1
            save('game-cost-'+str(cost),data);adb('shell','am','force-stop',PACKAGE)
    except Exception as error:failure=type(error).__name__+': '+str(error)
    finally:
        adb('shell','am','force-stop',PACKAGE);adb('shell','am','force-stop','com.best4u.untouch')
        # No display/font changes were made. Preserve the user's USB wake setting.
        adb('forward','--remove','tcp:8897')
    report={'ok':failure is None,'failure':failure,'baseline':baseline,'records':records,'count':len(records),'syntheticData':True,'realGoogleOrAds':False,'package':PACKAGE,'gamesStopped':True}
    (OUT/'acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    if failure:raise RuntimeError(failure)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);args=parser.parse_args()
    if args.output:OUT=args.output.resolve()
    run()
