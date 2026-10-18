"""Independent local ResumeBackup artifact validation; never FTP/HTTP."""
import argparse, hashlib, json, zipfile
from pathlib import Path
from datetime import datetime, timezone
p=argparse.ArgumentParser();p.add_argument('predeploy',type=Path);a=p.parse_args();folder=a.predeploy.resolve();release=folder.parent
load=lambda q:json.loads(q.read_text(encoding='utf-8-sig'))
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
r=load(folder/'deployment.json');snapshot=Path(r['sourceSnapshot']);s=load(snapshot/'manifest.json');c=load(release/'manifest.json');old={x['path']:x for x in s['files']};new={x['path']:x for x in c['files']};checks=[]
def need(v,m):
 if not v:raise AssertionError(m)
def case(n,f):
 try:checks.append({'name':n,'status':'PASS','value':f()})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
def identity():
 need(r['state']=='backup-complete' and r['uploaded']==[],'Not pre-upload ready')
 need(r['remoteRoot']=='/' and r['buildId']==c['buildId'] and c['version']=='1.0.69','Wrong release/root')
 need(r['sourceRequestedDate']=='2026-10-14' and r['sourceSnapshotState']==s['state']=='local-and-FTP-complete','Unaccepted snapshot')
 need(r['sourceOldIdentity']==s['oldIdentity'] and r['publicOldIdentityRechecked'] is True,'Old identity proof missing')
 need(r['sourceSnapshotManifestSHA256']==sha(snapshot/'manifest.json') and r['sourceSnapshotArchiveSHA256']==s['archiveSha256']==sha(snapshot/s['archive']),'Snapshot hash drift')
 need(r['candidateManifestSHA256']==sha(release/'manifest.json'),'Candidate hash drift')
 return {'buildId':r['buildId'],'oldVersion':s['version'],'snapshot':str(snapshot)}
case('accepted-old-snapshot-and-ready-candidate',identity)
def sets():
 existing=set(old)&set(new);absent=set(new)-set(old)
 need(set(r['existing'])==existing and len(r['existing'])==len(existing),'Wrong existing set')
 need(set(r['absent'])==absent and len(r['absent'])==len(absent),'Wrong absent set')
 expected={n for n in existing if old[n]['sha256']==new[n]['sha256']}
 need(set(r['unchanged'])==expected,'Wrong unchanged set')
 need(r['oldSHA256']=={n:old[n]['sha256'] for n in existing},'Wrong old hash map')
 return {'existing':len(existing),'absent':len(absent),'unchanged':len(expected),'candidate':len(new)}
case('complete-disjoint-existing-absent-unchanged',sets)
def facts():
 b=datetime.fromisoformat(r['recheckStartedAt']);e=datetime.fromisoformat(r['recheckCompletedAt']);need(b<=e and e==datetime.fromisoformat(r['createdAt']),'Invalid chronology')
 rows=r['snapshotFactsRechecked'];need(len(rows)==len(old) and {x['path'] for x in rows}==set(old),'Not all logical snapshot paths rechecked')
 for x in rows:
  o=old[x['path']];need((x['bytes'],x['modify'])==(o['bytes'],o['modify']),'Remote metadata changed')
  need(b<=datetime.fromisoformat(x['checkedAt'])<=e,'Fact outside check window')
 arr=r['absentFactsRechecked'];need(len(arr)==len(r['absent']) and {x['path'] for x in arr}==set(r['absent']),'Missing absence proof')
 for x in arr:
  parts=x['path'].split('/');parent=x['verifiedParent'].strip('/');idx=parts.index(x['missingComponent']);need('/'.join(parts[:idx])==parent,'Wrong ancestor proof')
  need(b<=datetime.fromisoformat(x['checkedAt'])<=e,'Absence fact outside check window')
 return {'snapshotFacts':len(rows),'absenceFacts':len(arr),'startedAt':b.isoformat(),'completedAt':e.isoformat()}
case('all-original-facts-and-ancestor-absence-recorded',facts)
def originals():
 actual={x.relative_to(folder).as_posix() for x in folder.rglob('*') if x.is_file()};need(actual==set(r['existing'])|{'deployment.json'},'Unexpected predeploy files')
 for n in r['existing']:
  q=folder/n;need(q.stat().st_size==old[n]['bytes'] and sha(q)==old[n]['sha256']==r['oldSHA256'][n],'Old copied byte mismatch: '+n)
 return len(r['existing'])
case('every-copied-original-bytes-SHA',originals)
def zipped():
 q=folder.with_suffix('.zip')
 with zipfile.ZipFile(q) as z:
  names=z.namelist();need(len(names)==len(set(names)) and set(names)==set(r['existing'])|{'deployment.json'},'ZIP missing/duplicate/extra')
  need(z.testzip() is None,'ZIP CRC failed')
  need(z.read('deployment.json')==(folder/'deployment.json').read_bytes(),'ZIP deployment record differs')
  for n in r['existing']:need(hashlib.sha256(z.read(n)).hexdigest()==old[n]['sha256'],'ZIP old-byte mismatch')
 return {'bytes':q.stat().st_size,'sha256':sha(q)}
case('predeploy-ZIP-CRC-every-member-SHA',zipped)
def candidate():
 actual={x.relative_to(release/'site').as_posix() for x in (release/'site').rglob('*') if x.is_file()};need(actual==set(new),'Candidate inventory drift')
 for n,x in new.items():need((release/'site'/n).stat().st_size==x['bytes'] and sha(release/'site'/n)==x['sha256'],'Candidate byte drift')
 return len(new)
case('candidate-frozen-bytes',candidate)
result={'updated':datetime.now(timezone.utc).isoformat(),'predeploy':str(folder),'remoteChecks':'Metadata from actual reviewed preparer; independent verifier opens no remote connections','summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':sum(x['status']=='FAIL' for x in checks)},'checks':checks}
out=Path(__file__).resolve().parent.parent/'docs/release-evidence/telegram-neon-release-20261014/predeploy-verification.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([x for x in checks if x['status']=='FAIL'],ensure_ascii=True));raise SystemExit(result['summary']['fail']>0)
