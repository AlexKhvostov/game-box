"""Collect reproducible frame timing fixtures on an explicitly selected phone."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import time
import sys
import urllib.request


def summary(data):
    rows = data['frames']
    def stats(values):
        values = sorted(values)
        def at(q):
            return values[round((len(values)-1)*q)] if values else 0
        return dict(n=len(values), p50ms=at(.5), p95ms=at(.95), p99ms=at(.99), maxMs=at(1),
                    over16_7=sum(v > 16.7 for v in values), over33_4=sum(v > 33.4 for v in values),
                    over50=sum(v > 50 for v in values))
    ticks = data['ticksUs']
    return dict(label=data['label'], frames=len(rows), moves=data['moves'],
                sustained=data['sustainedInvulnerabilityFixture'], idle=data['idle'], errors=data['errors'],
                build=stats([r[1]/1000 for r in rows]), raster=stats([r[2]/1000 for r in rows]),
                total=stats([r[3]/1000 for r in rows]), vsyncOverhead=stats([r[4]/1000 for r in rows]),
                tickIntervals=stats([(b-a)/1000 for a,b in zip(ticks,ticks[1:])]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--scenario', choices=['startup', 'idle', 'move-off', 'move-sound', 'move-music', 'normal-round', 'profile', 'share'], required=True)
    parser.add_argument('--seconds', type=float, default=25)
    parser.add_argument('--label')
    parser.add_argument('--warmup', action='store_true')
    parser.add_argument('--keep-running', action='store_true', help='Only for immediately consecutive traces; stop after them')
    args = parser.parse_args()
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
    subprocess.check_call([adb,'-s',args.device,'shell','am','start','-n',
        'com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity'],stdout=subprocess.DEVNULL)
    def shell(*commands):
        return subprocess.check_output([adb, '-s', args.device, 'shell', *commands], text=True, encoding='utf-8', errors='replace')
    def request(path):
        with urllib.request.urlopen('http://127.0.0.1:8878'+path, timeout=20) as r:
            return json.load(r)
    label = args.label or args.scenario
    for attempt in range(40):
        try:
            request('/frames')
            break
        except (OSError, ValueError):
            if attempt == 39: raise
            time.sleep(.25)
    if args.warmup:
        request('/warmup')
    conditions = dict(battery=shell('dumpsys','battery'), lowPower=shell('settings','get','global','low_power'),
                      device=shell('getprop','ro.product.model'), android=shell('getprop','ro.build.version.release'),
                      density=shell('wm','density'), refresh=shell('dumpsys','SurfaceFlinger','--latency').splitlines()[:1])
    (out/(label+'-conditions.json')).write_text(json.dumps(conditions, indent=2), encoding='utf-8')
    if args.scenario == 'startup':
        data = request('/frames')
    else:
        sustained = args.scenario.startswith('move-')
        sound = args.scenario in ('move-sound', 'move-music')
        music = args.scenario == 'move-music'
        request(f'/reset?sustained={str(sustained).lower()}&sound={str(sound).lower()}&music={str(music).lower()}')
        if sustained or args.scenario == 'normal-round':
            request('/drive?moving=true')
        # Capture before resetting counters, so screenshot work isn't timed.
        time.sleep(2)
        (out/(label+'.png')).write_bytes(subprocess.check_output([adb,'-s',args.device,'exec-out','screencap','-p']))
        request('/clear?label='+label)
        if args.scenario in ('profile','share'):
            request('/window?name='+args.scenario)
        print('MEASURING '+label, flush=True)
        time.sleep(args.seconds)
        data = request('/frames')
        request('/stop')
    (out/(label+'-raw.json')).write_text(json.dumps(data), encoding='utf-8')
    result = summary(data)
    (out/(label+'-summary.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    try:
        main()
    finally:
        if '--keep-running' not in sys.argv:
            device=sys.argv[sys.argv.index('--device')+1]
            adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
            subprocess.run([adb,'-s',device,'shell','am','force-stop','com.best4u.untouch.uiprobe'],check=False)
