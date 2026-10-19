"""Measure isolated production screen; never modifies the owner's package."""
import argparse, json, subprocess, time, urllib.request
from pathlib import Path

def stats(values):
    s=sorted(values)
    def q(f): return round(s[round((len(s)-1)*f)],3) if s else 0
    return dict(n=len(s),p50=q(.5),p95=q(.95),p99=q(.99),max=q(1),
                over16_7=sum(v>16.7 for v in s),over33_4=sum(v>33.4 for v in s),over50=sum(v>50 for v in s))

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--label',required=True)
    p.add_argument('--seconds',type=float,default=8);p.add_argument('--device',required=True)
    p.add_argument('--sharp',action='store_true')
    p.add_argument('--native-sharp',action='store_true')
    a=p.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
    pkg='com.best4u.untouch.uiprobe.review'
    def run(*args):return subprocess.check_output([adb,'-s',a.device,*args],text=True,encoding='utf-8',errors='replace')
    def get(path):
        with urllib.request.urlopen('http://127.0.0.1:8898'+path,timeout=20) as r:return json.load(r)
    try:
        run('shell','am','force-stop',pkg);run('forward','tcp:8898','tcp:8898')
        run('shell','am','start','-n',pkg+'/com.best4u.untouch.MainActivity')
        for i in range(80):
            try:
                state=get('/state')
                if 'field' in state:break
            except (OSError,ValueError):pass
            time.sleep(.15)
        conditions={k:run('shell',*v) for k,v in dict(battery=['dumpsys','battery'],lowPower=['settings','get','global','low_power'],density=['wm','density']).items()}
        get('/perf-clear')
        if a.native_sharp:
            f=state['field'];cx=(f[0]+f[2])/2;cy=(f[1]+f[3])/2
            gestures=[(-300,-230,300,230),(300,230,-300,230),(-300,230,300,-230),(0,-340,0,340),(-350,0,350,0)]
            until=time.monotonic()+a.seconds;count=0
            while time.monotonic()<until:
                x1,y1,x2,y2=gestures[count%len(gestures)]
                run('shell','input','swipe',str(round(cx+x1)),str(round(cy+y1)),str(round(cx+x2)),str(round(cy+y2)),'65')
                count+=1
        else:
            get('/perf-drive?sharp='+str(a.sharp).lower());time.sleep(a.seconds)
        data=get('/perf-stop');data['conditions']=conditions
        (out/(a.label+'-raw.json')).write_text(json.dumps(data),encoding='utf-8')
        frames=data['frames'];ticks=data['ticksUs']
        summary=dict(label=a.label,phase=data['phase'],moves=data['moves'],errors=data['errors'],
            build=stats([f[1]/1000 for f in frames]),raster=stats([f[2]/1000 for f in frames]),
            total=stats([f[3]/1000 for f in frames]),vsyncOverhead=stats([f[4]/1000 for f in frames]),
            intervals=stats([(b-a)/1000 for a,b in zip(ticks,ticks[1:])]),
            firstSecond=stats([max(f[1],f[2])/1000 for f in frames if f[0]<frames[0][0]+1000000]))
        (out/(a.label+'-summary.json')).write_text(json.dumps(summary,indent=2),encoding='utf-8')
        print(json.dumps(summary))
        assert data['phase']=='playing' and (a.native_sharp or data['moves']>200) and not data['errors']
    finally:run('shell','am','force-stop',pkg)

if __name__=='__main__':main()
