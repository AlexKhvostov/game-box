"""Isolated shop draw trace; service access stays loopback, both apps stop."""
import argparse
import collections
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

p=argparse.ArgumentParser()
p.add_argument('--device',required=True)
p.add_argument('--out',required=True)
a=p.parse_args()
adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
def call(*args):return subprocess.check_output([adb,'-s',a.device,*args])
def request(path):
    with urllib.request.urlopen('http://127.0.0.1:8877/'+path,timeout=20) as r:return json.load(r)
try:
    call('forward','tcp:8877','tcp:8877')
    call('shell','am','start','-n','com.best4u.untouch.uiprobe/com.best4u.untouch.MainActivity','--ez','trace-skia','true')
    for i in range(60):
        try:
            service=request('service');break
        except OSError:
            if i==59:raise
            time.sleep(.25)
    assert service['uri'],'Profile VM service unavailable'
    uri=urllib.parse.urlparse(service['uri'])
    call('forward','tcp:8879','tcp:'+str(uri.port))
    base='http://127.0.0.1:8879'+uri.path
    def rpc(method,**kwargs):
        query=urllib.parse.urlencode({k:'['+','.join(v)+']' if isinstance(v,list) else v for k,v in kwargs.items()})
        with urllib.request.urlopen(base+method+'?'+query,timeout=20) as r:
            data=json.load(r);assert 'error' not in data,data.get('error');return data['result']
    data=request('show?screen=daily&state=claimed&age=known')
    rpc('setVMTimelineFlags',recordedStreams=['Dart','Embedder','GC']);rpc('clearVMTimeline')
    for index in [1,2,3,0,2,0]:
        target=data['targets']['shop-tab-'+str(index)]
        call('shell','input','tap',str(round(target['x'])),str(round(target['y'])))
        time.sleep(.6)
    time.sleep(.3)
    timeline=rpc('getVMTimeline')
    (out/'timeline.json').write_text(json.dumps(timeline),encoding='utf-8')
    values=collections.defaultdict(list);stacks=collections.defaultdict(list)
    for e in timeline['traceEvents']:
        if e.get('ph')=='X':values[e['name']].append(e.get('dur',0)/1000)
        k=(e.get('pid'),e.get('tid'))
        if e.get('ph')=='B':stacks[k].append(e)
        if e.get('ph')=='E' and stacks[k]:
            b=stacks[k].pop()
            if e['ts']>=b['ts']:values[b['name']].append((e['ts']-b['ts'])/1000)
    report={k:dict(n=len(v),totalMs=round(sum(v),2),p50Ms=round(sorted(v)[len(v)//2],2),maxMs=round(max(v),2)) for k,v in values.items()}
    report=dict(sorted(report.items(),key=lambda kv:kv[1]['totalMs'],reverse=True))
    (out/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(dict(list(report.items())[:30])),flush=True)
finally:
    for package in ['com.best4u.untouch.uiprobe','com.best4u.untouch']:
        subprocess.run([adb,'-s',a.device,'shell','am','force-stop',package],capture_output=True)
    for port in ['8877','8879']:
        subprocess.run([adb,'-s',a.device,'forward','--remove','tcp:'+port],capture_output=True)
