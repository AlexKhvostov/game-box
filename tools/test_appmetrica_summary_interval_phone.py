"""Real five-minute UI interval on the isolated physical Android package."""
import json, subprocess, time, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/release-evidence/appmetrica-summary-20261024'
ADB='C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.best4u.untouch.uiprobe.analytics'
def adb(*args): return subprocess.check_output([ADB,*args],stderr=subprocess.STDOUT)
def get(port=8883): return json.load(urllib.request.urlopen(f'http://127.0.0.1:{port}/state',timeout=5))
try:
    adb('reverse','tcp:8883','tcp:8883'); adb('forward','tcp:8879','tcp:8879')
    before=len(get()['events'])
    adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
    end=time.monotonic()+30
    while time.monotonic()<end:
        try:
            state=get(8879)
            if state.get('brake') is not None and not state['playing']: break
        except (OSError,ValueError): pass
        time.sleep(.2)
    else: raise AssertionError('QA home unavailable')
    adb('shell','input','tap','920','155')
    opened=time.monotonic()
    end=opened+330
    while time.monotonic()<end:
        current=get()['events'][before:]
        intervals=[e['params'] for e in current if e['name']=='ui_summary' and e['params'].get('flush_reason')=='interval']
        if intervals: break
        time.sleep(2)
    else: raise AssertionError('No actual five-minute summary')
    first=intervals[0]
    assert first.get('window_profile_open_count')==1,first
    assert first.get('window_profile_active_ms',0)>290000,first
    time.sleep(7)
    adb('shell','input','keyevent','KEYCODE_BACK')
    adb('shell','input','keyevent','KEYCODE_HOME')
    time.sleep(8)
    current=get()['events'][before:]
    summaries=[e['params'] for e in current if e['name']=='ui_summary']
    assert len(summaries)==2,current
    second=summaries[1]
    assert 'window_profile_open_count' not in second,second
    assert second.get('window_profile_close_count')==1,second
    assert second.get('window_profile_active_ms',0)>5000,second
    assert not any(e['name']!='ui_summary' for e in current),current
    result={'passed':True,'physicalDevice':True,'actualIntervalSeconds':time.monotonic()-opened,'eventCount':len(current),'first':first,'second':second,'errors':get(8879)['errors']}
    result['profileTotalMs'] = sum(p.get('window_profile_active_ms', 0) for p in summaries)
    result['foregroundTotalMs'] = sum(p.get('foreground_ms', 0) for p in summaries)
    # actualIntervalSeconds includes the explicit 8s wait after leaving the app.
    # Remaining tolerance covers adb Back/Home dispatch, not another interval.
    result['observedHoldApproxMs'] = round((result['actualIntervalSeconds'] - 8) * 1000)
    result['timingDifferenceMs'] = abs(result['profileTotalMs'] - result['observedHoldApproxMs'])
    assert 0 <= result['foregroundTotalMs'] - result['profileTotalMs'] < 5000, result
    assert result['timingDifferenceMs'] < 2500, result
    assert not result['errors']
    (OUT/'phone-interval-acceptance.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':True,'actualFiveMinuteInterval':True,'eventCount':len(current),'firstProfileMs':first['window_profile_active_ms'],'secondProfileMs':second['window_profile_active_ms']}),flush=True)
finally:
    adb('shell','am','force-stop',PACKAGE)
    adb('shell','am','force-stop','com.best4u.untouch')
