<?php
// Disposable local fixtures only. No live config/accounts/Google/network.
if(PHP_SAPI!=='cli')exit(2);
function tg_load_economy(){return $GLOBALS['sb_config'];}
function tg_local_gameplay_config(){return ['game'=>['jumpEnabled'=>true,'helmetEnabled'=>true,'wallsKillPlayer'=>false]];}
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
require_once __DIR__.'/../telegram-web/api/mobile_invites.php';
require_once __DIR__.'/../telegram-web/api/mobile_play.php';
$GLOBALS['sb_config']=['initialLives'=>7,'initialTokens'=>13,'runRewardEvery'=>200,'runRewardTokens'=>1,'riskRewardEvery'=>5,'riskRewardTokens'=>1,'androidEnergyV2'=>mobile_energy_defaults()];
$GLOBALS['sb_config']['androidEnergyV2']['enabled']=true;
$GLOBALS['sb_config']['androidEnergyV2']['simpleBonus']=array_replace(mobile_bonus_defaults(),['enabled'=>true]);
function sb_db(){return new PDO('mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4','root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);}
function sb_check($ok,$name){if(!$ok)throw new RuntimeException($name);$GLOBALS['checks'][]=$name;}
function sb_row($pdo,$id,$p){$q=$pdo->prepare('SELECT * FROM '.mobile_table('mobile_players',$p).' WHERE id=?');$q->execute([$id]);return $q->fetch();}
function sb_wallet($pdo,$id,$p){return mobile_wallet(sb_row($pdo,$id,$p),tg_load_economy());}
function sb_op($pdo,$id,$p,$now,$kind='energy_bonus_claim',$key=null){return mobile_wallet_mutate($pdo,sb_row($pdo,$id,$p),$key??bin2hex(random_bytes(32)),$kind,[],$now,tg_load_economy(),$p)['wallet'];}
function sb_error($action,$code,$name){try{$action();}catch(MobileError $e){sb_check($e->getMessage()===$code,$name);return;}throw new RuntimeException('Expected rejection '.$name);}
function sb_player($pdo,$p,$now,$version=3){$secret=bin2hex(random_bytes(32));mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$p,180,$version);return mobile_auth($pdo,$secret,$p)['id'];}
$args=getopt('',['worker:']);
if(isset($args['worker'])){
  $x=json_decode(base64_decode($args['worker']),true);if(!preg_match('/^_sb_[a-f0-9]{16}_$/D',$x['prefix']))exit(2);
  while(microtime(true)<$x['at'])usleep(1000);
  try{sb_op(sb_db(),$x['id'],$x['prefix'],$x['now'],'energy_bonus_claim',$x['key']);echo 'ok';}catch(MobileError $e){echo $e->getMessage();}exit;
}
$prefix='_sb_'.bin2hex(random_bytes(8)).'_';$pdo=null;$failure=null;$cleaned=false;$GLOBALS['checks']=[];$now=2000000000000;
try{
  $pdo=sb_db();sb_check($pdo->query('SELECT DATABASE()')->fetchColumn()==='untouch_friend_invites_tests'&&(int)$pdo->query('SELECT @@port')->fetchColumn()===43317,'Isolated database/port guard');
  $scores=mobile_table('scores',$prefix);$pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day DATE,user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT,risk_count INT,score BIGINT,had_jump TINYINT,had_helmet TINYINT,created_at BIGINT) ENGINE=InnoDB");
  mobile_migrate($pdo,$prefix);mobile_invites_migrate($pdo,$prefix);mobile_energy_migrate_schema($pdo,$prefix);
  $id=sb_player($pdo,$prefix,$now);$w=sb_wallet($pdo,$id,$prefix);
  sb_check($w['energy']===50&&mobile_bonus_is_active($w)&&$w['simpleBonus']['nextAt']===0,'New player50 once, ready bonus');
  mobile_energy_prepare($pdo,sb_row($pdo,$id,$prefix),$now,3,$prefix);sb_check(sb_wallet($pdo,$id,$prefix)['energy']===50,'Repeat profile cannot grant startup again');
  $key=bin2hex(random_bytes(32));$w=sb_op($pdo,$id,$prefix,$now,'energy_bonus_claim',$key);
  sb_check($w['energy']===80&&$w['simpleBonus']['nextAt']===$now+28800000,'Claim30 and exact8h');
  sb_check(sb_op($pdo,$id,$prefix,$now+28800000,'energy_bonus_claim',$key)['energy']===80,'Lost response replay after8h still no second reward');
  sb_error(fn()=>sb_op($pdo,$id,$prefix,$now+28799999),'bonus_not_ready','One millisecond before boundary rejects');
  sb_error(fn()=>sb_op($pdo,$id,$prefix,$now-86400000),'bonus_not_ready','Client clock/backwards server test cannot bypass');
  sb_check(sb_op($pdo,$id,$prefix,$now+28800000)['energy']===110,'Exact8h boundary succeeds');
  sb_check(sb_op($pdo,$id,$prefix,$now+28800000*10)['energy']===140,'Missed cycles do not stack');
  sb_error(fn()=>sb_op($pdo,$id,$prefix,$now+28800000*20,'energy_claim'),'update_required','Old partial claim cannot duplicate new bonus');
  // Race independent operation IDs and exact duplicate ID in separate processes.
  foreach([false,true] as $duplicate){
    $race=sb_player($pdo,$prefix,$now);$at=microtime(true)+.5;$jobs=[];$key=bin2hex(random_bytes(32));
    for($i=0;$i<2;$i++){$payload=base64_encode(json_encode(['prefix'=>$prefix,'id'=>$race,'now'=>$now,'at'=>$at,'key'=>$duplicate?$key:bin2hex(random_bytes(32))]));$proc=proc_open([PHP_BINARY,__FILE__,'--worker='.$payload],[1=>['pipe','w'],2=>['pipe','w']],$pipes);$jobs[]=[$proc,$pipes];}
    $results=[];foreach($jobs as [$proc,$pipes]){$results[]=stream_get_contents($pipes[1]);$err=stream_get_contents($pipes[2]);foreach($pipes as $pipe)fclose($pipe);sb_check(proc_close($proc)===0,'Race worker exit');}
    sb_check(sb_wallet($pdo,$race,$prefix)['energy']===80,'Race credits once '.($duplicate?'sameId':'differentIds'));
    sb_check($duplicate?$results===['ok','ok']:count(array_filter($results,fn($s)=>$s==='ok'))===1,'Race responses consistent');
  }
  $hidden=sb_player($pdo,$prefix,$now);$hk=bin2hex(random_bytes(32));
  sb_check(sb_op($pdo,$hidden,$prefix,$now,'energy_hidden_tap',$hk)['energy']===70,'Hidden gesture grants20');
  sb_check(sb_op($pdo,$hidden,$prefix,$now+1,'energy_hidden_tap',$hk)['energy']===70,'Hidden retry cannot credit twice');
  sb_check(sb_op($pdo,$hidden,$prefix,$now+2,'energy_hidden_tap')['energy']===90,'Fresh hidden series grants next20');
  sb_error(fn()=>sb_op($pdo,$hidden,$prefix,$now+3,'energy_bonus_claim',$hk),'operation_conflict','Hidden receipt cannot authorize another kind');
  $other=sb_player($pdo,$prefix,$now);
  sb_error(fn()=>sb_op($pdo,$other,$prefix,$now+3,'energy_hidden_tap',$hk),'operation_conflict','Hidden receipt belongs to one owner');
  foreach(['energy_test_grant','beta_free_crystals'] as $retired)sb_error(fn()=>sb_op($pdo,$hidden,$prefix,$now+4,$retired),'operation_invalid','Removed credit rejected '.$retired);
  sb_error(fn()=>mobile_wallet_mutate($pdo,sb_row($pdo,$hidden,$prefix),bin2hex(random_bytes(32)),'energy_hidden_tap',['amount'=>9999],$now,tg_load_economy(),$prefix),'operation_invalid','Client cannot choose hidden amount');
  $legacy=sb_player($pdo,$prefix,$now,2);$w=sb_wallet($pdo,$legacy,$prefix);$w['energy']=1234;$w['batteries']=[mobile_energy_battery('free',mobile_energy_config(),$now-1000000)];mobile_wallet_write($pdo,$legacy,$w,$prefix);
  $row=mobile_energy_prepare($pdo,sb_row($pdo,$legacy,$prefix),$now,3,$prefix);$w=mobile_wallet($row,tg_load_economy());
  sb_check($w['energy']===1235&&$w['simpleBonusMigration']['settled']===1,'Migration preserves fractional accrued unit by rounding up once');
  mobile_energy_prepare($pdo,sb_row($pdo,$legacy,$prefix),$now+10000,3,$prefix);sb_check(sb_wallet($pdo,$legacy,$prefix)['energy']===1235,'Migration idempotent');
  $tier=sb_player($pdo,$prefix,$now);$w=sb_wallet($pdo,$tier,$prefix);$w['energySubscription']=['batteryCount'=>5,'expiresAt'=>$now+86400000,'periodId'=>'fixture','capacity'=>20,'durationMs'=>28800000];mobile_wallet_write($pdo,$tier,$w,$prefix);
  $w=sb_op($pdo,$tier,$prefix,$now);sb_check($w['energy']===200,'Verified tier5 bonus150');$next=$w['simpleBonus']['nextAt'];
  mobile_energy_transition($w,2,$now+1000,'tier2',mobile_energy_config(),$now+1000);$w['energySubscription']['batteryCount']=2;mobile_wallet_write($pdo,$tier,$w,$prefix);
  sb_check($w['simpleBonus']['nextAt']===$next&&$w['batteries']===[],'Tier switch preserves timer and cannot recreate batteries');
  $w=sb_op($pdo,$tier,$prefix,$now+1,'watch_ad');sb_check($w['energy']===240,'Subscribed rewarded video40 accepted');
  sb_error(fn()=>sb_op($pdo,$tier,$prefix,$now+120000,'watch_ad'),'ad_not_ready','Video one millisecond before120s rejects');
  $w=sb_op($pdo,$tier,$prefix,$now+120001,'watch_ad');sb_check($w['energy']===280,'Video boundary120s succeeds');
  $w=sb_op($pdo,$tier,$prefix,$next);sb_check($w['energy']===340,'Tier2 gives60 on same button');
  $GLOBALS['sb_config']['androidEnergyV2']['simpleBonus']['periodSec']=3600;
  sb_check($w['simpleBonus']['durationMs']===28800000,'Policy change does not shorten existing period');
  $w=sb_op($pdo,$tier,$prefix,$next+28800000);sb_check($w['simpleBonus']['durationMs']===3600000,'New policy duration applies next successful claim');
  sb_check(mobile_bonus_validation_error(['periodSec'=>-1])!==null&&mobile_bonus_validation_error(['tier2Reward'=>'40'])!==null,'Policy rejects invalid numeric inputs');
  // The actual invitation transaction still requires five finished games and
  // both Google identities. Only the inviter's new reward changes to60.
  $host=sb_player($pdo,$prefix,$now);$friend=sb_player($pdo,$prefix,$now);$players=mobile_table('mobile_players',$prefix);
  $pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute(['fixture-host-'.$host,$host]);
  $code=mobile_invites_own_code($pdo,$host,$now,$prefix);mobile_invites_bind($pdo,$friend,$code,'manual',$now,$prefix);
  $rounds=mobile_table('mobile_rounds',$prefix);$insert=$pdo->prepare("INSERT INTO $rounds (id,player_id,started_at,finished_at,result_json,context_json) VALUES (?,?,?,?,?,?)");
  for($i=0;$i<4;$i++)$insert->execute([bin2hex(random_bytes(32)),$friend,$now,$now+1000,'{"ok":true}','{}']);
  sb_check(mobile_invites_reconcile($pdo,$host,$now,$prefix)===0,'Four games do not pay referral');
  $insert->execute([bin2hex(random_bytes(32)),$friend,$now,$now+1000,'{"canceled":true}','{}']);
  $state=mobile_invites_paid_list($pdo,$host,null,50,$prefix);sb_check($state['pendingRows'][0]['games']===4,'Canceled attempt excluded from visible friend progress');
  $insert->execute([bin2hex(random_bytes(32)),$friend,$now,$now+1000,'{"ok":true}','{}']);
  sb_check(mobile_invites_reconcile($pdo,$host,$now,$prefix)===0,'Five games without both Google identities do not pay');
  $pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute(['fixture-friend-'.$friend,$friend]);
  sb_check(mobile_invites_reconcile($pdo,$host,$now,$prefix)===1,'Fifth game and both Google identities unlock actual transaction');
  sb_check(sb_wallet($pdo,$host,$prefix)['energy']===110&&sb_wallet($pdo,$friend,$prefix)['energy']===70,'Inviter60, invitee existing20 retained');
  sb_check(mobile_invites_reconcile($pdo,$host,$now+1,$prefix)===0&&sb_wallet($pdo,$host,$prefix)['energy']===110,'Referral60 cannot repeat');
  // Feed the same Google-shaped DEFERRED fixture through production
  // normalization and purchase application against a contract3 wallet.
  $f=json_decode(file_get_contents(__DIR__.'/../test/fixtures/google_play_deferred_replacement.json'),true);$tn=$f['nowMs'];$end=$f['cutoverMs'];$late=$f['afterMs'];
  $paid=sb_player($pdo,$prefix,$tn-1000);$sku='energy_batteries_5_v1';$target='energy_batteries_2_v1';$old='simple-old-'.$paid;$token='simple-replacement-'.$paid;
  $initial=['expiresAt'=>$end,'startedAt'=>$tn-1000,'periodId'=>'simple-old','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
  mobile_play_apply($pdo,sb_row($pdo,$paid,$prefix),$old,$sku,mobile_energy_product($sku),1,$end,'{}',$tn-1000,$prefix,0,$initial);
  sb_op($pdo,$paid,$prefix,$tn);$before=sb_wallet($pdo,$paid,$prefix);$next=$before['simpleBonus']['nextAt'];
  foreach(['pending'=>$tn,'active'=>$late]as$phase=>$time){
    $data=$f[$phase];$data['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:'.$paid);$data['linkedPurchaseToken']=$old;
    $row=sb_row($pdo,$paid,$prefix);$ctx=mobile_play_energy_context($pdo,$row,$token,$data,$prefix);$ent=mobile_play_energy_subscription($data,'android:'.$paid,$sku,mobile_energy_product($sku),$time,$ctx);
    mobile_play_apply($pdo,$row,$token,$ent['ledgerProductId'],$ent['ledgerTerms'],1,$ent['expiresAt'],'{}',$time,$prefix,0,$ent);$after=sb_wallet($pdo,$paid,$prefix);
    sb_check($after['energySubscription']['batteryCount']===($phase==='pending'?5:2),'Contract3 Google DEFERRED effective tier '.$phase);
    sb_check($after['simpleBonus']['nextAt']===$next&&$after['energy']===$before['energy']&&$after['batteries']===[],'Contract3 DEFERRED preserves timer/balance, no cells '.$phase);
  }
  $GLOBALS['sb_config']['androidEnergyV2']['simpleBonus']['enabled']=false;$old=sb_player($pdo,$prefix,$now,3);sb_check(!mobile_bonus_is_active(sb_wallet($pdo,$old,$prefix)),'Disabled flag prevents new transitions');
}catch(Throwable $e){$failure=$e->getMessage();}
finally{if($pdo){try{if($pdo->inTransaction())$pdo->rollBack();$pdo->exec('SET FOREIGN_KEY_CHECKS=0');$q=$pdo->prepare('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$q->execute([strlen($prefix),$prefix]);foreach($q->fetchAll(PDO::FETCH_COLUMN)as $table){if(strpos($table,$prefix)!==0)throw new RuntimeException('Cleanup guard');$pdo->exec('DROP TABLE `'.$table.'`');}$pdo->exec('SET FOREIGN_KEY_CHECKS=1');$q->execute([strlen($prefix),$prefix]);$cleaned=count($q->fetchAll())===0;}catch(Throwable $e){$failure=$failure??$e->getMessage();}}}
echo json_encode(['ok'=>$failure===null&&$cleaned,'checks'=>$GLOBALS['checks'],'count'=>count($GLOBALS['checks']),'cleanup'=>$cleaned,'failure'=>$failure],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE);exit($failure===null&&$cleaned?0:1);
