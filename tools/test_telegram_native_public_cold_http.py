"""Authorized public negative launch smoke. GETs and one invalid-signature read-only auth POST only."""
import asyncio,hashlib,json,time,urllib.parse,urllib.request,urllib.error,argparse
from datetime import datetime,timezone
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--build-id',required=True);args=parser.parse_args();expected_version='.'.join(args.build_id.split('_')[0][1:].split('.'));
root=Path(__file__).resolve().parents[1];out=root/'docs/release-evidence/telegram-helmet-native-launch-20261015';checks=[];origin='https://untouch.ballaball.xyz/'
def need(v,t):
 if not v:raise AssertionError(t)
def case(n,fn):
 try:checks.append({'name':n,'status':'PASS','value':fn()})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
def getjson(name,host=origin):
 req=urllib.request.Request(host+name+'?verify=independent-native-cold-'+str(int(time.time())),headers={'Cache-Control':'no-cache','Accept-Encoding':'identity'})
 with urllib.request.urlopen(req,timeout=25) as r:return json.loads(r.read().decode('utf-8-sig'))
def identities():
 game=getjson('release.json');version=getjson('version.json');need(game['version']==version['version']==expected_version and game['buildId']==args.build_id,'Public version differs from requested cold build');return game
case('public-game-release-and-requested-cold-version',identities)
def unchanged():
 c=getjson('api/config.php');n=getjson('api/mobile.php');l=getjson('release.json','https://untouch.fun/');need(c.get('ok') and c['revision']=='ddcca375631890786720d18132de3068f35dfd7aac53a2e340cdbd9be02665ef' and c['config']['mobileEnemies']=={'startSpeedSteps':30,'accelerationSteps':5},'Admin pace changed');need(n['buildId']=='mobile-api-v1.0.17_20261013_130903_785','Native API changed');need(l['buildId']=='v1.0.68_20261014_203149_313134','Separate landing changed');return {'revision':c['revision'],'pace':c['config']['mobileEnemies'],'mobile':n['buildId'],'landing':l['buildId']}
case('public-unchanged-admin-pace-native-landing',unchanged)
def negative():
 fake=urllib.parse.urlencode({'auth_date':str(int(time.time())),'user':json.dumps({'id':1}),'hash':'0'*64});req=urllib.request.Request(origin+'api/launch.php',data=json.dumps({'platform':'android','initData':fake}).encode(),headers={'Content-Type':'application/json','Cache-Control':'no-cache'},method='POST')
 try:
  with urllib.request.urlopen(req,timeout=25) as r:status=r.status;data=json.load(r);headers=r.headers
 except urllib.error.HTTPError as r:status=r.code;data=json.load(r);headers=r.headers
 need(status==403 and data.get('ok') is False and data.get('verified') is not True and 'no-store' in headers.get('Cache-Control',''),'Invalid native launch accepted');return {'http':status,'body':data,'payload':'Invented positive numeric id +zero hash; no real initData, not a user action'}
case('public-invalid-signature-native403',negative)
result={'updated':datetime.now(timezone.utc).isoformat(),'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':sum(x['status']=='FAIL' for x in checks)},'checks':checks,'limits':['Only authorized GETs +one invalid-signature read-only launch POST','No valid initData/users/players/payments/messages/FTP','No real Telegram/device/FPS claim']};(out/'public-cold-http-independent.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([x for x in checks if x['status']=='FAIL']));raise SystemExit(result['summary']['fail']>0)

