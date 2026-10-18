"""Physical smoke test of the isolated review package; no player data or cloud calls."""
import argparse,json,subprocess,time,urllib.request
from pathlib import Path

def main():
    p=argparse.ArgumentParser();p.add_argument('--apk',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--stall-frame',action='store_true');args=p.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    adb=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
    devices=[line.split()[0] for line in subprocess.check_output([str(adb),'devices']).decode().splitlines() if '\tdevice' in line and not line.startswith('emulator-')]
    assert len(devices)==1,'Exactly one physical Android device must be connected'
    prefix=[str(adb),'-s',devices[0]];package='com.best4u.untouch.uiprobe.review';records=[]
    def run(*a):return subprocess.check_output(prefix+list(map(str,a)),stderr=subprocess.STDOUT)
    def req(path=''):
        with urllib.request.urlopen('http://127.0.0.1:8898/'+path,timeout=10)as r:return json.load(r)
    def wait(predicate,seconds=8):
        until=time.monotonic()+seconds;last=None
        while time.monotonic()<until:
            try:
                last=req();assert not last['errors'],last['errors']
                if predicate(last):return last
            except (OSError,ValueError):pass
            time.sleep(.1)
        raise AssertionError(('Expected state not reached',last))
    def cold():
        run('shell','am','force-stop',package)
        run('shell','am','start','-n',package+'/com.best4u.untouch.MainActivity')
        return wait(lambda s:'field'in s and s['phase']=='idle',seconds=25)
    def tap_field(s):
        l,t,r,b=s['field'];run('shell','input','tap',round((l+r)/2),round((t+b)/2))
    def save(name,s):
        assert not s['errors'],s['errors'];records.append({'scenario':name,**s})
        (args.out/(name+'.png')).write_bytes(run('exec-out','screencap','-p'))
    try:
        run('shell','am','force-stop','com.best4u.untouch')
        installed=run('install','-r',args.apk.resolve());assert b'Success'in installed,installed.decode()
        run('forward','tcp:8898','tcp:8898')
        s=cold();assert s['energy']==50,s;assert s['configRemoteWaitMs']<1500,s;save('01-home',s)
        tap_field(s);s=wait(lambda s:s['phase']=='playing',seconds=3)
        if args.stall_frame:req('stall-frame');s=wait(lambda s:s['phase']=='playing',seconds=3)
        save('02-playing',s)
        l,t,r,b=s['field'];run('shell','input','swipe',round((l+r)/2),round((t+b)/2),round(l-40),round((t+b)/2),200)
        s=wait(lambda s:s['phase']=='result',seconds=6)
        s=wait(lambda s:s['attempts']and s['attempts'][0]['shared'],seconds=8);save('03-result-confirmed',s)
        run('shell','input','keyevent','4');s=wait(lambda s:s['phase']=='idle')
        req('fixture-run?failure=rules_changed');s=wait(lambda s:s['rulesUpdateRequired'])
        attempts=len(s['attempts']);tap_field(s);time.sleep(.25);s=req()
        assert s['phase']=='idle'and len(s['attempts'])==attempts,s
        assert s['attempts'][0]['error']=='rules_changed'and not s['attempts'][0]['pending'],s
        assert any('Правила обновились' in text for text in s['texts']),s
        save('04-rules-blocked',s)
        s=cold();req('fixture-run?offline=true');s=wait(lambda s:s['attempts']and s['attempts'][0]['pending'])
        assert s['energy']==49,s;save('05-offline-pending',s)
        req('retry');s=wait(lambda s:s['attempts'][0]['shared']);assert s['energy']==49,s
        save('06-reconnected-once',s)
        s=cold();req('fixture-run?failure=result_time_invalid');time.sleep(.15)
        req('retry');s=wait(lambda s:s['attempts']and s['attempts'][0]['shared'],seconds=10)
        save('07-finish-recovered',s)
        s=cold();req('result-fixture');s=wait(lambda s:s['phase']=='result'and s['attempts']and s['attempts'][0]['pending'])
        assert not any('получено'in text for text in s['texts']),s
        save('08-reward-awaiting-ack',s)
        req('retry');s=wait(lambda s:s['attempts'][0]['shared']and any('получено'in text for text in s['texts']),seconds=10)
        save('09-reward-confirmed',s)
        s=cold();tap_field(s);wait(lambda s:s['phase']=='playing');time.sleep(.6)
        s=req('collision-fixture');l,t,r,b=s['field'];scale=(r-l)/380
        run('shell','input','swipe',round(l+70*scale),round(t+140*scale),round(l+320*scale),round(t+140*scale),20)
        s=wait(lambda s:s['phase']=='result',seconds=5)
        assert s['player'][0]<150,s
        save('10-fast-swipe-collision',s)
        s=cold();req('energy-fixture?page=feedback');s=wait(lambda s:any('Сначала познакомьтесь'in t for t in s['texts']))
        save('11-feedback-shared-services',s)
        s=cold();req('energy-fixture');s=wait(lambda s:sum('/ 7 дней'in t for t in s['texts'])==2 and any('Google Play'in t for t in s['texts']))
        save('12-subscription-shared-services',s)
        (args.out/'verification.json').write_text(json.dumps({'scenarios':records,'allPassed':True,'cloudCalls':0,'package':package},ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps({'passed':len(records),'cloudCalls':0,'errors':[]},ensure_ascii=False))
    finally:
        for target in [package,'com.best4u.untouch']:
            subprocess.run(prefix+['shell','am','force-stop',target],capture_output=True)

if __name__=='__main__':main()
