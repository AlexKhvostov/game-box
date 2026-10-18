from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit
import argparse,json,hashlib,zipfile,re,subprocess
p=argparse.ArgumentParser();p.add_argument('release',type=Path);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
manifest=json.loads((a.release/'manifest.json').read_text(encoding='utf-8'))
old=json.loads((a.baseline/'manifest.json').read_text(encoding='utf-8-sig'))
site=a.release/'site'
allowed={'analytics.css','analytics.js','demo.js','index.html','privacy/index.html','release.json'}
changed={x['path'] for x in manifest['files'] if manifest['expectedBeforeHashes'][x['path']]!=x['sha256']}
assert changed==allowed
with zipfile.ZipFile(next(a.release.glob('untouch-*.zip'))) as z:
    assert z.testzip() is None
    for item in manifest['files']:
        raw=(site/item['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==item['sha256']
        assert z.read(item['path'])==raw
for item in old['files']:
    if item['path'] not in allowed:assert (site/item['path']).read_bytes()==(a.baseline/'site'/item['path']).read_bytes()
class Links(HTMLParser):
    def __init__(self):super().__init__();self.local=[]
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        for name in (['src','data-src'] if tag in ['img','script'] else ['href'] if tag=='link' else []):
            if name in d and not urlsplit(d[name]).scheme:self.local.append(urlsplit(d[name]).path)
page=Links();page.feed((site/'index.html').read_text(encoding='utf-8-sig'))
for file in page.local:assert (site/file).is_file(),file
def normalize(s):return re.sub(r'\?v=[^\x27\"]+','',s).lstrip('\ufeff').strip()
before=normalize((a.baseline/'site/demo.js').read_text(encoding='utf-8-sig'))
after=normalize((site/'demo.js').read_text(encoding='utf-8-sig'))
after=after.replace('    this.analyticsAttempts = 0;\n','')
after=re.sub(r"    if\(this.status!=='paused'\)\{\s*this.elapsed=0;\s*this.analyticsAttempts\+\+;\s*window.dispatchEvent\(new CustomEvent\('untouch:demo-start', \{detail:\{attempt_number:this.analyticsAttempts\}\}\)\);\s*\}","    if(this.status!=='paused'){this.elapsed=0;}",after)
after=re.sub(r"    window.dispatchEvent\(new CustomEvent\('untouch:demo-end',.*?\n",'',after)
assert before==after,'Demo changed outside instrumentation'
subprocess.run(['node',str(Path(__file__).with_name('test_landing_analytics.mjs'))],check=True)
result={'passed':True,'version':manifest['version'],'measurementId':manifest['analyticsMeasurementId'],
        'changedPaths':sorted(changed),'filesVerified':len(manifest['files']),'archiveCrcAndHashes':True,
        'allExistingNonAnalyticsFilesUnchanged':True,'demoOutsideInstrumentationUnchanged':True,
        'localAssetsResolved':True,'analyticsChecks':9}
a.out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
