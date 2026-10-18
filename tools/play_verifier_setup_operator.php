<?php
// One-shot operator: key installation and read-only catalog checks ONLY.
// Deliberately contains no private-config writer / payment activation action.
ini_set('display_errors','0');
header('Content-Type: application/json'); header('Cache-Control: no-store, private'); header('X-Robots-Tag: noindex, nofollow');
$pvToken='__TOKEN__'; $pvExpiry=(int)'__EXPIRES__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$pvToken)||
 !is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($pvToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])) {http_response_code(404);echo '{}';exit;}
if(time()>$pvExpiry||$pvExpiry>time()+1800){http_response_code(410);echo '{"ok":false,"error":"operator_expired"}';exit;}
function pv_check($condition){if(!$condition)throw new RuntimeException('setup_guard_failed');}
function pv_outside($path,$root){return $path!==$root&&strpos($path,$root.DIRECTORY_SEPARATOR)!==0;}
function pv_directory($path){
 pv_check(!is_link($path));
 if(!is_dir($path))pv_check(@mkdir($path,0700));
 pv_check(realpath($path)===$path&&!is_link($path)&&@chmod($path,0700));
 clearstatcache(true,$path);pv_check((fileperms($path)&0777)===0700);
}
function pv_service($bytes){
 $service=json_decode($bytes,true);
 pv_check(is_array($service)&&($service['type']??'')==='service_account'&&($service['project_id']??'')==='game-box-b30d4'&&
  ($service['token_uri']??'')==='https://oauth2.googleapis.com/token'&&
  ($service['client_email']??'')==='untouch-play-verifier@game-box-b30d4.iam.gserviceaccount.com'&&
  is_string($service['private_key']??null)&&openssl_pkey_get_private($service['private_key'])!==false);
 return $service;
}
try {
 $input=json_decode(file_get_contents('php://input',false,null,0,32769),true);
 pv_check(is_array($input)&&strlen(json_encode($input))<32768);
 $baseline=json_decode(base64_decode('__BASELINE__',true),true); pv_check(is_array($baseline));
 foreach($baseline['files'] as $relative=>$hash){
  pv_check(in_array($relative,['mobile_config.php','mobile-closed-test.enabled','.htaccess','config-data/.htaccess','mobile_play.php','mobile_beta.php','mobile_google.php'],true));
  pv_check(is_file(__DIR__.'/'.$relative)&&hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
 }
 require_once __DIR__.'/tg_common.php';require_once __DIR__.'/mobile_store.php';require_once __DIR__.'/mobile_google.php';require_once __DIR__.'/mobile_play.php';
 $private=mobile_private_config();
 pv_check(($private['energy_test_grants_enabled']??false)===true&&trim(file_get_contents(__DIR__.'/mobile-closed-test.enabled'))==='on');
 pv_check(empty($private['play_service_account_path']));
 $document=realpath($_SERVER['DOCUMENT_ROOT']??'');$site=realpath(dirname(__DIR__));pv_check($document&&$site);
 $parent=realpath(dirname($site));pv_check($parent&&$parent!==DIRECTORY_SEPARATOR);
 $container=$parent.'/.untouch-private';$directory=$container.'/play';
 pv_check(!is_link($container)&&!is_link($directory)&&pv_outside($directory,$document)&&pv_outside($directory,$site)&&
  hash_equals($baseline['candidateDirectorySha256'],hash('sha256',$directory)));
 $target=$directory.'/untouch-play-verifier-game-box-b30d4.json';pv_check(!is_link($target));
 $action=$input['action']??'';$installed=false;
 if($action==='install_key'){
  pv_check(($input['allowInstall']??false)===true);
  $bytes=base64_decode($input['keyBase64']??'',true);pv_check(is_string($bytes)&&strlen($bytes)>1000&&strlen($bytes)<16000);
  pv_check(hash_equals($baseline['keySha256'],hash('sha256',$bytes)));pv_service($bytes);
  pv_directory($container);pv_directory($directory);
  if(file_exists($target))pv_check(is_file($target)&&hash_equals($baseline['keySha256'],hash_file('sha256',$target)));
  else {
   $previous=umask(0077);$temporary=$directory.'/.install-'.bin2hex(random_bytes(16));$handle=null;
   try{
    $handle=@fopen($temporary,'x+b');pv_check($handle!==false);
    pv_check(@chmod($temporary,0600)&&fwrite($handle,$bytes)===strlen($bytes)&&fflush($handle));
    if(function_exists('fsync'))pv_check(fsync($handle));fclose($handle);$handle=null;
    pv_check(hash_equals($baseline['keySha256'],hash_file('sha256',$temporary))&&!is_link($target));
    // link is atomic and refuses an existing target. Never overwrite a key.
    pv_check(@link($temporary,$target));$installed=true;
   }finally{if(is_resource($handle))fclose($handle);if(isset($temporary)&&is_file($temporary))pv_check(@unlink($temporary));umask($previous);}
  }
  pv_check(@chmod($target,0600));
 }elseif(!in_array($action,['verify_key','catalog'],true))throw new RuntimeException();
 pv_check(is_file($target)&&!is_link($target)&&realpath($target)===$target&&hash_equals($baseline['keySha256'],hash_file('sha256',$target)));
 clearstatcache(true,$target);pv_check((fileperms($target)&0777)===0600&&(fileperms($directory)&0777)===0700&&(fileperms($container)&0777)===0700);
 $service=pv_service(file_get_contents($target));
 $result=['ok'=>true,'action'=>$action,'installed'=>$installed,'keySha256'=>hash_file('sha256',$target),'keyMode'=>'0600','directoryMode'=>'0700',
  'outsideDocumentRoot'=>true,'outsideActualSiteRoot'=>true,'privateConfigUnchanged'=>true,'playActivated'=>false];
 if($action==='catalog'){
  $access=mobile_play_access($service);$catalog=[];
  foreach(['energy_100_v1','energy_250_v1','energy_500_v1','energy_1000_v1','energy_batteries_2_v1','energy_batteries_5_v1'] as $sku){
   $subscription=strpos($sku,'energy_batteries_')===0;
   $url='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.best4u.untouch/'.($subscription?'subscriptions/':'oneTimeProducts/').rawurlencode($sku);
   $curl=curl_init($url);curl_setopt_array($curl,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_HTTPHEADER=>['Accept: application/json','Authorization: Bearer '.$access],CURLOPT_CONNECTTIMEOUT=>3,CURLOPT_TIMEOUT=>12]);
   $body=curl_exec($curl);$status=(int)curl_getinfo($curl,CURLINFO_HTTP_CODE);curl_close($curl);$data=json_decode($body?:'',true);
   $active=false;$weekly=false;
   if($subscription&&$status===200)foreach($data['basePlans']??[] as $plan){if(($plan['basePlanId']??'')==='weekly'){$weekly=true;$active=($plan['state']??'')==='ACTIVE';}}
   $catalog[]=['productId'=>$sku,'httpStatus'=>$status,'found'=>$status===200,'weeklyBasePlanFound'=>$subscription?$weekly:null,'weeklyBasePlanActive'=>$subscription?$active:null];
  }
  $result['oauthReady']=true;$result['catalog']=$catalog;$result['purchaseRequests']=0;
 }
 foreach($baseline['files'] as $relative=>$hash)pv_check(hash_equals($hash,hash_file('sha256',__DIR__.'/'.$relative)));
 echo json_encode($result,JSON_UNESCAPED_SLASHES);
}catch(Throwable $error){http_response_code(503);echo '{"ok":false,"error":"play_setup_guard_or_readonly_probe_failed","playActivated":false}';}
