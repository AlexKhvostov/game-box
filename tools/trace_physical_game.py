"""Capture a short VM timeline and actual SurfaceFlinger presentation gaps."""
import argparse
import collections
import json
from pathlib import Path
import re
import shlex
import subprocess
import atexit
import threading
import time
import urllib.parse
import urllib.request

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--device', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--seconds', type=float, default=8)
    p.add_argument('--vm-port')
    p.add_argument('--vm-path')
    p.add_argument('--window')
    p.add_argument('--keep-history', action='store_true')
    a = p.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    adb = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
    atexit.register(lambda: subprocess.run([adb, '-s', a.device, 'shell', 'am', 'force-stop',
        'com.best4u.untouch.uiprobe'], check=False))
    def shell(*args):
        return subprocess.check_output([adb, '-s', a.device, 'shell', *args], text=True, encoding='utf-8', errors='replace')
    if a.vm_port and a.vm_path:
        port, token = a.vm_port, a.vm_path
    else:
        with urllib.request.urlopen('http://127.0.0.1:8878/service', timeout=10) as r:
            info = json.load(r)
        service = urllib.parse.urlparse(info['uri'])
        port, token = str(service.port), service.path.strip('/')
    subprocess.check_call([adb,'-s',a.device,'forward','tcp:8879','tcp:'+port], stdout=subprocess.DEVNULL)
    base = 'http://127.0.0.1:8879/'+token+'/'
    def rpc(method, **params):
        query = urllib.parse.urlencode({k: '['+','.join(v)+']' if isinstance(v,list) else v for k,v in params.items()})
        with urllib.request.urlopen(base+method+'?'+query, timeout=20) as r:
            data = json.load(r)
            if 'error' in data: raise RuntimeError(data['error'])
            return data['result']
    layers = shell('dumpsys','SurfaceFlinger','--list').splitlines()
    layer = next(l for l in layers if l.startswith('SurfaceView - com.best4u.untouch.uiprobe/'))
    collected = []
    end = time.monotonic() + a.seconds
    def presentation():
        while time.monotonic() < end:
            collected.append(shell('dumpsys SurfaceFlinger --latency '+shlex.quote(layer)))
            time.sleep(.5)
    rpc('setVMTimelineFlags', recordedStreams=['Dart','Embedder','GC'])
    if not a.keep_history:
        rpc('clearVMTimeline')
    begin = rpc('getVMTimelineMicros')['timestamp']
    if a.window:
        with urllib.request.urlopen('http://127.0.0.1:8878/window?name='+a.window, timeout=10) as r:
            r.read()
    t = threading.Thread(target=presentation); t.start()
    time.sleep(a.seconds)
    finish = rpc('getVMTimelineMicros')['timestamp']
    timeline = rpc('getVMTimeline') if a.keep_history else rpc('getVMTimeline', timeOriginMicros=begin, timeExtentMicros=finish-begin)
    t.join()
    (out/'timeline.json').write_text(json.dumps(timeline), encoding='utf-8')
    (out/'surface-latency.txt').write_text('\n\n'.join(collected), encoding='utf-8')
    durations = collections.defaultdict(list)
    stacks = collections.defaultdict(list)
    for e in timeline['traceEvents']:
        if e.get('ph') == 'X': durations[e['name']].append(e.get('dur',0)/1000)
        key = (e.get('pid'), e.get('tid'))
        if e.get('ph') == 'B': stacks[key].append(e)
        if e.get('ph') == 'E' and stacks[key]:
            start = stacks[key].pop()
            if e['ts'] >= start['ts']: durations[start['name']].append((e['ts']-start['ts'])/1000)
    report = {k: dict(count=len(v), totalMs=round(sum(v),3), maxMs=round(max(v),3),
                      p95Ms=round(sorted(v)[round((len(v)-1)*.95)],3)) for k,v in durations.items()}
    report = dict(sorted(report.items(), key=lambda kv:kv[1]['totalMs'], reverse=True))
    shown = sorted({int(line.split()[1]) for block in collected for line in block.splitlines()[1:]
                    if len(line.split()) == 3 and 0<int(line.split()[1])<2**63-1})
    gaps = [(b-a)/1e6 for a,b in zip(shown,shown[1:])]
    result = dict(events=report, presentedFrames=len(shown), gapsOver25ms=sum(g>25 for g in gaps),
                  maxPresentationGapMs=max(gaps,default=0), presentationGapsMs=gaps)
    (out/'summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(dict(presentedFrames=len(shown), gapsOver25ms=result['gapsOver25ms'],
                         maxGapMs=result['maxPresentationGapMs'], events=dict(list(report.items())[:22]))))

if __name__ == '__main__': main()
