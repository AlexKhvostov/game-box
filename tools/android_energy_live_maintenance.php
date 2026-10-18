<?php
// ONE-SHOT TEMPLATE, not a permanent API. Inject a fresh 64-hex __TOKEN__,
// upload next to installed api/tg_common.php, use HTTPS, then remove it.
// inspect/backup intentionally work before the new Energy helpers are deployed.
ini_set('display_errors','0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private, max-age=0');
header('Pragma: no-cache');
header('X-Robots-Tag: noindex, nofollow');
header('X-Content-Type-Options: nosniff');
$aeLiveToken='__TOKEN__';
if(($_SERVER['REQUEST_METHOD']??'')!=='POST'||!preg_match('/^[a-f0-9]{64}$/D',$aeLiveToken)||
   !is_string($_SERVER['HTTP_X_UNTOUCH_TEST']??null)||!hash_equals($aeLiveToken,$_SERVER['HTTP_X_UNTOUCH_TEST'])) {
    http_response_code(404);echo '{}';exit;
}
// A forgotten temporary endpoint stops accepting its token after two hours.
$aeLiveCreated=@filemtime(__FILE__);
if(!$aeLiveCreated||time()>$aeLiveCreated+7200){http_response_code(410);echo '{"ok":false,"error":"maintenance_expired"}';exit;}
if(function_exists('set_time_limit'))@set_time_limit(120);
set_error_handler(function($severity){if(!(error_reporting()&$severity))return false;throw new ErrorException('maintenance_runtime',0,$severity);});

