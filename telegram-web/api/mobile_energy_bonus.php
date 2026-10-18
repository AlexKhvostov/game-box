<?php
// Android contract 3. Disabled until an operator explicitly enables this policy.
// The old 12->8h battery policy is independent and remains intact.
function mobile_bonus_defaults() {
    return ['enabled'=>false,'version'=>1,'initialEnergy'=>50,'reward'=>30,'periodSec'=>28800,
      'tier2Reward'=>60,'tier5Reward'=>150,'videoReward'=>40,'videoCooldownSec'=>120,'inviterReward'=>60];
}
function mobile_bonus_policy($config) {
    $raw=$config['simpleBonus']??[];$out=mobile_bonus_defaults();
    if(!is_array($raw))return $out;
    $out['enabled']=($raw['enabled']??false)===true;
    foreach($out as $key=>$fallback) {
      if($key==='enabled')continue;
      $min=in_array($key,['initialEnergy','videoCooldownSec'],true)?0:1;
      $max=$key==='periodSec'?2592000:($key==='videoCooldownSec'?86400:100000);
      if(isset($raw[$key])&&is_int($raw[$key])&&$raw[$key]>=$min&&$raw[$key]<=$max)$out[$key]=$raw[$key];
    }
    return $out;
}
function mobile_bonus_validation_error($raw) {
    if(!is_array($raw))return 'simpleBonus must be an object';
    $valid=mobile_bonus_policy(['simpleBonus'=>$raw]);
    foreach($raw as $key=>$value)if(!array_key_exists($key,$valid)||$valid[$key]!==$value)return 'Invalid simpleBonus.'.$key;
    return null;
}
function mobile_bonus_is_active($wallet) {return (int)($wallet['simpleBonus']['contract']??0)===3;}
function mobile_bonus_reward($wallet,$config,$now) {
    $policy=mobile_bonus_policy($config);$sub=$wallet['energySubscription']??null;
    $tier=$sub&&(int)($sub['expiresAt']??0)>$now?(int)($sub['batteryCount']??1):1;
    return ['tier'=>$tier,'amount'=>$tier===5?$policy['tier5Reward']:($tier===2?$policy['tier2Reward']:$policy['reward'])];
}
function mobile_bonus_public($wallet,$config,$now) {
    $bonus=$wallet['simpleBonus'];$reward=mobile_bonus_reward($wallet,$config,$now);
    return $bonus+['reward'=>$reward['amount'],'tier'=>$reward['tier'],'policy'=>mobile_bonus_policy($config)];
}
function mobile_bonus_migrate(&$wallet,$config,$now,$new=false) {
    $policy=mobile_bonus_policy($config);
    if(!$policy['enabled']||mobile_bonus_is_active($wallet))return false;
    // Working migration proposal: settle accrued legacy units once, round the
    // combined fractional remainder upward; retain the exact original cycles.
    // No existing paid balance is reset and no life/crystal migration repeats.
    $saved=$wallet['batteries']??[];$whole=0;$fraction=0.0;
    if(!$new)foreach($saved as $index=>$battery) {
      $end=$index>0&&isset($wallet['energySubscription'])?min($now,(int)$wallet['energySubscription']['expiresAt']):$now;
      $units=mobile_energy_charge($battery,$end);$whole+=$units;
      while(isset($battery['chargePolicy']['originalCycle'])&&$end<(int)$battery['chargePolicy']['effectiveAt'])$battery=$battery['chargePolicy']['originalCycle'];
      $duration=max(1,(int)$battery['durationMs']);$capacity=max(1,(int)$battery['capacity']);
      $earned=min($capacity,max(0,(int)$battery['initialUnits'])+max(0,min($duration,$end-(int)$battery['startedAt']))*$capacity/$duration);
      $fraction+=max(0,$earned-$units);
    }
    $settled=$whole+(int)ceil(round($fraction,9));
    if($new)$wallet['energy']=$policy['initialEnergy'];
    else $wallet['energy']=(int)$wallet['energy']+$settled;
    $wallet['simpleBonusMigration']=['at'=>$now,'legacyBatteries'=>$saved,'settled'=>$settled,
      'whole'=>$whole,'fraction'=>$fraction,'newPlayer'=>$new,'proposal'=>'settle-once-ready-first'];
    $wallet['batteries']=[];
    $wallet['simpleBonus']=['contract'=>3,'nextAt'=>0,'durationMs'=>$policy['periodSec']*1000,'lastClaimAt'=>0];
    return true;
}
function mobile_bonus_claim(&$wallet,$config,$now,$key) {
    if(!mobile_bonus_is_active($wallet))throw new MobileError('bonus_unavailable',409);
    if(!empty($wallet['energySubscription']['awaitingReconciliation']))throw new MobileError('subscription_verification_pending',409);
    if($now<(int)$wallet['simpleBonus']['nextAt'])throw new MobileError('bonus_not_ready',409);
    $policy=mobile_bonus_policy($config);$reward=mobile_bonus_reward($wallet,$config,$now);
    $wallet['energy']+=$reward['amount'];
    $wallet['simpleBonus']=['contract'=>3,'nextAt'=>$now+$policy['periodSec']*1000,
      'durationMs'=>$policy['periodSec']*1000,'lastClaimAt'=>$now];
    return ['kind'=>'energy_bonus_claim','operationId'=>$key,'amount'=>$reward['amount'],'tier'=>$reward['tier'],'claimedAt'=>$now];
}
