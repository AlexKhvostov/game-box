"""Build only the GA4 landing delta over a verified, immutable landing baseline."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,re,shutil,zipfile
p=argparse.ArgumentParser()
p.add_argument('--baseline',type=Path,required=True)
p.add_argument('--public-baseline',type=Path,required=True)
p.add_argument('--measurement-id',required=True)
p.add_argument('--version',required=True)
a=p.parse_args()
assert re.fullmatch(r'G-[A-Z0-9]{6,}',a.measurement_id) and 'TEST' not in a.measurement_id,'Real GA4 stream required'
assert re.fullmatch(r'\d+\.\d+\.\d+',a.version)
root=Path(__file__).resolve().parents[1]
old=json.loads((a.baseline/'manifest.json').read_text(encoding='utf-8-sig'))
published=json.loads((a.public_baseline/'hashes.json').read_text(encoding='utf-8'))
for file in ['index.html','demo.js','release.json']:
    record=next(x for x in old['files'] if x['path']==file)
    assert published[file]==record['sha256'],'Published baseline changed: '+file
now=datetime.now(timezone.utc)
build='v'+a.version+'_'+now.strftime('%Y%m%d_%H%M%S_%f')
release=root/'releases'/('landing-'+build)
assert not release.exists()
site=release/'site'
shutil.copytree(a.baseline/'site',site)
for file in ['index.html','demo.js','analytics.js','analytics.css','privacy/index.html']:
    target=site/file;target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/'telegram-web/landing'/file,target)
index=(site/'index.html').read_text(encoding='utf-8-sig')
assert index.count('data-measurement-id=""')==1
index=index.replace('data-measurement-id=""',f'data-measurement-id="{a.measurement_id}"')
for name in ['neon.css','hero.css','stores.js']:
    index=index.replace('"'+name+'"','"'+name+'?v='+old['buildId']+'"')
for name in ['demo.js','analytics.js','analytics.css']:
    index=index.replace('"'+name+'"','"'+name+'?v='+build+'"')
(site/'index.html').write_text(index,encoding='utf-8')
demo=(site/'demo.js').read_text(encoding='utf-8-sig')
demo=re.sub(r"from '(\./[^']+?\.js)(\?v=[^']*)?'",lambda m:"from '"+m[1]+'?v='+old['buildId']+"'",demo)
(site/'demo.js').write_text(demo,encoding='utf-8')
identity={'version':a.version,'buildId':build,'artifact':'landing','createdAt':now.isoformat()}
(site/'release.json').write_text(json.dumps(identity,indent=2),encoding='utf-8')
records=[{'path':f.relative_to(site).as_posix(),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
         for f in sorted(site.rglob('*')) if f.is_file()]
expected={x['path']:x['sha256'] for x in old['files']}
expected.update(published)
assert all(x['path'] in expected for x in records)
manifest={**identity,'files':records,'expectedBeforeHashes':expected,'analyticsMeasurementId':a.measurement_id}
(release/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
with zipfile.ZipFile(release/('untouch-landing-'+build+'.zip'),'w',zipfile.ZIP_DEFLATED) as z:
    for item in records:
        z.write(site/item['path'],item['path'])
print(json.dumps({'releasePath':str(release.relative_to(root)).replace('\\','/'),'buildId':build,'changedFiles':[
    x['path'] for x in records if expected[x['path']]!=x['sha256']]}))
