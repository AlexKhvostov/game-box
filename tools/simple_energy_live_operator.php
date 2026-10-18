<?php
// Temporary authenticated operator. No schema, private settings or payment writes.
ini_set('display_errors','0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Robots-Tag: noindex, nofollow');
$sbToken='__TOKEN__';$sbExpiry=(int)'__EXPIRES__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$sbToken)||!is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($sbToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])){http_response_code(404);echo '{}';exit;}
if($sbExpiry<time()||$sbExpiry>time()+1800){http_response_code(410);echo '{"ok":false,"error":"operator_expired"}';exit;}
if(function_exists('set_time_limit'))@set_time_limit(120);
class SbOperatorError extends RuntimeException{}
function sb_require($ok,$code){if(!$ok)throw new SbOperatorError($code);}
function sb_json($v){return json_encode($v,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR);}
function sb_paths(){
    $out=[];foreach(['mobile_energy_bonus.php','mobile_energy.php','mobile_wallet.php','mobile_store.php','mobile_invites.php','gameplay_config.php','mobile.php']as$name)$out['api/'.$name]=__DIR__.'/'.$name;
    return$out;
}
function sb_without_policy($config){unset($config['economy']['androidEnergyV2']['simpleBonus']);return$config;}
function sb_regular($path){return is_file($path)&&!is_link($path)&&!is_link(dirname($path));}
function sb_matches($path,$hash){return $hash===null?!file_exists($path):sb_regular($path)&&is_string($hash)&&preg_match('/^[a-f0-9]{64}$/D',$hash)&&hash_equals($hash,hash_file('sha256',$path));}
function sb_policy(){return ['enabled'=>true,'version'=>1,'initialEnergy'=>50,'reward'=>30,'periodSec'=>28800,'tier2Reward'=>60,'tier5Reward'=>150,'videoReward'=>40,'videoCooldownSec'=>120,'inviterReward'=>60];}
function sb_candidate($snapshot,$expectedRevision,$unchangedHash){
    sb_require(is_string($expectedRevision)&&hash_equals($snapshot['revision'],$expectedRevision),'publication_changed');
    sb_require(is_string($unchangedHash)&&hash_equals($unchangedHash,hash('sha256',sb_json(sb_without_policy($snapshot['config'])))),'unrelated_config_changed');
    $candidate=$snapshot['config'];sb_require(!empty($candidate['economy']['androidEnergyV2']['enabled']),'energy_v2_required');
    $candidate['economy']['androidEnergyV2']['simpleBonus']=sb_policy();
    sb_require(hash_equals($unchangedHash,hash('sha256',sb_json(sb_without_policy($candidate)))),'candidate_scope_invalid');
    return$candidate;
}
function sb_guards($input){
    global$sbExpiry;sb_require($sbExpiry>=time(),'operator_expired');
    $age=(int)round(microtime(true)*1000)-(int)($input['baselineCreatedAt']??0);sb_require($age>=-10000&&$age<=1800000,'audit_expired');
    $protected=$input['protectedHashes']??[];
    $required=['api/mobile_config.php','api/mobile-closed-test.enabled','api/.htaccess','api/config-data/.htaccess','api/mobile_play.php','api/mobile_google.php','api/energy_store.php','api/mobile_identity.php','api/tg_common.php'];
    sb_require(is_array($protected)&&array_keys($protected)===$required,'protected_scope_invalid');
    foreach($required as$name)sb_require(sb_matches(dirname(__DIR__).'/'.$name,$protected[$name]),'protected_baseline_changed');
    $snapshot=gameplay_snapshot();
    sb_require(hash_equals((string)($input['publicationRevision']??''),$snapshot['revision']),'publication_changed');
    sb_require(hash_equals((string)($input['unchangedConfigSha256']??''),hash('sha256',sb_json(sb_without_policy($snapshot['config'])))),'unrelated_config_changed');
    return$snapshot;
}
function sb_files($expected){
    $paths=sb_paths();sb_require(is_array($expected)&&array_keys($expected)===array_keys($paths),'file_scope_invalid');
    foreach($paths as$name=>$path)sb_require(sb_matches($path,$expected[$name]),'runtime_baseline_changed');
}
$pdo=null;$locked=false;$written=[];$configWritten=false;
try{
    $raw=file_get_contents('php://input',false,null,0,32769);sb_require(strlen($raw)<=32768,'request_too_large');
    $input=json_decode($raw,true);sb_require(is_array($input),'request_invalid');$action=$input['action']??'';
    sb_require(in_array($action,['inspect','publish','activate','verify'],true),'action_invalid');
    require_once __DIR__.'/tg_common.php';require_once __DIR__.'/gameplay_config.php';
    [$pdo]=tg_connect_pdo();sb_require($pdo instanceof PDO,'database_unavailable');
    $q=$pdo->prepare('SELECT GET_LOCK(?,20)');$q->execute(['untouch_android_energy_v2_release']);sb_require((int)$q->fetchColumn()===1,'operator_busy');$locked=true;
    if($action==='inspect'){
        $snapshot=gameplay_snapshot();
        $columns=$pdo->query('SHOW COLUMNS FROM mobile_operations')->fetchAll(PDO::FETCH_ASSOC);
        $result=['publicationRevision'=>$snapshot['revision'],'unchangedConfigSha256'=>hash('sha256',sb_json(sb_without_policy($snapshot['config']))),'config'=>$snapshot['config'],'receiptsReady'=>in_array('result_json',array_column($columns,'Field'),true),'serverNow'=>(int)round(microtime(true)*1000)];
    }else{
        $snapshot=sb_guards($input);sb_files($input['expectedFiles']??null);
        if($action==='publish'){
            $paths=sb_paths();$staged=$input['staged']??[];
            sb_require(is_array($staged)&&array_keys($staged)===array_keys($paths),'staging_scope_invalid');
            foreach($paths as$name=>$path){
                $row=$staged[$name];sb_require(is_array($row)&&preg_match('/^_sb_stage_[a-f0-9]{24}_[0-6]\.php$/D',$row['name']??'')&&preg_match('/^[a-f0-9]{64}$/D',$row['sha256']??''),'staging_name_invalid');
                sb_require(sb_matches(__DIR__.'/config-data/'.$row['name'],$row['sha256']),'staging_hash_invalid');
            }
            foreach($paths as$name=>$path){
                sb_guards($input);sb_require(sb_matches($path,$input['expectedFiles'][$name]),'runtime_baseline_changed');
                $stage=__DIR__.'/config-data/'.$staged[$name]['name'];sb_require(sb_matches($stage,$staged[$name]['sha256']),'staging_hash_changed');
                sb_require(chmod($stage,file_exists($path)?fileperms($path)&0777:0644),'mode_failed');
                sb_require(rename($stage,$path),'runtime_publish_failed');$written[$name]=$staged[$name]['sha256'];
                if(function_exists('opcache_invalidate'))@opcache_invalidate($path,true);
                sb_require(sb_matches($path,$written[$name]),'runtime_readback_failed');
            }
            $result=['published'=>$written,'configWritten'=>false];
        }elseif($action==='activate'){
            require_once __DIR__.'/mobile_store.php';
            sb_require(function_exists('mobile_bonus_defaults')&&mobile_bonus_defaults()['reward']===30,'bonus_runtime_missing');
            $columns=$pdo->query('SHOW COLUMNS FROM mobile_operations')->fetchAll(PDO::FETCH_ASSOC);
            sb_require(in_array('result_json',array_column($columns,'Field'),true),'operation_receipts_not_ready');
            $q=$pdo->query('SELECT wallet_json FROM mobile_players');
            foreach($q as$row)sb_require($row['wallet_json']===null||$row['wallet_json']===''||is_array(json_decode($row['wallet_json'],true)),'invalid_wallet_requires_review');
            $candidate=sb_candidate($snapshot,$input['publicationRevision'],$input['unchangedConfigSha256']);
            $published=gameplay_publish($candidate,$snapshot['revision']);sb_require(!empty($published['ok']),'config_publication_rejected');$configWritten=true;
            $after=gameplay_snapshot();sb_require($after['config']===$candidate,'config_readback_failed');
            $result=['configWritten'=>true,'publicationRevision'=>$after['revision'],'simpleBonus'=>sb_policy(),'unchangedConfigSha256'=>$input['unchangedConfigSha256']];
        }else{
            sb_require(($snapshot['config']['economy']['androidEnergyV2']['simpleBonus']??null)===sb_policy(),'bonus_policy_not_active');
            $result=['verified'=>true,'simpleBonus'=>sb_policy(),'schemaChanged'=>false,'privateChanged'=>false];
        }
    }
    echo sb_json(['ok'=>true,'action'=>$action]+$result);
}catch(Throwable$e){http_response_code(503);echo sb_json(['ok'=>false,'error'=>$e instanceof SbOperatorError?$e->getMessage():'operator_failed','published'=>$written,'configWritten'=>$configWritten,'recovery'=>'keep_forward_no_automatic_rollback']);}
finally{if($pdo&&$locked){try{$pdo->prepare('SELECT RELEASE_LOCK(?)')->execute(['untouch_android_energy_v2_release']);}catch(Throwable$ignored){}}}
