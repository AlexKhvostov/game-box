"""Independent immutable published71 -> cold-launch72 full/patch validation. No network, build or runtime edits."""
import argparse,hashlib,json,re,zipfile
from pathlib import Path
from datetime import datetime,timezone
parser=argparse.ArgumentParser();parser.add_argument('--full',type=Path,default=Path('releases/v1.0.70_20261014_234418_635'));parser.add_argument('--patch',type=Path,default=Path('releases/telegram-native-patch-v1.0.70_20261014_234418_635'));parser.add_argument('--version',default='1.0.72');parser.add_argument('--baseline',type=Path,default=Path('releases/v1.0.71_20261014_235142_821'));parser.add_argument('--archive-sha',default='f53aeeaacf7ad51afc432b162eb1008479dfab037098320b8d2e76ac34ef4b0c');args=parser.parse_args();root=Path(__file__).resolve().parents[1];base=args.baseline.resolve();full=args.full.resolve();patch=args.patch.resolve();out=root/'docs/release-evidence/telegram-helmet-native-launch-20261015';load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=load(base/'manifest.json');f=load(full/'manifest.json');m=load(patch/'manifest.json');br={x['path']:x for x in b['files']};fr={x['path']:x for x in f['files']};pr={x['path']:x for x in m['files']};accepted=m['acceptedSources'];checks=[]
def need(v,msg):
 if not v:raise AssertionError(msg)
def case(n,fn):
 try:checks.append({'name':n,'status':'PASS','value':fn()})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
def inventory():
 for directory,rows in [(base,br),(full,fr),(patch,pr)]:
  actual={p.relative_to(directory/'site').as_posix() for p in (directory/'site').rglob('*') if p.is_file()};need(actual==set(rows),'Inventory differs')
  for n,x in rows.items():
   p=directory/'site'/n;need(not p.is_symlink() and p.resolve().is_relative_to((directory/'site').resolve()),'Unsafe path');need(p.stat().st_size==x['bytes'] and sha(p)==x['sha256'],'Byte drift '+n)
 need(len(br)==125 and len(fr)==125 and len(pr)>0,'Counts differ');return {'base':len(br),'full':len(fr),'patch':len(pr)}
case('all-three-manifest-site-inventories-bytes-SHA',inventory)
def identity():
 need(f['buildId']==m['buildId'] and m['buildId'].startswith('v'+args.version+'_') and f['version']==m['version']==args.version and f['artifact']==m['artifact']=='telegram-native-launch','Identity differs')
 need(m['sourceFullManifestSHA256']==sha(full/'manifest.json') and m['baselineManifestSHA256']==sha(base/'manifest.json'),'Provenance hash differs')
 for directory in [full,patch]:need(load(directory/'site/release.json')['buildId']==m['buildId'] and load(directory/'site/version.json')['version']==args.version,'Public identity differs')
 return m['buildId']
case('new-version70-full-patch-provenance',identity)
NEW={'api/launch.php','css/neon-launch.css','js/launch.js'};APPROVED=NEW|{'index.html','js/main.js','js/game-world.js'};ACL='api/config-data/.htaccess'
def scope():
 need(set(accepted)==APPROVED and all(sha(root/'telegram-web'/n)==h for n,h in accepted.items()),'Six-source freeze differs')
 need(set(fr)==set(br),'Full scope expanded');need(ACL not in pr,'ACL need not overwrite serverpublication directory')
 changed={n for n,x in fr.items() if n!=ACL and (n not in br or br[n]['sha256']!=x['sha256'])};need(changed==set(pr),'Patch not exactly changed set')
 need(m['expectedBeforeHashes']=={n:br[n]['sha256'] if n in br else None for n in pr},'Before hash gate incomplete')
 need(not any(n.startswith('api/') for n in pr),'Existing/native API in cold-launch patch');
 for n in ['api/launch.php','css/neon-launch.css','js/main.js','js/game-world.js']:
  if n=='css/neon-launch.css':continue
  a=(root/'telegram-web'/n).read_text(encoding='utf-8-sig');old=(base/'site'/n).read_text(encoding='utf-8-sig');norm=lambda t:re.sub(r'\?v=v\d+\.\d+\.\d+_\d+_\d+_\d+', '',t);need(norm(a)==norm(old),'Cold-launch changed physics/API '+n)
 return {'acceptedSources':accepted,'expectedBefore':len(pr),'oldAPIinPatch':0}
case('exact-six-new-policy-sources-and-bounded-before-hash-patch',scope)
def jsbuild(text):return re.sub(r"from '(\./[^']+?\.js)(\?v=[^']*)?'",lambda x:"from '"+x[1]+'?v='+m['buildId']+"'",text)
def text(p):return p.read_text(encoding='utf-8-sig')
def parity():
 for n in fr:
  p=full/'site'/n
  if n.endswith('.js'):
   original=root/'telegram-web'/n if n in APPROVED else base/'site'/n;need(text(p)==jsbuild(text(original)),'JS changed beyond exact import stamping '+n)
  elif n in NEW:need(sha(p)==accepted[n],'New source bytes differ '+n)
  elif n not in {'index.html','release.json','version.json',ACL}:need(sha(p)==br[n]['sha256'],'Unapproved old file changed '+n)
  if n in pr:need(sha(patch/'site'/n)==sha(p),'Patch/full mismatch')
 return {'oldAPI4':'exact published71','config-assets-economy-pace':'exact71 except JS importstamp only','newPHP':'exact accepted'}
case('every-JS-exact-builder-transform-and-all-old-files-immutable',parity)
def html():
 s=text(root/'telegram-web/index.html');s=re.sub(r'''((?:src|href)=["'](?!https?:|//)[^"']+\.(?:js|css))(?:\?v=[^"']*)?(["'])''',lambda x:x[1]+'?v='+m['buildId']+x[2],s);need(s==text(full/'site/index.html'),'HTML changed beyond exact stamping')
 built=text(full/'site/index.html');scripts=re.findall(r'<script[^>]+src="([^"]+)"',built);need(scripts==['js/launch.js?v='+m['buildId']],'Eager game/SDK/helper script')
 need('new URL(import.meta.url).search' in text(full/'site/js/launch.js'),'Dynamic imports lack buildstamp propagation')
 return {'onlyEntry':scripts,'oldAssetsReferences':'frozen canonical71'}
case('index-launcher-only-entry-and-full-stamped-dynamic-loader',html)
def zips():
 results={}
 for directory,rows,prefix in [(full,fr,'untouch-telegram-web-'),(patch,pr,'untouch-telegram-native-')]:
  p=directory/(prefix+m['buildId']+'.zip')
  with zipfile.ZipFile(p) as z:
   need(z.testzip() is None and len(z.namelist())==len(rows) and set(z.namelist())==set(rows),'ZIP paths/CRC differ')
   for n,x in rows.items():need(hashlib.sha256(z.read(n)).hexdigest()==x['sha256'],'ZIP bytes differ '+n)
  results[directory.name]={'sha256':sha(p),'bytes':p.stat().st_size}
 need(results[patch.name]['sha256']==args.archive_sha,'Expected patch SHA differs');return results
case('full125-and-patch15-ZIP-every-member-CRC-SHA',zips)
result={'updated':datetime.now(timezone.utc).isoformat(),'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':sum(x['status']=='FAIL' for x in checks)},'checks':checks,'network':'none, all local read-only','limits':['Not deployment acceptance; root publishes only after functional gate','No current Android/sharedworkingtree content used for old files']};(out/'package-cold-independent.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([x for x in checks if x['status']=='FAIL']));raise SystemExit(result['summary']['fail']>0)


