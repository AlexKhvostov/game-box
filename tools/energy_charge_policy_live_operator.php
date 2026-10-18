<?php
// One-shot protected operator. No schema/private/marker/payment mutations.
ini_set('display_errors','0');header('Content-Type: application/json; charset=utf-8');header('Cache-Control: no-store, private');header('X-Robots-Tag: noindex, nofollow');
$cpToken='__TOKEN__';$cpExpiry=(int)'__EXPIRES__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$cpToken)||!is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($cpToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])){http_response_code(404);echo '{}';exit;}
if($cpExpiry<time()||$cpExpiry>time()+1800){http_response_code(410);echo '{"ok":false,"error":"operator_expired"}';exit;}
if(function_exists('set_time_limit'))@set_time_limit(120);
class CpOperatorError extends RuntimeException{}
function cp_require($ok,$code){if(!$ok)throw new CpOperatorError($code);}
function cp_json($v){return json_encode($v,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR);}
function cp_paths(){return ['api/mobile_energy.php'=>__DIR__.'/mobile_energy.php','api/mobile_wallet.php'=>__DIR__.'/mobile_wallet.php','api/mobile_store.php'=>__DIR__.'/mobile_store.php','api/mobile_play.php'=>__DIR__.'/mobile_play.php','api/mobile_play_notifications.php'=>__DIR__.'/mobile_play_notifications.php','api/gameplay_config.php'=>__DIR__.'/gameplay_config.php','admin/config-schema.json'=>dirname(__DIR__).'/admin/config-schema.json'];}
function cp_without_policy($config){unset($config['economy']['androidEnergyV2']['chargePolicy'],$config['economy']['androidEnergyV2']['revision']);return$config;}
function cp_play_ready(){try{mobile_play_context();return true;}catch(Throwable$e){return false;}}
function cp_regular($path){return is_file($path)&&!is_link($path)&&!is_link(dirname($path));}
function cp_guards($input){
 global$cpExpiry;cp_require($cpExpiry>=time(),'operator_expired');
 $age=(int)round(microtime(true)*1000)-(int)($input['baselineCreatedAt']??0);cp_require($age>=-10000&&$age<=1800000,'audit_expired');
 foreach(['api/mobile_config.php'=>__DIR__.'/mobile_config.php','api/mobile-closed-test.enabled'=>__DIR__.'/mobile-closed-test.enabled','api/.htaccess'=>__DIR__.'/.htaccess','api/config-data/.htaccess'=>__DIR__.'/config-data/.htaccess']as$name=>$path)
   cp_require(isset($input['protectedHashes'][$name])&&cp_regular($path)&&hash_equals($input['protectedHashes'][$name],hash_file('sha256',$path)),'protected_baseline_changed');
 cp_require(trim((string)file_get_contents(__DIR__.'/mobile-closed-test.enabled'))==='on','closed_marker_off');
 $snapshot=gameplay_snapshot();cp_require(hash_equals((string)($input['publicationRevision']??''),(string)$snapshot['revision']),'publication_changed');
 cp_require(hash_equals((string)($input['unchangedConfigSha256']??''),hash('sha256',cp_json(cp_without_policy($snapshot['config'])))),'unrelated_config_changed');
 return$snapshot;
}
function cp_files($expected){$paths=cp_paths();cp_require(is_array($expected)&&count($expected)===count($paths),'file_scope_invalid');foreach($paths as$name=>$path)cp_require(isset($expected[$name])&&is_string($expected[$name])&&preg_match('/^[a-f0-9]{64}$/D',$expected[$name])&&cp_regular($path)&&hash_equals($expected[$name],hash_file('sha256',$path)),'runtime_baseline_changed');}
$pdo=null;$locked=false;$written=[];$configWritten=false;$policy=null;$result=[];
try{
 $raw=file_get_contents('php://input',false,null,0,32769);cp_require(strlen($raw)<=32768,'request_too_large');$input=json_decode($raw,true);cp_require(is_array($input),'request_invalid');$action=$input['action']??'';cp_require(in_array($action,['inspect','publish','activate','verify'],true),'action_invalid');
 require_once __DIR__.'/tg_common.php';require_once __DIR__.'/gameplay_config.php';require_once __DIR__.'/mobile_store.php';require_once __DIR__.'/mobile_wallet.php';require_once __DIR__.'/mobile_google.php';require_once __DIR__.'/mobile_play.php';
 [$pdo]=tg_connect_pdo();cp_require($pdo instanceof PDO,'database_unavailable');$q=$pdo->prepare('SELECT GET_LOCK(?,20)');$q->execute(['untouch_android_energy_v2_release']);cp_require((int)$q->fetchColumn()===1,'operator_busy');$locked=true;
 if($action==='inspect'){$snapshot=gameplay_snapshot();$result=['publicationRevision'=>$snapshot['revision'],'unchangedConfigSha256'=>hash('sha256',cp_json(cp_without_policy($snapshot['config']))),'config'=>$snapshot['config'],'playConfigured'=>cp_play_ready(),'serverNow'=>(int)round(microtime(true)*1000)];}
 else{
  $snapshot=cp_guards($input);cp_files($input['expectedFiles']??null);
  if($action==='publish'){
   $staged=$input['staged']??null;$paths=cp_paths();cp_require(is_array($staged)&&count($staged)===count($paths),'staging_scope_invalid');
   foreach($paths as$name=>$path){$row=$staged[$name]??null;cp_require(is_array($row)&&preg_match('/^_cp_stage_[a-f0-9]{24}_[0-6]\.(php|json)$/D',$row['name']??'')&&preg_match('/^[a-f0-9]{64}$/D',$row['sha256']??''),'staging_name_invalid');$stage=__DIR__.'/config-data/'.$row['name'];cp_require(is_file($stage)&&!is_link($stage)&&hash_equals($row['sha256'],hash_file('sha256',$stage)),'staging_hash_invalid');}
   foreach($paths as$name=>$path){cp_guards($input);cp_require(cp_regular($path)&&hash_equals($input['expectedFiles'][$name],hash_file('sha256',$path)),'runtime_baseline_changed');$stage=__DIR__.'/config-data/'.$staged[$name]['name'];cp_require(cp_regular($stage)&&hash_equals($staged[$name]['sha256'],hash_file('sha256',$stage)),'staging_hash_changed');cp_require(chmod($stage,fileperms($path)&0777),'mode_failed');cp_require(rename($stage,$path),'runtime_publish_failed');$written[$name]=$staged[$name]['sha256'];if(function_exists('opcache_invalidate'))@opcache_invalidate($path,true);cp_require(hash_equals($written[$name],hash_file('sha256',$path)),'runtime_readback_failed');}
   $result=['published'=>$written,'configWritten'=>false];
  }elseif($action==='activate'){
   cp_require(function_exists('mobile_energy_policy_change_error'),'policy_runtime_missing');$candidate=$snapshot['config'];$now=(int)round(microtime(true)*1000);
   $old=$candidate['economy']['androidEnergyV2']['chargePolicy']??null;cp_require(!is_array($old)||empty($old['version']),'policy_already_installed');
   $policy=['version'=>1,'effectiveAt'=>$now,'chargeHours'=>8];$candidate['economy']['androidEnergyV2']['chargePolicy']=$policy;$candidate['economy']['androidEnergyV2']['revision']='android-energy-v2-charge8-v1';
   cp_require(hash_equals($input['unchangedConfigSha256'],hash('sha256',cp_json(cp_without_policy($candidate)))),'candidate_scope_invalid');
   $published=gameplay_publish($candidate,$snapshot['revision']);cp_require(!empty($published['ok']),'config_publication_rejected');$configWritten=true;
   $after=gameplay_snapshot();cp_require($after['config']===$candidate,'config_readback_failed');cp_require(hash_equals($input['unchangedConfigSha256'],hash('sha256',cp_json(cp_without_policy($after['config'])))),'unrelated_config_changed');
   $result=['configWritten'=>true,'publicationRevision'=>$after['revision'],'chargePolicy'=>$policy,'unchangedConfigSha256'=>$input['unchangedConfigSha256']];
  }else{
   $config=mobile_energy_config();$p=$config['chargePolicy']??[];cp_require(($p['version']??null)===1&&($p['chargeHours']??null)===8&&$config['chargeHours']==8,'policy_not_active');
   foreach($config['subscriptions']as$offer)cp_require($offer['chargeHours']==8&&($offer['originalChargeHours']??null)===12,'offer_not_effective8');
   $result=['verified'=>true,'chargePolicy'=>$p,'playConfigured'=>cp_play_ready(),'schemaChanged'=>false,'privateChanged'=>false];
  }
 }
 echo cp_json(['ok'=>true,'action'=>$action]+$result);
}catch(Throwable$e){http_response_code(503);echo cp_json(['ok'=>false,'error'=>$e instanceof CpOperatorError?$e->getMessage():'operator_failed','published'=>$written,'configWritten'=>$configWritten,'chargePolicy'=>$policy,'recovery'=>'keep_forward_no_automatic_rollback']);}
finally{if($pdo&&$locked){try{$pdo->prepare('SELECT RELEASE_LOCK(?)')->execute(['untouch_android_energy_v2_release']);}catch(Throwable$ignored){}}}
