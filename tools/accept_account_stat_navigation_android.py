"""Read-only visual acceptance on the owner's phone; no game-field actions."""
from pathlib import Path
import subprocess
import sys
import time

ADB = Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch'
OUT = Path(__file__).resolve().parents[1] / '.private/account-stat-navigation-20261018/native'
OUT.mkdir(parents=True, exist_ok=True)
devices = [s.split()[0] for s in subprocess.check_output([str(ADB), 'devices']).decode().splitlines() if '\tdevice' in s]
assert len(devices) == 1
def adb(*args):
    return subprocess.check_output([str(ADB), '-s', devices[0], *map(str,args)])
action = sys.argv[1]
if action == 'start':
    adb('shell','am','force-stop',PACKAGE)
    adb('shell','am','start','-n',PACKAGE+'/.MainActivity')
    time.sleep(12)
elif action == 'stop':
    adb('shell','am','force-stop',PACKAGE)
elif action == 'tap':
    adb('shell','input','tap',int(sys.argv[2]),int(sys.argv[3]))
    time.sleep(.8)
elif action == 'back':
    adb('shell','input','keyevent','4')
    time.sleep(.4)
elif action != 'capture':
    raise ValueError('Unknown action')
if action != 'stop':
    name = sys.argv[-1] if action in ['capture','tap','start','back'] and len(sys.argv)>2 else 'home'
    assert name.replace('-','').replace('_','').isalnum()
    (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
    print(str(OUT/(name+'.png')))
