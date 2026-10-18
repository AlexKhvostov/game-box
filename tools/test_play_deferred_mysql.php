<?php
// Isolated loopback PDO + synthetic Google fixtures. No real Google/FTP/players.
if(PHP_SAPI!=='cli')exit(2);
function tg_load_economy(){return $GLOBALS['pd_config'];}
function tg_local_gameplay_config(){return ['game'=>['helmetEnabled'=>true,'jumpEnabled'=>true]];}
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
require_once __DIR__.'/../telegram-web/api/mobile_play.php';
require_once __DIR__.'/../telegram-web/api/mobile_play_notifications.php';
$GLOBALS['pd_config']=['initialLives'=>7,'initialTokens'=>13,'androidEnergyV2'=>mobile_energy_defaults()];$GLOBALS['pd_config']['androidEnergyV2']['enabled']=true;
$checks=[];$failure=null;$pdo=null;$cleaned=false;$prefix='_pd_'.bin2hex(random_bytes(8)).'_';
function pd_check($ok,$label){if(!$ok)throw new RuntimeException($label);$GLOBALS['checks'][]=$label;}
function pd_error($call,$expected,$label){try{$call();}catch(MobileError $e){pd_check($e->getMessage()===$expected,$label);return;}throw new RuntimeException($label.' not rejected');}
function pd_row($pdo,$id,$prefix){$q=$pdo->prepare('SELECT * FROM '.mobile_table('mobile_players',$prefix).' WHERE id=?');$q->execute([$id]);return$q->fetch();}
function pd_wallet($pdo,$id,$prefix){return mobile_wallet(pd_row($pdo,$id,$prefix),tg_load_economy());}
function pd_data($fixture,$id,$name){$data=$fixture[$name];$data['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:'.$id);return$data;}
function pd_apply($pdo,$id,$prefix,$token,$data,$hint,$now){$row=pd_row($pdo,$id,$prefix);$ctx=mobile_play_energy_context($pdo,$row,$token,$data,$prefix);$ent=mobile_play_energy_subscription($data,'android:'.$id,$hint,mobile_energy_product($hint),$now,$ctx);mobile_play_apply($pdo,$row,$token,$ent['ledgerProductId'],$ent['ledgerTerms'],1,$ent['expiresAt'],'{}',$now,$prefix,0,$ent);return$ent;}
function pd_player($pdo,$prefix,$now){$secret=bin2hex(random_bytes(32));mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$prefix,180,2);return mobile_auth($pdo,$secret,$prefix);}
function pd_db(){return new PDO('mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4','root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);}
function pd_parallel($prefix,$id,$jobs,$now){$workers=[];$at=microtime(true)+.6;
 foreach($jobs as$job){$payload=base64_encode(json_encode(['prefix'=>$prefix,'id'=>$id,'job'=>$job,'now'=>$now,'at'=>$at]));$process=proc_open([PHP_BINARY,__FILE__,'--worker='.$payload],[1=>['pipe','w'],2=>['pipe','w']],$pipes);$workers[]=[$process,$pipes];}
 $out=[];foreach($workers as[$process,$pipes]){$raw=stream_get_contents($pipes[1]);$err=stream_get_contents($pipes[2]);foreach($pipes as$pipe)fclose($pipe);if(proc_close($process)!==0)throw new RuntimeException('Worker failed '.$err);$out[]=json_decode($raw,true);}return$out;}
$options=getopt('',['worker:']);
if(isset($options['worker'])){$x=json_decode(base64_decode($options['worker']),true);if(!preg_match('/^_pd_[a-f0-9]{16}_$/D',$x['prefix']??''))exit(2);
 while(microtime(true)<$x['at'])usleep(1000);try{$db=pd_db();pd_apply($db,$x['id'],$x['prefix'],$x['job']['token'],$x['job']['data'],$x['job']['hint'],$x['now']);echo json_encode(['ok'=>true]);}catch(Throwable$e){echo json_encode(['error'=>get_class($e).':'.$e->getMessage()]);}exit;}
try{
 $f=json_decode(file_get_contents(__DIR__.'/../test/fixtures/google_play_deferred_replacement.json'),true);$now=$f['nowMs'];$end=$f['cutoverMs'];$late=$f['afterMs'];$oldSku='energy_batteries_5_v1';$target='energy_batteries_2_v1';$oldTerms=mobile_energy_product($oldSku);$targetTerms=mobile_energy_product($target);
 $ctx=['linkedProductId'=>$oldSku,'linkedMetadata'=>['energyProductTerms'=>$oldTerms]];
 foreach(['pending','active'] as $phase){$time=$phase==='pending'?$now:$late;$data=$f[$phase];$ent=mobile_play_energy_subscription($data,$f['owner'],$oldSku,$oldTerms,$time,$ctx);
  pd_check($ent['ledgerProductId']===$target&&$ent['ledgerTerms']===$targetTerms,'Immutable target ledger '.$phase);
  pd_check($ent['effectiveProductId']===($phase==='pending'?$oldSku:$target)&&$ent['effectiveTerms']['batteryCount']===($phase==='pending'?5:2),'Effective tier '.$phase);
  pd_check($ent['ackProductId']===($phase==='pending'?$oldSku:$target),'ACK verified effective SKU with new token '.$phase);
  $ack=mobile_play_subscription_ack_url('https://example.invalid/purchases/',$target,'synthetic-new-token/?&',$ent);
  pd_check($ack==='https://example.invalid/purchases/subscriptions/'.($phase==='pending'?$oldSku:$target).'/tokens/synthetic-new-token%2F%3F%26:acknowledge','ACK exact encoded request uses new token '.$phase);
  pd_check($ent['deferredChain']['cutoverAt']===$end,'Cutover exact boundary '.$phase);
  $data['lineItems']=array_reverse($data['lineItems']);pd_check(mobile_play_energy_subscription($data,$f['owner'],$target,$targetTerms,$time,$ctx)===$ent,'Line order and SDK alias independent '.$phase);
  pd_check(mobile_play_subscription_hint($data)===$target,'RTDN hint order independent '.$phase);
 }
 $bad=$f['pending'];$bad['externalAccountIdentifiers']['obfuscatedExternalAccountId']='wrong';pd_error(function()use($bad,$f,$oldSku,$oldTerms,$now){mobile_play_energy_subscription($bad,$f['owner'],$oldSku,$oldTerms,$now);},'purchase_owner_invalid','Foreign Google owner rejected');
 foreach(['unknown','duplicate','excess','unlinked','wrongplan','unrelated'] as $case){$bad=$f['pending'];
  if($case==='unknown')$bad['lineItems'][1]['productId']='unknown';if($case==='duplicate')$bad['lineItems'][1]=$bad['lineItems'][0];if($case==='excess')$bad['lineItems'][]=$bad['lineItems'][0];if($case==='unlinked')unset($bad['linkedPurchaseToken']);if($case==='wrongplan')$bad['lineItems'][1]['offerDetails']['basePlanId']='monthly';if($case==='unrelated'){unset($bad['lineItems'][0]['deferredItemReplacement']);$bad['lineItems'][1]['expiryTime']=$bad['lineItems'][0]['expiryTime'];}
  pd_error(function()use($bad,$f,$oldSku,$oldTerms,$now){mobile_play_energy_subscription($bad,$f['owner'],$oldSku,$oldTerms,$now);},$case==='wrongplan'?'subscription_plan_invalid':'subscription_product_invalid','Invalid '.$case.' rejected');}
 $missing=$f['pending'];$missing['lineItems']=[$missing['lineItems'][0]];pd_error(function()use($missing,$f,$oldSku,$oldTerms,$now){mobile_play_energy_subscription($missing,$f['owner'],$oldSku,$oldTerms,$now);},'subscription_product_invalid','Missing deferred target cannot pin new token to old SKU');
 foreach([[],true,'invalid-date']as$value){$bad=$f['pending'];$bad['lineItems'][1]['expiryTime']=$value;pd_error(function()use($bad,$f,$oldSku,$oldTerms,$now){mobile_play_energy_subscription($bad,$f['owner'],$oldSku,$oldTerms,$now);},'subscription_period_invalid','Malformed expiry cannot masquerade as absent target expiry');}
 $pdo=pd_db();
 pd_check($pdo->query('SELECT DATABASE()')->fetchColumn()==='untouch_friend_invites_tests'&&(int)$pdo->query('SELECT @@port')->fetchColumn()===43317,'Exact loopback disposable DB');
 $pdo->exec('CREATE TABLE '.mobile_table('scores',$prefix).' (id INT AUTO_INCREMENT PRIMARY KEY,player_name VARCHAR(128),user_id VARCHAR(64)) ENGINE=InnoDB');mobile_migrate($pdo,$prefix);
 foreach([false,true] as $claimBefore){
  $player=pd_player($pdo,$prefix,$now-5*3600000);$id=$player['id'];$oldToken='synthetic-old-token-five';$token='synthetic-new-token-'.($claimBefore?'claim':'keep');
  $initial=['expiresAt'=>$end,'startedAt'=>$now-4*3600000,'periodId'=>'synthetic-order-old','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
  // Give each scenario its own old-token identifier while retaining exact Google shape.
  $oldToken.='-'.$id;$data=pd_data($f,$id,'pending');$data['linkedPurchaseToken']=$oldToken;
  mobile_play_apply($pdo,$player,$oldToken,$oldSku,$oldTerms,1,$end,'{}',$now-4*3600000,$prefix,0,$initial);
  $before=pd_wallet($pdo,$id,$prefix);$original=$before['batteries'];$ent=pd_apply($pdo,$id,$prefix,$token,$data,$oldSku,$now);$pending=pd_wallet($pdo,$id,$prefix);
  pd_check($pending['batteries']===$original&&$pending['energy']===$before['energy']&&count($pending['batteries'])===5,'Pending preserves all5 cycles/energy '.(int)$claimBefore);
  pd_check($pending['energySubscription']['productId']===$oldSku&&$pending['energySubscription']['ledgerProductId']===$target,'Wallet effective5 and ledger target2');
  pd_check(in_array(hash('sha256',$oldToken),$pending['energyRetiredTokens'],true),'Old token retired after accepting N');
  $q=$pdo->prepare('SELECT product_id,token_sealed FROM '.mobile_table('mobile_purchases',$prefix).' WHERE token_hash=?');$q->execute([hash('sha256',$token)]);$receipt=$q->fetch();
  pd_check($receipt['product_id']===$target&&json_decode($receipt['token_sealed'],true)['energyProductTerms']===$targetTerms,'New token immutable target2 receipt');
  pd_apply($pdo,$id,$prefix,$token,$data,$target,$now+1000);pd_check(pd_wallet($pdo,$id,$prefix)['batteries']===$original,'Pending replay cannot reset cycles');
  if($claimBefore){
    $GLOBALS['pd_config']['androidEnergyV2']['batteryCapacity']=40;$GLOBALS['pd_config']['androidEnergyV2']['chargeHours']=6;
    mobile_wallet_mutate($pdo,pd_row($pdo,$id,$prefix),bin2hex(random_bytes(32)),'energy_claim',[],$now+3600000,tg_load_economy(),$prefix);
    $claimed=pd_wallet($pdo,$id,$prefix);pd_check($claimed['batteries'][0]['capacity']===40&&$claimed['batteries'][1]['capacity']===20&&$claimed['batteries'][1]['durationMs']===43200000,'Pending claim freezes old paid SKU terms despite public config edit');
    $GLOBALS['pd_config']['androidEnergyV2']=mobile_energy_defaults();$GLOBALS['pd_config']['androidEnergyV2']['enabled']=true;
  }
  $beforeTransition=pd_wallet($pdo,$id,$prefix);$kept=array_slice($beforeTransition['batteries'],0,2);$settlement=0;foreach(array_slice($beforeTransition['batteries'],2)as$b)$settlement+=mobile_energy_charge($b,$end);
  $active=pd_data($f,$id,'active');$active['linkedPurchaseToken']=$oldToken;$activeEnt=pd_apply($pdo,$id,$prefix,$token,$active,$oldSku,$late);$after=pd_wallet($pdo,$id,$prefix);
  pd_check(count($after['batteries'])===2&&$after['batteries']===$kept,'Cutover preserves two remaining cycles '.(int)$claimBefore);
  pd_check($after['energy']===$beforeTransition['energy']+$settlement,'Three disconnected slots settle strictly at E '.(int)$claimBefore);
  pd_check($after['energySubscription']['productId']===$target,'Wallet becomes effective2 only after paid renewal');
  pd_apply($pdo,$id,$prefix,$token,$active,$target,$late+1000);pd_check(pd_wallet($pdo,$id,$prefix)['energy']===$after['energy'],'Renewed replay does not settle twice');
  $single=$active;$single['lineItems']=[$active['lineItems'][1]];unset($single['lineItems'][0]['itemReplacement']);
  pd_apply($pdo,$id,$prefix,$token,$single,$oldSku,$late+1200);pd_check(pd_wallet($pdo,$id,$prefix)['batteries']===$after['batteries'],'Pruned single-line renewal accepts only persisted old-hint chain');
  $stale=$data;$stale['lineItems'][0]['latestSuccessfulOrderId']='different-stale-order';pd_apply($pdo,$id,$prefix,$token,$stale,$oldSku,$late+2000);$current=pd_wallet($pdo,$id,$prefix);
  pd_check($current===$after,'Stale pending after active never rolls back tier/balance/phase');
  mobile_play_apply($pdo,pd_row($pdo,$id,$prefix),$oldToken,$oldSku,$oldTerms,1,$end,'{}',$late+3000,$prefix,0,$initial);
  pd_check(pd_wallet($pdo,$id,$prefix)['batteries']===$after['batteries']&&pd_wallet($pdo,$id,$prefix)['energySubscription']['productId']===$target,'Old RTDN cannot restore5/remove2');
  $other=pd_player($pdo,$prefix,$now);pd_error(function()use($pdo,$other,$token,$active,$prefix){mobile_play_energy_context($pdo,$other,$token,$active,$prefix);},'purchase_owner_invalid','Cross owner new-token context rejected');
  $foreign=$active;$foreign['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:'.$other['id']);pd_error(function()use($pdo,$other,$foreign,$prefix){mobile_play_energy_context($pdo,$other,'unknown-new-token',$foreign,$prefix);},'purchase_owner_invalid','Cross owner linked-token context rejected');
  $expired=$active;$expired['subscriptionState']='SUBSCRIPTION_STATE_EXPIRED';$final=$activeEnt['expiresAt']+1000;pd_apply($pdo,$id,$prefix,$token,$expired,$target,$final);$ended=pd_wallet($pdo,$id,$prefix);pd_check(count($ended['batteries'])===1&&$ended['energySubscription']===null,'Confirmed target expiry disconnects once');
  pd_apply($pdo,$id,$prefix,$token,$expired,$target,$final+1000);pd_check(pd_wallet($pdo,$id,$prefix)['energy']===$ended['energy'],'Confirmed expiry replay cannot pay twice');
 }
 // Google may expire O first when transferring its remaining paid time to N.
 $player=pd_player($pdo,$prefix,$now-5*3600000);$id=$player['id'];$oldToken='synthetic-transfer-old-'.$id;$newToken='synthetic-transfer-new-'.$id;
 $old=['expiresAt'=>$end,'startedAt'=>$now-4*3600000,'periodId'=>'old-transfer','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
 mobile_play_apply($pdo,$player,$oldToken,$oldSku,$oldTerms,1,$end,'{}',$now-4*3600000,$prefix,0,$old);$cycles=pd_wallet($pdo,$id,$prefix)['batteries'];
 $gone=pd_data($f,$id,'pending');$gone['lineItems']=[$gone['lineItems'][0]];unset($gone['lineItems'][0]['deferredItemReplacement'],$gone['linkedPurchaseToken']);$gone['subscriptionState']='SUBSCRIPTION_STATE_EXPIRED';$gone['canceledStateContext']=['replacementCancellation'=>[]];$gone['lineItems'][0]['expiryTime']=gmdate('c',intdiv($now,1000));
 $oldEnt=pd_apply($pdo,$id,$prefix,$oldToken,$gone,$oldSku,$now);pd_check(!empty($oldEnt['replacementAwaitingToken'])&&$oldEnt['expiresAt']===$end&&!$oldEnt['endConfirmed'],'Replacement-expired O retains last verified boundary before N');
 pd_check(pd_wallet($pdo,$id,$prefix)['batteries']===$cycles,'Old EXPIRED-before-N preserves paid cycles');
 mobile_energy_prepare($pdo,pd_row($pdo,$id,$prefix),$end+1000,2,$prefix);$pending=pd_wallet($pdo,$id,$prefix);
 pd_check(count($pending['batteries'])===5&&!empty($pending['energySubscription']['awaitingReconciliation']),'Missing N after old boundary freezes5 without eternal charging');
 pd_error(function()use($pdo,$id,$prefix,$end){mobile_wallet_mutate($pdo,pd_row($pdo,$id,$prefix),bin2hex(random_bytes(32)),'energy_claim',[],$end+1000,tg_load_economy(),$prefix);},'subscription_verification_pending','Replacement awaiting N blocks whole claim');
 $lateData=pd_data($f,$id,'active');$lateData['linkedPurchaseToken']=$oldToken;pd_apply($pdo,$id,$prefix,$newToken,$lateData,$oldSku,$late);$lateWallet=pd_wallet($pdo,$id,$prefix);
 pd_check(count($lateWallet['batteries'])===2&&$lateWallet['batteries']===array_slice($cycles,0,2),'First N after cutover restores kept cycles without losing progress');
 $expected=20;foreach(array_slice($cycles,2)as$b)$expected+=mobile_energy_charge($b,$end);pd_check($lateWallet['energy']===$expected,'Late N settles three only through cutover once');
 pd_apply($pdo,$id,$prefix,$oldToken,$gone,$oldSku,$late+1000);pd_check(pd_wallet($pdo,$id,$prefix)['energySubscription']['productId']===$target,'Expired O after N cannot remove new entitlement');
 foreach([false,true]as$staleRace){
  $player=pd_player($pdo,$prefix,$now-5*3600000);$id=$player['id'];$oldToken='synthetic-race-old-'.$id;$newToken='synthetic-race-new-'.$id;
  mobile_play_apply($pdo,$player,$oldToken,$oldSku,$oldTerms,1,$end,'{}',$now-4*3600000,$prefix,0,$old);
  $pending=pd_data($f,$id,'pending');$pending['linkedPurchaseToken']=$oldToken;pd_apply($pdo,$id,$prefix,$newToken,$pending,$oldSku,$now);
  $before=pd_wallet($pdo,$id,$prefix);$settle=0;foreach(array_slice($before['batteries'],2)as$b)$settle+=mobile_energy_charge($b,$end);
  $active=pd_data($f,$id,'active');$active['linkedPurchaseToken']=$oldToken;$pending['lineItems'][0]['latestSuccessfulOrderId']='racing-stale-order';
  $jobs=[['token'=>$newToken,'data'=>$active,'hint'=>$target],['token'=>$newToken,'data'=>$staleRace?$pending:$active,'hint'=>$oldSku]];
  $results=pd_parallel($prefix,$id,$jobs,$late);pd_check(count(array_filter($results,function($r){return!empty($r['ok']);}))===2,'Concurrent verified responses accepted '.(int)$staleRace);
  $after=pd_wallet($pdo,$id,$prefix);pd_check(count($after['batteries'])===2&&$after['energySubscription']['productId']===$target&&$after['energy']===$before['energy']+$settle&&$after['batteries']===array_slice($before['batteries'],0,2),'Concurrent cutover settles once and stale phase cannot win '.(int)$staleRace);
 }
}catch(Throwable $error){$failure=get_class($error).': '.$error->getMessage();}
finally{if($pdo){if($pdo->inTransaction())$pdo->rollBack();foreach(['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players']as$name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($name,$prefix));$q=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$q->execute([strlen($prefix),$prefix]);$cleaned=(int)$q->fetchColumn()===0;}}
echo json_encode(['ok'=>$failure===null&&$cleaned,'checks'=>count($checks),'passed'=>$checks,'cleaned'=>$cleaned,'failure'=>$failure,'syntheticOnly'=>true,'googleRequests'=>0],JSON_PRETTY_PRINT).PHP_EOL;exit($failure===null&&$cleaned?0:1);
