"""Physical UI acceptance using only the isolated synthetic update package."""
from pathlib import Path
import json, re, subprocess, sys, time, urllib.request, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
ADB=Path('C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe')
PACKAGE='com.best4u.untouch.uiprobe.updates'
MAIN='com.best4u.untouch'
OUT=ROOT/'docs/release-evidence/android-flexible-update-20261024'
OUT.mkdir(parents=True,exist_ok=True)
devices=subprocess.check_output([str(ADB),'devices'],text=True)
connected=[line.split()[0] for line in devices.splitlines()[1:] if line.endswith('\tdevice')]
assert len(connected)==1,'Expected one explicitly connected physical device'
BASE=[str(ADB),'-s',connected[0]]
def adb(*args):return subprocess.check_output(BASE+list(args),stderr=subprocess.STDOUT)
def shell(*args):return adb('shell',*args).decode('utf-8',errors='replace')
def version():
    match=re.search(r'versionCode=(\d+)',shell('dumpsys','package',MAIN))
    return int(match.group(1)) if match else None
def api(route='/snapshot'):
    with urllib.request.urlopen('http://127.0.0.1:18897'+route,timeout=8) as response:
        return json.load(response)
def wait_for(predicate,timeout=12):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        try:
            value=api()
            if predicate(value):return value
        except Exception:pass
        time.sleep(.15)
    raise AssertionError('Expected QA state did not arrive')
def tap(label):
    shell('uiautomator','dump','/sdcard/untouch-update-qa.xml')
    raw=shell('cat','/sdcard/untouch-update-qa.xml')
    tree=ET.fromstring(raw[raw.index('<?xml'):])
    matches=[node for node in tree.iter('node') if node.attrib.get('text')==label or node.attrib.get('content-desc')==label]
    assert matches, f'Button not found: {label}'
    bounds=list(map(int,re.findall(r'\d+',matches[0].attrib['bounds'])))
    shell('input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2))
def screenshot(name):(OUT/name).write_bytes(adb('exec-out','screencap','-p'))
checks=[]
before=version()
try:
    shell('am','force-stop',PACKAGE)
    result=adb('install','-r',sys.argv[1]).decode()
    assert 'Success' in result,result
    adb('forward','tcp:18897','tcp:8897')
    shell('am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
    wait_for(lambda state:state['phase']=='unavailable',timeout=30)
    assert api('/native')['supported'] is False
    checks.append('Native Play channel compiled/responds; USB-installed QA correctly unsupported')
    api('/state?value=offer');wait_for(lambda s:s['dialog']=='available')
    screenshot('phone-offer.png');tap('Позже')
    wait_for(lambda s:s['dialog'] is None and s['banner'])
    checks.append('Offer Later preserves play and manual download action')
    tap('Скачать');wait_for(lambda s:s['dialog']=='available');tap('Скачать')
    wait_for(lambda s:s['phase']=='downloading' and s['dialog'] is None)
    screenshot('phone-downloading.png')
    # Touch the production game field, not the update banner.
    size=list(map(int,re.findall(r'\d+',shell('wm','size'))[-2:]))
    shell('input','tap',str(size[0]//2),str(int(size[1]*.38)))
    playing=wait_for(lambda s:s['playing'] and s['timeMs']>0)
    api('/state?value=ready')
    during=api();assert during['dialog'] is None and during['banner'] is False,during
    checks.append('Downloaded event does not interrupt actual game/result or show a banner')
    api('/finish');wait_for(lambda s:s['result'])
    result=api();assert result['dialog'] is None,result
    checks.append('Production result remains unobscured and attempt is recorded')
    api('/result-close');wait_for(lambda s:s['dialog']=='ready')
    screenshot('phone-ready.png');tap('Позже')
    deferred=wait_for(lambda s:s['dialog'] is None and s['banner'])
    assert deferred['completions']==0
    shell('input','keyevent','3');shell('am','start','-n',PACKAGE+'/com.best4u.untouch.MainActivity')
    restored=wait_for(lambda s:s['phase']=='ready' and s['dialog'] is None and s['banner'])
    screenshot('phone-ready-later.png')
    checks.append('Ready Later survives background/foreground; no automatic restart')
    tap('Перезапустить и обновить');wait_for(lambda s:s['dialog']=='ready')
    tap('Перезапустить и обновить')
    failed=wait_for(lambda s:s['dialog']=='failed')
    assert failed['completions']==1 and failed['attempt'] is not None,failed
    screenshot('phone-error.png');tap('Позже')
    final=wait_for(lambda s:s['dialog'] is None)
    assert not final['errors'],final['errors']
    checks.append('Explicit restart waits for saved attempt; synthetic installer failure is recoverable')
finally:
    shell('am','force-stop',PACKAGE)
    shell('am','force-stop',MAIN)
    adb('forward','--remove','tcp:18897')
    after=version()
    assert before==after,'Main app version changed'
    checks.append('Main installation version preserved; both games stopped; ADB forward removed')
    (OUT/'phone-checks.json').write_text(json.dumps({
        'checks':checks,'mainVersionBefore':before,'mainVersionAfter':after,
        'screenStayOn':shell('settings','get','global','stay_on_while_plugged_in').strip(),
        'limitation':'Physical production UI, synthetic Play state. No real download or installation from Google Play.'
    },ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':checks},ensure_ascii=False))
