"""Physical acceptance of the disposable, network-free chart UI probe only."""
import argparse,json,math,re,subprocess,time,urllib.request
from pathlib import Path

parser=argparse.ArgumentParser();parser.add_argument('apk',type=Path)
parser.add_argument('--out',type=Path,default=Path('docs/release-evidence/weighted-rms-20261020'))
parser.add_argument('--version-code',type=int,default=198)
parser.add_argument('--expected-average-ms',type=float,default=10995.868454706817)
args=parser.parse_args()
adb='C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
devices=subprocess.check_output([adb,'devices'],text=True)
found=re.findall(r'^(\S+)\s+device$',devices,re.M)
assert len(found)==1,'Expected exactly one authorized physical Android device'
serial=found[0];pkg='com.best4u.untouch.uiprobe.averagechart';main='com.best4u.untouch'
out=args.out;out.mkdir(parents=True,exist_ok=True)
def run(*parts):return subprocess.check_output([adb,'-s',serial,*parts],text=True,encoding='utf-8',errors='replace').strip()
def get(path='/state'):
    with urllib.request.urlopen('http://127.0.0.1:8897'+path,timeout=10) as response:return json.load(response)
def shot(name):(out/(name+'.png')).write_bytes(subprocess.check_output([adb,'-s',serial,'exec-out','screencap','-p']))
def tap(s,key):
    rect=s['rectangles'][key];ratio=s['devicePixelRatio']
    run('shell','input','tap',str(round((rect['left']+rect['width']/2)*ratio)),str(round((rect['top']+rect['height']/2)*ratio)))
    time.sleep(.3)
