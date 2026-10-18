"""Independent actual launch.php via isolated PHP server and fake bot token; no production HTTP/DB."""
import hashlib,hmac,json,os,shutil,socket,subprocess,time,urllib.parse,urllib.request,urllib.error
from pathlib import Path
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1];parent=root/'tmp/telegram-helmet-native-launch-20261015/verifier';stand=parent/('php-'+str(time.time_ns()));stand.mkdir();assert stand.resolve().is_relative_to(parent.resolve());api=stand/'api';api.mkdir()
for name,src in [('launch.php',root/'telegram-web/api/launch.php'),('tg_common.php',root/'releases/telegram-neon-v1.0.69_20261014_210147_890/site/api/tg_common.php')]:shutil.copyfile(src,api/name)
token='fixture-token-never-production';(api/'bot_config.php').write_text("<?php return ['token'=>'"+token+"'];",encoding='utf-8');sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close();proc=subprocess.Popen(['C:/xampp/php/php.exe','-S',f'127.0.0.1:{port}','-t',str(stand)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0));checks=[]
def signed(fields):
 fields={k:str(v) if not isinstance(v,(dict,list)) else json.dumps(v,separators=(',',':'),ensure_ascii=False) for k,v in fields.items()};secret=hmac.new(b'WebAppData',token.encode(),hashlib.sha256).digest();fields['hash']=hmac.new(secret,'\n'.join(k+'='+fields[k] for k in sorted(fields)).encode(),hashlib.sha256).hexdigest();return urllib.parse.urlencode(fields)
def base(user=None,**kw):return signed({'auth_date':str(int(time.time())),'query_id':'isolated-fixture','user':user if user is not None else {'id':424242,'first_name':'Тест'},**kw})
def req(data,method='POST',ctype='application/json'):
 raw=data if isinstance(data,bytes) else json.dumps(data).encode();q=urllib.request.Request(f'http://127.0.0.1:{port}/api/launch.php',data=raw if method=='POST' else None,headers={'Content-Type':ctype},method=method)
 try:
  with urllib.request.urlopen(q,timeout=5) as x:return x.status,json.loads(x.read())
 except urllib.error.HTTPError as x:return x.code,json.loads(x.read())
def case(n,data,expected,**kw):
 try:
  code,body=req(data,**kw);assert code==expected,(code,expected,body);assert body.get('ok')==(expected==200);assert body.get('verified') is True if expected==200 else body.get('verified') is not True;checks.append({'name':n,'status':'PASS','http':code})
 except Exception as e:checks.append({'name':n,'status':'FAIL','error':str(e)})
try:
 for i in range(50):
  try:socket.create_connection(('127.0.0.1',port),.1).close();break
  except OSError:time.sleep(.05)
 for platform in ['android','ios','tdesktop','macos']:case('native/'+platform,{'platform':platform,'initData':base()},200)
 for platform in ['webk','weba','unknown','browser','']:case('reject-platform/'+platform,{'platform':platform,'initData':base()},403)
 case('GET rejected',{},405,method='GET');case('content-type rejected',b'{}',415,ctype='text/plain');case('invalid JSON',b'{',400);case('missing initData',{'platform':'android'},400);case('empty initData',{'platform':'android','initData':''},400)
 case('invalid signature',{'platform':'android','initData':base()[:-1]+'x'},403)
 case('stale signed',{'platform':'android','initData':base(auth_date=str(int(time.time())-86405))},403);case('future signed',{'platform':'android','initData':base(auth_date=str(int(time.time())+310))},403)
 fields={'user':{'id':424242}};case('missing signed authDate',{'platform':'android','initData':signed(fields)},403)
 for label,user in [('missing id',{'first_name':'Test'}),('negative id',{'id':-1}),('zero id',{'id':0}),('nonnumeric id',{'id':'not-user'}),('array id',{'id':[1]}),('fractional id',{'id':1.25})]:case('invalid signed user/'+label,{'platform':'android','initData':base(user)},403)
 case('duplicate field',{'platform':'android','initData':base()+'&auth_date='+str(int(time.time()))},403)
 case('oversized initData',{'platform':'android','initData':'x'*32769},400)
 case('oversized body',b'x'*65537,413)
 (api/'bot_config.php').write_text('<?php return [];',encoding='utf-8');case('missing configured test token fails closed',{'platform':'android','initData':base()},503)
finally:
 proc.terminate();proc.wait(timeout=5)
 assert stand.resolve().is_relative_to(parent.resolve());shutil.rmtree(stand)
result={'updated':datetime.now(timezone.utc).isoformat(),'summary':{'pass':sum(x['status']=='PASS' for x in checks),'fail':sum(x['status']=='FAIL' for x in checks)},'checks':checks,'endpointSHA256':hashlib.sha256((root/'telegram-web/api/launch.php').read_bytes()).hexdigest(),'network':'Only owned127.0.0.1 PHP stand; fake token, no DB/messages/production','sharedHelper':'immutable published69 tg_common exact copied'};q=root/'docs/release-evidence/telegram-helmet-native-launch-20261015/launch-php-independent.json';q.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(result['summary']));print(json.dumps([x for x in checks if x['status']=='FAIL']));raise SystemExit(result['summary']['fail']>0)

