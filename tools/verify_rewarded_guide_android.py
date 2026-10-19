"""Huawei acceptance of the real guide; disposable QA package, no main-data writes."""
import argparse, json, re, subprocess, time, urllib.request
from pathlib import Path

parser=argparse.ArgumentParser();parser.add_argument('--device',required=True);parser.add_argument('--phase',choices=['layout','ad'],default='layout');args=parser.parse_args()
adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe');pkg='com.best4u.untouch.uiprobe.review'
out=Path('docs/release-evidence/rewarded-guide-20261019');out.mkdir(parents=True,exist_ok=True)
def run(*xs):return subprocess.check_output([adb,'-s',args.device,*xs],text=True,encoding='utf-8',errors='replace')
def get(p='/state'):
    with urllib.request.urlopen('http://127.0.0.1:8898'+p,timeout=20) as r:return json.load(r)
def shot(name):
    (out/(name+'.png')).write_bytes(subprocess.check_output([adb,'-s',args.device,'exec-out','screencap','-p']))
def start():
    run('shell','am','start','-n',pkg+'/com.best4u.untouch.MainActivity')
    for _ in range(80):
        try:
            s=get()
            if 'arcade-game-field' in s['rectangles']:return s
        except (OSError,ValueError):pass
        time.sleep(.2)
    raise RuntimeError('QA not ready')
def tap(key,state=None):
    r=(state or get())['rectangles'][key]
    run('shell','input','tap',str(round(r['left']+r['width']/2)),str(round(r['top']+r['height']/2)))
    time.sleep(.4)
def geometry(label):
    s=get('/video');time.sleep(.3);s=get();assert not s['errors'],s['errors']
    names=['simple-energy-window','rewarded-guide-step-1','rewarded-guide-step-2','rewarded-guide-reward','simple-watch-video','rewarded-ad-data-info']
    rs={k:s['rectangles'][k] for k in names}
    window=rs['simple-energy-window'];limit=window['top']+window['height']
    for key in names[1:]:
        r=rs[key];assert r['top']>=window['top'] and r['top']+r['height']<=limit+1,(label,key,rs)
    shot('phone-'+label)
    tap('simple-energy-close',s)
    return {'label':label,'rectangles':rs,'errors':s['errors'],'allControlsInsideWindow':True}

run('forward','tcp:8898','tcp:8898')
if args.phase=='layout':
    size=run('shell','wm','size');font=run('shell','settings','get','system','font_scale').strip()
    override=re.search(r'Override size: (\d+x\d+)',size);results=[]
    try:
        start();results.append(geometry('normal'))
        s=get('/video');tap('rewarded-ad-data-info',s)
        s=get();assert any('идентификаторы устройства' in t for t in s['texts']);assert not s['errors']
        shot('phone-ad-details');run('shell','input','keyevent','4');time.sleep(.3);tap('simple-energy-close')
        run('shell','wm','size','960x1920');time.sleep(1);results.append(geometry('320x640'))
        run('shell','settings','put','system','font_scale','2');time.sleep(1)
        s=get('/video');time.sleep(.3);s=get();assert not s['errors'],s['errors']
        # Large accessibility text may scroll. The launch action must be reachable.
        for _ in range(4):
            r=s['rectangles']['simple-watch-video']
            if r['top']+r['height']<1820:break
            run('shell','input','swipe','480','1600','480','750','220');time.sleep(.2);s=get()
        assert r['top']>=0 and r['top']+r['height']<1820
        shot('phone-320x640-font2');results.append({'label':'320x640-font2','launchReachable':True,'errors':s['errors']})
        (out/'phone-layout.json').write_text(json.dumps({'ok':True,'results':results,'mainUntouched':True},indent=2),encoding='utf-8')
    finally:
        run('shell','settings','put','system','font_scale',font)
        run('shell','wm','size',override.group(1) if override else 'reset')
        run('shell','am','force-stop',pkg)
elif args.phase=='ad':
    s=start();s=get('/energy');time.sleep(.3);tap('simple-energy-video',s)
    s=get();assert 'Подождите' in s['texts'];assert 'Закройте' in s['texts']
    before=s['energy'];Path('.private/rewarded-guide-before-ad.json').write_text(json.dumps(s),encoding='utf-8')
    tap('simple-watch-video',s);time.sleep(9);shot('phone-sdk-video')
    print(json.dumps({'sdkInspectionReady':True,'beforeEnergy':before}))
print('Phase complete:',args.phase)