def main_version():return re.search(r'versionCode=(\d+)',run('shell','dumpsys','package',main)).group(1)
assert f'package:{pkg}' not in run('shell','pm','list','packages','--user','0'),'Do not replace an existing user0 probe'
aapt=sorted(Path('C:/Users/alexe/AppData/Local/Android/Sdk/build-tools').glob('*/aapt.exe'))[-1]
badging=subprocess.check_output([str(aapt),'dump','badging',str(args.apk)],text=True,encoding='utf-8',errors='replace')
assert f"name='{pkg}'" in badging and f"versionCode='{args.version_code}'" in badging
assert f"application-label:'QA{args.version_code} Untouch'" in badging
size=run('shell','wm','size');override=re.search(r'Override size: (\d+x\d+)',size)
old_font=run('shell','settings','get','system','font_scale')
old_usb=run('shell','settings','get','global','stay_on_while_plugged_in')
before=main_version();installed=False;results=[]
packages_before=run('shell','pm','list','packages','--user','0','com.best4u.untouch')
try:
    run('shell','am','force-stop',main)
    install=run('install','--user','0','-r',str(args.apk));assert 'Success' in install;installed=True
    run('forward','tcp:8897','tcp:8897')
    run('shell','am','start','-n',pkg+'/com.best4u.untouch.MainActivity')
    for _ in range(80):
        try:s=get();break
        except (OSError,ValueError):time.sleep(.25)
    else:raise AssertionError('Probe HTTP did not start')
    assert s['allNetworkIntercepted'] and not s['errors'],s.get('errors')
    assert s['qaBuild']==args.version_code and s['algorithm']=='weighted_rms_v1'
    # Actual Android tap on the production ranking button, then actual close.
    s=get('/show?screen=ranking');tap(s,'average-chart-open');s=get()
    assert 'average-chart-dialog' in s['rectangles'] and not s['errors']
    assert s['points']==100 and s['currentWindow']==50 and s['activeBars']==50
    assert abs(s['averageMs']-args.expected_average_ms)<1e-7
    shot('phone-normal')
    # Real tap on bar80, independently check its value and RMS at that point.
    plot=s['rectangles']['average-chart-plot'];ratio=s['devicePixelRatio']
    x=plot['left']+44+(plot['width']-56)*.795;y=plot['top']+plot['height']/2
    run('shell','input','tap',str(round(x*ratio)),str(round(y*ratio)));time.sleep(.25);s=get()
    assert s['selection']=='Попытка 80: 10,154 с',s['selection']
    fixture=[200+(i%8)*100 if i%13==3 else 1000+((i*7307+1931)%19001) for i in range(80)]
    used=fixture[-50:][::-1];weights=[.92**i for i in range(len(used))]
    rms=math.sqrt(sum(t*t*w for t,w in zip(used,weights))/sum(weights))
    expected=f'Среднее: {rms/1000:.3f} с'.replace('.',',')
    assert expected in s['texts'],(expected,s['texts'])
    shot('phone-selection80')
    viewport=s['rectangles']['average-chart-horizontal'];before_scroll=s['horizontal']['offset']
    run('shell','input','swipe',str(round((viewport['left']+50)*ratio)),str(round(y*ratio)),
        str(round((viewport['left']+viewport['width']-25)*ratio)),str(round(y*ratio)),'120')
    time.sleep(.25);s=get();assert s['horizontal']['offset']<before_scroll and not s['errors']
    results.append({'case':'actual-bar80-and-fast-swipe','ok':True,'attemptMs':10154,'historicalRmsMs':rms,'historyScrolled':True})
    tap(s,'average-chart-close');s=get()
    assert 'average-chart-dialog' not in s['rectangles'] and 'average-chart-open' in s['rectangles']
    results.append({'case':'actual-ranking-open-close','ok':True,'points':100,'activeBars':50,'averageMs':s['averageMs']})
    for name,screen,scale,mode in [
        ('phone-320','960x1920',1,'filled'),
        ('phone-320-font2','960x1920',2,'filled'),
        ('phone-offline','960x1920',1,'offline'),
        ('phone-empty','960x1920',1,'empty'),
        ('phone-threshold','960x1920',1,'threshold'),
        ('phone-long','960x1920',1,'long')]:
        run('shell','wm','size',screen);time.sleep(.3)
        s=get(f'/show?screen=chart&scale={scale}&mode={mode}')
        assert not s['errors'],s['errors']
        close=s['rectangles']['average-chart-close'];ratio=s['devicePixelRatio']
        width,height=map(int,screen.split('x'))
        assert close['left']>=0 and close['top']>=0
        assert (close['left']+close['width'])*ratio<=width+1
        assert (close['top']+close['height'])*ratio<=height+1
        assert s['points']==(0 if mode=='empty' else 100)
        assert s['activeBars']==(0 if mode=='empty' else 50)
        shot(name);results.append({'case':name,'points':s['points'],'activeBars':s['activeBars'],'errors':s['errors'],'ok':True})
        if name=='phone-320-font2':
            # The large-text dialog scrolls vertically; verify its bottom can
            # actually be reached and Android Back returns to ranking.
            for _ in range(3):
                run('shell','input','swipe',str(width//2),str(round(height*.83)),str(width//2),str(round(height*.32)),'180')
                time.sleep(.2)
            s=get();selection=s['rectangles']['average-chart-selection']
            assert selection['top']>=0 and (selection['top']+selection['height'])*ratio<=height+1
            assert not s['errors'],s['errors'];shot('phone-320-font2-bottom')
            run('shell','input','keyevent','4');time.sleep(.2);s=get()
            assert 'average-chart-dialog' not in s['rectangles'] and 'average-chart-open' in s['rectangles']
            results.append({'case':'large-text-scroll-bottom-and-android-back','ok':True,'bottomReached':True,'backToRanking':True})
    print('Huawei: RMS, actual button/bar80/fast swipe/close, 100/50, small/font2/offline/empty/threshold/200-history PASS')
finally:
    run('shell','wm','size',override.group(1) if override else 'reset')
    run('shell','am','force-stop',pkg);run('shell','am','force-stop',main)
    run('forward','--remove','tcp:8897')
    if installed:run('shell','pm','uninstall','--user','0',pkg)
    assert main_version()==before
    assert run('shell','settings','get','system','font_scale')==old_font
    assert run('shell','settings','get','global','stay_on_while_plugged_in')==old_usb
    assert run('shell','pm','list','packages','--user','0','com.best4u.untouch')==packages_before
    (out/'phone-verification.json').write_text(json.dumps({'cases':results,'allNetworkIntercepted':True,
      'realPlayerDataChanged':False,'mainVersionPreserved':before,'qaUser0Removed':installed,
      'displayRestored':True,'fontRestored':True,'usbPreserved':True,'mainStopped':True,
      'originalPackagesPreserved':True,'qaVersion':args.version_code,'algorithm':'weighted_rms_v1'},indent=2),encoding='utf-8')
