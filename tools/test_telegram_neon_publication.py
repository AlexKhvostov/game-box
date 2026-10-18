"""Independent terminal release gate. Local reads plus explicitly allowed public GETs only."""
import argparse, hashlib, json, zipfile, urllib.request, urllib.parse
from pathlib import Path
from datetime import datetime, timezone
p=argparse.ArgumentParser();p.add_argument('--https',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1];release=root/'releases/telegram-neon-v1.0.69_20261014_210147_890';backup=release/'predeploy-20261014_220707_756576';out=root/'docs/release-evidence/telegram-neon-release-20261014';load=lambda q:json.loads(q.read_text(encoding='utf-8-sig'));sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
r=load(backup/'deployment.json');m=load(release/'manifest.json');sdir=Path(r['sourceSnapshot']);s=load(sdir/'manifest.json');old={x['path']:x for x in s['files']};new={x['path']:x for x in m['files']};checks=[]
def need(v,text):
 if not v:raise AssertionError(text)
def case(n,f):
 try:checks.append({'name':n,'status':'PASS','value':f()})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
def terminal():
 need(r['state']=='uploaded-and-verified' and r['buildId']==m['buildId'] and r['remoteRoot']=='/','Wrong terminal record')
 need(set(r['existing'])==set(old)&set(new) and set(r['absent'])==set(new)-set(old),'Scope differs')
 unchanged={n for n in set(old)&set(new) if old[n]['sha256']==new[n]['sha256']};uploaded=set(new)-unchanged
 need(set(r['unchanged'])==unchanged and set(r['uploaded'])==uploaded,'Uploaded/unchanged not complete')
 need(len(r['uploaded'])==len(uploaded) and len(r['unchanged'])==len(unchanged),'Duplicate record')
 need(r['candidateManifestSHA256']==sha(release/'manifest.json') and r['sourceSnapshotManifestSHA256']==sha(sdir/'manifest.json'),'Manifest drift')
 need(r['sourceSnapshotArchiveSHA256']==s['archiveSha256']==sha(sdir/s['archive']) and s['state']=='local-and-FTP-complete' and s['ftpArchiveVerified'] and s['httpAccessDenied'],'Old backup invalid')
 return {'uploaded':len(uploaded),'unchanged':len(unchanged),'total':len(new)}
case('terminal-FTPS-record-disjoint-complete-scope',terminal)
def artifacts():
 for n,x in new.items():need(sha(release/'site'/n)==x['sha256'],'Candidate changed '+n)
 for n in r['existing']:need(sha(backup/n)==old[n]['sha256']==r['oldSHA256'][n],'Rollback byte changed '+n)
 zpath=backup.with_suffix('.zip');need(sha(zpath)=='f38470ac3e928eae708964225640f45ec3caad7717feba31b8856f65508b2809','Rollback ZIP drift')
 with zipfile.ZipFile(zpath) as z:
  need(z.testzip() is None and set(z.namelist())==set(r['existing'])|{'deployment.json'},'Rollback ZIP corrupt')
  inside=json.loads(z.read('deployment.json'));need(inside['state']=='backup-complete' and inside['uploaded']==[],'ZIP original gate record changed')
  for n in r['existing']:need(hashlib.sha256(z.read(n)).hexdigest()==old[n]['sha256'],'Rollback ZIP bytes changed')
 accepted=load(root/'docs/release-evidence/telegram-final-parity-20261014/source-freeze.json')['acceptedHashes'];historical=load(out/'release-verification.json');need(len(accepted)==95 and historical['summary']=={'pass':69,'fail':0},'Historical accepted build proof missing')
 drift=[x['path'] for x in accepted if sha(root/x['path'])!=x['sha256']]
 return {'candidateFiles':len(new),'acceptedBuildTimeSourceHashes':len(accepted),'rollbackCopies':len(r['existing']),'currentWorkspaceDrift':drift,'workspaceNote':'Separate explicitly authorized Android energy work after packaging; not in frozen121 release. Current95 equality is not claimed.'}
