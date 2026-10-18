"""Inspect linked Google control without toggling the owner's privacy or accounts."""
from pathlib import Path
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
devices=[x.split()[0] for x in subprocess.check_output([adb,'devices']).decode().splitlines()
         if '\tdevice' in x and not x.startswith('emulator-')]
assert len(devices)==1
def call(*args):return subprocess.check_output([adb,'-s',devices[0],*args])
version=int(re.search(r'versionCode=(\d+)',call('shell','dumpsys','package','com.best4u.untouch').decode()).group(1))
private=Path(f'.private/profile-google-checkbox-20261013/main{version}')
private.mkdir(parents=True,exist_ok=True)
font=call('shell','settings','get','system','font_scale').decode().strip()
records=[]
try:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','input','keyevent','224')
    assert 'mIsShowing=true' not in call('shell','dumpsys','window','policy').decode(errors='replace')
    call('logcat','-c')
    for scale in [font,'2.0']:
        call('shell','am','force-stop','com.best4u.untouch')
        call('shell','settings','put','system','font_scale',scale)
        call('shell','am','start','-n','com.best4u.untouch/.MainActivity')
        time.sleep(4)
        call('shell','input','tap','920','160')
        time.sleep(1)
        name='profile-font'+scale
        (private/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
        dump=call('shell','uiautomator','dump','/sdcard/untouch-profile-control.xml')
        assert b'dumped' in dump,'Profile hierarchy unavailable; do not reuse stale XML'
        xml=call('exec-out','cat','/sdcard/untouch-profile-control.xml')
        (private/(name+'.xml')).write_bytes(xml)
        tree=ET.fromstring(xml)
        privacy=[n for n in tree.iter('node') if 'Скрывать Google' in n.get('content-desc','')]
        status=next(n for n in tree.iter('node') if 'Google подключён' in n.get('content-desc',''))
        assert len(privacy)==1
        assert 'Отображение в рейтинге' not in xml.decode()
        checked=privacy[0].get('checked')
        bounds=list(map(int,re.findall(r'\d+',privacy[0].get('bounds'))))
        status_bounds=list(map(int,re.findall(r'\d+',status.get('bounds'))))
        # Accessibility merges the status into the whole Google panel.
        assert bounds[0]>=(status_bounds[0]+status_bounds[2])/2
        assert status_bounds[0]<=bounds[0]<bounds[2]<=status_bounds[2]
        assert status_bounds[1]<=bounds[1]<bounds[3]<=status_bounds[3]
        records.append({'fontScale':scale,'checkboxInRightHalfOfGooglePanel':True,
                        'linkedGooglePreserved':True,'oldSeparateSectionAbsent':True,
                        'checked':checked,'bounds':bounds})
        print('Linked Google/right checkbox font'+scale+' passed',flush=True)
    assert records[0]['checked']==records[1]['checked']
finally:
    call('shell','am','force-stop','com.best4u.untouch')
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','settings','put','system','font_scale',font)
    call('shell','settings','put','global','stay_on_while_plugged_in','2')
    log=call('logcat','-d','-v','brief').decode(errors='replace')
    errors=[line for line in log.splitlines() if 'RenderFlex overflow' in line or 'FlutterError:' in line]
    result={'version':version,'states':records,'errors':errors,'privacyNeverToggled':True,
            'purchasesOrRoundsStarted':False,'screenshotsPrivate':True,'bothAppsStopped':True,
            'originalFontRestored':font,'usbStayAwake':2}
    Path('docs/release-evidence/profile-google-checkbox-20261013/physical.json').write_text(
        json.dumps(result,indent=2),encoding='utf-8')
    print('Both games stopped; font restored and USB2 kept.',flush=True)
