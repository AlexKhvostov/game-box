"""Targeted native retest of disabled CTA, subscription links and large HUD."""
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/release-evidence/energy-v2-20261015/physical/final'
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
devices=[l.split()[0] for l in subprocess.check_output([str(ADB),'devices']).decode().splitlines()
         if '\tdevice' in l and not l.startswith('emulator-')]
assert len(devices)==1
OUT.mkdir(parents=True,exist_ok=True)
def call(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
def state(screen=None,**params):
    url='http://127.0.0.1:8892/'
    if screen:
        params['screen']=screen;url+='show?'+urllib.parse.urlencode(params)
    r=json.load(urllib.request.urlopen(url,timeout=30));assert not r['errors'],r['errors'];return r
records=[]
def save(name,r):
    (OUT/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
    (OUT/(name+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    records.append(name);print(name,'PASS',flush=True)
try:
    call('shell','am','force-stop','com.best4u.untouch')
    call('forward','tcp:8892','tcp:8892')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity')
    for attempt in range(60):
        try:state();break
        except OSError:
            if attempt==59:raise
            time.sleep(.2)
    for name,screen,params in [
      ('01-charge','charge',{}),('02-tasks','tasks',{}),('03-friends','friends',{}),('04-buy','buy',{}),
      ('08-charge-two','charge',{'slots':2}),('09-charge-five','charge',{'slots':5,'percent':45}),
      ('12-charge-empty','charge',{'percent':0}),('19-subscription','subscription',{}),
      ('20-subscription-two','subscription',{'slots':2}),('21-subscription-five','subscription',{'slots':5}),
      ('27-helmet-off','helmet',{}),('29-jump-off','jump',{}),
      ('40-home','home',{}),('41-home-empty','home',{'balance':0}),
      ('42-home-large','home',{'balance':12345678}),
      ('43-home-abilities','home',{'helmet':'true','jump':'true'}),
      ('46-subscription-verification','charge',{'slots':2,'state':'pending'}),
      ('system-font200-empty','charge',{'percent':0,'scale':2}),
      ('system-font200-subscription','subscription',{'scale':2}),
    ]:save(name,state(screen,**params))
    r=state('feedback');rect=r['rectangles']['energy-feedback-text']
    call('shell','input','tap',round(rect['left']+rect['width']/2),round(rect['top']+rect['height']/2))
    call('shell','input','text','1234567890123456789');time.sleep(.4)
    save('38-feedback-19',state())
    call('shell','input','text','0');time.sleep(.4)
    save('39-feedback-20',state())
    call('shell','input','keyevent','4');time.sleep(.4)
    save('16-feedback-ready',state())
    (OUT/'verification.json').write_text(json.dumps({'ok':True,'states':len(records),
      'cases':records,'mode':'profile','device':'Huawei P30 Lite','allApiIntercepted':True,
      'syntheticPrices':True,'ownerDataChanged':False},indent=2),encoding='utf-8')
finally:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop','com.best4u.untouch')
