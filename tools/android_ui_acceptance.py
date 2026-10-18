"""Small explicit native UI steps for an authorized physical Android session.

No wallet/reset/login shortcuts. Call read() before choosing a visible label.
Receipt/account text is kept out of public logs unless specifically selected.
"""
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ADB=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'

class Phone:
    def __init__(self):
        devices=[x.split()[0] for x in subprocess.check_output([str(ADB),'devices']).decode().splitlines() if '\tdevice' in x and not x.startswith('emulator-')]
        assert len(devices)==1,'Exactly one authorized phone required'
        self.base=[str(ADB),'-s',devices[0]]
        self.nodes=[]
    def adb(self,*args):
        return subprocess.check_output(self.base+list(map(str,args)))
    def read(self):
        for attempt in range(3):
            output=self.adb('shell','uiautomator','dump','/sdcard/untouch-sandbox-qa.xml')
            if b'dumped to' in output:break
            if attempt==2:raise RuntimeError('Native UI hierarchy not ready')
            time.sleep(.3)
        root=ET.fromstring(self.adb('shell','cat','/sdcard/untouch-sandbox-qa.xml'))
        self.nodes=[n for n in root.iter('node') if n.get('text') or n.get('content-desc')]
        return [(n.get('text') or n.get('content-desc'),n.get('bounds')) for n in self.nodes]
    def click(self,label,contains=False):
        matches=[]
        for n in self.nodes:
            text=n.get('text') or n.get('content-desc') or ''
            if (label in text if contains else label==text):
                x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
                if x2>x1 and y2>y1:matches.append(((x2-x1)*(y2-y1),x1,y1,x2,y2))
        assert matches,'Visible label missing: '+label
        _,x1,y1,x2,y2=min(matches)
        self.adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2)
    def start(self):
        self.adb('shell','am','start','-n','com.best4u.untouch/.MainActivity')
        time.sleep(1)
    def stop(self):
        self.adb('shell','am','force-stop','com.best4u.untouch')
    def screenshot(self,path):
        Path(path).parent.mkdir(parents=True,exist_ok=True)
        Path(path).write_bytes(self.adb('exec-out','screencap','-p'))
