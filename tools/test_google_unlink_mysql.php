<?php
// Local loopback-only disposable fixtures. No Google network calls or real users.
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
function tg_load_economy(){return ['initialLives'=>7,'initialTokens'=>13,'installBonusAutoClaim'=>false];}
function tg_local_gameplay_config(){return ['game'=>['jumpEnabled'=>true,'helmetEnabled'=>true]];}
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
function gu_db(){return new PDO('mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4','root','',
  [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_EMULATE_PREPARES=>false,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);}
function gu_prefix($p){if(!is_string($p)||!preg_match('/^_gu_[a-f0-9]{16}_$/D',$p))throw new RuntimeException('Fixture scope required');return $p;}
function gu_check($ok,$label){if(!$ok)throw new RuntimeException($label);$GLOBALS['gu_checks'][]=$label;}
function gu_error($call,$expected,$label){try{$call();}catch(MobileError $e){gu_check($e->getMessage()===$expected,$label);return;}throw new RuntimeException($label.' did not reject');}
function gu_row($pdo,$p,$id){$q=$pdo->prepare('SELECT * FROM '.mobile_table('mobile_players',gu_prefix($p)).' WHERE id=?');$q->execute([$id]);return $q->fetch();}
function gu_rows($pdo,$p,$table){return $pdo->query('SELECT * FROM '.mobile_table($table,gu_prefix($p)).' ORDER BY 1')->fetchAll();}
function gu_player($pdo,$p,$now,$v2=false){
  $secret=bin2hex(random_bytes(32));$profile=mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$p);$id=(int)substr($profile['id'],8);
  $wallet=mobile_wallet(gu_row($pdo,$p,$id),tg_load_economy());
  if($v2){$wallet=mobile_energy_migrate_wallet($wallet,mobile_energy_defaults(),$now,true);$wallet['energy']=987;
    $wallet['batteries'][]=mobile_energy_battery('paid-fixture',mobile_energy_defaults(),$now-3600000);
    $wallet['energySubscription']=['productId'=>'energy_batteries_2_v1','batteryCount'=>2,'expiresAt'=>$now+86400000,'tokenHash'=>hash('sha256','synthetic-sub-'.$id)];}
  $wallet['claimed']=['energy_google','energy_age','energy_feedback','survive_10s'];$wallet['unlocked']=['risks_5'];
  $wallet['bestTimeMs']=123456;$wallet['gamesStarted']=77;$wallet['plusUntil']=$now+300000;
  $wallet['jumpUntil']=$now+100000;$wallet['helmetUntil']=$now+200000;$wallet['fixtureCustom']=['keep'=>[1,2,null],'bool'=>true];
  $wallet['_hideGoogleAccount']=false;mobile_wallet_write($pdo,$id,$wallet,$p);
  $subject=(string)(100000+$id);mobile_google_link($pdo,gu_row($pdo,$p,$id),$subject,$p);
  mobile_google_save_details($pdo,$id,['sub'=>$subject,'name'=>'Synthetic Person','email'=>'synthetic@example.test'],$p);
  $purchases=mobile_table('mobile_purchases',$p);
  $pdo->prepare("INSERT INTO $purchases(token_hash,player_id,product_id,kind,token_sealed,expires_at,created_at) VALUES(?,?,?,?,?,?,?)")
    ->execute([hash('sha256','synthetic-token-'.$id),$id,$v2?'energy_batteries_2_v1':'plus_weekly','subscription','synthetic sealed fixture',$now+86400000,$now]);
  return ['id'=>$id,'secret'=>$secret,'subject'=>$subject];
}
function gu_batch($p,$jobs,$now){
  $processes=[];$at=microtime(true)+0.5;
  foreach($jobs as $job){$payload=base64_encode(json_encode(['prefix'=>$p,'job'=>$job,'now'=>$now,'at'=>$at]));
    $process=proc_open([PHP_BINARY,__FILE__,'--worker='.$payload],[1=>['pipe','w'],2=>['pipe','w']],$pipes);$processes[]=[$process,$pipes];}
  $results=[];foreach($processes as [$process,$pipes]){$out=stream_get_contents($pipes[1]);$err=stream_get_contents($pipes[2]);foreach($pipes as $pipe)fclose($pipe);
    if(proc_close($process)!==0)throw new RuntimeException('Synthetic worker failed');$results[]=json_decode($out,true);}
  return $results;
}
$options=getopt('',['worker:']);
if(isset($options['worker'])){
  $x=json_decode(base64_decode($options['worker']),true);gu_prefix($x['prefix']??null);$pdo=gu_db();while(microtime(true)<$x['at'])usleep(1000);
  try{$profile=mobile_google_unlink($pdo,gu_row($pdo,$x['prefix'],$x['job']['id']),$x['job']['key'],$x['now'],$x['prefix']);echo json_encode(['ok'=>true,'linked'=>$profile['googleLinked']]);}
  catch(MobileError $e){echo json_encode(['error'=>$e->getMessage(),'status'=>$e->status]);}exit;
}
$pdo=null;$p='_gu_'.bin2hex(random_bytes(8)).'_';$GLOBALS['gu_checks']=[];$failure=null;$cleaned=false;$now=2000000000000;
try {
  $pdo=gu_db();gu_check($pdo->query('SELECT DATABASE()')->fetchColumn()==='untouch_friend_invites_tests'&&(int)$pdo->query('SELECT @@port')->fetchColumn()===43317,'Exact isolated loopback database');
  $scores=mobile_table('scores',$p);$pdo->exec("CREATE TABLE $scores(id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,user_id VARCHAR(64),player_name VARCHAR(128)) ENGINE=InnoDB");mobile_migrate($pdo,$p);
  foreach([false,true] as $v2){
    $who=gu_player($pdo,$p,$now,$v2);$id=$who['id'];$mode=$v2?'V2':'legacy';
    $restoredSecret=bin2hex(random_bytes(32));mobile_google_restore($pdo,$who['subject'],$restoredSecret,bin2hex(random_bytes(16)),$p);
    $before=gu_row($pdo,$p,$id);$walletBefore=json_decode($before['wallet_json'],true);$devicesBefore=gu_rows($pdo,$p,'mobile_devices');$purchasesBefore=gu_rows($pdo,$p,'mobile_purchases');
    gu_check(mobile_identity_public_name($before)==='Synthetic Person',$mode.' identity is initially public');
    $key=bin2hex(random_bytes(32));$profile=mobile_google_unlink($pdo,$before,$key,$now,$p);$after=gu_row($pdo,$p,$id);$walletAfter=json_decode($after['wallet_json'],true);
    $expected=$walletBefore;unset($expected['_googleIdentity']);$expected['_hideGoogleAccount']=true;
    gu_check($walletAfter===$expected,$mode.' wallet, batteries, claims, subscription, rentals and progress preserved');
    gu_check($after['id']===$before['id']&&$after['nickname']===$before['nickname']&&$after['installation_hash']===$before['installation_hash']&&$after['secret_hash']===$before['secret_hash']&&$after['created_at']===$before['created_at'],$mode.' canonical identity and guest credentials preserved');
    gu_check($after['google_sub']===null&&!array_key_exists('_googleIdentity',$walletAfter),$mode.' binding and stored personal Google identity removed');
    gu_check((int)$after['wallet_version']===(int)$before['wallet_version']+1,$mode.' changed wallet increments version once');
    gu_check(!$profile['googleLinked']&&$profile['googleName']===null&&$profile['googleEmail']===null&&$profile['hideGoogleAccount']===true,$mode.' returned profile confirms disconnect and hidden Google');
    gu_check(gu_rows($pdo,$p,'mobile_devices')===$devicesBefore&&gu_rows($pdo,$p,'mobile_purchases')===$purchasesBefore,$mode.' all device bindings and purchase ledger unchanged');
    gu_check((int)mobile_auth($pdo,$who['secret'],$p)['id']===$id&&(int)mobile_auth($pdo,$restoredSecret,$p)['id']===$id,$mode.' original and restored devices retain access');
    $public=mobile_identity_public_scores($pdo,[['userId'=>'android:'.$id,'googleName'=>'old cached','username'=>'old','firstName'=>'old','lastName'=>'old']],$p)[0];
    gu_check($public['googleName']===null&&$public['username']===null&&$public['firstName']===null&&$public['lastName']===null,$mode.' ranking response clears Google and legacy personal fields');
    gu_error(function()use($pdo,$p,$id,$who){mobile_google_save_details($pdo,$id,['sub'=>$who['subject'],'name'=>'Delayed OAuth','email'=>'delayed@example.test'],$p);},'google_account_mismatch',$mode.' delayed old Google details cannot resurrect identity');
    mobile_google_unlink($pdo,gu_row($pdo,$p,$id),$key,$now+1,$p);gu_check(gu_row($pdo,$p,$id)===$after,$mode.' same receipt replay causes no new mutation');
    mobile_google_unlink($pdo,gu_row($pdo,$p,$id),bin2hex(random_bytes(32)),$now+2,$p);gu_check(gu_row($pdo,$p,$id)===$after,$mode.' already disconnected new receipt leaves version unchanged');
    $newSubject=(string)(200000+$id);mobile_google_link($pdo,gu_row($pdo,$p,$id),$newSubject,$p);
    mobile_google_save_details($pdo,$id,['sub'=>$newSubject,'name'=>'New Synthetic Person','email'=>'new@example.test'],$p);$relinked=gu_row($pdo,$p,$id);
    $reply=mobile_google_unlink($pdo,gu_row($pdo,$p,$id),$key,$now+3,$p);
    gu_check(gu_row($pdo,$p,$id)===$relinked&&$reply['googleLinked']&&$reply['googleName']==='New Synthetic Person',$mode.' replay of old unlink after new link returns current profile without unlinking');
    $other=gu_player($pdo,$p,$now);$otherBefore=gu_row($pdo,$p,$other['id']);
    gu_error(function()use($pdo,$p,$other,$key,$now){mobile_google_unlink($pdo,gu_row($pdo,$p,$other['id']),$key,$now,$p);},'operation_conflict',$mode.' another authenticated owner cannot reuse receipt');
    gu_check(gu_row($pdo,$p,$other['id'])===$otherBefore,$mode.' foreign receipt failure preserves other owner');
    $operations=mobile_table('mobile_operations',$p);$trigger=$p.'fail_receipt';$pdo->exec("CREATE TRIGGER `$trigger` BEFORE INSERT ON $operations FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='synthetic rollback probe'");
    $rollback=false;try{mobile_google_unlink($pdo,gu_row($pdo,$p,$id),bin2hex(random_bytes(32)),$now,$p);}catch(PDOException $e){$rollback=true;}
    $pdo->exec("DROP TRIGGER `$trigger`");gu_check($rollback&&gu_row($pdo,$p,$id)===$relinked,$mode.' failed durable receipt rolls back binding and wallet together');
  }
  $row=gu_row($pdo,$p,1);foreach([null,'',str_repeat('A',64),str_repeat('a',63),123,[]] as $invalid)
    gu_error(function()use($pdo,$p,$row,$invalid,$now){mobile_google_unlink($pdo,$row,$invalid,$now,$p);},'operation_invalid','Malformed receipt refused before mutation');
  gu_error(function()use($pdo,$p,$now){mobile_google_unlink($pdo,['id'=>99999999],bin2hex(random_bytes(32)),$now,$p);},'unauthorized','Missing canonical player is unauthorized');
  $same=gu_player($pdo,$p,$now,true);$sameBefore=gu_row($pdo,$p,$same['id']);$sameKey=bin2hex(random_bytes(32));
  $out=gu_batch($p,[['id'=>$same['id'],'key'=>$sameKey],['id'=>$same['id'],'key'=>$sameKey]],$now);
  gu_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===2&&(int)gu_row($pdo,$p,$same['id'])['wallet_version']===(int)$sameBefore['wallet_version']+1,'Concurrent same-owner duplicate unlink two ACKs and one mutation');
  $a=gu_player($pdo,$p,$now);$b=gu_player($pdo,$p,$now);$shared=bin2hex(random_bytes(32));
  $out=gu_batch($p,[['id'=>$a['id'],'key'=>$shared],['id'=>$b['id'],'key'=>$shared]],$now);
  gu_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===1&&count(array_filter($out,function($x){return($x['error']??'')==='operation_conflict'&&$x['status']===409;}))===1,'Concurrent different owners sharing key have one winner and one409');
  gu_check((int)(gu_row($pdo,$p,$a['id'])['google_sub']===null)+(int)(gu_row($pdo,$p,$b['id'])['google_sub']===null)===1,'Cross-owner receipt race cannot unlink both accounts');
  $broken=gu_player($pdo,$p,$now);$players=mobile_table('mobile_players',$p);$pdo->prepare("UPDATE $players SET wallet_json='not-json' WHERE id=?")->execute([$broken['id']]);$before=gu_row($pdo,$p,$broken['id']);
  gu_error(function()use($pdo,$p,$before,$now){mobile_google_unlink($pdo,$before,bin2hex(random_bytes(32)),$now,$p);},'wallet_unavailable','Invalid stored wallet refuses unlink instead of replacing financial state');
  gu_check(gu_row($pdo,$p,$broken['id'])===$before,'Invalid-wallet failure retains Google and wallet bytes');
}catch(Throwable $e){$failure=get_class($e).': '.$e->getMessage();}
finally {
  if($pdo){try{if($pdo->inTransaction())$pdo->rollBack();foreach(['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($name,gu_prefix($p)));
    $q=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$q->execute([strlen($p),$p]);$cleaned=(int)$q->fetchColumn()===0;
  }catch(Throwable $e){$failure='Fixture cleanup failed';}}
}
echo json_encode(['ok'=>$failure===null&&$cleaned,'checks'=>count($GLOBALS['gu_checks']),'passed'=>$GLOBALS['gu_checks'],'cleaned'=>$cleaned,'failure'=>$failure],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
exit($failure===null&&$cleaned?0:1);
