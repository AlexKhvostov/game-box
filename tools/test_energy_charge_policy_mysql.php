<?php
// Synthetic clocks and disposable loopback tables only. No Google/FTP/mail.
if(PHP_SAPI!=='cli')exit(2);
function tg_load_economy(){return $GLOBALS['p8_config'];}
function tg_local_gameplay_config(){return ['game'=>['helmetEnabled'=>true,'jumpEnabled'=>true]];}
require_once __DIR__.'/../telegram-web/api/mobile_store.php';
require_once __DIR__.'/../telegram-web/api/mobile_wallet.php';
require_once __DIR__.'/../telegram-web/api/mobile_google.php';
require_once __DIR__.'/../telegram-web/api/mobile_play.php';
$GLOBALS['p8_config']=['initialLives'=>7,'initialTokens'=>13,'androidEnergyV2'=>mobile_energy_defaults()];$GLOBALS['p8_config']['androidEnergyV2']['enabled']=true;
$checks=[];$failure=null;$pdo=null;$cleaned=false;$prefix='_p8_'.bin2hex(random_bytes(8)).'_';
function p8_check($ok,$label){if(!$ok)throw new RuntimeException($label);$GLOBALS['checks'][]=$label;}
function p8_set($at,$version=1){$GLOBALS['p8_config']['androidEnergyV2']['chargePolicy']=['version'=>$version,'effectiveAt'=>$at,'chargeHours'=>8];}
function p8_row($pdo,$id,$prefix){$q=$pdo->prepare('SELECT * FROM '.mobile_table('mobile_players',$prefix).' WHERE id=?');$q->execute([$id]);return$q->fetch();}
function p8_wallet($pdo,$id,$prefix){return mobile_wallet(p8_row($pdo,$id,$prefix),tg_load_economy());}
function p8_player($pdo,$prefix,$now){$secret=bin2hex(random_bytes(32));mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,$now,$prefix,180,2);return mobile_auth($pdo,$secret,$prefix);}
function p8_fraction($b,$at){if(isset($b['chargePolicy']['originalCycle'])&&$at<$b['chargePolicy']['effectiveAt'])return p8_fraction($b['chargePolicy']['originalCycle'],$at);return min($b['capacity'],$b['initialUnits']+max(0,min($b['durationMs'],$at-$b['startedAt']))*$b['capacity']/$b['durationMs']);}
function p8_meta($pdo,$prefix,$token){$q=$pdo->prepare('SELECT token_sealed FROM '.mobile_table('mobile_purchases',$prefix).' WHERE token_hash=?');$q->execute([hash('sha256',$token)]);return json_decode($q->fetchColumn(),true);}
function p8_apply($pdo,$id,$prefix,$token,$data,$hint,$now){$row=p8_row($pdo,$id,$prefix);$ctx=mobile_play_energy_context($pdo,$row,$token,$data,$prefix);$ent=mobile_play_energy_subscription($data,'android:'.$id,$hint,mobile_energy_product($hint),$now,$ctx);mobile_play_apply($pdo,$row,$token,$ent['ledgerProductId'],$ent['ledgerTerms'],1,$ent['expiresAt'],'{}',$now,$prefix,0,$ent);return$ent;}
try{
 $T=2000000000000;$hour=3600000;p8_set($T);$raw=$GLOBALS['p8_config']['androidEnergyV2'];$cfg=mobile_energy_config(tg_load_economy(),$T);
 p8_check(mobile_energy_config(tg_load_economy(),$T-1)['chargeHours']===12,'Policy future leaves original12h');
 p8_check($cfg['chargeHours']==8&&$cfg['subscriptions'][0]['chargeHours']==8&&$cfg['subscriptions'][1]['chargeHours']==8,'Public free and both paid offers8h at T');
 p8_check($cfg['subscriptions'][0]['originalChargeHours']===12&&mobile_energy_product('energy_batteries_2_v1')['chargeHours']===12,'Immutable registry and original offer remain12h');
 $base=mobile_energy_battery('synthetic',mobile_energy_defaults(),$T-3*$hour-12345);$w=['energyVersion'=>2,'energy'=>73,'batteries'=>[$base]];
 p8_check(!mobile_energy_apply_charge_policy($w,$cfg,$T-1),'No early migration Tminus1');
 mobile_energy_apply_charge_policy($w,$cfg,$T+2*$hour);$b=$w['batteries'][0];
 p8_check($w['energy']===73&&$b['durationMs']===8*$hour,'Upgrade changes speed only, no wallet credit');
 foreach([$T-1,$T,$T+1]as$stamp){$expected=p8_fraction($base,min($stamp,$T))+max(0,$stamp-$T)*20/(8*$hour);$actual=p8_fraction($b,$stamp);p8_check($actual+1e-10>=$expected&&$actual-$expected<=20/(8*$hour)+1e-10,'Fraction preserved at boundary '.$stamp);}
 $expected=p8_fraction($base,$T)+2*$hour*20/(8*$hour);p8_check(abs(p8_fraction($b,$T+2*$hour)-$expected)<=20/(8*$hour)+1e-10,'Late profile accrues12h before T and8h after T');
 $once=$w;p8_check(!mobile_energy_apply_charge_policy($w,$cfg,$T+3*$hour)&&$w===$once,'Repeated policy application cannot migrate or credit again');
 foreach([false,true]as$full){$x=['energyVersion'=>2,'energy'=>1,'batteries'=>[mobile_energy_battery('state',mobile_energy_defaults(),$T,$full)]];mobile_energy_apply_charge_policy($x,$cfg,$T);p8_check(mobile_energy_charge($x['batteries'][0],$T)===($full?20:0),'Empty/full state preserved '.(int)$full);}
 foreach([['version'=>0,'effectiveAt'=>$T,'chargeHours'=>8],['version'=>'unknown','effectiveAt'=>$T,'chargeHours'=>8],['version'=>1,'effectiveAt'=>$T+1,'chargeHours'=>8]]as$disabled){$x=['energyVersion'=>2,'batteries'=>[$base]];$c=$cfg;$c['chargePolicy']=$disabled;p8_check(!mobile_energy_apply_charge_policy($x,$c,$T)&&$x['batteries'][0]===$base,'Disabled/future/invalid version cannot affect cycles');}
 p8_check(mobile_energy_policy_change_error($raw,null)===null,'Initial policy allowed');
 $bad=$raw;$bad['chargePolicy']['version']=0;p8_check(mobile_energy_policy_change_error($bad,$raw)!==null,'Policy cannot be disabled after promise');
 $bad=$raw;$bad['chargePolicy']['chargeHours']=12;$bad['chargePolicy']['version']=2;p8_check(mobile_energy_policy_change_error($bad,$raw)!==null,'New version cannot slow down promised8h');
 $bad=$raw;$bad['chargePolicy']['effectiveAt']++;p8_check(mobile_energy_policy_change_error($bad,$raw)!==null,'Same version cannot rewrite historical T');
 $bad=$raw;$bad['chargePolicy']=['version'=>2,'effectiveAt'=>$T+$hour,'chargeHours'=>6];p8_check(mobile_energy_policy_change_error($bad,$raw,$T+1)!==null,'Active8h cannot be replaced by future6h and temporarily fall back12h');
 $bad['chargePolicy']['effectiveAt']=$T+1;p8_check(mobile_energy_policy_change_error($bad,$raw,$T+1)!==null,'Replacing active policy now cannot discard8h history of offline wallets');
 foreach([$T-$hour,$T,$T+$hour]as$end){$x=['energyVersion'=>2,'energy'=>5,'batteries'=>[$base,$base], 'energySubscription'=>['expiresAt'=>$end,'durationMs'=>12*$hour,'endConfirmed'=>false]];
  mobile_energy_expire($x,$T+2*$hour,$cfg);$expected=p8_fraction($base,min($end,$T))+max(0,$end-$T)*20/(8*$hour);$expected=(int)floor($expected+1e-9);
  p8_check(!empty($x['energySubscription']['awaitingReconciliation'])&&$x['energy']===5&&mobile_energy_charge($x['batteries'][1],$end)===$expected,'Pending expiry frozen with correct piecewise history '.$end);
  $public=mobile_energy_public_battery($x['batteries'][1],$end,$T+2*$hour);p8_check($public['durationMs']===8*$hour&&mobile_energy_charge($public,$end)===$expected&&!isset($public['chargePolicy']),'Old client DTO freezes earned phase at expiry '.$end);
  $x['energySubscription']['endConfirmed']=true;mobile_energy_expire($x,$T+2*$hour,$cfg);$settled=$x;mobile_energy_expire($x,$T+3*$hour,$cfg);p8_check($x['energy']===5+$expected&&count($x['batteries'])===1&&$x===$settled,'Confirmed expiry settles historical phase once '.$end);
 }
 $pdo=new PDO('mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4','root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
 p8_check($pdo->query('SELECT DATABASE()')->fetchColumn()==='untouch_friend_invites_tests'&&(int)$pdo->query('SELECT @@port')->fetchColumn()===43317,'Exact disposable loopback database');
 $pdo->exec('CREATE TABLE '.mobile_table('scores',$prefix).' (id INT AUTO_INCREMENT PRIMARY KEY,player_name VARCHAR(128),user_id VARCHAR(64)) ENGINE=InnoDB');mobile_migrate($pdo,$prefix);
 $player=p8_player($pdo,$prefix,$T-6*$hour);$id=$player['id'];$sku='energy_batteries_5_v1';$terms=mobile_energy_product($sku);$expiry=$T+8*$hour;
 $quoteId=bin2hex(random_bytes(32));$oldQuote=mobile_energy_quote($pdo,$player,$sku,$quoteId,$T-$hour,$prefix);p8_check($oldQuote['terms']['chargeHours']===12,'Quote before T promises original12h');
 $ent=['expiresAt'=>$expiry,'startedAt'=>$T-4*$hour,'periodId'=>'old-five','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];
 mobile_play_apply($pdo,$player,'synthetic-policy-five',$sku,$terms,1,$expiry,'{}',$T-4*$hour,$prefix,0,$ent);
 $before=p8_wallet($pdo,$id,$prefix);$late=$T+2*$hour;mobile_energy_prepare($pdo,p8_row($pdo,$id,$prefix),$late,2,$prefix);$migrated=p8_wallet($pdo,$id,$prefix);
 p8_check($migrated['energy']===$before['energy']&&count(array_filter($migrated['batteries'],function($b)use($hour){return$b['durationMs']===8*$hour;}))===5,'Persisted migration gives all5 speed8h without credits');
 mobile_energy_prepare($pdo,p8_row($pdo,$id,$prefix),$late+1000,2,$prefix);p8_check(p8_wallet($pdo,$id,$prefix)===$migrated,'Repeated prepare is durable idempotent');
 $replay=mobile_energy_quote($pdo,p8_row($pdo,$id,$prefix),$sku,$quoteId,$late,$prefix);p8_check($replay===$oldQuote,'Historical quote replay remains immutable12h');
 $quote=mobile_energy_quote($pdo,p8_row($pdo,$id,$prefix),$sku,bin2hex(random_bytes(32)),$late,$prefix);p8_check($quote['terms']['chargeHours']==8&&$quote['originalTerms']['chargeHours']===12,'New quote8 with separate base12');
 $pre=p8_wallet($pdo,$id,$prefix);$expected=0;foreach($pre['batteries']as$b)$expected+=mobile_energy_charge($b,$late);$key=bin2hex(random_bytes(32));
 mobile_wallet_mutate($pdo,p8_row($pdo,$id,$prefix),$key,'energy_claim',[],$late,tg_load_economy(),$prefix);$claimed=p8_wallet($pdo,$id,$prefix);
 p8_check($claimed['energy']===$pre['energy']+$expected&&count(array_filter($claimed['batteries'],function($b)use($hour){return$b['durationMs']===8*$hour&&$b['initialUnits']===0;}))===5,'Claim credits accumulated amount once and resets every cycle8h');
 mobile_wallet_mutate($pdo,p8_row($pdo,$id,$prefix),$key,'energy_claim',[],$late+1000,tg_load_economy(),$prefix);p8_check(p8_wallet($pdo,$id,$prefix)===$claimed,'Claim replay does not reset cycles or credit again');
 $new=p8_player($pdo,$prefix,$T-$hour);$nid=$new['id'];$nterms=mobile_energy_product('energy_batteries_2_v1');$ne=$ent;$ne['startedAt']=$late;$ne['periodId']='new-two';
 $preT=mobile_energy_quote($pdo,$new,'energy_batteries_2_v1',bin2hex(random_bytes(32)),$T-1,$prefix);p8_check($preT['terms']['chargeHours']===12,'Prepolicy quote cannot freeze inferior terms on purchase after T');
 mobile_play_apply($pdo,$new,'synthetic-new-promise','energy_batteries_2_v1',$nterms,1,$expiry,'{}',$late,$prefix,0,$ne);$meta=p8_meta($pdo,$prefix,'synthetic-new-promise');
 p8_check($meta['energyProductTerms']['chargeHours']===12&&$meta['energyPromisedTerms']['chargeHours']==8&&$meta['energyPurchaseChargePolicy']['version']===1,'New purchase stores immutable base12 and actual promised8 separately');
 $GLOBALS['p8_config']['androidEnergyV2']['chargePolicy']['version']=0;$renew=$ne;$renew['expiresAt']=$expiry+7*86400000;$renew['periodId']='new-two-renew';
 mobile_play_apply($pdo,p8_row($pdo,$nid,$prefix),'synthetic-new-promise','energy_batteries_2_v1',$nterms,1,$renew['expiresAt'],'{}',$late+$hour,$prefix,0,$renew);
 p8_check(p8_wallet($pdo,$nid,$prefix)['energySubscription']['durationMs']===8*$hour&&p8_meta($pdo,$prefix,'synthetic-new-promise')['energyPromisedTerms']['chargeHours']==8,'Stored promised8 survives policy missing on renewal');
 foreach([false,true]as$gap){
  p8_set($T);$start=$T-4*$hour;$end=$T-$hour;$late=$T+$hour;$player=p8_player($pdo,$prefix,$start);$rid=$player['id'];$token='synthetic-policy-renew-'.(int)$gap;
  $e=['expiresAt'=>$end,'startedAt'=>$start,'periodId'=>'policy-before-renew','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];mobile_play_apply($pdo,$player,$token,'energy_batteries_2_v1',$nterms,1,$end,'{}',$start,$prefix,0,$e);
  mobile_energy_prepare($pdo,p8_row($pdo,$rid,$prefix),$late,2,$prefix);$before=p8_wallet($pdo,$rid,$prefix);$renew=$e;$renew['periodId']='policy-after-renew';$renew['expiresAt']=$end+7*86400000;
  if($gap){$renew['startedAt']=$T+intdiv($hour,2);$renew['linkedTokenHash']=hash('sha256',$token);}
  mobile_play_apply($pdo,p8_row($pdo,$rid,$prefix),$gap?'synthetic-policy-real-gap':$token,'energy_batteries_2_v1',$nterms,1,$renew['expiresAt'],'{}',$late,$prefix,0,$renew);$after=p8_wallet($pdo,$rid,$prefix);
  if($gap)p8_check($after['energy']===$before['energy']+5&&mobile_energy_charge($after['batteries'][1],$late)===0&&$after['batteries'][1]['durationMs']===8*$hour,'Proven unpaid gap settles only old E then starts empty8h cycle');
  else p8_check($after['energy']===$before['energy']&&mobile_energy_charge($after['batteries'][1],$late)===9&&empty($after['energySubscription']['awaitingReconciliation']),'Continuous renewal across policy and known old expiry resumes exact12then8h cycle');
 }
 foreach([false,true]as$beforePolicy){
  $f=json_decode(file_get_contents(__DIR__.'/../test/fixtures/google_play_deferred_replacement.json'),true);$E=$f['cutoverMs'];$switch=$beforePolicy?$E+$hour:$E-$hour;$start=$E-4*$hour;$late=max($E,$switch)+2*$hour;p8_set($switch);
  $player=p8_player($pdo,$prefix,$start);$id=$player['id'];$old='synthetic-policy-deferred-old-'.$id;$token='synthetic-policy-deferred-new-'.$id;
  $oldEnt=['expiresAt'=>$E,'startedAt'=>$start,'periodId'=>'before-deferred','linkedTokenHash'=>null,'state'=>'SUBSCRIPTION_STATE_ACTIVE','endConfirmed'=>false];mobile_play_apply($pdo,$player,$old,$sku,$terms,1,$E,'{}',$start,$prefix,0,$oldEnt);
  $pending=$f['pending'];$pending['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:'.$id);$pending['linkedPurchaseToken']=$old;p8_apply($pdo,$id,$prefix,$token,$pending,$sku,$E-2*$hour);
  $oldWallet=p8_wallet($pdo,$id,$prefix);$active=$f['active'];$active['externalAccountIdentifiers']['obfuscatedExternalAccountId']=hash('sha256','android:'.$id);$active['linkedPurchaseToken']=$old;p8_apply($pdo,$id,$prefix,$token,$active,$sku,$late);$after=p8_wallet($pdo,$id,$prefix);
  $earned=(min($E,$switch)-$start)*20/(12*$hour)+max(0,$E-$switch)*20/(8*$hour);$settled=3*(int)floor($earned+1e-9);
  p8_check(count($after['batteries'])===2&&$after['energy']===$oldWallet['energy']+$settled,'Deferred3 slots settle strictly E with policy on either side '.(int)$beforePolicy);
  $expected=(min($late,$switch)-$start)*20/(12*$hour)+max(0,$late-$switch)*20/(8*$hour);p8_check(abs(p8_fraction($after['batteries'][1],$late)-$expected)<=20/(8*$hour)+1e-9,'Deferred kept paid cycle retains fractional progress '.(int)$beforePolicy);
  p8_apply($pdo,$id,$prefix,$token,$pending,$sku,$late+1000);p8_check(p8_wallet($pdo,$id,$prefix)===$after,'Stale deferred replay cannot undo policy/cutover '.(int)$beforePolicy);
 }
}catch(Throwable$error){$failure=get_class($error).': '.$error->getMessage();}
finally{if($pdo){if($pdo->inTransaction())$pdo->rollBack();foreach(['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players']as$name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($name,$prefix));$q=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$q->execute([strlen($prefix),$prefix]);$cleaned=(int)$q->fetchColumn()===0;}}
echo json_encode(['ok'=>$failure===null&&$cleaned,'checks'=>count($checks),'passed'=>$checks,'cleaned'=>$cleaned,'failure'=>$failure,'syntheticOnly'=>true,'googleRequests'=>0],JSON_PRETTY_PRINT).PHP_EOL;exit($failure===null&&$cleaned?0:1);
