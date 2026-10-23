"""Isolated release probe on the physical phone. Never spends real account energy."""
import json,time,subprocess,urllib.request,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ADB='C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
EVIDENCE=ROOT/'docs/release-evidence/android-brake-20261023'
EVIDENCE.mkdir(parents=True,exist_ok=True)
def adb(*args):return subprocess.check_output([ADB,*args],stderr=subprocess.STDOUT)
def state(path='/state'):return json.load(urllib.request.urlopen('http://127.0.0.1:8879'+path,timeout=5))
def capture(name):(EVIDENCE/name).write_bytes(adb('exec-out','screencap','-p'))
def wait_for(predicate,timeout=10):
 until=time.monotonic()+timeout
 while time.monotonic()<until:
  try:s=state()
  except (OSError,ValueError):time.sleep(.1);continue
  if predicate(s):return s
  time.sleep(.1)
 raise AssertionError('probe state timeout')
checks=[]
try:
 adb('forward','tcp:8879','tcp:8879');adb('shell','monkey','-p','com.best4u.untouch.uiprobe.brake','-c','android.intent.category.LAUNCHER','1');wait_for(lambda s:s.get('brake') is not None,30)
 for brake,meter in [(True,True),(True,False),(False,True),(False,False)]:
  state(f'/case?brake={int(brake)}&meter={int(meter)}');s=wait_for(lambda s:s.get('brake') is not None and not s['playing']);assert not s['errors'];assert s['meterPresent']==meter;assert s['brake']['enabled']==brake;assert s['brake']['speedBarEnabled']==meter
  adb('shell','input','tap','540','900');s=wait_for(lambda s:s['playing']);before=s['brake']['speed'];previous=before;start=time.monotonic();charged=False
  while time.monotonic()-start<6.5:
   s=state();assert not s['errors'];assert s['playing'];b=s['brake']
   if not brake:assert b['speed']>=previous and b['presses']==0
   if brake and not charged and b['effectiveSec']>2.8 and b['presses']==0:capture(f'charging-brake-{int(brake)}-meter-{int(meter)}.png');charged=True
   previous=b['speed']
   if brake and b['presses']>0:break
   time.sleep(.1)
  if brake:assert s['brake']['presses']==1
  else:assert s['brake']['effectiveSec']>6 and s['brake']['speed']>before
  capture(f'phone-brake-{int(brake)}-meter-{int(meter)}.png')
  frames=s.pop('frames');checks.append({'case':{'brake':brake,'meter':meter},'state':s,'frames':len(frames),'buildP95Us':sorted(f['buildUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None,'rasterP95Us':sorted(f['rasterUs'] for f in frames)[int((len(frames)-1)*.95)] if frames else None})
 # Observe a raised ready pedal, then cross it with a real Android swipe.
 state('/case?brake=1&meter=1');wait_for(lambda s:s.get('brake') is not None and not s['playing']);adb('shell','input','tap','540','900');wait_for(lambda s:s['playing']);adb('shell','input','swipe','540','900','820','1180','100');ready=wait_for(lambda s:s['brake']['ready']);assert ready['brake']['presses']==0;capture('phone-ready.png');before=ready['brake']['speed'];adb('shell','input','swipe','820','1180','540','900','150');pressed=wait_for(lambda s:s['brake']['presses']==1);capture('phone-wave.png');assert pressed['brake']['targetSpeed']<before;assert not pressed['errors'];pressed.pop('frames');ready.pop('frames');checks.append({'case':'real-swipe-from-ready-to-brake','before':ready,'after':pressed})
 (EVIDENCE/'phone-checks.json').write_text(json.dumps({'isolated':True,'realAccountUsed':False,'checks':checks,'passed':True},indent=2)+'\n',encoding='utf-8');print(json.dumps({'passed':len(checks),'realAccountUsed':False,'frameSummaries':[{k:c[k] for k in ['frames','buildP95Us','rasterP95Us']} for c in checks if 'frames' in c]}))
finally:
 adb('shell','am','force-stop','com.best4u.untouch.uiprobe.brake');adb('shell','am','force-stop','com.best4u.untouch')
