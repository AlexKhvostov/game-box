"""Update the existing main installation only; never uninstall or clear data."""
from pathlib import Path
import subprocess,json,re,time,argparse,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
PACKAGE='com.best4u.untouch'

def identity(raw):
    keys={'uid':r'userId=(\d+)','versionCode':r'versionCode=(\d+)','versionName':r'versionName=([^\r\n]+)','firstInstallTime':r'firstInstallTime=([^\r\n]+)','dataDir':r'dataDir=([^\r\n]+)'}
    return {k:re.search(pattern,raw)[1].strip() for k,pattern in keys.items()}

def main():
    p=argparse.ArgumentParser();p.add_argument('download_receipt',type=Path);a=p.parse_args()
    stage=Path('C:/Users/alexe/.codex/artifacts/untouch/banner-unlock229-20261027')
    proof=json.loads((stage/'signed-apk-verification.json').read_text());assert proof['passed'] and proof['versionCode']==229
    receipt=json.loads(a.download_receipt.read_text());assert receipt['ok'] and receipt['versionCode']==229
    adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
    devices=[x.split()[0] for x in subprocess.check_output([adb,'devices'],text=True).splitlines() if '\tdevice' in x and not x.startswith('emulator')];assert len(devices)==1
    base=[adb,'-s',devices[0]]
    def cmd(*args):return subprocess.check_output(base+list(map(str,args)),stderr=subprocess.STDOUT)
    before=identity(cmd('shell','dumpsys','package',PACKAGE).decode())
    baseline=identity((stage/'phone-before/package.txt').read_text())
    assert before==baseline,'Installed application changed since baseline; inspect before updating'
    out=stage/'phone-after';out.mkdir(exist_ok=False)
    result={'installed':False,'before':before,'dataCleared':False,'uninstalled':False,'tracksChanged':False}
    try:
        cmd('shell','am','force-stop',PACKAGE)
        install=cmd('install-multiple','-r',*[f['path'] for f in receipt['files']]).decode()
        (out/'install.txt').write_text(install);assert 'Success' in install,install
        after=identity(cmd('shell','dumpsys','package',PACKAGE).decode())
        assert after['versionCode']=='229'
        for key in ['uid','firstInstallTime','dataDir']:assert after[key]==before[key],key
        result.update(installed=True,after=after,identityPreserved=True)
        cmd('shell','am','start','-S','-W','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
        time.sleep(6)
        pid=cmd('shell','pidof',PACKAGE).decode().strip();assert pid
        logs=cmd('logcat','-d','--pid='+pid,'-v','brief').decode('utf-8',errors='replace')
        (out/'logcat.txt').write_text(logs,encoding='utf-8')
        cmd('shell','uiautomator','dump','/sdcard/untouch-ad-controls-after.xml')
        xml=cmd('shell','cat','/sdcard/untouch-ad-controls-after.xml');(out/'ui.xml').write_bytes(xml)
        labels=[n.get('content-desc') or n.get('text') or '' for n in ET.fromstring(xml).iter('node')];labels=[s for s in labels if s]
        (out/'screen.png').write_bytes(cmd('exec-out','screencap','-p'))
        (out/'ui-labels.json').write_text(json.dumps(labels,ensure_ascii=False,indent=2),encoding='utf-8')
        rc=json.loads((stage/'rc-readback.json').read_text())
        result.update(configRevisionObserved=rc['revision'] in logs,rcVersion=rc['rcVersion'],configRevision=rc['revision'],appErrors=bool(re.search(r'FlutterError:|Uncaught zone error:|PlatformError:|FATAL EXCEPTION',logs)))
        energy=next((int(m[1] or m[2]) for s in labels if (m:=re.search(r'Баланс (\d+) энергии|Энергия: (\d+)',s))),None)
        result['energyAfter']=energy
        print(json.dumps({'installation':result,'visibleLabels':labels},ensure_ascii=False))
    finally:
        cmd('shell','am','force-stop',PACKAGE)
        result['stopped']=True;result['usbStayAwake']=cmd('shell','settings','get','global','stay_on_while_plugged_in').decode().strip()
        (stage/'phone-install-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':main()
