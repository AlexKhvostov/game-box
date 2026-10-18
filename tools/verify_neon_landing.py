"""Verify deliverable bytes, referenced assets and unchanged demo mechanics."""
import argparse, hashlib, json, re, zipfile, subprocess, base64
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit
p=argparse.ArgumentParser()
p.add_argument('release',type=Path)
p.add_argument('--baseline',type=Path)
p.add_argument('--deployment-baseline',type=Path)
p.add_argument('--android-demo',action='store_true')
a=p.parse_args()
release=a.release.resolve(); site=release/'site'
manifest=json.loads((release/'manifest.json').read_text(encoding='utf-8-sig'))
archive=next(release.glob('untouch-*.zip'))
with zipfile.ZipFile(archive) as z:
    for item in manifest['files']:
        content=(site/item['path']).read_bytes()
        assert hashlib.sha256(content).hexdigest()==item['sha256'],item['path']
        assert z.read(item['path'])==content,item['path']
        assert not item['path'].startswith(('api/','privacy/','delete-account/')),item['path']
class Page(HTMLParser):
    def __init__(self):super().__init__();self.assets=[];self.anchors=[];self.ids=set()
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if 'id' in attrs:self.ids.add(attrs['id'])
        if tag in ('img','script') and 'src' in attrs:self.assets.append(attrs['src'])
        if tag=='img' and 'data-src' in attrs:self.assets.append(attrs['data-src'])
        if tag=='link' and 'href' in attrs:self.assets.append(attrs['href'])
        if tag=='a' and attrs.get('href','').startswith('#'):self.anchors.append(attrs['href'][1:])
page=Page();page.feed((site/'index.html').read_text(encoding='utf-8-sig'))
for asset in page.assets:
    parsed=urlsplit(asset)
    if not parsed.scheme:assert (site/parsed.path).is_file(),asset
for anchor in page.anchors:
    if anchor:assert anchor in page.ids,anchor
if (site/'media.js').is_file():
    for name,size in re.findall(r"'(assets/neon-[^']+)':(\d+)",(site/'media.js').read_text(encoding='utf-8-sig')):
        assert (site/name).stat().st_size==int(size),'Range size mismatch: '+name
if (site/'assets/delivery.json').is_file():
    delivery=json.loads((site/'assets/delivery.json').read_text(encoding='ascii'))
    for name,info in delivery.items():
        chunks=[]
        for part in info['parts']:
            assert (site/part).stat().st_size<16384,'Oversized image part'
            chunks.append(base64.b64decode(json.loads((site/part).read_text(encoding='ascii'))['data']))
        content=b''.join(chunks)
        assert content==(site/name).read_bytes() and hashlib.sha256(content).hexdigest()==info['sha256']
if a.baseline:
    baseline=a.baseline.resolve()
    before=json.loads((baseline/'manifest.json').read_text(encoding='utf-8'))
    with zipfile.ZipFile(baseline.with_suffix('.zip')) as z:
        for item in before['files']:
            assert hashlib.sha256(z.read('site/'+item['path'])).hexdigest()==item['sha256']
    def normalize(text):return re.sub(r'\?v=[^\'\"]+','',text).lstrip('\ufeff').strip()
    for name in (('game-world.js','util.js') if a.android_demo else ('config.js','game-world.js','renderer.js','util.js')):
        assert normalize((site/'demo-engine'/name).read_text(encoding='utf-8-sig'))==normalize((baseline/'site/demo-engine'/name).read_text(encoding='utf-8-sig')),name
    before_demo=normalize((baseline/'site/demo.js').read_text(encoding='utf-8-sig')).replace("accent:'#c6f76b',danger:'#fb6c83'","accent:'#43ecc0',danger:'#ff6b7a'")
    after_demo=normalize((site/'demo.js').read_text(encoding='utf-8-sig'))
    if not a.android_demo:
        assert before_demo[before_demo.index('const KEY'):]==after_demo[after_demo.index('const KEY'):],'Demo behavior differs beyond colors'
    published=json.loads((a.deployment_baseline/'manifest.json').read_text(encoding='utf-8-sig')) if a.deployment_baseline else before
    old_hashes={item['path']:item['sha256'] for item in published['files']}
    manifest['expectedBeforeHashes']={item['path']:old_hashes.get(item['path']) for item in manifest['files']}
    (release/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
if a.android_demo:
    subprocess.run(['node','--experimental-default-type=module',str(Path(__file__).with_name('test_landing_parity.mjs')),str(site)],check=True)
result=dict(buildId=manifest['buildId'],files=len(manifest['files']),bytes=sum(i['bytes'] for i in manifest['files']),zipHashes=True,assets=True,anchors=True,baselineVerified=bool(a.baseline),demoBehaviorUnchanged=bool(a.baseline) and not a.android_demo,androidParity=a.android_demo)
(release/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
