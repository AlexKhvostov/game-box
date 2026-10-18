"""Inject actual Android MotionEvents into the isolated simple-energy probe."""
import json
import argparse
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.simpleenergy'
OUT=ROOT/'docs/release-evidence/android-simple-energy-20261016/physical/design-ready'
def main():
    devices=[x.split()[0]for x in subprocess.check_output([str(ADB),'devices']).decode().splitlines()if '\tdevice' in x and not x.startswith('emulator-')]
    assert len(devices)==1
    def call(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
    def snapshot(path=''):return json.load(urllib.request.urlopen('http://127.0.0.1:8897/'+path,timeout=20))
    def start():
        call('shell','am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        for i in range(70):
            try:return snapshot()
            except OSError:
                if i==69:raise
                time.sleep(.15)
    report={'syntheticWallet':True,'nativeInput':True};failure=None
    try:
        call('shell','am','force-stop','com.best4u.untouch');call('forward','tcp:8897','tcp:8897');start()
        before=snapshot('show?screen=home&helmet=true&jump=true')
        focus=call('shell','dumpsys','activity','activities').decode(errors='replace')
        assert any(PACKAGE+'/' in line for line in focus.splitlines()if 'mResumedActivity' in line or 'ResumedActivity' in line)
        r=before['rectangles']['arcade-game-field'];x=round(r['left']+r['width']/2);y=round(r['top']+r['height']/2)
        dex=ROOT/'.private/android-energy-20261015/gesture/classes.dex';assert dex.is_file()
        call('push',dex,'/data/local/tmp/untouch-simple-energy-input.dex')
        result=call('shell',f'CLASSPATH=/data/local/tmp/untouch-simple-energy-input.dex app_process /data/local/tmp InputSequence ISOLATED_ENERGY_PROBE {x} {y}').decode()
        assert 'ANDROID_MULTITOUCH_SENT' in result
        after=snapshot();assert not after['errors']
        assert after['starts']==1 and after['energy']==before['energy']-3 and after['gameplay']['jumpCooldownMs']>0
        assert after['gameplay']['helmetEquipped']
        OUT.mkdir(parents=True,exist_ok=True)
        (OUT/'native-two-fingers.png').write_bytes(call('exec-out','screencap','-p'))
        (OUT/'native-two-fingers.json').write_text(json.dumps(after,ensure_ascii=False,indent=2),encoding='utf-8')
        assert 'jump-cooldown-status' in after['rectangles'], 'HUD must display actual game cooldown'
        report['twoFingers']={'starts':after['starts'],'energy':after['energy'],'cost':after['attemptCost'],'jumpCooldownMs':after['gameplay']['jumpCooldownMs'],'errors':after['errors']}
        call('shell','am','force-stop',PACKAGE);start();data=snapshot('show?screen=home&jump=true')
        r=data['rectangles']['arcade-game-field'];x=round(r['left']+r['width']/2);y=round(r['top']+r['height']/2)
        call('shell','input','tap',x,y);time.sleep(.12);call('shell','input','tap',x,y);time.sleep(.12)
        after=snapshot();assert not after['errors'] and after['starts']==1 and after['energy']==48 and after['gameplay']['jumpCooldownMs']==0
        report['separateTaps']={'starts':after['starts'],'energy':after['energy'],'jumpCooldownMs':after['gameplay']['jumpCooldownMs']}
    except Exception as e:failure=type(e).__name__+': '+str(e)
    finally:
        call('shell','am','force-stop',PACKAGE);call('shell','am','force-stop','com.best4u.untouch');call('forward','--remove','tcp:8897')
    report.update(ok=failure is None,failure=failure,gamesStopped=True)
    (OUT/'native-multitouch.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    if failure:raise RuntimeError(failure)
    print('PASS: real second finger jumps; separate taps do not; single debit3/2')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.output:OUT=args.output.resolve()
    main()
