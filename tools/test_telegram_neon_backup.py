"""Independent read-only local backup metadata/ZIP review. No FTP/HTTP."""
import argparse, hashlib, json, re, zipfile
from pathlib import Path, PurePosixPath
from datetime import datetime, timezone, timedelta
parser=argparse.ArgumentParser();parser.add_argument('backup',type=Path);args=parser.parse_args()
root=Path(__file__).resolve().parent.parent;folder=args.backup.resolve();out=root/'docs/release-evidence/telegram-neon-release-20261014';out.mkdir(parents=True,exist_ok=True)
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
manifest=read(folder/'manifest.json');checks=[];failures=[]
def need(ok,message):
 if not ok:raise AssertionError(message)
def check(name,fn):
 try:checks.append({'name':name,'status':'PASS','value':fn()})
 except Exception as error:failures.append({'name':name,'error':str(error)});checks.append({'name':name,'status':'FAIL','error':str(error)})
def identity():
 need(manifest['state']=='local-and-FTP-complete','Backup not complete')
 need(manifest['requestedDate']=='2026-10-14' and manifest['remoteRoot']=='/','Requested label/root mismatch')
 need(manifest['artifact']=='telegram-rollback','Wrong backup artifact')
 need(manifest['ftpArchiveVerified'] is True and manifest['httpAccessDenied'] is True,'Remote protection/readback missing')
 need(re.fullmatch(r'/\.backups/telegram-before-neon-2026-10-14_\d{8}_\d{6}_\d{6}',manifest['remoteDirectory']), 'Unprotected/unexpected remote folder')
 need(manifest['ftpArchive']==manifest['remoteDirectory']+'/'+manifest['archive'],'Remote ZIP path mismatch')
 archive_match=re.fullmatch(r'telegram-before-neon-2026-10-14(?:-verified-(\d{8}_\d{6}_\d{6}))?\.zip',manifest['archive'])
 need(archive_match and (not archive_match.group(1) or manifest['remoteDirectory'].endswith('_'+archive_match.group(1))),'Verified ZIP/remote nonce mismatch')
 need(read(folder/'site/release.json')==manifest['oldIdentity'],'Previous game identity mismatch')
 need(manifest['version']!= '1.0.69','Snapshot is already new game')
 times=[datetime.fromisoformat(manifest[x]) for x in ['startedAt','completedAt','finishedAt']]
 need(times==sorted(times),'Backup completion time order')
 return {'requestedDate':manifest['requestedDate'],'actualMinskStarted':times[0].astimezone(timezone(timedelta(hours=3))).isoformat(),'oldIdentity':manifest['oldIdentity'],'remoteDirectory':manifest['remoteDirectory']}
check('complete-private-dated-backup-identity',identity)
files=manifest['files'];paths=[x['path'] for x in files];private={'api/scores.php','api/tg_common.php','api/mobile_store.php'};roots={'.htaccess','index.html','release.json','version.json','manifest.json','favicon.png','i.php'}
def scope():
 need(len(paths)==len(set(paths)),'Duplicate backup paths')
 for name in paths:
  p=PurePosixPath(name);need(not p.is_absolute() and '..'not in p.parts and '\\'not in name,'Unsafe backup path')
  need(name in roots or p.parts[0] in {'js','css','config','assets','icons'} or name in private,'Unrelated/protected backup path: '+name)
 need(set(x for x in paths if x.startswith('api/'))==private,'Profile rollback set incomplete')
 groups={}
 for item in files:groups.setdefault(item['path'].casefold(),[]).append(item)
 expected_aliases=sorted(tuple(sorted(x['path'] for x in rows)) for rows in groups.values() if len(rows)>1)
 for rows in groups.values():need(len({(x['bytes'],x['sha256']) for x in rows})==1,'Conflicting case aliases')
 declared=sorted(tuple(sorted(rows)) for rows in manifest.get('identicalCaseAliases',[]))
 need(declared==expected_aliases,'Case alias declaration mismatch')
 actual={p.relative_to(folder/'site').as_posix() for p in (folder/'site').rglob('*') if p.is_file()}
 need({x.casefold() for x in actual}==set(groups) and len(actual)==len(groups),'Backup physical/casefold site mismatch')
 inv=read(folder/'inventory.json');need(sorted((x['path'],x['bytes'],x['modify']) for x in inv)==sorted((x['path'],x['bytes'],x['modify']) for x in files),'Inventory/manifest mismatch')
 return {'files':len(paths),'bytes':sum(x['bytes'] for x in files),'physicalFiles':len(actual),'identicalCaseGroups':len(expected_aliases),'api':sorted(private)}
check('complete-prior-client-plus-only-three-API',scope)
if not any(x['name']=='complete-prior-client-plus-only-three-API' for x in failures):
 def site_hashes():
  for item in files:
   file=folder/'site'/item['path'];need(file.stat().st_size==item['bytes'],'Backup file size mismatch: '+item['path']);need(hashlib.sha256(file.read_bytes()).hexdigest()==item['sha256'],'Backup file SHA mismatch: '+item['path'])
  return len(files)
 check('all-local-backup-bytes-SHA',site_hashes)
 def archive():
  zip_path=folder/manifest['archive'];need(zip_path.stat().st_size==manifest['archiveBytes'],'Backup ZIP size mismatch');need(hashlib.sha256(zip_path.read_bytes()).hexdigest()==manifest['archiveSha256'],'Backup ZIP SHA mismatch')
  with zipfile.ZipFile(zip_path) as z:
   need(z.testzip() is None,'ZIP CRC mismatch');names=[x.filename for x in z.infolist() if not x.is_dir()]
   expected={'site/'+x for x in paths}|{'inventory.json','manifest.json','RESTORE.md'};need(len(names)==len(set(names)) and set(names)==expected,'ZIP set mismatch')
   for item in files:need(hashlib.sha256(z.read('site/'+item['path'])).hexdigest()==item['sha256'],'ZIP member SHA mismatch: '+item['path'])
   inside=json.loads(z.read('manifest.json').decode('utf-8-sig'));need(inside['state']=='local-complete' and inside['files']==files and inside['oldIdentity']==manifest['oldIdentity'],'Local/FTP-complete manifests disagree beyond terminal metadata')
  return {'sha256':manifest['archiveSha256'],'bytes':manifest['archiveBytes'],'innerState':'local-complete','outerState':manifest['state']}
 check('ZIP-CRC-SHA-all-members-snapshot-state',archive)
result={'updated':datetime.now(timezone.utc).isoformat(),'kind':'Independent local artifact read-only review; remote FTP/hash/403 established by reviewed helper terminal metadata, not a second remote connection','backup':str(folder),'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':len(failures)},'checks':checks,'failures':failures}
(out/'backup-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(result['summary']));
for error in failures:print(json.dumps(error,ensure_ascii=False))
raise SystemExit(bool(failures))
