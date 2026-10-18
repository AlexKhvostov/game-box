import collections
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
trace = json.loads(path.read_text(encoding='utf-8'))
stacks = collections.defaultdict(list)
durations = collections.defaultdict(list)
for e in trace['traceEvents']:
    key = (e.get('pid'), e.get('tid'))
    if e.get('ph') == 'B': stacks[key].append(e)
    if e.get('ph') == 'E' and stacks[key]:
        start = stacks[key].pop()
        if e['ts'] >= start['ts']:
            durations[start['name']].append((e['ts']-start['ts'])/1000)
    if e.get('ph') == 'X': durations[e['name']].append(e.get('dur',0)/1000)
summary = {name: dict(count=len(v), totalMs=round(sum(v),3), maxMs=round(max(v),3),
                     p95Ms=round(sorted(v)[round((len(v)-1)*.95)],3)) for name,v in durations.items()}
summary = dict(sorted(summary.items(),key=lambda x:x[1]['totalMs'],reverse=True))
path.with_name('events-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(dict(list(summary.items())[:32])))
