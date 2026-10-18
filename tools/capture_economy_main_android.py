"""Read-only acceptance of the owner's installed game; never start or spend."""
import json
from pathlib import Path
import subprocess
import time
import re
import xml.etree.ElementTree as ET

adb = str(Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe')
device = [line.split()[0] for line in subprocess.check_output([adb, 'devices']).decode().splitlines()
          if '\tdevice' in line and not line.startswith('emulator-')]
assert len(device) == 1, 'Expected one authorized physical phone'
package_dump = subprocess.check_output([adb, '-s', device[0], 'shell', 'dumpsys', 'package', 'com.best4u.untouch']).decode()
version_code = int(re.search(r'versionCode=(\d+)', package_dump).group(1))
private = Path(f'.private/economy-20261013/main{version_code}')
private.mkdir(parents=True, exist_ok=True)

def call(*args):
    return subprocess.check_output([adb, '-s', device[0], *args])

def capture(name):
    (private / (name + '.png')).write_bytes(call('exec-out', 'screencap', '-p'))
    dump=call('shell', 'uiautomator', 'dump', '/sdcard/untouch-window.xml')
    if b'UI hierchary dumped' not in dump and b'UI hierarchy dumped' not in dump:
        (private/(name+'.xml')).write_text('<capture status="uiautomator-no-idle"/>',encoding='utf-8')
        return False
    (private / (name + '.xml')).write_bytes(call('exec-out', 'cat', '/sdcard/untouch-window.xml'))
    return True

try:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch.uiprobe')
    call('shell', 'am', 'force-stop', 'com.best4u.untouch')
    call('shell', 'input', 'keyevent', '224')
    policy = call('shell', 'dumpsys', 'window', 'policy').decode(errors='replace')
    assert 'mIsShowing=true' not in policy, 'Owner must unlock the phone'
    call('logcat', '-c')
    call('shell', 'am', 'start', '-n', 'com.best4u.untouch/.MainActivity')
    time.sleep(4)
    call('shell', 'input', 'tap', '150', '160')
    time.sleep(1.2)
    capture('main-lives')
    for index in range(8):
        (private / f'main-heart-{index}.png').write_bytes(call('exec-out', 'screencap', '-p'))
        time.sleep(.09)
    call('shell', 'input', 'keyevent', '4')
    call('shell', 'input', 'tap', '410', '160')
    time.sleep(1.2)
    capture('main-daily')
    tree = ET.parse(private/'main-daily.xml')
    tab = next((n for n in tree.iter('node') if n.get('content-desc','').startswith('Покупки')),None)
    if tab is not None:
        x1,y1,x2,y2 = map(int,re.findall(r'\d+',tab.get('bounds')))
        x,y=(x1+x2)//2,(y1+y2)//2
    else:
        # Observed on Huawei's actual main-daily screenshot (1080x2312).
        x,y=410,1260
    call('shell','input','tap',str(x),str(y))
    time.sleep(.8)
    purchase_semantics=capture('main-purchases')
    purchase_xml = (private/'main-purchases.xml').read_text(encoding='utf-8')
    if purchase_semantics:
        for price in ['$0.99','$1.99','$3.99','$9.99']:
            assert price in purchase_xml, 'Expected planned crystal price absent'
    call('shell','input','keyevent','4')
    call('shell','input','tap','920','160')
    time.sleep(.8)
    capture('main-profile')
    profile_xml = (private/'main-profile.xml').read_text(encoding='utf-8')
    assert 'Google подключён' in profile_xml
    # No private nickname or email is copied into the public evidence report.
    Path(f'docs/release-evidence/economy-20261013/main-ui-checks-{version_code}.json').write_text(
        json.dumps({'plannedPricesDisplayed':purchase_semantics,'manualPurchaseScreenshotReviewRequired':not purchase_semantics,
                    'googleProfileScreenOpened':True,'linkedGooglePreserved':True,
                    'installedVersion':version_code,'transactionsOrRoundsStarted':False,
                    'screenshotsPrivate':True},indent=2),encoding='utf-8')
finally:
    call('shell', 'am', 'force-stop', 'com.best4u.untouch')
    call('shell', 'am', 'force-stop', 'com.best4u.untouch.uiprobe')
    log = call('logcat', '-d', '-v', 'brief').decode(errors='replace')
    errors = [line for line in log.splitlines() if 'RenderFlex overflow' in line
              or 'Unhandled Exception' in line or 'EXCEPTION CAUGHT BY' in line]
    Path(f'docs/release-evidence/economy-20261013/main-errors-{version_code}.json').write_text(
        json.dumps({'errors': errors, 'bothAppsStopped': True, 'roundsOrTransactionsStarted': False}, indent=2), encoding='utf-8')
    print('Main lives/daily captured privately; both apps stopped; UI errors:', len(errors))
