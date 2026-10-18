"""Lossless, small static JSON parts for hosting routes that stall large/ranged reads."""
from pathlib import Path
import re,json,base64,hashlib,argparse
parser=argparse.ArgumentParser();parser.add_argument('--site',type=Path);parser.add_argument('--include-modules',action='store_true');args=parser.parse_args()
root=Path(__file__).resolve().parents[1];site=args.site or root/'telegram-web/landing'
paths=sorted(set(re.findall(r'data-src="(assets/neon-[a-z0-9-]+\.webp)"',(site/'index.html').read_text(encoding='utf-8-sig'))))
if args.include_modules: paths+=['demo-engine/game-world.js','demo-engine/renderer.js']
directory=site/'assets/delivery-parts';directory.mkdir(exist_ok=True)
manifest={}
for relative in paths:
    raw=(site/relative).read_bytes();digest=hashlib.sha256(raw).hexdigest();parts=[];reassembled=[]
    for index,start in enumerate(range(0,len(raw),8192)):
        data=raw[start:start+8192]
        name=f'{Path(relative).stem}-{digest[:12]}-{index:02}.json'
        payload=json.dumps({'data':base64.b64encode(data).decode('ascii')},separators=(',',':'))
        (directory/name).write_text(payload,encoding='ascii')
        parts.append('assets/delivery-parts/'+name)
        reassembled.append(base64.b64decode(json.loads(payload)['data']))
    assert b''.join(reassembled)==raw
    manifest[relative]={'size':len(raw),'sha256':digest,'parts':parts}
(site/'assets/delivery.json').write_text(json.dumps(manifest,separators=(',',':')),encoding='ascii')
print(json.dumps({'images':len(manifest),'parts':sum(len(x['parts']) for x in manifest.values()),'manifestBytes':(site/'assets/delivery.json').stat().st_size,'lossless':True}))
