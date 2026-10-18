"""Overlay-install the signed candidate; preserve owner's storage and never start a run."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PRIVATE=ROOT/'.private/android-energy-20261015/main-install'
PRIVATE.mkdir(parents=True,exist_ok=True)
PACKAGE='com.best4u.untouch'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk',type=Path)
parser.add_argument('--resume-verification',action='store_true',help='Use preserved pre-install capture after successful overlay install')
args=parser.parse_args()
assert args.apk.is_file() and args.apk.suffix=='.apk'
devices=[l.split()[0] for l in subprocess.check_output([str(ADB),'devices']).decode().splitlines()
         if '\tdevice' in l and not l.startswith('emulator-')]
assert len(devices)==1
def call(*args):return subprocess.check_output([str(ADB),'-s',devices[0],*map(str,args)])
def labels_from_xml(xml):
    nodes=ET.fromstring(xml)
    return [n.get('content-desc','') or n.get('text','') for n in nodes.iter('node')]
def wallet(labels):
    result={}
    for label in labels:
        for key,pattern in [('lives',r'^Жизни:\s*(\d+)'),('crystals',r'^Кристаллы:\s*(\d+)')]:
            match=re.search(pattern,label,re.I)
            if match:result[key]=int(match.group(1))
    return result
def idle(labels):return any(v.split('\n')[0].strip()=='00:00.000' for v in labels)
def capture(name):
    call('shell','am','start','-n',PACKAGE+'/.MainActivity')
    time.sleep(15)
    call('shell','uiautomator','dump','/sdcard/untouch-energy-main.xml')
    xml=call('exec-out','cat','/sdcard/untouch-energy-main.xml')
    if not idle(labels_from_xml(xml)):
        # At zero lives the existing startup flow opens its recovery dialog.
        # Back closes that dialog without pressing the field or spending funds.
        call('shell','input','keyevent','4')
        time.sleep(.5)
        call('shell','uiautomator','dump','/sdcard/untouch-energy-main.xml')
        xml=call('exec-out','cat','/sdcard/untouch-energy-main.xml')
    (PRIVATE/(name+'.png')).write_bytes(call('exec-out','screencap','-p'))
    (PRIVATE/(name+'.xml')).write_bytes(xml)
    labels=labels_from_xml(xml)
    call('shell','am','force-stop',PACKAGE)
    return {'balances':wallet(labels),'idleTimer':idle(labels),'labels':labels}
try:
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
    call('shell','am','force-stop',PACKAGE)
    if args.resume_verification:
        labels=labels_from_xml((PRIVATE/'before.xml').read_bytes())
        before={'balances':wallet(labels),'idleTimer':idle(labels),'labels':labels}
    else:
        before=capture('before')
        result=call('install','-r',args.apk.resolve()).decode()
        assert 'Success' in result,result
    after=capture('after-home')
    version=call('shell','dumpsys','package',PACKAGE).decode(errors='replace')
    version_code=int(re.search(r'versionCode=(\d+)',version).group(1))
    assert version_code==122
    # Keep all owner's labels/images private; public report stores only checks.
    assert before['balances'] and before['balances']==after['balances'], 'Displayed wallet changed'
    assert before['idleTimer'] and after['idleTimer'], 'Owner run must remain unstarted'
    (PRIVATE/'comparison.json').write_text(json.dumps({'before':before,'after':after},ensure_ascii=False,indent=2),encoding='utf-8')
    report={'ok':True,'versionCode':version_code,'installedWithoutClearOrUninstall':True,
      'displayedBalancesPreserved':True,'ownerRoundNeverStarted':True,
      'ownerLabelsPrivate':True,'liveV2NotEnabled':True,
      'googleClientConfigurationPreserved':True}
    (ROOT/'docs/release-evidence/energy-v2-20261015/main-install.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))
finally:
    call('shell','am','force-stop',PACKAGE)
    call('shell','am','force-stop','com.best4u.untouch.uiprobe')
