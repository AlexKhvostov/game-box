<?php
require_once __DIR__.'/mobile_energy_bonus.php';
// Android-only model. Telegram's energy_store.php and its wallet are independent.
function mobile_energy_defaults() {
    return ['enabled'=>false,'revision'=>'android-energy-v2-1','initialEnergy'=>20,
      'batteryCapacity'=>20,'chargeHours'=>12,'chargePolicy'=>['version'=>0,'effectiveAt'=>0,'chargeHours'=>12],
      'baseAttemptCost'=>1,'helmetExtraCost'=>1,'jumpExtraCost'=>1,'watchAdCooldownSec'=>120,'simpleBonus'=>mobile_bonus_defaults(),
      'rewards'=>['achievement'=>10,'ad'=>20,'google'=>10,'age'=>10,'feedback'=>20,'invite'=>20],
      'packages'=>[
        ['id'=>'energy_100_v1','productId'=>'energy_100_v1','energy'=>100],
        ['id'=>'energy_250_v1','productId'=>'energy_250_v1','energy'=>250],
        ['id'=>'energy_500_v1','productId'=>'energy_500_v1','energy'=>500],
        ['id'=>'energy_1000_v1','productId'=>'energy_1000_v1','energy'=>1000]],
      'subscriptions'=>[
        ['id'=>'energy_batteries_2_v1','productId'=>'energy_batteries_2_v1','batteryCount'=>2,'additionalBatteries'=>1,'basePlanId'=>'weekly','capacity'=>20,'chargeHours'=>12,'periodDays'=>7],
        ['id'=>'energy_batteries_5_v1','productId'=>'energy_batteries_5_v1','batteryCount'=>5,'additionalBatteries'=>4,'basePlanId'=>'weekly','capacity'=>20,'chargeHours'=>12,'periodDays'=>7]]];
}
function mobile_energy_charge_policy($config,$now) {
    $policy=$config['chargePolicy']??null;
    if(!is_array($policy)||!is_int($policy['version']??null)||$policy['version']<1||
      !is_int($policy['effectiveAt']??null)||$policy['effectiveAt']<1||$policy['effectiveAt']>$now||
      !is_numeric($policy['chargeHours']??null)||$policy['chargeHours']<1||$policy['chargeHours']>720)return null;
    return $policy;
}
function mobile_energy_policy_change_error($candidate,$previous=null,$now=null) {
    $now=$now??(int)round(microtime(true)*1000);
    $policy=$candidate['chargePolicy']??['version'=>0,'effectiveAt'=>0,'chargeHours'=>12];
    if(!is_array($policy)||!is_int($policy['version']??null)||$policy['version']<0)return 'Некорректная версия политики зарядки';
    if($policy['version']>0&&(!is_int($policy['effectiveAt']??null)||$policy['effectiveAt']<1||
      !is_numeric($policy['chargeHours']??null)||$policy['chargeHours']<1||$policy['chargeHours']>720))return 'Укажите дату начала и эффективное время зарядки';
    $old=$previous['chargePolicy']??null;
    if(is_array($old)&&($old['version']??0)>0){
      // This release installs one beneficial policy. Replacing its global
      // history would lose the intermediate speed for wallets still offline.
      if($old['effectiveAt']<=$now&&($policy['version']!==$old['version']||($policy['effectiveAt']??null)!==$old['effectiveAt']||
        (float)($policy['chargeHours']??0)!==(float)$old['chargeHours']))return 'Действующая политика неизменяема: для следующего ускорения нужна поддержка полной истории';
      if($policy['version']<$old['version']||($policy['chargeHours']??721)>$old['chargeHours'])return 'Ускорение нельзя отменять или замедлять ранее выданные права';
      if($policy['version']===$old['version']&&($policy['effectiveAt']!==$old['effectiveAt']||(float)$policy['chargeHours']!==(float)$old['chargeHours']))return 'Для изменения политики повысьте её версию';
      if($policy['version']>$old['version']&&$policy['effectiveAt']<$old['effectiveAt'])return 'Новая политика не может начинаться раньше предыдущей';
    }
    return null;
}
function mobile_energy_effective_terms($original,$config,$now) {
    $policy=mobile_energy_charge_policy($config,$now);
    if($policy&&($original['kind']??'')==='energy_subscription')$original['chargeHours']=min((float)$original['chargeHours'],(float)$policy['chargeHours']);
    return $original;
}
function mobile_energy_config($economy=null,$now=null) {
    $now=$now??(int)round(microtime(true)*1000);
    $economy=$economy??tg_load_economy();
    $raw=is_array($economy['androidEnergyV2']??null)?$economy['androidEnergyV2']:[];$defaults=mobile_energy_defaults();
    $config=array_replace($defaults,$raw);$config['rewards']=array_replace($defaults['rewards'],$raw['rewards']??[]);
    $policy=mobile_energy_charge_policy($config,$now);if($policy)$config['chargeHours']=min((float)$config['chargeHours'],(float)$policy['chargeHours']);
    foreach($config['subscriptions'] as &$offer){$product=mobile_energy_product($offer['productId']??$offer['id']??'');if($product&&$product['kind']==='energy_subscription'){
      $offer['originalChargeHours']=$product['chargeHours'];$product=mobile_energy_effective_terms($product,$config,$now);
      $offer['batteryCount']=$product['batteryCount'];$offer['additionalBatteries']=$product['batteryCount']-1;$offer['basePlanId']=$product['basePlanId'];
      $offer['capacity']=$product['batteryCapacity'];$offer['chargeHours']=$product['chargeHours'];$offer['periodDays']=7;}}
    unset($offer);return $config;
}
function mobile_energy_is_v2($wallet) { return (int)($wallet['energyVersion']??0)===2; }
// A separate private switch must be explicitly enabled for temporary Android
// grants. The existing closed-test marker and lack of real Play billing remain
// mandatory; neither a request argument nor public Remote Config can enable it.
function mobile_energy_video_require_ready($wallet,$now,$config) {
    $seconds=mobile_bonus_is_active($wallet)?mobile_bonus_policy($config)['videoCooldownSec']:max(0,min(86400,(int)($config['watchAdCooldownSec']??120)));
    $last=max((int)($wallet['lastAdAt']??0),(int)($wallet['lastTestVideoAt']??0));
    if($last>0&&$now<$last+$seconds*1000)throw new MobileError('ad_not_ready',409);
}
function mobile_energy_product($sku) {
    $packs=['energy_100_v1'=>100,'energy_250_v1'=>250,'energy_500_v1'=>500,'energy_1000_v1'=>1000];
    if(isset($packs[$sku]))return ['kind'=>'energy','amount'=>$packs[$sku],'revision'=>'v1'];
    $tiers=['energy_batteries_2_v1'=>2,'energy_batteries_5_v1'=>5];
    if(isset($tiers[$sku]))return ['kind'=>'energy_subscription','batteryCount'=>$tiers[$sku],'basePlanId'=>'weekly',
      'batteryCapacity'=>20,'chargeHours'=>12,'revision'=>'v1'];
    // New versions are explicitly prepared server-side; a public admin value
    // cannot redefine the amount promised by an already published SKU.
    $path=__DIR__.'/mobile_config.php';$private=is_file($path)?include($path):[];
    $product=is_array($private)?($private['energy_products'][$sku]??null):null;
    if(!is_array($product))return null;
    if(preg_match('/^energy_([1-9][0-9]{0,6})_v([1-9][0-9]{0,3})$/D',$sku,$match)&&
      ($product['kind']??'')==='energy'&&(int)($product['amount']??0)===(int)$match[1])return $product+['revision'=>$sku];
    if(preg_match('/^energy_batteries_([25])_v([1-9][0-9]{0,3})$/D',$sku,$match)&&
      ($product['kind']??'')==='energy_subscription'&&(int)($product['batteryCount']??0)===(int)$match[1]&&
      ($product['basePlanId']??'')==='weekly'&&is_int($product['batteryCapacity']??null)&&$product['batteryCapacity']>0&&$product['batteryCapacity']<=10000&&
      (float)($product['chargeHours']??0)>0&&(float)$product['chargeHours']<=720)return $product+['revision'=>$sku];
    return null;
}
function mobile_energy_battery($id,$config,$now,$full=false) {
    return ['id'=>$id,'startedAt'=>(int)$now,'capacity'=>max(1,(int)$config['batteryCapacity']),
      'durationMs'=>max(1,(int)round($config['chargeHours']*3600000)),
      'initialUnits'=>$full?max(1,(int)$config['batteryCapacity']):0,'revision'=>(string)$config['revision']];
}
function mobile_energy_charge($battery,$now) {
    if(isset($battery['chargePolicy']['originalCycle'])&&$now<(int)$battery['chargePolicy']['effectiveAt'])return mobile_energy_charge($battery['chargePolicy']['originalCycle'],$now);
    $capacity=max(1,(int)$battery['capacity']);$duration=max(1,(int)$battery['durationMs']);
    $elapsed=max(0,min($duration,(int)$now-(int)$battery['startedAt']));
    // Integer arithmetic: no floating-point fractions or device-clock trust.
    return min($capacity,max(0,(int)$battery['initialUnits'])+intdiv($elapsed*$capacity,$duration));
}
function mobile_energy_rebase_cycle($battery,$at,$duration) {
    // Preserve units AND fractional progress. Round the equivalent phase upward
    // by at most one millisecond, so an upgrade never removes earned progress.
    $capacity=max(1,(int)$battery['capacity']);$oldDuration=max(1,(int)$battery['durationMs']);
    $elapsed=max(0,min($oldDuration,$at-(int)$battery['startedAt']));
    $numerator=min($capacity*$oldDuration,max(0,(int)$battery['initialUnits'])*$oldDuration+$elapsed*$capacity);
    $units=intdiv($numerator,$oldDuration);$remainder=$numerator%$oldDuration;
    $denominator=$oldDuration*$capacity;$scaled=$remainder*$duration;
    $phase=intdiv($scaled,$denominator)+($scaled%$denominator>0?1:0);
    $battery['startedAt']=$at-$phase;$battery['initialUnits']=$units;$battery['durationMs']=$duration;
    return $battery;
}
function mobile_energy_apply_charge_policy(&$wallet,$config,$now) {
    if(!mobile_energy_is_v2($wallet)||!($policy=mobile_energy_charge_policy($config,$now)))return false;
    $duration=(int)round($policy['chargeHours']*3600000);$changed=false;
    foreach($wallet['batteries']??[] as$index=>$battery){
      if((int)($battery['chargePolicy']['version']??0)>=$policy['version']||(int)$battery['durationMs']<=$duration)continue;
      $at=max((int)$policy['effectiveAt'],(int)$battery['startedAt']);if($at>$now)continue;
      $rebased=mobile_energy_rebase_cycle($battery,$at,$duration);
      $rebased['chargePolicy']=['version'=>$policy['version'],'effectiveAt'=>$at,'originalCycle'=>$battery];
      $wallet['batteries'][$index]=$rebased;$changed=true;
    }
    if(isset($wallet['energySubscription'])){
      $sub=&$wallet['energySubscription'];$original=(int)($sub['originalDurationMs']??$sub['durationMs']);
      if($sub['durationMs']>$duration){$sub['originalDurationMs']=$original;$sub['durationMs']=$duration;$sub['chargePolicyVersion']=$policy['version'];$changed=true;}
      unset($sub);
    }
    return $changed;
}
function mobile_energy_public_battery($battery,$cutoff,$now) {
    // Old clients know only one linear cycle. If reconciliation freezes a paid
    // slot before the policy boundary, expose its original earned phase at E.
    if(isset($battery['chargePolicy']['originalCycle'])&&$cutoff!==null&&$cutoff<(int)$battery['chargePolicy']['effectiveAt']){
      $old=$battery['chargePolicy']['originalCycle'];
      while(isset($old['chargePolicy']['originalCycle'])&&$cutoff<(int)$old['chargePolicy']['effectiveAt'])$old=$old['chargePolicy']['originalCycle'];
      $battery=mobile_energy_rebase_cycle($old,$cutoff,(int)$battery['durationMs']);
    }
    unset($battery['chargePolicy']);if($cutoff!==null)$battery['activeUntil']=(int)$cutoff;
    return $battery;
}
function mobile_energy_migrate_wallet($wallet,$config,$now,$new=false) {
    if (mobile_energy_is_v2($wallet)) return $wallet;
    $wallet['energyVersion']=2;
    $wallet['energy']=$new?max(0,(int)$config['initialEnergy']):max(0,(int)($wallet['lives']??0))+2*max(0,(int)($wallet['tokens']??0));
    $wallet['energyMigration']=['at'=>(int)$now,'lives'=>(int)($wallet['lives']??0),'crystals'=>(int)($wallet['tokens']??0),'crystalRate'=>2,'newPlayer'=>(bool)$new];
    $wallet['batteries']=[mobile_energy_battery('free',$config,$now,true)];
    $wallet['energySubscription']=null;$wallet['energyConfig']=$config;
    $wallet['jumpUntil']=0;$wallet['helmetUntil']=0;$wallet['plusUntil']=0;
    return $wallet;
}
function mobile_energy_transition(&$wallet,$count,$expiry,$periodId,$config,$now) {
    if(mobile_bonus_is_active($wallet))return 0;
    $count=in_array((int)$count,[1,2,5],true)?(int)$count:1;
    $old=$wallet['batteries']??[]; $kept=[];$settled=0;
    // Calculate disconnected slots only through their effective entitlement end.
    $cutoff=min($now,max(0,(int)$expiry));
    foreach ($old as $index=>$battery) {
      if ($index<$count) $kept[]=$battery;
      else $settled+=mobile_energy_charge($battery,$cutoff);
    }
    $wallet['energy']=(int)$wallet['energy']+$settled;
    while (count($kept)<$count) $kept[]=mobile_energy_battery('paid-'.count($kept).'-'.substr(hash('sha256',$periodId),0,12),$config,$now);
    $wallet['batteries']=$kept;
    return $settled;
}
function mobile_energy_expire(&$wallet,$now,$config) {
    if (!mobile_energy_is_v2($wallet)) return false;
    $policyChanged=mobile_energy_apply_charge_policy($wallet,$config,$now);
    $subscription=$wallet['energySubscription']??null;
    if (!$subscription || (int)$subscription['expiresAt']>$now) return $policyChanged;
    // A last-known renewal boundary is not proof that Google stopped the
    // subscription. Keep cycles frozen until reconciliation resolves it.
    if(empty($subscription['endConfirmed'])) {
      $changed=empty($subscription['awaitingReconciliation']);
      $wallet['energySubscription']['awaitingReconciliation']=true;
      $wallet['energySubscription']['pendingSince']=(int)$subscription['expiresAt'];
      return $changed||$policyChanged;
    }
    mobile_energy_transition($wallet,1,(int)$subscription['expiresAt'],$subscription['periodId']??'expiry',$config,$now);
    $wallet['energySubscription']=null;
    return true;
}
function mobile_energy_prepare(PDO $pdo,$player,$now,$version=1,$prefix='') {
    $config=mobile_energy_config(null,$now);$wallet=mobile_wallet($player,tg_load_economy());
    if (!mobile_energy_is_v2($wallet) && (!in_array((int)$version,[2,3],true) || empty($config['enabled']))) return $player;
    $players=mobile_table('mobile_players',$prefix);$pdo->beginTransaction();
    try {
      $query=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$query->execute([$player['id']]);$current=$query->fetch();
      if (!$current) throw new MobileError('unauthorized',401);
      $wallet=mobile_wallet($current,tg_load_economy());$before=json_encode($wallet);
      $wallet=mobile_energy_migrate_wallet($wallet,$config,$now);
      mobile_energy_expire($wallet,$now,$config);
      if((int)$version===3)mobile_bonus_migrate($wallet,$config,$now);
      if (json_encode($wallet)!==$before) {mobile_wallet_write($pdo,$current['id'],$wallet,$prefix);$current['wallet_json']=json_encode($wallet);$current['wallet_version']++;}
      $pdo->commit();return $current;
    } catch(Throwable $e) {if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}
function mobile_energy_feedback_table($prefix='') {
    if (!preg_match('/^[a-z0-9_]*$/D',$prefix)) throw new InvalidArgumentException('Invalid prefix');
    return '`'.$prefix.'mobile_energy_feedback`';
}
function mobile_energy_migrate_schema(PDO $pdo,$prefix='') {
    // Explicit operator/CLI migration only; ordinary HTTP handlers never call it.
    $operations=mobile_table('mobile_operations',$prefix);
    $column=$pdo->prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME='result_json'");
    $column->execute([$prefix.'mobile_operations']);
    if(!(int)$column->fetchColumn())$pdo->exec("ALTER TABLE $operations ADD result_json TEXT NULL");
    $table=mobile_energy_feedback_table($prefix);$players=mobile_table('mobile_players',$prefix);$fk='ae_feedback_'.substr(hash('sha256',$prefix),0,16);
    $pdo->exec("CREATE TABLE IF NOT EXISTS $table (id CHAR(64) CHARACTER SET ascii PRIMARY KEY,player_id INT UNSIGNED NOT NULL UNIQUE,
      comment TEXT NOT NULL,rating TINYINT UNSIGNED NULL,reward INT UNSIGNED NOT NULL,revision VARCHAR(128) NOT NULL,
      created_at BIGINT UNSIGNED NOT NULL,delivery_state VARCHAR(16) NOT NULL DEFAULT 'pending',attempts INT UNSIGNED NOT NULL DEFAULT 0,
      delivered_at BIGINT UNSIGNED NULL,last_attempt_at BIGINT UNSIGNED NULL,
      CONSTRAINT `$fk` FOREIGN KEY (player_id) REFERENCES $players (id) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
function mobile_energy_operation(PDO $pdo,$player,&$wallet,$kind,$args,$key,$now,$config,$prefix='') {
    if (!mobile_energy_is_v2($wallet)) throw new MobileError('energy_unavailable',409);
    mobile_energy_expire($wallet,$now,$config);
    if(mobile_bonus_is_active($wallet)){
      $bonusPolicy=mobile_bonus_policy($config);
      $config['rewards']['ad']=$bonusPolicy['videoReward'];
      $config['watchAdCooldownSec']=$bonusPolicy['videoCooldownSec'];
    }
    switch($kind) {
      case 'energy_hidden_tap':
        if(count($args)!==0)throw new MobileError('operation_invalid');
        $wallet['energy']+=20;
        return ['kind'=>$kind,'operationId'=>$key,'amount'=>20];
      case 'energy_bonus_claim':
        if(count($args)!==0)throw new MobileError('operation_invalid');
        return mobile_bonus_claim($wallet,$config,$now,$key);
      case 'energy_claim':
        if(mobile_bonus_is_active($wallet))throw new MobileError('update_required',409);
        if(!empty($wallet['energySubscription']['awaitingReconciliation']))throw new MobileError('subscription_verification_pending',409);
        $amount=0;foreach($wallet['batteries'] as $battery)$amount+=mobile_energy_charge($battery,$now);
        if($amount<1)throw new MobileError('charge_empty',409);
        $wallet['energy']+=$amount;
        foreach($wallet['batteries'] as $index=>$battery) {
          $cycleConfig=$config;$subscription=$wallet['energySubscription']??null;
          if($index>0&&$subscription){$cycleConfig['batteryCapacity']=$subscription['capacity'];$cycleConfig['chargeHours']=$subscription['durationMs']/3600000;$cycleConfig['revision']=$subscription['revision'];}
          $wallet['batteries'][$index]=mobile_energy_battery($battery['id'],$cycleConfig,$now);
        }
        break;
      case 'energy_age_completed':
        // No age group, birthday or analytics payload is accepted or persisted.
        if(count($args)!==0)throw new MobileError('age_payload_invalid');
        $wallet['energyAgeCompleted']=true;break;
      case 'energy_reward':
        $id=$args['id']??'';$rewardId='energy_'.$id;
        if(in_array($rewardId,$wallet['claimed'],true))break;
        if($id==='google') {if(empty($player['google_sub']))throw new MobileError('bonus_locked',409);$amount=$config['rewards']['google'];}
        elseif($id==='age') {if(empty($wallet['energyAgeCompleted']))throw new MobileError('bonus_locked',409);$amount=$config['rewards']['age'];}
        elseif(in_array($id,['survive_10s','record_20s','risks_5'],true)) {
          // Existing legacy claims stay spent. New claims preserve the original id.
          if(in_array($id,$wallet['claimed'],true))break;
          if(!in_array($id,$wallet['unlocked'],true))throw new MobileError('bonus_locked',409);
          $amount=$config['rewards']['achievement'];$rewardId=$id;
        } else throw new MobileError('bonus_invalid');
        $wallet['energy']+=max(0,(int)$amount);$wallet['claimed'][]=$rewardId;break;
      case 'watch_ad':
        mobile_energy_video_require_ready($wallet,$now,$config);
        $amount=mobile_bonus_is_active($wallet)?mobile_bonus_policy($config)['videoReward']:max(0,(int)$config['rewards']['ad']);if($amount<1)throw new MobileError('ad_unavailable',409);
        $wallet['energy']+=$amount;$wallet['lastAdAt']=$now;break;
      case 'energy_feedback':
        if(in_array('energy_feedback',$wallet['claimed'],true))break;
        $comment=$args['comment']??null;
        if(!is_string($comment)||!preg_match('//u',$comment))throw new MobileError('feedback_invalid');
        $comment=preg_replace('/^[\s\p{Z}]+|[\s\p{Z}]+$/u','',$comment);$length=mb_strlen($comment,'UTF-8');
        if($length<20||$length>1000)throw new MobileError('feedback_length');
        $rating=$args['rating']??null;
        if($rating!==null&&(!is_int($rating)||$rating<1||$rating>5))throw new MobileError('feedback_rating');
        $amount=max(0,(int)$config['rewards']['feedback']);$table=mobile_energy_feedback_table($prefix);
        $pdo->prepare("INSERT INTO $table (id,player_id,comment,rating,reward,revision,created_at) VALUES (?,?,?,?,?,?,?)")
          ->execute([$key,$player['id'],$comment,$rating,$amount,$config['revision'],$now]);
        $wallet['energy']+=$amount;$wallet['claimed'][]='energy_feedback';break;
      default:throw new MobileError('update_required',409);
    }
}

function mobile_energy_quote(PDO $pdo,$player,$sku,$requestId,$now,$prefix='') {
    $product=mobile_energy_product($sku);
    if(!$product||!is_string($requestId)||!preg_match('/^[a-f0-9]{64}$/D',$requestId))throw new MobileError('offer_invalid');
    $config=mobile_energy_config(null,$now);if(empty($config['enabled']))throw new MobileError('energy_unavailable',409);
    $listed=false;foreach(array_merge($config['packages'],$config['subscriptions']) as $offer)if(($offer['productId']??$offer['id']??null)===$sku)$listed=true;
    if(!$listed)throw new MobileError('offer_invalid');
    $players=mobile_table('mobile_players',$prefix);$pdo->beginTransaction();
    try {
      $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$q->execute([$player['id']]);$current=$q->fetch();
      if(!$current)throw new MobileError('unauthorized',401);
      $wallet=mobile_wallet($current,tg_load_economy());if(!mobile_energy_is_v2($wallet))throw new MobileError('update_required',409);
      mobile_energy_expire($wallet,$now,$config);
      if($product['kind']==='energy_subscription'&&!empty($wallet['energySubscription']['awaitingReconciliation']))throw new MobileError('subscription_verification_pending',409);
      $quotes=$wallet['energyQuotes']??[];
      foreach($quotes as $quote)if($quote['requestId']===$requestId){if($quote['productId']!==$sku)throw new MobileError('operation_conflict',409);$pdo->commit();return $quote;}
      $quote=['requestId'=>$requestId,'owner'=>'android:'.$player['id'],'productId'=>$sku,'revision'=>$config['revision'],
        'terms'=>mobile_energy_effective_terms($product,$config,$now),'originalTerms'=>$product,
        'chargePolicy'=>$config['chargePolicy'],'createdAt'=>$now,'immutableSku'=>true];
      $quotes[]=$quote;$wallet['energyQuotes']=array_slice($quotes,-100);mobile_wallet_write($pdo,$player['id'],$wallet,$prefix);
      $pdo->commit();return $quote;
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}
