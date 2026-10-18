<?php
// Separate activation template. Never deployed by the installation operator.
ini_set('display_errors','0');header('Content-Type: application/json');header('Cache-Control: no-store, private');header('X-Robots-Tag: noindex, nofollow');
$paToken='__TOKEN__';$paExpiry=(int)'__EXPIRES__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$paToken)||!is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($paToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])){http_response_code(404);echo '{}';exit;}
if(time()>$paExpiry||$paExpiry>time()+1800){http_response_code(410);echo '{"ok":false,"error":"operator_expired"}';exit;}
function pa_check($value){if(!$value)throw new RuntimeException('activation_guard_failed');}
function pa_outside($path,$root){return $path!==$root&&strpos($path,$root.DIRECTORY_SEPARATOR)!==0;}
function pa_token_key($existing,$purchaseCount){
 pa_check(is_string($existing));
 if($existing!==''){pa_check(strlen(base64_decode($existing,true)?:'')===32);return [$existing,false];}
 pa_check($purchaseCount===0);return [base64_encode(random_bytes(32)),true];
}
function pa_catalog_ready($data,$subscription){
 if($subscription){foreach($data['basePlans']??[] as $plan)if(($plan['basePlanId']??'')==='weekly'&&($plan['state']??'')==='ACTIVE'&&($plan['autoRenewingBasePlanType']['billingPeriodDuration']??'')==='P1W')return true;}
 else{foreach($data['purchaseOptions']??[] as $option)if(($option['state']??'')==='ACTIVE'&&isset($option['buyOption']))return true;}
 return false;
}
function pa_backup_candidate($path,$bytes){
 pa_check(!file_exists($path)&&!is_link($path));$old=umask(0077);$handle=null;
 try{$handle=@fopen($path,'x+b');pa_check($handle!==false&&@chmod($path,0600));
  pa_check(fwrite($handle,$bytes)===strlen($bytes)&&fflush($handle));if(function_exists('fsync'))pa_check(fsync($handle));
  fclose($handle);$handle=null;pa_check(hash_equals(hash('sha256',$bytes),hash_file('sha256',$path))&&(fileperms($path)&0777)===0600);
 }finally{if(is_resource($handle))fclose($handle);umask($old);}
 // Deliberately durable: never remove a candidate containing a token key.
}
function pa_write($path,$bytes,$mode){
 $temporary=__DIR__.'/config-data/.play-activation-'.bin2hex(random_bytes(16)).'.tmp';$handle=null;$previous=umask(0077);
 try{
  $handle=@fopen($temporary,'x+b');pa_check($handle!==false&&@chmod($temporary,$mode));
  pa_check(fwrite($handle,$bytes)===strlen($bytes)&&fflush($handle));if(function_exists('fsync'))pa_check(fsync($handle));
  fclose($handle);$handle=null;pa_check(hash_equals(hash('sha256',$bytes),hash_file('sha256',$temporary)));
  pa_check(@rename($temporary,$path));if(function_exists('opcache_invalidate'))opcache_invalidate($path,true);
 }finally{if(is_resource($handle))fclose($handle);if(is_file($temporary))pa_check(@unlink($temporary));umask($previous);}
}
$paWritten=false;$paCandidateRetained=false;$paPrivatePath=__DIR__.'/mobile_config.php';$paMode=0600;
try{
 $input=json_decode(file_get_contents('php://input',false,null,0,2049),true);
 pa_check(is_array($input)&&in_array($input['action']??'',['stage','activate'],true)&&($input['allowActivation']??false)===true&&preg_match('/^[a-f0-9]{64}$/D',$input['stageId']??''));
 $baseline=json_decode(base64_decode('__BASELINE__',true),true);pa_check(is_array($baseline));
 foreach($baseline['files'] as $relative=>$hash){
  pa_check(in_array($relative,['mobile_config.php','mobile-closed-test.enabled','.htaccess','config-data/.htaccess','mobile_play.php','mobile_beta.php','mobile_google.php','config-data/published.json'],true));
  pa_check(is_file(__DIR__.'/'.$relative)&&!is_link(__DIR__.'/'.$relative)&&hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
 }
 pa_check(!is_link($paPrivatePath)&&!is_link(__DIR__.'/config-data'));$paMode=fileperms($paPrivatePath)&0777;
 require_once __DIR__.'/tg_common.php';require_once __DIR__.'/mobile_store.php';require_once __DIR__.'/mobile_google.php';require_once __DIR__.'/mobile_play.php';
 $before=mobile_private_config();pa_check(empty($before['play_service_account_path'])&&($before['energy_test_grants_enabled']??false)===true&&trim(file_get_contents(__DIR__.'/mobile-closed-test.enabled'))==='on');
 $document=realpath($_SERVER['DOCUMENT_ROOT']??'');$site=realpath(dirname(__DIR__));pa_check($document&&$site);
 $parent=realpath(dirname($site));pa_check($parent&&$parent!==DIRECTORY_SEPARATOR);
 $container=$parent.'/.untouch-private';$directory=$container.'/play';$path=$directory.'/untouch-play-verifier-game-box-b30d4.json';
 pa_check(!is_link($container)&&!is_link($directory)&&!is_link($path)&&realpath($path)===$path&&pa_outside($path,$document)&&pa_outside($path,$site)&&
  hash_equals($baseline['candidateDirectorySha256'],hash('sha256',$directory))&&hash_equals($baseline['keySha256'],hash_file('sha256',$path)));
 pa_check((fileperms($path)&0777)===0600&&(fileperms($directory)&0777)===0700&&(fileperms($container)&0777)===0700);
 $service=json_decode(file_get_contents($path),true);pa_check(is_array($service)&&($service['type']??'')==='service_account'&&($service['project_id']??'')==='game-box-b30d4'&&
  ($service['client_email']??'')==='untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com'&&($service['token_uri']??'')==='https://oauth2.googleapis.com/token');
 $access=mobile_play_access($service);pa_check(is_string($access)&&$access!=='');
 foreach(['energy_100_v1','energy_250_v1','energy_500_v1','energy_1000_v1','energy_batteries_2_v1','energy_batteries_5_v1'] as $sku){
  $subscription=strpos($sku,'energy_batteries_')===0;
  $url='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/'.($subscription?'subscriptions/':'oneTimeProducts/').rawurlencode($sku);
  pa_check(pa_catalog_ready(mobile_play_http($url,'GET',null,$access),$subscription));
 }unset($access);
 $existing=$before['play_token_key']??'';$purchaseCount=null;
 if($existing===''){
  [$pdo]=tg_connect_pdo();pa_check($pdo instanceof PDO);
  $purchaseCount=(int)$pdo->query('SELECT COUNT(*) FROM mobile_purchases')->fetchColumn();
 }
 $backupPath=$directory.'/activation-candidate-'.$input['stageId'].'.php';pa_check(!is_link($backupPath));
 if($input['action']==='stage'&&!file_exists($backupPath)){
  [$tokenKey,$newTokenKey]=pa_token_key($existing,$purchaseCount);
  $candidate=$before;$candidate['play_service_account_path']=$path;$candidate['play_package']='com.best4u.untouch';$candidate['play_token_key']=$tokenKey;
 }else{
  pa_check(is_file($backupPath)&&realpath($backupPath)===$backupPath&&(fileperms($backupPath)&0777)===0600);
  if($input['action']==='activate')pa_check(is_string($input['candidateSha256']??null)&&hash_equals($input['candidateSha256'],hash_file('sha256',$backupPath)));
  $candidate=require $backupPath;pa_check(is_array($candidate)&&($candidate['play_service_account_path']??'')===$path&&($candidate['play_package']??'')==='com.best4u.untouch');
  [$tokenKey]=pa_token_key($candidate['play_token_key']??null,null);$newTokenKey=$existing==='';
  if(!$newTokenKey)pa_check(hash_equals($existing,$tokenKey));
 }
 $unchangedBefore=$before;$unchangedAfter=$candidate;
 foreach(['play_service_account_path','play_package','play_token_key'] as $name){unset($unchangedBefore[$name],$unchangedAfter[$name]);}
 pa_check($unchangedBefore===$unchangedAfter);
 foreach($baseline['files'] as $relative=>$hash)pa_check(hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
 $bytes="<?php\nreturn ".var_export($candidate,true).";\n";
 if($input['action']==='stage'){
  if(!file_exists($backupPath))pa_backup_candidate($backupPath,$bytes);
  else pa_check(hash_equals(hash('sha256',$bytes),hash_file('sha256',$backupPath)));
  $paCandidateRetained=true;
  echo json_encode(['ok'=>true,'action'=>'stage','candidateSha256'=>hash('sha256',$bytes),'candidateBase64'=>base64_encode($bytes),
   'durableCandidateSaved'=>true,'privateConfigUnchanged'=>true,'playConfigured'=>false,'oauthReady'=>true,'catalogReady'=>true]);exit;
 }
 $paCandidateRetained=true;pa_check(hash_equals(hash('sha256',$bytes),hash_file('sha256',$backupPath)));
 // The config-data directory is HTTPS-denied; private PHP bytes never go in a public temp file.
 $staging=__DIR__.'/config-data/.play-private-'.bin2hex(random_bytes(16)).'.php';$paWritten=false;
 try{
  pa_write($staging,$bytes,0600);$parsed=require $staging;pa_check($parsed===$candidate);
  foreach($baseline['files'] as $relative=>$hash)pa_check(hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
  pa_check(@chmod($staging,$paMode)&&@rename($staging,$paPrivatePath));$paWritten=true;
  if(function_exists('opcache_invalidate'))opcache_invalidate($paPrivatePath,true);
 }finally{if(is_file($staging))pa_check(@unlink($staging));}
 [$actual,$actualService,$actualKey]=mobile_play_context();pa_check($actual===$candidate&&strlen($actualKey)===32&&$actualService['client_email']===$service['client_email']);
 foreach($baseline['files'] as $relative=>$hash)if($relative!=='mobile_config.php')pa_check(hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
 pa_check(hash_equals(hash('sha256',$bytes),hash_file('sha256',$paPrivatePath)));
 echo json_encode(['ok'=>true,'action'=>'activate','playConfigured'=>true,'oauthReady'=>true,'onlyRequiredPrivateKeysChanged'=>true,
  'tokenKeyPreserved'=>!$newTokenKey,'tokenKeyCreated'=>$newTokenKey,'privateConfigSha256'=>hash_file('sha256',$paPrivatePath),
  'markerUnchanged'=>true,'publicConfigUnchanged'=>true,'grantFlagPreserved'=>true,'catalogReady'=>true,'durableCandidateSaved'=>true,'purchaseRequests'=>0]);
}catch(Throwable $error){
 // After exposure a purchase may already have committed: never erase/rotate its
 // token key or overwrite another config writer. Recover forward from backups.
 http_response_code(503);echo json_encode(['ok'=>false,'error'=>'play_activation_guard_failed','configWritten'=>$paWritten,'candidateRetained'=>$paCandidateRetained,
  'automaticRollback'=>false,'manualReconciliationRequired'=>$paWritten]);
}
