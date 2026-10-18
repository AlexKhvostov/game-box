<?php
// One-shot POST fixture template. Upload only after the Energy V2 dependencies.
// Inject a fresh 64-hex __TOKEN__, call over HTTPS, remove after the check.
// Every row/DDL mutation below is limited to a generated _aelive_<nonce>_ scope.
ini_set('display_errors','0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private, max-age=0');
header('Pragma: no-cache');
header('X-Robots-Tag: noindex, nofollow');
header('X-Content-Type-Options: nosniff');
$aelrToken='__TOKEN__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$aelrToken)||
   !is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($aelrToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])) {
    http_response_code(404);echo '{}';exit;
}
$aelrCreated=@filemtime(__FILE__);
if(!$aelrCreated||time()>$aelrCreated+7200){http_response_code(410);echo '{"ok":false,"error":"rehearsal_expired"}';exit;}
if(function_exists('set_time_limit'))@set_time_limit(90);
set_error_handler(function($severity){if(!(error_reporting()&$severity))return false;throw new ErrorException('rehearsal_runtime',0,$severity);});

class AelrFailure extends RuntimeException {}
function aelr_check($condition,$label){
    if(!$condition){$GLOBALS['aelrFailedCheck']=$label;throw new AelrFailure('check_failed');}
    $GLOBALS['aelrChecks'][]=$label;
}
function aelr_scope($prefix){
    if(!is_string($prefix)||!preg_match('/^_aelive_[a-f0-9]{16}_$/D',$prefix))throw new AelrFailure('scope_invalid');
    return $prefix;
}
function aelr_names(){return ['mobile_energy_feedback','mobile_invite_ledger','mobile_invites','mobile_invite_codes',
  'mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players'];}
function aelr_table($prefix,$name){
    aelr_scope($prefix);if(!in_array($name,aelr_names(),true))throw new AelrFailure('table_invalid');
    return '`'.$prefix.$name.'`';
}
function aelr_tables_count(PDO $pdo,$prefix){
    aelr_scope($prefix);$q=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');
    $q->execute([strlen($prefix),$prefix]);return (int)$q->fetchColumn();
}
function aelr_row(PDO $pdo,$prefix,$id){
    $q=$pdo->prepare('SELECT * FROM '.aelr_table($prefix,'mobile_players').' WHERE id=?');$q->execute([$id]);
    $row=$q->fetch(PDO::FETCH_ASSOC);if(!$row)throw new AelrFailure('fixture_missing');return $row;
}
function aelr_wallet(PDO $pdo,$prefix,$id,$config){return mobile_wallet(aelr_row($pdo,$prefix,$id),$config);}
function aelr_write_fixture(PDO $pdo,$prefix,$id,$wallet){
    $pdo->beginTransaction();
    try {
      $q=$pdo->prepare('SELECT id FROM '.aelr_table($prefix,'mobile_players').' WHERE id=? FOR UPDATE');$q->execute([$id]);
      if(!$q->fetchColumn())throw new AelrFailure('fixture_missing');
      mobile_wallet_write($pdo,$id,$wallet,$prefix);$pdo->commit();
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}
function aelr_guest(PDO $pdo,$prefix,$now){
    aelr_scope($prefix);
    // This invokes the real guest SQL with an explicit disposable prefix.
    // Version1 deliberately avoids the production flag; V2 migration is
    // seeded explicitly below with a local configuration while live is off.
    $secret=bin2hex(random_bytes(32));
    $profile=mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$prefix,180,1);
    $id=(int)substr($profile['id'],8);if($id<1)throw new AelrFailure('fixture_guest_invalid');return $id;
}

