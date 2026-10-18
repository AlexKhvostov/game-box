"""Check real widget feedback from injected game gestures, not private state."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.request
import atexit

p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--out',required=True)
a=p.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
atexit.register(lambda:subprocess.run([adb,'-s',a.device,'shell','am','force-stop','com.best4u.untouch.uiprobe'],check=False))
subprocess.check_call([adb,'-s',a.device,'shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity'],stdout=subprocess.DEVNULL)
def req(path):
    with urllib.request.urlopen('http://127.0.0.1:8878'+path,timeout=20) as r:return json.load(r)
def shot(name):
    (out/(name+'.png')).write_bytes(subprocess.check_output([adb,'-s',a.device,'exec-out','screencap','-p']))
for attempt in range(40):
    try:req('/frames');break
    except (OSError,ValueError):
        if attempt==39:raise
        time.sleep(.25)
req('/reset?sustained=true&rent=true&sound=false&music=false');req('/drive?moving=false');time.sleep(.3)
shot('ready')
req('/clear?label=jump-feedback');req('/observeControls');req('/jump');time.sleep(.08);req('/jump')
shot('blocked-red')
observed=req('/frames');samples=observed['controlSamples']
begins=0;previous=False
for s in samples:
    if s['warning'] and not previous:begins+=1
    previous=s['warning']
assert begins==2, ('Expected two red flashes',begins,samples)
assert observed['jumpRemainingMs'] < 2000, 'Blocked attempt must not restart cooldown'
time.sleep(2)
ready=req('/frames');assert ready['controls']['ready'];assert not ready['controls']['warning']
shot('recharged')
req('/jump');time.sleep(.3);shot('cooldown')
req('/stop')
(out/'verification.json').write_text(json.dumps(dict(redFlashes=begins,samples=samples,
    ready=ready['controls'], blockedRemainingMs=observed['jumpRemainingMs'],errors=ready['errors']),indent=2),encoding='utf-8')
print(json.dumps(dict(redFlashes=begins,ready=ready['controls']['ready'],errors=ready['errors'])))
