"""Run approved economics against disposable MySQL wallets; never live players."""
import base64
import ftplib
import io
import json
from pathlib import Path
import secrets
import ssl
import sys
import urllib.request

ROOT=Path(__file__).resolve().parent.parent
credentials=json.load(sys.stdin)
def connect():
    context=ssl.create_default_context();context.maximum_version=ssl.TLSVersion.TLSv1_2
    ftp=ftplib.FTP_TLS(context=context,timeout=30)
    ftp.connect(credentials['host'],int(credentials.get('port',21)));ftp.auth()
    ftp.login(credentials['user'],credentials['password']);ftp.prot_p();ftp.cwd('/')
    return ftp
ftp=connect();body=io.BytesIO()
try:ftp.retrbinary('RETR api/mobile_wallet.php',body.write)
finally:ftp.close()
wallet=body.getvalue().decode('utf-8-sig')
wallet=wallet[wallet.index('function mobile_wallet_mutate('):]
wallet=wallet.replace('function mobile_wallet_mutate(', 'function economy_test_wallet_mutate(').replace('mobile_beta_credit_amount(', 'economy_test_beta_credit_amount(')
beta=(ROOT/'tmp/economy-20261013/api-source/mobile_beta.php').read_text(encoding='utf-8')[5:].replace('mobile_beta_', 'economy_test_beta_')
config=json.loads((ROOT/'tmp/economy-20261013/candidate.json').read_text(encoding='utf-8'))['economy']
encoded=base64.b64encode(json.dumps(config,ensure_ascii=False).encode()).decode()
nonce,gate=secrets.token_hex(8),secrets.token_hex(32)
prefix='_untouch_ec_test_'+nonce+'_';endpoint='api/_ec_test_'+nonce+'.php'
php='''<?php
header('Content-Type: application/json');header('Cache-Control: no-store');
if($_SERVER['REQUEST_METHOD']!=='POST'||!hash_equals('__GATE__',$_SERVER['HTTP_X_UNTOUCH_TEST']??'')){http_response_code(404);exit;}
require __DIR__.'/tg_common.php';require __DIR__.'/mobile_store.php';require __DIR__.'/mobile_wallet.php';
__BETA__
__WALLET__
try {
 [$pdo]=tg_connect_pdo();$prefix='__PREFIX__';$input=json_decode(file_get_contents('php://input'),true);
 if($input['action']==='cleanup'){
  foreach(['mobile_rounds','mobile_devices','mobile_operations','mobile_purchases','mobile_names','mobile_players','scores'] as $t)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($t,$prefix));
  echo '{"ok":true}';exit;
 }
 $scores=mobile_table('scores',$prefix);$now=2000000000000;$config=json_decode(base64_decode('__CONFIG__'),true);$checks=[];
 $pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,user_id VARCHAR(64),player_name VARCHAR(128)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
 mobile_migrate($pdo,$prefix);
 function fixture($pdo,$prefix,$now,$config,$tokens=200,$premium=false){
  $secret=bin2hex(random_bytes(32));mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$prefix);
  $p=mobile_auth($pdo,$secret,$prefix);$w=mobile_wallet_seed($config);$w['tokens']=$tokens;$w['lives']=10;$w['plusUntil']=$premium?$now+8*86400000:0;
  mobile_wallet_write($pdo,$p['id'],$w,$prefix);return mobile_auth($pdo,$secret,$prefix);
 }
 foreach([[1,1],[10,15],[25,50],[49,100]] as $pack){
  $p=fixture($pdo,$prefix,$now,$config);$key=bin2hex(random_bytes(32));
  $result=economy_test_wallet_mutate($pdo,$p,$key,'lives',['lives'=>$pack[1],'costTokens'=>$pack[0]],$now,$config,$prefix);
  if($result['wallet']['tokens']!==200-$pack[0]||$result['wallet']['lives']!==10+$pack[1])throw new Exception('Life offer debit');
  if(economy_test_wallet_mutate($pdo,$p,$key,'lives',['lives'=>$pack[1],'costTokens'=>$pack[0]],$now,$config,$prefix)!=$result)throw new Exception('Life replay');
 }
 $p=fixture($pdo,$prefix,$now,$config,0);$denied=false;
 try{economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'lives',['lives'=>100,'costTokens'=>49],$now,$config,$prefix);}catch(MobileError $e){$denied=$e->getMessage()==='insufficient_crystals';}
 if(!$denied)throw new Exception('Insufficient balance');
 $checks[]='all four life exchanges; exact debit; replay; insufficient balance';
 foreach(['rent_jump','rent_helmet'] as $kind){foreach([false,true] as $hour){
  $p=fixture($pdo,$prefix,$now,$config);$r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),$kind,['hour'=>$hour],$now,$config,$prefix);
  $field=$kind==='rent_jump'?'jumpUntil':'helmetUntil';
  if($r['wallet']['tokens']!==200-($hour?20:10)||$r['wallet'][$field]!==$now+($hour?60:10)*60000)throw new Exception('Rental cost/duration');
 }}
 $checks[]='helmet/jump ten crystals ten minutes;20 one hour';
 $p=fixture($pdo,$prefix,$now,$config,0);$expected=[2,4,8,12,18,24,36];$sum=0;
 foreach($expected as $day=>$amount){$sum+=$amount;$r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'daily',[],$now+$day*86400000,$config,$prefix);if($r['wallet']['tokens']!==$sum)throw new Exception('Daily schedule');}
 $p=fixture($pdo,$prefix,$now,$config,0,true);$r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'daily',[],$now,$config,$prefix);
 if($r['wallet']['tokens']!==(int)round(2*$config['premiumDailyMultiplier']))throw new Exception('Plus multiplier');
 $checks[]='daily2/4/8/12/18/24/36; existing Plus multiplier';
 $p=fixture($pdo,$prefix,$now,$config,0);$key=bin2hex(random_bytes(32));$r=economy_test_wallet_mutate($pdo,$p,$key,'timed',[],$now,$config,$prefix);
 if($r['wallet']['tokens']!==4||economy_test_wallet_mutate($pdo,$p,$key,'timed',[],$now,$config,$prefix)!=$r)throw new Exception('Hourly amount/replay');
 $denied=false;try{economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'timed',[],$now+3599999,$config,$prefix);}catch(MobileError $e){$denied=$e->getMessage()==='timed_not_ready';}if(!$denied)throw new Exception('Hourly cooldown');
 $r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'timed',[],$now+3600000,$config,$prefix);if($r['wallet']['tokens']!==8)throw new Exception('Hourly exact boundary');
 $p=fixture($pdo,$prefix,$now,$config,0);$r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'watch_ad',['reward'=>99999],$now,$config,$prefix);
 if($r['wallet']['tokens']!==10)throw new Exception('Server ad amount');
 $checks[]='hourly4/cooldown/replay/exact boundary; simulated ad reward10 ignores client amount';
 $products=tg_products_from_economy($config);
 foreach(['pack_s'=>20,'pack_m'=>50,'pack_l'=>200,'pack_xl'=>1000] as $id=>$amount){
  if($products[$id]['crystals']!==$amount||economy_test_beta_credit_amount($id,true)!==$amount)throw new Exception('Purchase/beta catalogue');
  $p=fixture($pdo,$prefix,$now,$config,0);$r=economy_test_wallet_mutate($pdo,$p,bin2hex(random_bytes(32)),'beta_free_crystals',['productId'=>$id],$now,$config,$prefix,true);
  if($r['wallet']['tokens']!==$amount)throw new Exception('Beta credit amount');
 }
 $checks[]='20/50/200/1000 product and beta catalogue; fixture credit exact';
 echo json_encode(['ok'=>true,'checks'=>$checks,'realPlayerDataTouched'=>false,'paymentsOrRealAdsPerformed'=>false]);
}catch(Throwable $error){echo json_encode(['ok'=>false,'error'=>get_class($error).':'.$error->getMessage()]);}
'''.replace('__GATE__',gate).replace('__PREFIX__',prefix).replace('__BETA__',beta).replace('__WALLET__',wallet).replace('__CONFIG__',encoded)
def rpc(action):
    request=urllib.request.Request('https://untouch.ballaball.xyz/'+endpoint,data=json.dumps({'action':action}).encode(),headers={'Content-Type':'application/json','X-Untouch-Test':gate})
    with urllib.request.urlopen(request,timeout=40) as response:result=json.load(response)
    if not result.get('ok'):raise RuntimeError('Fixture check failed: '+str(result.get('error')))
    return result
uploaded=False
try:
    ftp=connect()
    try:ftp.storbinary('STOR '+endpoint,io.BytesIO(php.encode()));uploaded=True
    finally:ftp.close()
    result=rpc('test')
finally:
    cleanup_error=None
    try:
        if uploaded:rpc('cleanup')
    except Exception as error:cleanup_error=error
    finally:
        if uploaded:
            ftp=connect()
            try:ftp.delete(endpoint)
            finally:ftp.close()
    if cleanup_error:raise cleanup_error
result['tablesAndEndpointRemoved']=True
out=ROOT/'docs/release-evidence/economy-20261013/server-checks.json'
out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PASS: real MySQL economy/catalogue checks; own tables and endpoint removed')