case('frozen-release-historical-source95-and-retained-rollback-bytes',artifacts)
if a.https:
 nonce=m['buildId']+'-independent-'+datetime.now(timezone.utc).strftime('%H%M%S');origin='https://untouch.ballaball.xyz/'
 def get(name,host=origin,start=None,end=None,total=None):
  h={'Cache-Control':'no-cache','Accept-Encoding':'identity'}
  if start is not None:h['Range']=f'bytes={start}-{end}'
  q=urllib.request.Request(host+urllib.parse.quote(name)+'?verify='+nonce,headers=h)
  with urllib.request.urlopen(q,timeout=25) as x:
   if start is not None:need(x.status==206 and x.headers.get('Content-Range')==f'bytes {start}-{end}/{total}','Range response mismatch')
   data=x.read(1048576)
  if start is not None:need(len(data)==end-start+1,'Incomplete range')
  return data
 def jsonget(n,host=origin):return json.loads(get(n,host).decode('utf-8-sig'))
 def identities():
  # Samples are explicitly authorized while root reconciles the final landing-ID guard.
  identity=jsonget('release.json');v=jsonget('version.json');need(identity['buildId']==m['buildId'] and identity['version']==v['version']=='1.0.69','Public69 differs')
  return {'buildId':identity['buildId'],'version':v['version']}
 case('actual-independent-public-release-and-version',identities)
 def smallcss():
  n='css/neon-profile-help.css';b=get(n);need(len(b)==new[n]['bytes'] and hashlib.sha256(b).hexdigest()==new[n]['sha256'],'Public CSS differs');return {'path':n,'bytes':len(b),'sha256':new[n]['sha256']}
 case('actual-small-CSS-full-SHA',smallcss)
 def main():
  n='js/main.js';size=new[n]['bytes'];parts=[]
  for start in range(0,size,16384):parts.append(get(n,start=start,end=min(size-1,start+16383),total=size))
  b=b''.join(parts);need(len(b)==size and hashlib.sha256(b).hexdigest()==new[n]['sha256'],'Public main range hash differs');return {'path':n,'ranges':len(parts),'bytes':size,'sha256':new[n]['sha256']}
 case('actual-main-16K-ranges-entire-SHA',main)
 def protected():
  c=jsonget('api/config.php');need(c.get('ok') and c['revision']=='ddcca375631890786720d18132de3068f35dfd7aac53a2e340cdbd9be02665ef','Config changed');need(c['config']['mobileEnemies']=={'startSpeedSteps':30,'accelerationSteps':5},'Android pace changed')
  mobile=jsonget('api/mobile.php');need(mobile['buildId']=='mobile-api-v1.0.17_20261013_130903_785','NativeAPI changed')
  landing=jsonget('release.json','https://untouch.fun/');need(landing['version']=='1.0.68' and landing['buildId']=='v1.0.68_20261014_203149_313134','Landing changed')
  return {'configRevision':c['revision'],'mobileEnemies':c['config']['mobileEnemies'],'nativeBuildId':mobile['buildId'],'landingBuildId':landing['buildId']}
 case('actual-readonly-admin-native-and-separate-landing',protected)
result={'updated':datetime.now(timezone.utc).isoformat(),'kind':'Independent terminal artifact gate'+(' + explicitly authorized actual public HTTPS GETs' if a.https else ' local only; HTTPS awaited'),'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':sum(x['status']=='FAIL' for x in checks)},'checks':checks,'limits':['No FTP or POST by verifier','No players/profile/score/payment/message writes','No actual Telegram/device/iOS/FPS check']};(out/('publication-independent.json' if a.https else 'terminal-local-independent.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([x for x in checks if x['status']=='FAIL'],ensure_ascii=True));raise SystemExit(result['summary']['fail']>0)

