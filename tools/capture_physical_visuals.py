"""Qualitative phone capture only; screen recording must not be used as a benchmark."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import urllib.request
from PIL import Image, ImageDraw
import atexit

p=argparse.ArgumentParser()
p.add_argument('--device',required=True)
p.add_argument('--out',required=True)
p.add_argument('--scenario',choices=['jump','windows'],required=True)
a=p.parse_args()
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
atexit.register(lambda:subprocess.run([adb,'-s',a.device,'shell','am','force-stop','com.best4u.untouch.uiprobe'],check=False))
subprocess.check_call([adb,'-s',a.device,'shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity'],stdout=subprocess.DEVNULL)
def request(path):
    with urllib.request.urlopen('http://127.0.0.1:8878'+path,timeout=20) as r:return json.load(r)
def screen(name):
    path=out/(name+'.png')
    path.write_bytes(subprocess.check_output([adb,'-s',a.device,'exec-out','screencap','-p']))
    return path
for attempt in range(40):
    try:
        request('/frames')
        break
    except (OSError, ValueError):
        if attempt==39:raise
        time.sleep(.25)
request('/reset?sustained=true&rent=true&sound=false&music=false')
request('/drive?moving=false')
time.sleep(1)
remote='/sdcard/Movies/Untouch-probe-'+str(int(time.time()))+'.mp4'
record=subprocess.Popen([adb,'-s',a.device,'shell','screenrecord','--size','540x1156','--bit-rate','2000000','--time-limit','14',remote],stdout=subprocess.DEVNULL)
time.sleep(.5)
images=[];data=[]
if a.scenario=='jump':
    screen('jump-ready')
    start=time.monotonic();request('/jump')
    for i in range(9):
        now=time.monotonic()-start
        info=request('/frames')
        images.append(screen('jump-'+str(i)))
        data.append(dict(t=now,remainingMs=info['jumpRemainingMs']))
        time.sleep(.3)
    images.append(screen('jump-last'))
else:
    for name in ['profile','share','rent','lives']:
        request('/window?name='+name)
        images.append(screen(name+'-entry'))
        time.sleep(.8)
        images.append(screen(name+'-ready'))
        request('/back');time.sleep(.4)
record.wait(timeout=20)
video=None
if record.returncode==0:
    video=str(out/(a.scenario+'.mp4'))
    subprocess.check_call([adb,'-s',a.device,'pull',remote,video],stdout=subprocess.DEVNULL)
request('/stop')
tiles=[]
for i,path in enumerate(images):
    im=Image.open(path).convert('RGB')
    if a.scenario=='jump':im=im.crop((0,335,1080,470))
    im.thumbnail((540,470))
    tile=Image.new('RGB',(560,im.height+35),'#071B2D');tile.paste(im,(10,30))
    ImageDraw.Draw(tile).text((10,7),path.stem+(' t='+str(round(data[i]['t'],2)) if i<len(data) else ''),fill='white')
    tiles.append(tile)
h=max(t.height for t in tiles);sheet=Image.new('RGB',(1120,h*((len(tiles)+1)//2)),'#071B2D')
for i,tile in enumerate(tiles):sheet.paste(tile,((i%2)*560,(i//2)*h))
sheet.save(out/'contact-sheet.png')
(out/'samples.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(samples=len(images),video=video,jump=data,recordExit=record.returncode)))
