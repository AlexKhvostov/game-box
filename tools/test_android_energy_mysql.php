<?php
// Disposable, loopback-only MySQL tests. No Google calls, real mail, FTP or players.
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
function tg_load_economy(){return $GLOBALS['ae_config'];}
function tg_local_gameplay_config(){return ['game'=>['jumpEnabled'=>true,'helmetEnabled'=>true,'wallsKillPlayer'=>false]];}
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_invites.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
require_once __DIR__.'/../telegram-web/api/mobile_play.php';
require_once __DIR__.'/../telegram-web/api/mobile_energy_feedback.php';
require_once __DIR__.'/../telegram-web/api/gameplay_config.php';
$GLOBALS['ae_config']=['initialLives'=>7,'initialTokens'=>13,'runRewardEvery'=>200,'runRewardTokens'=>1,'riskRewardEvery'=>5,'riskRewardTokens'=>1,
  'earnSurviveSeconds'=>10,'earnRecordSeconds'=>20,'earnRisksInRun'=>5,'watchAdCooldownSec'=>60,'androidEnergyV2'=>mobile_energy_defaults()];
$GLOBALS['ae_config']['androidEnergyV2']['enabled']=true;
function ae_db(){return new PDO('mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4','root','',
  [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_EMULATE_PREPARES=>false,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);}
function ae_check($ok,$label){if(!$ok)throw new RuntimeException($label);$GLOBALS['ae_passed'][]=$label;}
function ae_error($call,$expected,$label){try{$call();}catch(MobileError $e){ae_check($e->getMessage()===$expected,$label.' ('.$e->getMessage().')');return;}throw new RuntimeException($label.' did not reject');}
function ae_row($pdo,$id,$prefix){$q=$pdo->prepare('SELECT * FROM '.mobile_table('mobile_players',$prefix).' WHERE id=?');$q->execute([$id]);return $q->fetch();}
function ae_wallet($pdo,$id,$prefix){return mobile_wallet(ae_row($pdo,$id,$prefix),tg_load_economy());}
function ae_player($pdo,$prefix,$now,$version=2){$secret=bin2hex(random_bytes(32));$profile=mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$prefix,180,$version);return mobile_auth($pdo,$secret,$prefix);}
function ae_op($pdo,$id,$prefix,$kind,$args,$now,$key=null){return mobile_wallet_mutate($pdo,ae_row($pdo,$id,$prefix),$key??bin2hex(random_bytes(32)),$kind,$args,$now,tg_load_economy(),$prefix)['wallet'];}
function ae_history($pdo,$id,$prefix,$now){$table=mobile_table('mobile_rounds',$prefix);$q=$pdo->prepare("INSERT INTO $table (id,player_id,started_at,finished_at,result_json,context_json) VALUES (?,?,?,?,?,?)");for($i=0;$i<5;$i++)$q->execute([bin2hex(random_bytes(32)),$id,$now,$now+1000,'{"ok":true,"score":0}','{}']);}
function ae_workers($prefix,$id,$jobs,$now){
  $processes=[];$at=microtime(true)+0.7;
  foreach($jobs as $job){$payload=base64_encode(json_encode(['prefix'=>$prefix,'id'=>$id,'job'=>$job,'now'=>$now,'at'=>$at]));
    $p=proc_open([PHP_BINARY,__FILE__,'--worker='.$payload],[1=>['pipe','w'],2=>['pipe','w']],$pipes);$processes[]=[$p,$pipes];}
  $out=[];foreach($processes as [$p,$pipes]){$s=stream_get_contents($pipes[1]);$err=stream_get_contents($pipes[2]);foreach($pipes as $pipe)fclose($pipe);$code=proc_close($p);if($code!==0)throw new RuntimeException('Worker failed '.$err);$out[]=json_decode($s,true);}
  return $out;
}
$options=getopt('',['worker:']);
if(isset($options['worker'])) {
  $x=json_decode(base64_decode($options['worker']),true);if(!preg_match('/^_ae_[a-f0-9]{16}_$/D',$x['prefix']??''))exit(2);
  while(microtime(true)<$x['at'])usleep(1000);$pdo=ae_db();
  try{
    if($x['job']['kind']==='round_cancel')mobile_round_cancel($pdo,ae_row($pdo,$x['id'],$x['prefix']),$x['job']['roundId'],$x['now'],$x['prefix']);
    elseif($x['job']['kind']==='round_finish')mobile_round_finish($pdo,ae_row($pdo,$x['id'],$x['prefix']),['roundId'=>$x['job']['roundId'],'timeMs'=>1000,'runDistance'=>0,'riskCount'=>0,'hadJump'=>false,'hadHelmet'=>false],$x['now'],$x['prefix']);
    else ae_op($pdo,$x['id'],$x['prefix'],$x['job']['kind'],$x['job']['args']??[],$x['now'],$x['job']['key']??null);
    echo json_encode(['ok'=>true]);}
  catch(MobileError $e){echo json_encode(['error'=>$e->getMessage()]);}exit;
}
$pdo=null;$prefix='_ae_'.bin2hex(random_bytes(8)).'_';$GLOBALS['ae_passed']=[];$failure=null;$cleaned=false;$now=2000000000000;
try {
  $pdo=ae_db();ae_check($pdo->query('SELECT DATABASE()')->fetchColumn()==='untouch_friend_invites_tests','Exact disposable database guard');
  ae_check((int)$pdo->query('SELECT @@port')->fetchColumn()===43317,'Loopback test port guard');
  $scores=mobile_table('scores',$prefix);
  $pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day DATE,user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT,risk_count INT,score BIGINT,had_jump TINYINT,had_helmet TINYINT,created_at BIGINT) ENGINE=InnoDB");
  mobile_migrate($pdo,$prefix);mobile_invites_migrate($pdo,$prefix);mobile_energy_migrate_schema($pdo,$prefix);
  $config=mobile_energy_config();$cases=json_decode(file_get_contents(__DIR__.'/../test/fixtures/android_energy_v2_cases.json'),true);
  foreach($cases['migration'] as $c){$w=mobile_energy_migrate_wallet(['lives'=>$c['lives'],'tokens'=>$c['crystals'],'claimed'=>['risks_5'],'unlocked'=>['record_20s'],'jumpUntil'=>999999,'helmetUntil'=>999999,'plusUntil'=>999999],$config,$now);
    ae_check($w['energy']===$c['energy']&&mobile_energy_charge($w['batteries'][0],$now)===$c['charge'],'Migration fixture '.$c['energy']);
    ae_check(mobile_energy_migrate_wallet($w,$config,$now+1000)===$w,'Migration replay keeps state '.$c['energy']);
    ae_check($w['claimed']===['risks_5']&&$w['jumpUntil']===0&&$w['helmetUntil']===0&&$w['plusUntil']===0,'Old claims retained, rentals reset once');}
  $battery=mobile_energy_battery('free',$config,$now);
  foreach($cases['charge'] as $c)ae_check(mobile_energy_charge($battery,$now+$c['elapsedMs'])===$c['units'],'Integer charge boundary '.$c['elapsedMs']);
  $new=ae_player($pdo,$prefix,$now);$id=$new['id'];$w=ae_wallet($pdo,$id,$prefix);
  ae_check($w['energy']===20&&mobile_energy_charge($w['batteries'][0],$now)===20,'New account wallet20 and full20');
  $key=bin2hex(random_bytes(32));$w=ae_op($pdo,$id,$prefix,'energy_claim',[],$now,$key);
  ae_check($w['energy']===40&&mobile_energy_charge($w['batteries'][0],$now)===0,'First claim produces40, resets cycle');
  ae_check(ae_op($pdo,$id,$prefix,'energy_claim',[],$now,$key)['energy']===40,'Lost claim ACK replay no duplicate');
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'energy_claim',[],$now+1);},'charge_empty','Zero claim cannot reset fractional cycle');
  ae_check(ae_wallet($pdo,$id,$prefix)['batteries'][0]['startedAt']===$now,'Zero claim preserved clock');
  $legacy=ae_player($pdo,$prefix,$now,1);$m=mobile_energy_prepare($pdo,$legacy,$now,2,$prefix);$w=mobile_wallet($m,tg_load_economy());
  ae_check($w['energy']===33&&mobile_energy_charge($w['batteries'][0],$now)===20,'Existing wallet7+2*13, no extra wallet gift');
  $GLOBALS['ae_config']['androidEnergyV2']['enabled']=false;$legacy2=ae_player($pdo,$prefix,$now,1);
  ae_check(!mobile_energy_is_v2(mobile_wallet(mobile_energy_prepare($pdo,$legacy2,$now,2,$prefix),tg_load_economy())),'Disabled server does not migrate');
  $GLOBALS['ae_config']['androidEnergyV2']['enabled']=true;
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'daily',[],$now);},'update_required','Migrated wallet refuses fresh legacy mutation');
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'energy_age_completed',['band'=>4],$now);},'age_payload_invalid','Age band rejected');
  ae_op($pdo,$id,$prefix,'energy_age_completed',[],$now);$w=ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'age'],$now);
  ae_check($w['energy']===50,'Age fact then manual10');ae_check(ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'age'],$now)['energy']===50,'Age reward once across IDs');
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'google'],$now);},'bonus_locked','Google cannot be forged');
  $players=mobile_table('mobile_players',$prefix);$pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute(['fixture-google-'.$id,$id]);
  ae_check(ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'google'],$now)['energy']===60,'Verified Google manual10');
  $w=ae_wallet($pdo,$id,$prefix);$w['unlocked']=['survive_10s','record_20s','risks_5'];$w['claimed'][]='risks_5';mobile_wallet_write($pdo,$id,$w,$prefix);
  ae_check(ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'risks_5'],$now)['energy']===60,'Historical achievement remains claimed');
  ae_check(ae_op($pdo,$id,$prefix,'energy_reward',['id'=>'survive_10s'],$now)['energy']===70,'Achievement10');
  ae_check(ae_op($pdo,$id,$prefix,'watch_ad',[],$now)['energy']===90,'Ad20');
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'watch_ad',[],$now+59999);},'ad_not_ready','Ad cooldown preserved');
  ae_error(function()use($pdo,$id,$prefix,$now){ae_op($pdo,$id,$prefix,'energy_feedback',['comment'=>str_repeat('a',19)],$now);},'feedback_length','Feedback minimum20 codepoints');
  $w=ae_op($pdo,$id,$prefix,'energy_feedback',['comment'=>'  '.str_repeat('🙂',20).'  ','rating'=>1],$now);
  ae_check($w['energy']===110,'Feedback low rating receives20');ae_check(ae_op($pdo,$id,$prefix,'energy_feedback',['comment'=>str_repeat('b',20),'rating'=>5],$now)['energy']===110,'Feedback first grant once');
  $table=mobile_energy_feedback_table($prefix);ae_check($pdo->query("SELECT COUNT(*) FROM $table")->fetchColumn()==1,'Feedback and outbox persisted atomically');
  ae_check(mobile_energy_deliver_feedback($pdo,function(){return false;},$now,$prefix)===0,'Failed mail delivery stays retryable');
  $sent=[];ae_check(mobile_energy_deliver_feedback($pdo,function($to,$subject,$body)use(&$sent){$sent[]=[$to,$body];return true;},$now+1000,$prefix)===1,'Mock sink delivered retry');
  ae_check(count($sent)===1&&$sent[0][0]==='support@untouch.fun'&&ae_wallet($pdo,$id,$prefix)['energy']===110,'Retry email never regrants energy');
  ae_check(mobile_energy_deliver_feedback($pdo,function(){throw new Exception('must not deliver twice');},$now+2000,$prefix)===0,'Delivered outbox not retried');
  $feedbackRace=ae_player($pdo,$prefix,$now);$out=ae_workers($prefix,$feedbackRace['id'],[
    ['kind'=>'energy_feedback','args'=>['comment'=>str_repeat('x',20),'rating'=>1]],['kind'=>'energy_feedback','args'=>['comment'=>str_repeat('y',20),'rating'=>5]]],$now);
  ae_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===2&&ae_wallet($pdo,$feedbackRace['id'],$prefix)['energy']===40,'Concurrent feedback two ACKs one20 grant');
  foreach($cases['attempts'] as $c){$before=ae_wallet($pdo,$id,$prefix)['energy'];$rid=bin2hex(random_bytes(32));$opts=['currentRevision'=>'r1','economyVersion'=>2,'helmet'=>$c['helmet'],'jump'=>$c['jump']];
    $start=mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now,$prefix,$rid,'r1',$opts);ae_check($start['attemptCost']===$c['cost']&&$start['profile']['wallet']['energy']===$before-$c['cost'],'Attempt cost '.$c['cost']);
    $opts['currentRevision']='r2';ae_check(mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now,$prefix,$rid,'r1',$opts)['profile']['wallet']['energy']===$before-$c['cost'],'Accepted replay before current revision');
    mobile_round_cancel($pdo,ae_row($pdo,$id,$prefix),$rid,$now+1,$prefix);ae_check(ae_wallet($pdo,$id,$prefix)['energy']===$before,'Guard cancel refunds exact snapshot');
    mobile_round_cancel($pdo,ae_row($pdo,$id,$prefix),$rid,$now+2,$prefix);ae_check(ae_wallet($pdo,$id,$prefix)['energy']===$before,'Cancel replay no second refund');
    ae_error(function()use($pdo,$id,$prefix,$rid,$now){mobile_round_finish($pdo,ae_row($pdo,$id,$prefix),['roundId'=>$rid],$now+1000,$prefix);},'round_canceled','Canceled round cannot finish');}
  ae_check(mobile_invites_completed_games($pdo,$id,$prefix)===0,'Canceled starts never qualify invitation');
  $rid=bin2hex(random_bytes(32));mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now,$prefix,$rid,'r1',['economyVersion'=>2]);mobile_round_activate($pdo,ae_row($pdo,$id,$prefix),$rid,$now+1,$prefix);
  ae_check(mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now+2,$prefix,$rid,'r1',['economyVersion'=>2])['activated']===true,'Durable replay reports already activated run');
  ae_error(function()use($pdo,$id,$prefix,$rid,$now){mobile_round_cancel($pdo,ae_row($pdo,$id,$prefix),$rid,$now+2,$prefix);},'round_already_started','Activated run cannot be refunded');
  $before=ae_wallet($pdo,$id,$prefix)['energy'];$result=mobile_round_finish($pdo,ae_row($pdo,$id,$prefix),['roundId'=>$rid,'timeMs'=>1000,'runDistance'=>400,'riskCount'=>5,'hadJump'=>false,'hadHelmet'=>false],$now+1001,$prefix);
  ae_check($result['energyReward']===3&&ae_wallet($pdo,$id,$prefix)['energy']===$before+3,'Run/risk events pay1 each, thresholds unchanged');
  ae_check(mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now+1002,$prefix,$rid,'r1',['economyVersion'=>2])['finished']===true,'Durable replay reports finished run');
  ae_error(function()use($pdo,$id,$prefix,$now){mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now,$prefix,null,'r1',['economyVersion'=>1]);},'update_required','Old client cannot start migrated wallet');
  $late=bin2hex(random_bytes(32));mobile_round_start($pdo,ae_row($pdo,$id,$prefix),$now,$prefix,$late,'r1',['economyVersion'=>2]);
  ae_error(function()use($pdo,$id,$prefix,$late,$now){mobile_round_cancel($pdo,ae_row($pdo,$id,$prefix),$late,$now+5001,$prefix);},'round_cancel_expired','Cancel refund has bounded5s window');
  $oldRoundOwner=ae_player($pdo,$prefix,$now,1);$oldRound=mobile_round_start($pdo,$oldRoundOwner,$now,$prefix)['roundId'];
  mobile_energy_prepare($pdo,ae_row($pdo,$oldRoundOwner['id'],$prefix),$now+1,2,$prefix);$before=ae_wallet($pdo,$oldRoundOwner['id'],$prefix)['energy'];
  $oldResult=mobile_round_finish($pdo,ae_row($pdo,$oldRoundOwner['id'],$prefix),['roundId'=>$oldRound,'timeMs'=>1000,'runDistance'=>200,'riskCount'=>5,'hadJump'=>false,'hadHelmet'=>false],$now+1100,$prefix);
  ae_check($oldResult['energyReward']===4&&ae_wallet($pdo,$oldRoundOwner['id'],$prefix)['energy']===$before+4,'Accepted legacy run keeps old snapshot at migration2x');
  $race=ae_player($pdo,$prefix,$now);$out=ae_workers($prefix,$race['id'],[['kind'=>'energy_claim'],['kind'=>'energy_claim']],$now);
  ae_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===1&&ae_wallet($pdo,$race['id'],$prefix)['energy']===40,'Concurrent claims across IDs one winner');
  $race2=ae_player($pdo,$prefix,$now);$sameKey=bin2hex(random_bytes(32));$out=ae_workers($prefix,$race2['id'],[['kind'=>'energy_claim','key'=>$sameKey],['kind'=>'energy_claim','key'=>$sameKey]],$now);
  ae_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===2&&ae_wallet($pdo,$race2['id'],$prefix)['energy']===40,'Concurrent same receipt two ACKs one credit');
  $roundRace=ae_player($pdo,$prefix,$now);$raceId=bin2hex(random_bytes(32));mobile_round_start($pdo,$roundRace,$now,$prefix,$raceId,'r1',['economyVersion'=>2]);
  $out=ae_workers($prefix,$roundRace['id'],[['kind'=>'round_cancel','roundId'=>$raceId],['kind'=>'round_finish','roundId'=>$raceId]],$now+1100);
  ae_check(count(array_filter($out,function($x){return !empty($x['ok']);}))===1,'Concurrent cancel/finish has one winning outcome');
  $rounds=mobile_table('mobile_rounds',$prefix);$q=$pdo->prepare("SELECT result_json FROM $rounds WHERE id=?");$q->execute([$raceId]);$outcome=json_decode($q->fetchColumn(),true);
  ae_check(ae_wallet($pdo,$roundRace['id'],$prefix)['energy']===(!empty($outcome['canceled'])?20:19),'Cancel/finish race balance matches sole outcome');
  $sub=ae_player($pdo,$prefix,$now);$sid=$sub['id'];$sku='energy_batteries_2_v1';$product=mobile_energy_product($sku);$expiry=$now+7*86400000;
  $ent=['expiresAt'=>$expiry,'startedAt'=>$now,'periodId'=>'order1','linkedTokenHash'=>null];
  mobile_play_apply($pdo,$sub,'synthetic-token-one',$sku,$product,1,$expiry,'{}',$now,$prefix,0,$ent);$w=ae_wallet($pdo,$sid,$prefix);
  ae_check(count($w['batteries'])===2&&mobile_energy_charge($w['batteries'][0],$now)===20&&mobile_energy_charge($w['batteries'][1],$now)===0,'Subscribe adds one empty, preserves free full');
  $ent2=['expiresAt'=>$expiry,'startedAt'=>$now+1000,'periodId'=>'order2','linkedTokenHash'=>hash('sha256','synthetic-token-one')];
  mobile_play_apply($pdo,ae_row($pdo,$sid,$prefix),'synthetic-token-two','energy_batteries_5_v1',mobile_energy_product('energy_batteries_5_v1'),1,$expiry,'{}',$now+1000,$prefix,0,$ent2);$w=ae_wallet($pdo,$sid,$prefix);
  ae_check(count($w['batteries'])===5&&$w['batteries'][1]['startedAt']===$now&&$w['batteries'][4]['startedAt']===$now+1000,'2to5 adds three, keeps old cycles');
  $oldPeriod=['expiresAt'=>$expiry-1000,'startedAt'=>$now,'periodId'=>'older-order','linkedTokenHash'=>null];
  mobile_play_apply($pdo,ae_row($pdo,$sid,$prefix),'synthetic-token-two','energy_batteries_5_v1',mobile_energy_product('energy_batteries_5_v1'),1,$expiry-1000,'{}',$now+1500,$prefix,0,$oldPeriod);
  ae_check(ae_wallet($pdo,$sid,$prefix)['energySubscription']['periodId']==='order2','Older period cannot shorten newer validated same-token period');
  mobile_play_apply($pdo,ae_row($pdo,$sid,$prefix),'synthetic-token-one',$sku,$product,1,0,'{}',$now+2000,$prefix,0,['expiresAt'=>$now+2000,'startedAt'=>$now,'periodId'=>'order1','linkedTokenHash'=>null]);
  ae_check(count(ae_wallet($pdo,$sid,$prefix)['batteries'])===5,'Old RTDN cannot disable replacement');
  $adBefore=ae_wallet($pdo,$sid,$prefix)['energy'];ae_check(ae_op($pdo,$sid,$prefix,'watch_ad',[],$now)['energy']===$adBefore+20,'Subscription allows voluntary rewarded ad');
  $GLOBALS['ae_config']['androidEnergyV2']['batteryCapacity']=40;$GLOBALS['ae_config']['androidEnergyV2']['chargeHours']=6;
  $w=ae_op($pdo,$sid,$prefix,'energy_claim',[],$now+43200000);
  ae_check($w['batteries'][0]['capacity']===40&&$w['batteries'][0]['durationMs']===21600000&&$w['batteries'][1]['capacity']===20&&$w['batteries'][1]['durationMs']===43200000,'Claim uses new free terms, paid period snapshot');
  $ent3=['expiresAt'=>$expiry+86400000,'startedAt'=>$now+43200000,'periodId'=>'order3','linkedTokenHash'=>hash('sha256','synthetic-token-two')];
  $before=$w['energy'];$kept=$w['batteries'][1];
  mobile_play_apply($pdo,ae_row($pdo,$sid,$prefix),'synthetic-token-three',$sku,$product,1,$ent3['expiresAt'],'{}',$now+43200000+4320000,$prefix,0,$ent3);$w=ae_wallet($pdo,$sid,$prefix);
  ae_check(count($w['batteries'])===2&&$w['batteries'][1]===$kept&&$w['energy']===$before+6,'Validated5to2 settles3 slots of2, preserves remaining cycles');
  $exp=ae_player($pdo,$prefix,$now);$eid=$exp['id'];$w=ae_wallet($pdo,$eid,$prefix);$w['batteries']=[];
  $cfg=mobile_energy_defaults();for($i=0;$i<5;$i++){$b=mobile_energy_battery('slot'.$i,$cfg,$now);$b['initialUnits']=$i===0?6:2;$w['batteries'][]=$b;}
  $w['energySubscription']=['expiresAt'=>$now,'periodId'=>'expiry','endConfirmed'=>true];mobile_wallet_write($pdo,$eid,$w,$prefix);
  mobile_energy_prepare($pdo,ae_row($pdo,$eid,$prefix),$now+86400000,2,$prefix);$w=ae_wallet($pdo,$eid,$prefix);
  ae_check($w['energy']===28&&count($w['batteries'])===1&&$w['batteries'][0]['initialUnits']===6,'Delayed resume settles only disconnected through expiry');
  mobile_energy_prepare($pdo,ae_row($pdo,$eid,$prefix),$now+172800000,2,$prefix);ae_check(ae_wallet($pdo,$eid,$prefix)['energy']===28,'Expiry settlement once');
  $pack=ae_player($pdo,$prefix,$now);$pid=$pack['id'];$p=mobile_energy_product('energy_100_v1');
  mobile_play_apply($pdo,$pack,'synthetic-pack-token','energy_100_v1',$p,1,0,'{}',$now,$prefix);mobile_play_apply($pdo,ae_row($pdo,$pid,$prefix),'synthetic-pack-token','energy_100_v1',$p,1,0,'{}',$now,$prefix);
  ae_check(ae_wallet($pdo,$pid,$prefix)['energy']===120,'Immutable package receipt grants once');
  mobile_play_apply($pdo,ae_row($pdo,$pid,$prefix),'synthetic-pack-token','energy_100_v1',$p,1,0,'{}',$now,$prefix,1);mobile_play_apply($pdo,ae_row($pdo,$pid,$prefix),'synthetic-pack-token','energy_100_v1',$p,1,0,'{}',$now,$prefix,1);
  ae_check(ae_wallet($pdo,$pid,$prefix)['energy']===20,'Cumulative refund once');
  $data=['externalAccountIdentifiers'=>['obfuscatedExternalAccountId'=>hash('sha256','android:'.$sid)],'startTime'=>gmdate('c',(int)($now/1000)),
    'subscriptionState'=>'SUBSCRIPTION_STATE_ACTIVE','lineItems'=>[['productId'=>$sku,'expiryTime'=>gmdate('c',(int)($expiry/1000)),'offerDetails'=>['basePlanId'=>'wrong']]]];
  ae_error(function()use($data,$sid,$sku,$product,$now){mobile_play_energy_subscription($data,'android:'.$sid,$sku,$product,$now);},'subscription_plan_invalid','Verified base plan cannot be swapped');
  ae_check(mobile_energy_product('energy_100_v1')['amount']===100&&mobile_energy_product('energy_101_v1')===null,'Unknown/unprepared SKU refused');
  $quoteId=bin2hex(random_bytes(32));$quote=mobile_energy_quote($pdo,ae_row($pdo,$pid,$prefix),'energy_100_v1',$quoteId,$now,$prefix);
  $GLOBALS['ae_config']['androidEnergyV2']['revision']='r-new';$quoteReplay=mobile_energy_quote($pdo,ae_row($pdo,$pid,$prefix),'energy_100_v1',$quoteId,$now+1,$prefix);
  ae_check($quoteReplay===$quote&&$quote['terms']['amount']===100,'Prepayment quote receipt preserves immutable terms/revision');
  $inviteHost=ae_player($pdo,$prefix,$now,1);$inviteGuest=ae_player($pdo,$prefix,$now,1);
  foreach([$inviteHost,$inviteGuest] as $who)$pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute(['invite-google-'.$who['id'],$who['id']]);
  ae_history($pdo,$inviteGuest['id'],$prefix,$now);$code=mobile_invites_own_code($pdo,$inviteHost['id'],$now,$prefix);mobile_invites_bind($pdo,$inviteGuest['id'],$code,'manual',$now,$prefix);mobile_invites_reconcile($pdo,$inviteGuest['id'],$now,$prefix);
  mobile_energy_prepare($pdo,ae_row($pdo,$inviteHost['id'],$prefix),$now+1,2,$prefix);$history=mobile_invites_paid_list($pdo,$inviteHost['id'],null,50,$prefix);
  ae_check($history['rewardTotal']===20&&$history['paidRows'][0]['originalAmount']===10&&$history['paidRows'][0]['originalCurrency']==='crystals'&&$history['paidRows'][0]['energyEquivalent']===20,'Old invite ledger raw10crystals displays20energy');
  $inviteGuest2=ae_player($pdo,$prefix,$now);$pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute(['invite-google-'.$inviteGuest2['id'],$inviteGuest2['id']]);ae_history($pdo,$inviteGuest2['id'],$prefix,$now);
  $beforeHost=ae_wallet($pdo,$inviteHost['id'],$prefix)['energy'];mobile_invites_bind($pdo,$inviteGuest2['id'],$code,'manual',$now+2,$prefix);mobile_invites_reconcile($pdo,$inviteGuest2['id'],$now+2,$prefix);
  $history=mobile_invites_paid_list($pdo,$inviteHost['id'],null,50,$prefix);
  ae_check($history['rewardTotal']===40&&ae_wallet($pdo,$inviteHost['id'],$prefix)['energy']===$beforeHost+20&&ae_wallet($pdo,$inviteGuest2['id'],$prefix)['energy']===40,'New invite both sides20, mixed history sums energy');
  $GLOBALS['ae_config']['androidEnergyV2']['rewards']['invite']=30;$history2=mobile_invites_paid_list($pdo,$inviteHost['id'],null,50,$prefix);
  ae_check($history2['reward']===30&&$history2['rewardTotal']===40,'Remote future invite reward leaves history unchanged');
  $boundary=$now+7*86400000;$hour=3600000;$cfg=mobile_energy_defaults();
  foreach([false,true] as $profileFirst) {
    $renew=ae_player($pdo,$prefix,$now);$renewId=$renew['id'];$renewToken='renew-proof-'.($profileFirst?'profile':'direct');
    $old=['expiresAt'=>$boundary,'startedAt'=>$now,'periodId'=>'period1','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
    mobile_play_apply($pdo,$renew,$renewToken,$sku,$product,1,$boundary,'{}',$now,$prefix,0,$old);
    ae_op($pdo,$renewId,$prefix,'energy_claim',[],$boundary-$hour);$before=ae_wallet($pdo,$renewId,$prefix);$cycleStart=$before['batteries'][1]['startedAt'];
    if($profileFirst) {
      mobile_energy_prepare($pdo,ae_row($pdo,$renewId,$prefix),$boundary+$hour,2,$prefix);$pending=ae_wallet($pdo,$renewId,$prefix);
      ae_check(!empty($pending['energySubscription']['awaitingReconciliation'])&&$pending['energy']===$before['energy']&&count($pending['batteries'])===2,'Known renewal boundary freezes without credit/removing paid cycle');
      ae_error(function()use($pdo,$renewId,$prefix,$boundary,$hour){ae_op($pdo,$renewId,$prefix,'energy_claim',[],$boundary+$hour);},'subscription_verification_pending','Pending reconciliation blocks whole charge claim');
      ae_error(function()use($pdo,$renewId,$prefix,$boundary,$hour){mobile_energy_quote($pdo,ae_row($pdo,$renewId,$prefix),'energy_batteries_5_v1',bin2hex(random_bytes(32)),$boundary+$hour,$prefix);},'subscription_verification_pending','Pending reconciliation blocks new subscription checkout');
    }
    $next=['expiresAt'=>$boundary+7*86400000,'startedAt'=>$now,'periodId'=>'period2','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
    mobile_play_apply($pdo,ae_row($pdo,$renewId,$prefix),$renewToken,$sku,$product,1,$next['expiresAt'],'{}',$boundary+$hour,$prefix,0,$next);$after=ae_wallet($pdo,$renewId,$prefix);
    ae_check($after['batteries'][1]['startedAt']===$cycleStart&&mobile_energy_charge($after['batteries'][1],$boundary+$hour)===3&&$after['energy']===$before['energy'],'Continuous same-token renewal retains2h charge and original cycle'.($profileFirst?' after pending profile':''));
    ae_check(empty($after['energySubscription']['awaitingReconciliation']),'Verified renewal clears pending state');
  }
  $ended=ae_player($pdo,$prefix,$now);$endedId=$ended['id'];$endToken='true-end-proof';
  $ent=['expiresAt'=>$boundary,'startedAt'=>$now,'periodId'=>'ending-period','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
  mobile_play_apply($pdo,$ended,$endToken,$sku,$product,1,$boundary,'{}',$now,$prefix,0,$ent);ae_op($pdo,$endedId,$prefix,'energy_claim',[],$boundary-$hour);$before=ae_wallet($pdo,$endedId,$prefix)['energy'];
  mobile_energy_prepare($pdo,ae_row($pdo,$endedId,$prefix),$boundary+$hour,2,$prefix);
  $endEnt=$ent;$endEnt['state']='SUBSCRIPTION_STATE_EXPIRED';$endEnt['endConfirmed']=true;
  for($i=0;$i<2;$i++)mobile_play_apply($pdo,ae_row($pdo,$endedId,$prefix),$endToken,$sku,$product,1,$boundary,'{}',$boundary+$hour,$prefix,0,$endEnt);
  $after=ae_wallet($pdo,$endedId,$prefix);ae_check($after['energy']===$before+1&&count($after['batteries'])===1&&$after['energySubscription']===null,'Verified actual end settles only through end once after pending');
  $gap=ae_player($pdo,$prefix,$now);$gapId=$gap['id'];$gapToken='gap-old-proof';
  mobile_play_apply($pdo,$gap,$gapToken,$sku,$product,1,$boundary,'{}',$now,$prefix,0,$ent);ae_op($pdo,$gapId,$prefix,'energy_claim',[],$boundary-$hour);$before=ae_wallet($pdo,$gapId,$prefix)['energy'];
  mobile_energy_prepare($pdo,ae_row($pdo,$gapId,$prefix),$boundary+$hour,2,$prefix);
  $gapEnt=['expiresAt'=>$boundary+7*86400000,'startedAt'=>$boundary+1800000,'periodId'=>'gap-new','linkedTokenHash'=>hash('sha256',$gapToken),'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
  mobile_play_apply($pdo,ae_row($pdo,$gapId,$prefix),'gap-new-proof',$sku,$product,1,$gapEnt['expiresAt'],'{}',$boundary+$hour,$prefix,0,$gapEnt);$after=ae_wallet($pdo,$gapId,$prefix);
  ae_check($after['energy']===$before+1&&$after['batteries'][1]['startedAt']===$boundary+$hour&&mobile_energy_charge($after['batteries'][1],$boundary+$hour)===0,'Validated real gap settles old charge then starts empty new slots');
  $published=gameplay_defaults();ae_check(gameplay_validate($published)===[],'Admin full defaults pass server validator');
  $bad=$published;$bad['economy']['androidEnergyV2']['packages'][0]['energy']=101;
  ae_check(isset(gameplay_validate($bad)['economy.androidEnergyV2.packages.0.productId']),'Admin refuses changed amount on immutable SKU');
  $bad=$published;$bad['economy']['androidEnergyV2']['subscriptions'][0]['capacity']=40;
  ae_check(isset(gameplay_validate($bad)['economy.androidEnergyV2.subscriptions.0.productId']),'Admin refuses paid capacity redefinition on same SKU');
  $bad=$published;$bad['economy']['androidEnergyV2']['batteryCapacity']=0;
  ae_check(isset(gameplay_validate($bad)['economy.androidEnergyV2.batteryCapacity']),'Admin refuses zero free capacity');
  $bad=$published;$bad['economy']['androidEnergyV2']['packages'][0]['productId']='energy_101_v2';
  ae_check(isset(gameplay_validate($bad)['economy.androidEnergyV2.packages.0.productId']),'Admin refuses unprepared remote SKU');
}catch(Throwable $e){$failure=get_class($e).': '.$e->getMessage();}
finally {
  if($pdo){try{if($pdo->inTransaction())$pdo->rollBack();$pdo->exec('DROP TABLE IF EXISTS '.mobile_energy_feedback_table($prefix));
    foreach(['mobile_invite_ledger','mobile_invites','mobile_invite_codes'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_invite_table($name,$prefix));
    foreach(['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($name,$prefix));
    $q=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$q->execute([strlen($prefix),$prefix]);$cleaned=(int)$q->fetchColumn()===0;
  }catch(Throwable $e){$failure=($failure??'').'; cleanup '.get_class($e);}}
}
echo json_encode(['ok'=>$failure===null&&$cleaned,'checks'=>count($GLOBALS['ae_passed']),'passed'=>$GLOBALS['ae_passed'],'cleaned'=>$cleaned,'failure'=>$failure],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
exit($failure===null&&$cleaned?0:1);