class AeLiveError extends RuntimeException {
    public $status;
    public function __construct($code,$status=409){parent::__construct($code);$this->status=$status;}
}
function ae_live_json($value){return json_encode($value,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR);}
function ae_live_hash($value){return hash('sha256',ae_live_json($value));}
function ae_live_table($name){
    if(!is_string($name)||!preg_match('/^(?:mobile_[a-z0-9_]+|schema_versions)$/D',$name))throw new AeLiveError('table_scope_invalid');
    return '`'.$name.'`';
}
function ae_live_table_inventory(PDO $pdo){
    $rows=$pdo->query("SELECT TABLE_NAME,TABLE_TYPE,ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME")->fetchAll(PDO::FETCH_ASSOC);
    $tables=[];
    foreach($rows as $row)if(preg_match('/^(?:mobile_[a-z0-9_]+|schema_versions)$/D',$row['TABLE_NAME'])) {
      $tables[]=['name'=>$row['TABLE_NAME'],'type'=>$row['TABLE_TYPE'],'engine'=>strtoupper((string)$row['ENGINE'])];
    }
    return $tables;
}
function ae_live_non_android_hash($config){unset($config['economy']['androidEnergyV2']);return ae_live_hash($config);}
function ae_live_publication(){
    $snapshot=gameplay_snapshot();
    if(!is_array($snapshot['config']??null)||!is_string($snapshot['revision']??null))throw new AeLiveError('publication_invalid',503);
    return $snapshot;
}
function ae_live_dependencies(){
    $names=['tg_common.php','gameplay_config.php','mobile_store.php','mobile_wallet.php','mobile_google.php','mobile_identity.php',
      'mobile_beta.php','mobile_google_nickname.php','mobile_pace.php','mobile_energy.php','mobile_invites.php','mobile_energy_feedback.php'];
    $found=[];foreach($names as $name)$found[$name]=is_file(__DIR__.'/'.$name);return $found;
}
function ae_live_versions(PDO $pdo,$names){
    if(!in_array('schema_versions',$names,true))return [];
    $versions=[];foreach($pdo->query('SELECT component,version FROM schema_versions ORDER BY component')->fetchAll(PDO::FETCH_ASSOC) as $row)$versions[$row['component']]=(int)$row['version'];
    return $versions;
}
function ae_live_inspect(PDO $pdo){
    $now=(int)round(microtime(true)*1000);$inventory=ae_live_table_inventory($pdo);$names=array_column($inventory,'name');
    $aggregate=['players'=>0,'legacyProfiles'=>0,'energyProfiles'=>0,'invalidWallets'=>0,'walletEnergySubscriptions'=>0,
      'paidBatteryProfiles'=>0,'pendingEnergySubscriptions'=>0,'energySubscriptionPurchaseRows'=>0,'activeEnergySubscriptionPurchaseRows'=>0,
      'energyPurchaseRows'=>0,'legacySubscriptionPurchaseRows'=>0,'activeLegacyWalletSubscriptions'=>0,'activeLegacySubscriptionPurchaseRows'=>0,
      'energyBalanceTotal'=>0,'legacyLivesTotal'=>0,'legacyCrystalsTotal'=>0];
    foreach($inventory as &$table){
      $table['rows']=$table['type']==='BASE TABLE'?(int)$pdo->query('SELECT COUNT(*) FROM '.ae_live_table($table['name']))->fetchColumn():null;
    }unset($table);
    if(in_array('mobile_players',$names,true)) {
      foreach($pdo->query('SELECT wallet_json FROM mobile_players') as $row) {
        $aggregate['players']++;$raw=$row['wallet_json'];
        $wallet=$raw===null||$raw===''?[]:json_decode($raw,true);
        if(!is_array($wallet)){$aggregate['invalidWallets']++;continue;}
        if((int)($wallet['energyVersion']??0)===2){$aggregate['energyProfiles']++;$aggregate['energyBalanceTotal']+=(int)($wallet['energy']??0);}
        else {$aggregate['legacyProfiles']++;$aggregate['legacyLivesTotal']+=(int)($wallet['lives']??0);$aggregate['legacyCrystalsTotal']+=(int)($wallet['tokens']??0);}
        if(!empty($wallet['energySubscription']))$aggregate['walletEnergySubscriptions']++;
        if((int)($wallet['plusUntil']??0)>$now)$aggregate['activeLegacyWalletSubscriptions']++;
        if(!empty($wallet['energySubscription']['awaitingReconciliation']))$aggregate['pendingEnergySubscriptions']++;
        if(is_array($wallet['batteries']??null)&&count($wallet['batteries'])>1)$aggregate['paidBatteryProfiles']++;
      }
    }
    if(in_array('mobile_purchases',$names,true)) {
      $q=$pdo->prepare("SELECT kind,COUNT(*) n,SUM(CASE WHEN expires_at>? THEN 1 ELSE 0 END) active FROM mobile_purchases GROUP BY kind");$q->execute([$now]);
      foreach($q as $row){
        if($row['kind']==='energy_subscription'){$aggregate['energySubscriptionPurchaseRows']=(int)$row['n'];$aggregate['activeEnergySubscriptionPurchaseRows']=(int)$row['active'];}
        elseif($row['kind']==='energy')$aggregate['energyPurchaseRows']=(int)$row['n'];
        elseif($row['kind']==='subscription'){$aggregate['legacySubscriptionPurchaseRows']=(int)$row['n'];$aggregate['activeLegacySubscriptionPurchaseRows']=(int)$row['active'];}
      }
    }
    $required=['mobile_players','mobile_rounds','mobile_operations','mobile_purchases','mobile_names','mobile_devices','schema_versions'];
    $missing=array_values(array_diff($required,$names));$nonTransactional=[];
    foreach($inventory as $table)if($table['type']!=='BASE TABLE'||$table['engine']!=='INNODB')$nonTransactional[]=$table['name'];
    $inviteTables=['mobile_invite_codes','mobile_invites','mobile_invite_ledger'];$inviteReady=count(array_diff($inviteTables,$names))===0;
    foreach($inventory as $table)if(in_array($table['name'],$inviteTables,true)&&$table['engine']!=='INNODB')$inviteReady=false;
    $inviteColumns=[];if(in_array('mobile_invite_ledger',$names,true))foreach($pdo->query('SHOW COLUMNS FROM mobile_invite_ledger') as $column)$inviteColumns[]=$column['Field'];
    $versions=ae_live_versions($pdo,$names);$snapshot=ae_live_publication();
    return ['serverNow'=>$now,'publicationRevision'=>$snapshot['revision'],'effectiveConfigSha256'=>ae_live_hash($snapshot['config']),
      'nonAndroidConfigSha256'=>ae_live_non_android_hash($snapshot['config']),
      'androidEnergyEnabled'=>!empty($snapshot['config']['economy']['androidEnergyV2']['enabled']),
      'schema'=>['versions'=>$versions,'missingBaseTables'=>$missing,'nonTransactionalTables'=>$nonTransactional,
        'inviteTablesReady'=>$inviteReady,'inviteCurrencyColumn'=>in_array('currency',$inviteColumns,true),'inviteRevisionColumn'=>in_array('revision',$inviteColumns,true),
        'feedbackTableReady'=>in_array('mobile_energy_feedback',$names,true)],
      'aggregates'=>$aggregate,'tables'=>$inventory,'dependencies'=>ae_live_dependencies()];
}
function ae_live_require_v2(){
    foreach(['mobile_store.php','mobile_wallet.php','mobile_energy.php','mobile_invites.php','mobile_energy_feedback.php'] as $file){
      if(!is_file(__DIR__.'/'.$file))throw new AeLiveError('v2_dependency_missing',503);
      require_once __DIR__.'/'.$file;
    }
    if(!function_exists('mobile_energy_defaults')||!function_exists('mobile_energy_migrate_schema')||!function_exists('mobile_invites_migrate'))throw new AeLiveError('v2_dependency_incompatible',503);
}
function ae_live_require_schema($state){
    $s=$state['schema'];
    if($s['missingBaseTables']||$s['nonTransactionalTables']||(int)($s['versions']['mobile']??0)<1||(int)($s['versions']['scores']??0)<2||
      !$s['inviteTablesReady']||!$s['inviteCurrencyColumn']||!$s['inviteRevisionColumn']||!$s['feedbackTableReady'])throw new AeLiveError('v2_schema_not_ready',503);
}
function ae_live_require_free_only($state){
    $a=$state['aggregates'];
    if($a['invalidWallets']>0)throw new AeLiveError('invalid_wallets_require_review');
    if($a['walletEnergySubscriptions']||$a['paidBatteryProfiles']||$a['energySubscriptionPurchaseRows'])throw new AeLiveError('energy_subscriptions_require_review');
    if($a['activeLegacyWalletSubscriptions']||$a['activeLegacySubscriptionPurchaseRows'])throw new AeLiveError('active_legacy_subscriptions_require_review');
}
function ae_live_lock(PDO $pdo){
    $q=$pdo->prepare('SELECT GET_LOCK(?,20)');$q->execute(['untouch_android_energy_v2_release']);
    if((int)$q->fetchColumn()!==1)throw new AeLiveError('maintenance_busy',503);
}
function ae_live_backup(PDO $pdo){
    $before=ae_live_publication();$inventory=ae_live_table_inventory($pdo);
    if(!$inventory)throw new AeLiveError('backup_scope_empty');
    foreach($inventory as $table)if($table['type']!=='BASE TABLE'||$table['engine']!=='INNODB')throw new AeLiveError('backup_requires_innodb');
    $oldBuffered=$pdo->getAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY);$oldStringify=$pdo->getAttribute(PDO::ATTR_STRINGIFY_FETCHES);
    $pdo->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY,false);$pdo->setAttribute(PDO::ATTR_STRINGIFY_FETCHES,true);
    $payload=['format'=>'android-energy-db-v1','capturedAtUtc'=>gmdate('c'),'publication'=>$before,
      'cellEncoding'=>'base64 of exact driver string; null remains null','tables'=>[]];$size=0;$summary=[];
    try {
      $pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
      $pdo->exec('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY');
      // Transactional SELECTs retain metadata locks until commit, so a table's
      // DDL cannot change between SHOW CREATE and dumping its snapshot rows.
      foreach($inventory as $table){$q=$pdo->query('SELECT * FROM '.ae_live_table($table['name']).' LIMIT 0');$q->closeCursor();}
      foreach($inventory as $table) {
        $name=$table['name'];$quoted=ae_live_table($name);$q=$pdo->query('SHOW CREATE TABLE '.$quoted);$create=$q->fetch(PDO::FETCH_NUM);$q->closeCursor();
        if(!is_string($create[1]??null))throw new AeLiveError('backup_ddl_unavailable');
        $columns=[];$q=$pdo->query('SHOW COLUMNS FROM '.$quoted);while($column=$q->fetch(PDO::FETCH_ASSOC))$columns[]=$column['Field'];$q->closeCursor();
        $rows=[];$q=$pdo->query('SELECT * FROM '.$quoted);
        while($row=$q->fetch(PDO::FETCH_NUM)) {
          $cells=[];foreach($row as $cell){$encoded=$cell===null?null:base64_encode((string)$cell);$cells[]=$encoded;$size+=strlen($encoded??'')+8;}
          if($size>16777216)throw new AeLiveError('backup_too_large_use_private_dump',413);
          $rows[]=$cells;
        }$q->closeCursor();
        $payload['tables'][]=['name'=>$name,'engine'=>'INNODB','createSql'=>$create[1],'columns'=>$columns,'rowCount'=>count($rows),'rowsBase64'=>$rows];
        $summary[]=['name'=>$name,'rows'=>count($rows)];
      }
      if(ae_live_table_inventory($pdo)!==$inventory)throw new AeLiveError('backup_table_set_changed');
      $after=ae_live_publication();
      if($after['revision']!==$before['revision']||ae_live_hash($after['config'])!==ae_live_hash($before['config']))throw new AeLiveError('backup_publication_changed');
      $pdo->commit();
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
    finally{$pdo->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY,$oldBuffered);$pdo->setAttribute(PDO::ATTR_STRINGIFY_FETCHES,$oldStringify);}
    $encoded=ae_live_json($payload);
    return ['backup'=>['format'=>'android-energy-db-v1','payloadBase64'=>base64_encode($encoded),'sha256'=>hash('sha256',$encoded),
      'bytes'=>strlen($encoded),'tables'=>$summary,'publicationRevision'=>$before['revision']]];
}