$aelrPdo=null;$aelrPrefix=null;$aelrOwned=false;$aelrLocked=false;$aelrCleaned=false;
$GLOBALS['aelrChecks']=[];$GLOBALS['aelrFailedCheck']=null;$aelrFailure=null;
try {
    $raw=file_get_contents('php://input',false,null,0,2049);
    if(strlen($raw)>2048)throw new AelrFailure('request_too_large');
    $input=json_decode($raw,true);
    if(!is_array($input)||($input['action']??'')!=='rehearsal'||count($input)!==1)throw new AelrFailure('action_invalid');
    foreach(['tg_common.php','gameplay_config.php','mobile_store.php','mobile_wallet.php','mobile_energy.php','mobile_invites.php','mobile_energy_feedback.php'] as $file){
      if(!is_file(__DIR__.'/'.$file))throw new AelrFailure('v2_dependency_missing');
      require_once __DIR__.'/'.$file;
    }
    foreach(['mobile_migrate','mobile_guest','mobile_energy_migrate_wallet','mobile_wallet_mutate','mobile_invites_migrate','mobile_energy_migrate_schema'] as $function)
      if(!function_exists($function))throw new AelrFailure('v2_dependency_incompatible');
    [$aelrPdo]=tg_connect_pdo();if(!$aelrPdo)throw new AelrFailure('database_unavailable');
    $q=$aelrPdo->prepare('SELECT GET_LOCK(?,1)');$q->execute(['untouch_android_energy_v2_rehearsal']);
    if((int)$q->fetchColumn()!==1)throw new AelrFailure('rehearsal_busy');$aelrLocked=true;
    $publicationBefore=gameplay_snapshot();
    $configHashBefore=hash('sha256',json_encode($publicationBefore['config'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR));
    $aelrPrefix='_aelive_'.bin2hex(random_bytes(8)).'_';aelr_scope($aelrPrefix);
    aelr_check(aelr_tables_count($aelrPdo,$aelrPrefix)===0,'Generated disposable scope initially empty');
    $aelrOwned=true;
    $aelrPdo->exec('CREATE TABLE '.aelr_table($aelrPrefix,'scores').' LIKE `scores`');
    aelr_check((int)$aelrPdo->query('SELECT COUNT(*) FROM '.aelr_table($aelrPrefix,'scores'))->fetchColumn()===0,'scores LIKE copies schema without production rows');
    mobile_migrate($aelrPdo,$aelrPrefix);mobile_invites_migrate($aelrPdo,$aelrPrefix);mobile_energy_migrate_schema($aelrPdo,$aelrPrefix);
    aelr_check(aelr_tables_count($aelrPdo,$aelrPrefix)===count(aelr_names()),'All eleven disposable tables prepared');
    $now=(int)round(microtime(true)*1000);$energy=mobile_energy_defaults();$energy['enabled']=true;
    $local=tg_load_economy();$local['initialLives']=7;$local['initialTokens']=13;$local['androidEnergyV2']=$energy;
    $oldId=aelr_guest($aelrPdo,$aelrPrefix,$now);
    $legacy=mobile_wallet_seed($local);$legacy['lives']=7;$legacy['tokens']=13;$legacy['jumpUntil']=$now+3600000;$legacy['helmetUntil']=$now+3600000;
    aelr_write_fixture($aelrPdo,$aelrPrefix,$oldId,$legacy);
    $migrated=mobile_energy_migrate_wallet(aelr_wallet($aelrPdo,$aelrPrefix,$oldId,$local),$energy,$now,false);
    aelr_write_fixture($aelrPdo,$aelrPrefix,$oldId,$migrated);$oldWallet=aelr_wallet($aelrPdo,$aelrPrefix,$oldId,$local);
    aelr_check($oldWallet['energy']===33&&count($oldWallet['batteries'])===1&&mobile_energy_charge($oldWallet['batteries'][0],$now)===20,'Legacy fixture7+2x13 becomes33 plus separate full20');
    aelr_check($oldWallet['jumpUntil']===0&&$oldWallet['helmetUntil']===0,'Legacy fixture rentals reset on migration');
    $again=mobile_energy_migrate_wallet($oldWallet,$energy,$now+1000,false);
    aelr_check($again===$oldWallet&&aelr_wallet($aelrPdo,$aelrPrefix,$oldId,$local)===$oldWallet,'Repeat migration keeps fixture wallet and cycle unchanged');
    $newId=aelr_guest($aelrPdo,$aelrPrefix,$now);
    $newWallet=mobile_energy_migrate_wallet(mobile_wallet_seed($local),$energy,$now,true);
    aelr_write_fixture($aelrPdo,$aelrPrefix,$newId,$newWallet);$newWallet=aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local);
    aelr_check($newWallet['energy']===20&&count($newWallet['batteries'])===1&&mobile_energy_charge($newWallet['batteries'][0],$now)===20,'New-player fixture20 plus full20 with explicit local enabled config');
    $claimId=bin2hex(random_bytes(32));
    mobile_wallet_mutate($aelrPdo,aelr_row($aelrPdo,$aelrPrefix,$newId),$claimId,'energy_claim',[],$now,$local,$aelrPrefix);
    $claimed=aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local);
    aelr_check($claimed['energy']===40&&mobile_energy_charge($claimed['batteries'][0],$now)===0,'Real wallet mutation claims20 into40 and empties cycle');
    mobile_wallet_mutate($aelrPdo,aelr_row($aelrPdo,$aelrPrefix,$newId),$claimId,'energy_claim',[],$now+1,$local,$aelrPrefix);
    aelr_check(aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local)===$claimed,'Claim receipt replay changes neither balance nor cycle');
    $zeroRejected=false;
    try {mobile_wallet_mutate($aelrPdo,aelr_row($aelrPdo,$aelrPrefix,$newId),bin2hex(random_bytes(32)),'energy_claim',[],$now+1000,$local,$aelrPrefix);}
    catch(MobileError $e){if($e->getMessage()!=='charge_empty')throw $e;$zeroRejected=true;}
    aelr_check($zeroRejected&&aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local)===$claimed,'Zero claim rejected without resetting fractional progress');
    $ops=aelr_table($aelrPrefix,'mobile_operations');
    aelr_check((int)$aelrPdo->query('SELECT COUNT(*) FROM '.$ops)->fetchColumn()===1,'Only one claim receipt exists after replay and rejected zero');
    $feedbackArgs=['comment'=>'Synthetic Android energy deployment rehearsal.','rating'=>1];
    mobile_wallet_mutate($aelrPdo,aelr_row($aelrPdo,$aelrPrefix,$newId),bin2hex(random_bytes(32)),'energy_feedback',$feedbackArgs,$now+1000,$local,$aelrPrefix);
    aelr_check(aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local)['energy']===60,'First internal feedback grants20 independently of rating');
    mobile_wallet_mutate($aelrPdo,aelr_row($aelrPdo,$aelrPrefix,$newId),bin2hex(random_bytes(32)),'energy_feedback',$feedbackArgs,$now+2000,$local,$aelrPrefix);
    $feedback=aelr_table($aelrPrefix,'mobile_energy_feedback');
    $q=$aelrPdo->query('SELECT COUNT(*) n,SUM(reward) rewards,MIN(delivery_state) state,SUM(attempts) attempts FROM '.$feedback);$outbox=$q->fetch(PDO::FETCH_ASSOC);
    aelr_check((int)$outbox['n']===1&&(int)$outbox['rewards']===20&&$outbox['state']==='pending'&&(int)$outbox['attempts']===0&&
      aelr_wallet($aelrPdo,$aelrPrefix,$newId,$local)['energy']===60,'Feedback replay does not regrant; one pending outbox row, zero delivery attempts');
    $publicationAfter=gameplay_snapshot();
    aelr_check($publicationBefore['revision']===$publicationAfter['revision']&&$configHashBefore===hash('sha256',json_encode($publicationAfter['config'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR)),
      'Effective live configuration and publication revision unchanged');
}catch(Throwable $e){
    $aelrFailure=$e instanceof AelrFailure?$e->getMessage():'rehearsal_failed';
    error_log('android_energy_rehearsal: '.get_class($e));
}finally {
    if($aelrPdo&&$aelrOwned&&$aelrPrefix) {
      try {
        if($aelrPdo->inTransaction())$aelrPdo->rollBack();
        foreach(aelr_names() as $table)$aelrPdo->exec('DROP TABLE IF EXISTS '.aelr_table($aelrPrefix,$table));
        $aelrCleaned=aelr_tables_count($aelrPdo,$aelrPrefix)===0;
      }catch(Throwable $cleanupError){$aelrFailure='rehearsal_cleanup_failed';error_log('android_energy_rehearsal_cleanup: '.get_class($cleanupError));}
    }
    if($aelrPdo&&$aelrLocked){try{$q=$aelrPdo->prepare('SELECT RELEASE_LOCK(?)');$q->execute(['untouch_android_energy_v2_rehearsal']);}catch(Throwable $ignored){}}
}
$aelrOk=$aelrFailure===null&&$aelrCleaned;
if(!$aelrOk)http_response_code(503);
echo json_encode(['ok'=>$aelrOk,'checks'=>count($GLOBALS['aelrChecks']),'passed'=>$GLOBALS['aelrChecks'],'failedCheck'=>$GLOBALS['aelrFailedCheck'],
  'cleaned'=>$aelrCleaned,'temporaryTableCount'=>count(aelr_names()),'productionProfileRowsCreated'=>0,'mailDeliveryCalls'=>0,
  'migrationMode'=>'explicit local config fixtures; production flag unchanged','error'=>$aelrFailure],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
