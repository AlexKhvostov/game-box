"""Read-only Huawei acceptance of installed config and offline account cache.
Installs signed user-requested update with -r; never clears data or starts a run.
"""
import argparse,json,re,sys,time,subprocess
from pathlib import Path
from tools.android_ui_acceptance import Phone

def main(apk):
    p=Phone();out=Path('docs/release-evidence/offline-zero-remote-config-20261017')
    wifi=p.adb('shell','settings','get','global','wifi_on').decode().strip()
    data=p.adb('shell','settings','get','global','mobile_data').decode().strip()
    record={'versionCode':154,'installedWithoutClear':False,'attemptsStartedByTest':0}
    def home(name):
        for _ in range(8):
            rows=p.read()
            energy=next((re.search(r'Энергия: (\d+)',text) for text,_ in rows if 'Энергия:' in text),None)
            if energy:
                value=int(energy.group(1));p.screenshot(out/name);return value
            time.sleep(1)
        raise AssertionError('Home energy was not visible')
    try:
        p.stop();print(p.adb('install','-r',str(apk.resolve())).decode().strip())
        record['installedWithoutClear']=True
        package=p.adb('shell','dumpsys','package','com.best4u.untouch').decode()
        assert re.search(r'versionCode=154\b',package)
        p.start();record['onlineEnergy']=home('phone154-online.png')
        logs=p.adb('logcat','-d','-t','3000').decode(errors='replace')
        matching=[line for line in logs.splitlines() if 'Economy RC:' in line]
        record['configLog']=matching[-1] if matching else None
        assert record['configLog'] and 'configSource=firebase-remote-config' in record['configLog']
        assert 'revision=14f4e82932a195779a5438cd685f60bd11ad39ec6a028dac2f5a37f78a2321c8' in record['configLog']
        p.stop();p.adb('shell','svc','wifi','disable');p.adb('shell','svc','data','disable')
        p.start();record['offlineRestartEnergy']=home('phone154-offline-restart.png');p.stop()
        assert record['offlineRestartEnergy']==record['onlineEnergy']
        p.adb('shell','svc','wifi','enable' if wifi=='1' else 'disable')
        p.adb('shell','svc','data','enable' if data=='1' else 'disable')
        p.start();record['reconnectedEnergy']=home('phone154-reconnected.png')
        assert record['reconnectedEnergy']==record['onlineEnergy']
        record['ok']=True
    finally:
        p.stop();p.adb('shell','svc','wifi','enable' if wifi=='1' else 'disable');p.adb('shell','svc','data','enable' if data=='1' else 'disable')
        record['stopped']=not subprocess.run(p.base+['shell','pidof','com.best4u.untouch'],capture_output=True).stdout.strip()
        record['usbWake']=p.adb('shell','settings','get','global','stay_on_while_plugged_in').decode().strip()
        record['wifiRestored']=p.adb('shell','settings','get','global','wifi_on').decode().strip()==wifi
        record['dataRestored']=p.adb('shell','settings','get','global','mobile_data').decode().strip()==data
        p.adb('shell','rm','-f','/sdcard/untouch-sandbox-qa.xml')
        (out/'phone-acceptance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(record,ensure_ascii=False))

if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    parser=argparse.ArgumentParser();parser.add_argument('apk',type=Path);main(parser.parse_args().apk)