$aeLivePdo=null;$aeLiveLocked=false;
try {
    $raw=file_get_contents('php://input',false,null,0,16385);
    if(strlen($raw)>16384)throw new AeLiveError('request_too_large',413);
    $input=json_decode($raw,true);if(!is_array($input))throw new AeLiveError('request_invalid',400);
    $action=$input['action']??'';
    if(!in_array($action,['inspect','backup','schema','activate','verify'],true))throw new AeLiveError('action_invalid',400);
    require_once __DIR__.'/tg_common.php';require_once __DIR__.'/gameplay_config.php';
    [$aeLivePdo]=tg_connect_pdo();if(!$aeLivePdo)throw new AeLiveError('database_unavailable',503);
    if($action==='inspect')$result=ae_live_inspect($aeLivePdo);
    elseif($action==='backup') {ae_live_lock($aeLivePdo);$aeLiveLocked=true;$result=ae_live_backup($aeLivePdo);}
    else {
      ae_live_require_v2();ae_live_lock($aeLivePdo);$aeLiveLocked=true;
      if($action==='schema') {
        $before=ae_live_inspect($aeLivePdo);
        if($before['androidEnergyEnabled'])throw new AeLiveError('disable_v2_before_schema');
        ae_live_require_free_only($before);
        if($before['schema']['missingBaseTables']||(int)($before['schema']['versions']['mobile']??0)<1)throw new AeLiveError('base_schema_missing',503);
        mobile_energy_migrate_schema($aeLivePdo);mobile_invites_migrate($aeLivePdo);
        $result=ae_live_inspect($aeLivePdo);ae_live_require_schema($result);$result['schemaApplied']=true;
      } elseif($action==='activate') {
        $state=ae_live_inspect($aeLivePdo);ae_live_require_schema($state);ae_live_require_free_only($state);
        $snapshot=ae_live_publication();$expected=$input['expectedPublicationRevision']??null;$nonAndroid=$input['expectedNonAndroidConfigSha256']??null;
        if(!is_string($expected)||!hash_equals($snapshot['revision'],$expected))throw new AeLiveError('publication_changed');
        if(!is_string($nonAndroid)||!preg_match('/^[a-f0-9]{64}$/D',$nonAndroid)||!hash_equals(ae_live_non_android_hash($snapshot['config']),$nonAndroid))throw new AeLiveError('non_android_config_changed');
        $candidate=$snapshot['config'];$android=mobile_energy_defaults();$android['enabled']=true;$candidate['economy']['androidEnergyV2']=$android;
        if(!hash_equals(ae_live_non_android_hash($candidate),$nonAndroid))throw new AeLiveError('non_android_config_changed');
        $published=gameplay_publish($candidate,$expected);
        if(empty($published['ok']))throw new AeLiveError('publication_rejected',(int)($published['status']??409));
        $result=ae_live_inspect($aeLivePdo);
        if(!$result['androidEnergyEnabled']||!hash_equals($result['nonAndroidConfigSha256'],$nonAndroid))throw new AeLiveError('publication_verification_failed',503);
        $result['activated']=true;
      } else {
        $result=ae_live_inspect($aeLivePdo);ae_live_require_schema($result);ae_live_require_free_only($result);$result['verified']=true;
      }
    }
    echo ae_live_json(['ok'=>true]+$result);
}catch(AeLiveError $e){http_response_code($e->status);echo json_encode(['ok'=>false,'error'=>$e->getMessage()]);}
catch(Throwable $e){error_log('android_energy_maintenance: '.get_class($e));http_response_code(503);echo '{"ok":false,"error":"maintenance_failed"}';}
finally {
    if($aeLivePdo&&$aeLiveLocked){try{$q=$aeLivePdo->prepare('SELECT RELEASE_LOCK(?)');$q->execute(['untouch_android_energy_v2_release']);}catch(Throwable $ignored){}}
}
