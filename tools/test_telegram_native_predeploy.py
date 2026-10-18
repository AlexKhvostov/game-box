"""Independent read-only native patch predeploy backup proof; no FTP."""
import argparse,json,hashlib,zipfile
from pathlib import Path
from datetime import datetime,timezone
parser=argparse.ArgumentParser();parser.add_argument('--patch',type=Path,required=True);parser.add_argument('--backup',type=Path,required=True);args=parser.parse_args();root=Path(__file__).resolve().parents[1];patch=args.patch.resolve();backup=args.backup.resolve();load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();m=load(patch/'manifest.json');r=load(backup/'deployment.json');before=m['expectedBeforeHashes'];existing={n for n,h in before.items() if h};absent=set(before)-existing;checks=[]
def need(v,t):
 if not v:raise AssertionError(t)
def case(n,fn):
 try:checks.append({'name':n,'status':'PASS','value':fn()})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
def scope():
 need(r['buildId']==m['buildId'] and set(r['existing'])==existing and set(r['absent'])==absent,'Backup scope mismatch');need(not set(r.get('uploaded',[]))-set(before),'Foreign upload recorded');return {'existing':len(existing),'absent':len(absent),'outerStateObserved':r['state']}
case('exact-before-scope-and-build',scope)
def copies():
 actual={p.relative_to(backup).as_posix() for p in backup.rglob('*') if p.is_file()};need(actual==existing|{'deployment.json'},'Unexpected local backup members')
 for n in existing:need(sha(backup/n)==before[n],'Before SHA mismatch '+n)
 return len(existing)
case('every-old-file-exact-frozen-beforeSHA',copies)
def archive():
 zpath=backup.with_suffix('.zip')
 with zipfile.ZipFile(zpath) as z:
  need(z.testzip() is None and len(z.namelist())==len(existing)+1 and set(z.namelist())==existing|{'deployment.json'},'ZIP members/CRC differ')
  for n in existing:need(hashlib.sha256(z.read(n)).hexdigest()==before[n],'ZIP before SHA mismatch '+n)
  inner=json.loads(z.read('deployment.json'));need(inner['state']=='backup-complete' and not inner['uploaded'],'Backup ZIP must preserve pre-upload checkpoint');need(set(inner['existing'])==existing and set(inner['absent'])==absent and inner['buildId']==m['buildId'],'ZIP original scope mismatch')
 return {'archiveSHA256':sha(zpath),'bytes':zpath.stat().st_size}
case('ZIP-original-before-state-members-CRC-SHA',archive)
result={'updated':datetime.now(timezone.utc).isoformat(),'summary':{'pass':sum(c['status']=='PASS' for c in checks),'fail':sum(c['status']=='FAIL' for c in checks)},'checks':checks,'network':'None, local read-only','buildId':m['buildId']};out=root/'docs/release-evidence/telegram-helmet-native-launch-20261015/predeploy-cold-independent.json';out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([c for c in checks if c['status']=='FAIL']));raise SystemExit(result['summary']['fail']>0)
