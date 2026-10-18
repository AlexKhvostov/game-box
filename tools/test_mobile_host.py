"""Run Android identity candidates only against named disposable MySQL tables."""
import io
import base64
import ftplib
import json
import pathlib
import secrets
import urllib.request
from concurrent.futures import ThreadPoolExecutor


def run(ftp, reconnect=None):
    nonce, gate = secrets.token_hex(8), secrets.token_hex(32)
    prefix = '_untouch_mobile_test_' + nonce + '_'
    endpoint = 'api/_mobile_test_' + nonce + '.php'
    root = pathlib.Path(__file__).resolve().parent.parent / 'telegram-web/api'
    source = '\n'.join((root / name).read_text(encoding='utf-8')[5:] for name in ['mobile_store.php','mobile_wallet.php','mobile_play.php','mobile_play_notifications.php'])
    source += '\n' + (root.parent.parent / 'tools/mobile_account_deletion.php').read_text(encoding='utf-8')[5:]
    google = (root / 'mobile_google.php').read_text(encoding='utf-8')[5:]
    # Embed the exact local JWT classes in a gated disposable endpoint. One upload
    # avoids partial vendor directories on hosts that drop the FTP control socket.
    classes = {path.stem: base64.b64encode(path.read_text(encoding='utf-8')[5:].encode()).decode()
               for path in (root / 'vendor/php-jwt/src').glob('*.php')}
    loader = "$jwtSources=json_decode('" + json.dumps(classes) + "',true);\n" + '''
spl_autoload_register(function($class) use ($jwtSources) {
 $prefix='Firebase\\\\JWT\\\\'; if (strncmp($class,$prefix,strlen($prefix))!==0) return;
 $name=substr($class,strlen($prefix)); if (isset($jwtSources[$name])) eval(base64_decode($jwtSources[$name]));
});
'''
    google = loader + google[google.index('function mobile_private_config'):]
    body = '''<?php
header('Content-Type: application/json'); header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD']!=='POST' || !hash_equals('__GATE__',$_SERVER['HTTP_X_UNTOUCH_TEST']??'')) { http_response_code(404); exit; }
require __DIR__ . '/tg_common.php';
__SOURCE__
__GOOGLE__
try {
 [$pdo]=tg_connect_pdo(); if (!$pdo) throw new Exception('Database unavailable');
 $prefix='__PREFIX__'; $input=json_decode(file_get_contents('php://input'),true); $now=2000000000000;
 if ($input['action']==='auth_probe') {
  $headers=function_exists('getallheaders')?getallheaders():[];
  $found=false; foreach ($headers as $name=>$value) if (strcasecmp($name,'Authorization')===0) $found=true;
  echo json_encode(['ok'=>true,'serverHeader'=>!empty($_SERVER['HTTP_AUTHORIZATION']),'redirectHeader'=>!empty($_SERVER['REDIRECT_HTTP_AUTHORIZATION']),'requestHeader'=>$found]); exit;
 }
 if (in_array($input['action'],['http_profile','http_round'],true)) {
  $header=mobile_request_authorization();
  try { $player=mobile_auth($pdo,strncmp($header,'Bearer ',7)===0?substr($header,7):'',$prefix); }
  catch (MobileError $error) { echo json_encode(['ok'=>true,'denied'=>$error->status===401]); exit; }
  if ($input['action']==='http_round') {
   $result=mobile_round_start($pdo,$player,$now,$prefix,$input['requestId'],'http-fixture');
   echo json_encode(['ok'=>true]+$result); exit;
  }
  echo json_encode(['ok'=>true,'profile'=>mobile_profile($player)]); exit;
 }
 if ($input['action']==='cleanup') {
  foreach (['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','mobile_players','scores'] as $name) $pdo->exec('DROP TABLE IF EXISTS ' . mobile_table($name,$prefix));
  echo '{"ok":true}'; exit;
 }
 if ($input['action']==='guest') { echo json_encode(['ok'=>true,'profile'=>mobile_guest($pdo,$input['installation'],$input['secret'],$now,$prefix)]); exit; }
 if ($input['action']==='test') {
  $scores=mobile_table('scores',$prefix);
  $pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day VARCHAR(10),user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT DEFAULT 0,risk_count INT DEFAULT 0,score BIGINT DEFAULT 0,had_jump TINYINT DEFAULT 0,had_helmet TINYINT DEFAULT 0,created_at BIGINT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
  $pdo->exec("INSERT INTO $scores (user_id,player_name,time_ms,created_at) VALUES ('11','SharedNick',1234,0),('12','sharednick',4321,0),('13','user00000001',999,0)");
  mobile_migrate($pdo,$prefix);
  $install=str_repeat('a',32); $secret=str_repeat('b',64);
  $a=mobile_guest($pdo,$install,$secret,$now,$prefix);
  if (!preg_match('/^user[0-9]{8}$/D',$a['nickname']) || $a['nickname']==='user00000001') throw new Exception('Sequential name / legacy collision');
  if (mobile_guest($pdo,$install,$secret,$now,$prefix)!=$a) throw new Exception('Guest replay');
  $denied=false; try { mobile_guest($pdo,$install,str_repeat('c',64),$now,$prefix); } catch (MobileError $e) { $denied=$e->status===401; } if (!$denied) throw new Exception('Installation ID impersonation');
  $player=mobile_auth($pdo,$secret,$prefix);
  $denied=false; try { mobile_rename($pdo,$player,'SHAREDNICK',$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Cross-platform uniqueness');
  $denied=false; try { mobile_rename($pdo,$player,'abcd',$prefix); } catch (MobileError $e) { $denied=$e->getMessage()==='nickname_invalid'; } if (!$denied) throw new Exception('Four-character nickname allowed');
  if (mobile_name('абвгд')!=='абвгд' || mobile_name('abcde')!=='abcde') throw new Exception('Five-character nickname boundary');
  $a=mobile_rename($pdo,$player,'AndroidAudit',$prefix); $player=mobile_auth($pdo,$secret,$prefix);
  $b=mobile_guest($pdo,str_repeat('d',32),str_repeat('e',64),$now,$prefix);
  $other=mobile_auth($pdo,str_repeat('e',64),$prefix);
  $denied=false; try { mobile_rename($pdo,$other,'androidaudit',$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Android uniqueness');
  $round=mobile_round_start($pdo,$player,$now,$prefix);
  $result=$round+['timeMs'=>10000,'runDistance'=>20,'riskCount'=>2];
  $denied=false; try { mobile_round_finish($pdo,$other,$result,$now+11000,$prefix); } catch (MobileError $e) { $denied=$e->status===404; } if (!$denied) throw new Exception('Round owner');
  $denied=false; try { mobile_round_finish($pdo,$player,$result,$now+100,$prefix); } catch (MobileError $e) { $denied=$e->status===400; } if (!$denied) throw new Exception('Elapsed proof');
  $first=mobile_round_finish($pdo,$player,$result,$now+11000,$prefix);
  if (mobile_round_finish($pdo,$player,$result,$now+12000,$prefix)!=$first) throw new Exception('Finish replay');
  if ((int)$pdo->query("SELECT COUNT(*) FROM $scores")->fetchColumn()!==4 || $first['score']!==600) throw new Exception('Shared score / duplicate');
  mobile_migrate($pdo,$prefix);
  $renamed=mobile_rename($pdo,$player,'ANDROIDAUDIT',$prefix);
  if ($renamed['nickname']!=='ANDROIDAUDIT') throw new Exception('Case rename / migration replay');
  mobile_google_link($pdo,$player,'1234567',$prefix);
  $denied=false; try { mobile_google_link($pdo,$other,'1234567',$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('No silent Google merge');
  $restored=mobile_google_restore($pdo,'1234567',str_repeat('f',64),str_repeat('1',32),$prefix);
  if ($restored['id']!==$a['id'] || !mobile_auth($pdo,$secret,$prefix) || mobile_auth($pdo,str_repeat('f',64),$prefix)['id']!==$player['id']) throw new Exception('Multiple-device recovery');
  if (mobile_guest($pdo,str_repeat('1',32),str_repeat('f',64),$now,$prefix)['id']!==$a['id']) throw new Exception('Recovery persists across restart');
  $key=openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA]); openssl_pkey_export($key,$private); $public=openssl_pkey_get_details($key)['key'];
  $claims=['aud'=>'audit-client','iss'=>'https://accounts.google.com','sub'=>'1234567','exp'=>time()+300];
  $token=Firebase\\JWT\\JWT::encode($claims,$private,'RS256','audit');
  if (mobile_google_subject($token,'audit-client',['audit'=>$public])!=='1234567') throw new Exception('Signed JWT');
  foreach ([['aud'=>'wrong'],['iss'=>'wrong'],['exp'=>time()-1]] as $bad) {
    $invalid=Firebase\\JWT\\JWT::encode(array_merge($claims,$bad),$private,'RS256','audit');
    $denied=false; try { mobile_google_subject($invalid,'audit-client',['audit'=>$public]); } catch (MobileError $e) { $denied=$e->status===401; } if (!$denied) throw new Exception('JWT claims validation');
  }
  $parts=explode('.',$token); $parts[1]=rtrim(strtr(base64_encode(json_encode(array_merge($claims,['sub'=>'7654321']))),'+/','-_'),'=');
  $denied=false; try { mobile_google_subject(implode('.',$parts),'audit-client',['audit'=>$public]); } catch (MobileError $e) { $denied=$e->status===401; } if (!$denied) throw new Exception('JWT signature');
  $config=['initialLives'=>30,'initialTokens'=>100,'dailyRewardTokens'=>[2,4], 'timedBonusHours'=>1,'timedBonusTokens'=>22,'watchAdCooldownSec'=>60,
    'lifePacks'=>[['lives'=>5,'costTokens'=>5]],'jumpRentalCost'=>20,'jumpRentalMinutes'=>10,'helmetRentalCost'=>20,'helmetRentalMinutes'=>10,
    'earnActions'=>[['id'=>'watch_ad','reward'=>9]],'premiumDailyMultiplier'=>2];
  mobile_wallet_write($pdo,$other['id'],mobile_wallet_seed($config),$prefix);
  $daily=str_repeat('2',64);
  $wallet=mobile_wallet_mutate($pdo,$other,$daily,'daily',[],$now,$config,$prefix)['wallet'];
  if ($wallet['tokens']!==102 || mobile_wallet_mutate($pdo,$other,$daily,'daily',[],$now,$config,$prefix)['wallet']['tokens']!==102) throw new Exception('Daily one-shot');
  $denied=false; try { mobile_wallet_mutate($pdo,$other,str_repeat('3',64),'daily',[],$now,$config,$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Daily second key');
  $denied=false; try { mobile_wallet_mutate($pdo,$player,$daily,'daily',[],$now,$config,$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Wallet operation owner');
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('4',64),'timed',[],$now,$config,$prefix)['wallet'];
  if ($wallet['tokens']!==124) throw new Exception('Timed amount');
  $denied=false; try { mobile_wallet_mutate($pdo,$other,str_repeat('5',64),'timed',[],$now+3599999,$config,$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Timed boundary');
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('5',64),'timed',[],$now+3600000,$config,$prefix)['wallet']; if ($wallet['tokens']!==146) throw new Exception('Timed exact boundary');
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('6',64),'lives',['lives'=>5],$now,$config,$prefix)['wallet']; if ($wallet['tokens']!==141 || $wallet['lives']!==35) throw new Exception('Life offer');
  mobile_wallet_mutate($pdo,$other,str_repeat('7',64),'rent_jump',[],$now,$config,$prefix);
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('8',64),'rent_jump',[],$now,$config,$prefix)['wallet']; if ($wallet['jumpUntil']!==$now+1200000 || $wallet['tokens']!==101) throw new Exception('Rental extension');
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('9',64),'watch_ad',[],$now,$config,$prefix)['wallet']; if ($wallet['tokens']!==110) throw new Exception('Ad amount');
  $denied=false; try { mobile_wallet_mutate($pdo,$other,str_repeat('0',64),'watch_ad',[],$now+59999,$config,$prefix); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Ad cooldown');
  $wallet=mobile_wallet_mutate($pdo,$other,str_repeat('0',64),'watch_ad',[],$now+60000,$config,$prefix)['wallet']; if ($wallet['tokens']!==119) throw new Exception('Ad exact boundary');
  $denied=false; try { mobile_wallet_mutate($pdo,$other,str_repeat('a',64),'lives',['lives'=>999999],$now,$config,$prefix); } catch (MobileError $e) { $denied=$e->status===400; } if (!$denied) throw new Exception('Forged offer');
  $owner='android:' . $other['id'];
  $purchase=['purchaseState'=>0,'obfuscatedExternalAccountId'=>hash('sha256',$owner),'quantity'=>2];
  if (mobile_play_product($purchase,$owner)!==2) throw new Exception('Verified Play quantity');
  $denied=false; try { mobile_play_product(array_merge($purchase,['purchaseState'=>2]),$owner); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('Pending purchase');
  $denied=false; try { mobile_play_product($purchase,'android:999'); } catch (MobileError $e) { $denied=$e->status===403; } if (!$denied) throw new Exception('Play account binding');
  $fakeToken='isolated-google-play-fixture'; $product=['kind'=>'crystals','amount'=>30];
  $profile=mobile_play_apply($pdo,$other,$fakeToken,'pack_s',$product,2,0,'encrypted-test-fixture',$now,$prefix);
  if ($profile['wallet']['tokens']!==179 || mobile_play_apply($pdo,$other,$fakeToken,'pack_s',$product,2,0,'encrypted-test-fixture',$now,$prefix)['wallet']['tokens']!==179) throw new Exception('Play ledger once');
  $denied=false; try { mobile_play_apply($pdo,$player,$fakeToken,'pack_s',$product,2,0,'encrypted-test-fixture',$now,$prefix); } catch (MobileError $e) { $denied=$e->status===403; } if (!$denied) throw new Exception('Play ledger owner');
  $subscription=['subscriptionState'=>'SUBSCRIPTION_STATE_ACTIVE','externalAccountIdentifiers'=>['obfuscatedExternalAccountId'=>hash('sha256',$owner)],
    'lineItems'=>[['productId'=>'plus_weekly','expiryTime'=>gmdate('c',(int)($now/1000)+604800)]]];
  $expiry=mobile_play_subscription($subscription,$owner,'plus_weekly',$now); if ($expiry!==$now+604800000) throw new Exception('Subscription expiry');
  $profile=mobile_play_apply($pdo,$other,'isolated-subscription','plus_weekly',['kind'=>'subscription'],1,$expiry,'encrypted-test-fixture',$now,$prefix);
  if ($profile['wallet']['plusUntil']!==$expiry) throw new Exception('Subscription entitlement');
  if (mobile_play_subscription(array_merge($subscription,['subscriptionState'=>'SUBSCRIPTION_STATE_ON_HOLD']),$owner,'plus_weekly',$now)!==0) throw new Exception('Subscription hold');
  $profile=mobile_play_apply($pdo,$other,'isolated-subscription','plus_weekly',['kind'=>'subscription'],1,0,'encrypted-test-fixture',$now,$prefix);
  if ($profile['wallet']['plusUntil']!==0 || $profile['wallet']['tokens']!==179) throw new Exception('Subscription revoked / independent wallet');
  $profile=mobile_play_apply($pdo,$other,$fakeToken,'pack_s',['kind'=>'crystals','amount'=>999],2,0,'{}',$now,$prefix,1);
  if ($profile['wallet']['tokens']!==149) throw new Exception('Partial refund uses original grant price');
  $profile=mobile_play_apply($pdo,$other,$fakeToken,'pack_s',$product,2,0,'{}',$now,$prefix,1);
  if ($profile['wallet']['tokens']!==149) throw new Exception('Duplicate partial refund');
  $profile=mobile_play_apply($pdo,$other,$fakeToken,'pack_s',$product,2,0,'{}',$now,$prefix,0);
  if ($profile['wallet']['tokens']!==149) throw new Exception('Stale purchase cannot regrant refund');
  $profile=mobile_play_apply($pdo,$other,$fakeToken,'pack_s',$product,2,0,'{}',$now,$prefix,2);
  if ($profile['wallet']['tokens']!==119) throw new Exception('Remaining refund');
  $wallet=$profile['wallet']; $wallet['tokens']=1; mobile_wallet_write($pdo,$other['id'],$wallet,$prefix);
  mobile_play_apply($pdo,$other,'refund-spent-fixture','pack_s',$product,1,0,'{}',$now,$prefix);
  $wallet['tokens']=0; mobile_wallet_write($pdo,$other['id'],$wallet,$prefix);
  $profile=mobile_play_apply($pdo,$other,'refund-spent-fixture','pack_s',$product,1,0,'{}',$now,$prefix,1);
  if ($profile['wallet']['tokens']!==0) throw new Exception('Refund creates debt');
  foreach (['SUBSCRIPTION_STATE_CANCELED','SUBSCRIPTION_STATE_IN_GRACE_PERIOD'] as $state)
    if (mobile_play_subscription(array_merge($subscription,['subscriptionState'=>$state]),$owner,'plus_weekly',$now)!==$expiry) throw new Exception('Cancel/grace access');
  foreach (['SUBSCRIPTION_STATE_EXPIRED','SUBSCRIPTION_STATE_PAUSED','SUBSCRIPTION_STATE_PENDING'] as $state)
    if (mobile_play_subscription(array_merge($subscription,['subscriptionState'=>$state]),$owner,'plus_weekly',$now)!==0) throw new Exception('Inactive subscription access');
  $v2=['obfuscatedExternalAccountId'=>hash('sha256',$owner),'purchaseStateContext'=>['purchaseState'=>'PURCHASED'],
    'productLineItem'=>[['productId'=>'pack_s','productOfferDetails'=>['quantity'=>2,'refundableQuantity'=>1,'consumptionState'=>'CONSUMPTION_STATE_CONSUMED']]]];
  if (mobile_play_product_v2($v2,$owner,'pack_s')!==[2,1,'CONSUMPTION_STATE_CONSUMED']) throw new Exception('V2 partial refund');
  $v2['purchaseStateContext']['purchaseState']='CANCELLED';
  if (mobile_play_product_v2($v2,$owner,'pack_s')[1]!==2) throw new Exception('V2 cancel');
  $v2['purchaseStateContext']['purchaseState']='PENDING';
  $denied=false; try { mobile_play_product_v2($v2,$owner,'pack_s'); } catch (MobileError $e) { $denied=$e->status===409; } if (!$denied) throw new Exception('V2 pending');
  $cfg=['play_package'=>'com.best4u.untouch','play_rtdn_subscription'=>'projects/test/subscriptions/test','play_rtdn_audience'=>'https://test.invalid/rtdn','play_rtdn_service_email'=>'push@test.invalid'];
  $event=['packageName'=>$cfg['play_package'],'testNotification'=>['version'=>'1.0']];
  $envelope=['subscription'=>$cfg['play_rtdn_subscription'],'message'=>['data'=>base64_encode(json_encode($event))]];
  if (mobile_play_event(json_encode($envelope),$cfg)!==$event) throw new Exception('RTDN envelope');
  $envelope['subscription']='projects/other/subscriptions/test';
  $denied=false; try { mobile_play_event(json_encode($envelope),$cfg); } catch (MobileError $e) { $denied=true; } if (!$denied) throw new Exception('RTDN wrong subscription');
  $rsa=openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA]);
  openssl_pkey_export($rsa,$private); $public=openssl_pkey_get_details($rsa)['key'];
  $claims=['aud'=>$cfg['play_rtdn_audience'],'iss'=>'https://accounts.google.com','email'=>$cfg['play_rtdn_service_email'],'email_verified'=>true,'iat'=>time(),'exp'=>time()+300];
  $jwt=Firebase\\JWT\\JWT::encode($claims,$private,'RS256','test'); mobile_play_push_claims($jwt,$cfg,['test'=>$public]);
  foreach (['aud'=>'wrong','email'=>'wrong','email_verified'=>false,'exp'=>time()-100] as $field=>$value) {
    $bad=Firebase\\JWT\\JWT::encode(array_merge($claims,[$field=>$value]),$private,'RS256','test');
    $denied=false; try { mobile_play_push_claims($bad,$cfg,['test'=>$public]); } catch (MobileError $e) { $denied=$e->status===401; } if (!$denied) throw new Exception('RTDN claims validation');
  }
  $sealed=mobile_play_seal($fakeToken,str_repeat('a',32)); if (strpos($sealed,$fakeToken)!==false) throw new Exception('No plaintext purchase storage');
  $rateIdentity='isolated:' . bin2hex(random_bytes(16)); $rateDir=__DIR__ . '/config-data';
  try {
    $rateNow=(int)floor($now/60000)*60000;
    mobile_rate_limit($rateIdentity,2,$rateNow,$rateDir); mobile_rate_limit($rateIdentity,2,$rateNow,$rateDir);
    $denied=false; try { mobile_rate_limit($rateIdentity,2,$rateNow,$rateDir); } catch (MobileError $e) { $denied=$e->status===429; }
    if (!$denied) throw new Exception('Mobile rate limit');
    mobile_rate_limit($rateIdentity,2,$rateNow+60000,$rateDir);
    if (mobile_play_unseal($sealed,str_repeat('a',32))!==$fakeToken) throw new Exception('Purchase token decryption');
  } finally { unlink(mobile_rate_file($rateIdentity,$rateDir)); }
  // Exact-ID deletion fixtures; never real players or production tables.
  $delInstall=str_repeat('7',32); $delSecret=str_repeat('8',64);
  $del=mobile_guest($pdo,$delInstall,$delSecret,$now,$prefix); $delPlayer=mobile_auth($pdo,$delSecret,$prefix);
  $del=mobile_rename($pdo,$delPlayer,'DeletionChallenge',$prefix);
  mobile_round_start($pdo,$delPlayer,$now,$prefix);
  mobile_wallet_mutate($pdo,$delPlayer,str_repeat('c',64),'daily',[],$now,$config,$prefix);
  mobile_play_apply($pdo,$delPlayer,'deletion-purchase-fixture','pack_s',$product,1,0,'{}',$now,$prefix);
  $pdo->prepare("INSERT INTO $scores (user_id,player_name,time_ms,created_at) VALUES (?,?,1,0)")->execute([$del['id'],'DeletionChallenge']);
  $pdo->prepare("INSERT INTO $scores (user_id,player_name,time_ms,created_at) VALUES ('telegram-same-name',?,1,0)")->execute(['DeletionChallenge']);
  $before=mobile_deletion_review($pdo,$del['id'],$prefix);
  if ($before!==mobile_deletion_review($pdo,$del['id'],$prefix) || count($before['counts'])!==7 || min($before['counts'])<1) throw new Exception('Deletion dry run / fixture coverage');
  foreach (['telegram:1','android:0','android:01','android:1 OR 1=1','1'] as $invalid) {
    $denied=false; try { mobile_deletion_review($pdo,$invalid,$prefix); } catch (InvalidArgumentException $e) { $denied=true; }
    if (!$denied) throw new Exception('Deletion exact Android ID');
  }
  foreach ([['WrongChallenge',$before['fingerprint'],'DELETE ' . $del['id']], ['DeletionChallenge','stale','DELETE ' . $del['id']], ['DeletionChallenge',$before['fingerprint'],'DELETE android:999']] as $invalid) {
    $denied=false; try { mobile_deletion_execute($pdo,$del['id'],$invalid[0],$invalid[1],$invalid[2],$prefix,true); } catch (Throwable $e) { $denied=true; }
    if (!$denied || mobile_deletion_review($pdo,$del['id'],$prefix)!==$before) throw new Exception('Deletion rollback / ownership');
  }
  $denied=false; try { mobile_deletion_execute($pdo,$del['id'],'DeletionChallenge',$before['fingerprint'],'DELETE ' . $del['id'],$prefix); } catch (Throwable $e) { $denied=true; }
  if (!$denied) throw new Exception('Production purchase deletion guard');
  $deleted=mobile_deletion_execute($pdo,$del['id'],'DeletionChallenge',$before['fingerprint'],'DELETE ' . $del['id'],$prefix,true);
  if (array_sum($deleted['remaining'])!==0 || mobile_deletion_review($pdo,$del['id'],$prefix)['exists']) throw new Exception('Deletion seven tables');
  $denied=false; try { mobile_auth($pdo,$delSecret,$prefix); } catch (MobileError $e) { $denied=$e->status===401; }
  if (!$denied || !mobile_auth($pdo,$secret,$prefix)) throw new Exception('Deletion credentials / other player');
  if ((int)$pdo->query("SELECT COUNT(*) FROM $scores WHERE user_id='telegram-same-name'")->fetchColumn()!==1) throw new Exception('Deletion Telegram isolation');
  $denied=false; try { mobile_deletion_execute($pdo,$del['id'],'DeletionChallenge',$before['fingerprint'],'DELETE ' . $del['id'],$prefix,true); } catch (Throwable $e) { $denied=true; }
  if (!$denied) throw new Exception('Deletion replay');
  foreach (['wallet','rename','start','finish','google','purchase'] as $stale) {
    $denied=false; try {
      if ($stale==='wallet') mobile_wallet_mutate($pdo,$delPlayer,str_repeat('d',64),'daily',[],$now,$config,$prefix);
      if ($stale==='rename') mobile_rename($pdo,$delPlayer,'AfterDelete',$prefix);
      if ($stale==='start') mobile_round_start($pdo,$delPlayer,$now,$prefix);
      if ($stale==='finish') mobile_round_finish($pdo,$delPlayer,['roundId'=>str_repeat('d',64)],$now,$prefix);
      if ($stale==='google') mobile_google_link($pdo,$delPlayer,'99999999',$prefix);
      if ($stale==='purchase') mobile_play_apply($pdo,$delPlayer,'stale-after-delete','pack_s',$product,1,0,'{}',$now,$prefix);
    } catch (MobileError $e) { $denied=$e->status===401; }
    if (!$denied || array_sum(mobile_deletion_review($pdo,$del['id'],$prefix)['counts'])!==0) throw new Exception('Deleted profile stale write: ' . $stale);
  }
  echo '{"ok":true,"checks":82}'; exit;
 }
 throw new Exception('Invalid action');
} catch (Throwable $error) { echo json_encode(['ok'=>false,'error'=>$error->getMessage()]); }
'''.replace('__GATE__', gate).replace('__SOURCE__', source).replace('__GOOGLE__', google).replace('__PREFIX__', prefix)

    def rpc(action, _bearer=None, **data):
        headers = {'X-Untouch-Test': gate, 'Content-Type': 'application/json'}
        if _bearer is not None:
            headers['Authorization'] = 'Bearer ' + _bearer
        request = urllib.request.Request('https://untouch.ballaball.xyz/' + endpoint,
            data=json.dumps({'action': action, **data}).encode(),
            headers=headers)
        with urllib.request.urlopen(request, timeout=45) as response:
            result = json.load(response)
        if not result.get('ok'):
            raise RuntimeError(result.get('error', 'Mobile test failed'))
        return result

    endpoint_uploaded = False
    endpoint_attempted = False
    print('Disposable fixture resources:', prefix, endpoint, flush=True)
    try:
        endpoint_attempted = True
        ftp.storbinary('STOR ' + endpoint, io.BytesIO(body.encode()))
        endpoint_uploaded = True
        print('Authorization header transport:', rpc('auth_probe', _bearer=secrets.token_hex(32)), flush=True)
        result = rpc('test')
        installation, secret = secrets.token_hex(16), secrets.token_hex(32)
        with ThreadPoolExecutor(max_workers=4) as pool:
            profiles=list(pool.map(lambda _:rpc('guest',installation=installation,secret=secret)['profile'],range(6)))
            assert len({p['id'] for p in profiles})==1
            distinct=list(pool.map(lambda _:rpc('guest',installation=secrets.token_hex(16),secret=secrets.token_hex(32))['profile'],range(6)))
            assert len({p['nickname'] for p in distinct})==6
        authenticated = rpc('http_profile', _bearer=secret)['profile']
        assert authenticated['id'] == profiles[0]['id']
        assert rpc('http_profile').get('denied') is True
        assert rpc('http_profile', _bearer=secrets.token_hex(32)).get('denied') is True
        request_id = secrets.token_hex(32)
        started = rpc('http_round', _bearer=secret, requestId=request_id)
        replay = rpc('http_round', _bearer=secret, requestId=request_id)
        assert started['roundId'] == replay['roundId'] == request_id
        assert started['profile']['wallet']['lives'] == authenticated['wallet']['lives'] - 1
        assert replay['profile']['wallet']['lives'] == started['profile']['wallet']['lives']
        print('PASS: HTTPS bearer profile, missing/wrong bearer rejection, round start and one-shot replay', flush=True)
        print('PASS: isolated real MySQL Android identity, sequential names, legacy names, authentication, uniqueness, round ownership, elapsed proof and finish replay:', result['checks'], flush=True)
    finally:
        # Do not report success if cleanup did not finish.
        if endpoint_uploaded:
            rpc('cleanup')
        # A disconnected upload must still remove its own partial resources.
        if reconnect:
            ftp = reconnect()
        if endpoint_attempted:
            try:
                ftp.delete(endpoint)
            except ftplib.error_perm as error:
                if '550' not in str(error) or endpoint_uploaded:
                    raise
        print('Disposable mobile tables and endpoint removed', flush=True)
