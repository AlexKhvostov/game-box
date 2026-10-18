<?php
require_once __DIR__ . '/mobile_energy.php';
function mobile_wallet_seed($config) {
    return ['lives'=>(int)($config['initialLives']??10),'tokens'=>(int)($config['initialTokens']??0),
      'dailyStreak'=>0,'lastDailyAt'=>0,'lastTimedAt'=>0,'lastAdAt'=>0,'jumpUntil'=>0,'helmetUntil'=>0,
      'bestTimeMs'=>0,'gamesStarted'=>0,'plusUntil'=>0,
      'claimed'=>!empty($config['installBonusAutoClaim'])?['install_bonus']:[], 'unlocked'=>[]];
}
function mobile_wallet($player,$config) {
    $stored=json_decode($player['wallet_json']??'',true);
    return is_array($stored)?array_merge(mobile_wallet_seed($config),$stored):mobile_wallet_seed($config);
}
function mobile_wallet_write(PDO $pdo,$playerId,$wallet,$prefix='') {
    $pdo->prepare('UPDATE ' . mobile_table('mobile_players',$prefix) . ' SET wallet_json=?,wallet_version=wallet_version+1 WHERE id=?')->execute([json_encode($wallet),$playerId]);
}
function mobile_wallet_mutate(PDO $pdo,$player,$key,$kind,$args,$now,$config,$prefix='', $betaAvailable=null,&$testGrantReceipt=null) {
    $testGrantReceipt=null;
    if(in_array($kind,['energy_test_grant','beta_free_crystals'],true))throw new MobileError('operation_invalid');
    if (!is_string($key) || !preg_match('/^[a-f0-9]{64}$/D',$key)) throw new MobileError('operation_invalid');
    if(!is_array($args))throw new MobileError('operation_invalid');
    $players=mobile_table('mobile_players',$prefix); $operations=mobile_table('mobile_operations',$prefix);
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE"); $query->execute([$player['id']]); $current=$query->fetch();
      if (!$current) throw new MobileError('unauthorized',401);
      $columns=in_array($kind,['energy_hidden_tap','energy_bonus_claim'],true)?'player_id,result_json':'player_id';
      $query=$pdo->prepare("SELECT $columns FROM $operations WHERE id=?"); $query->execute([$key]); $receipt=$query->fetch(PDO::FETCH_ASSOC);
      if ($receipt) {
        if ((int)$receipt['player_id']!==(int)$player['id']) throw new MobileError('operation_conflict',409);
        if(in_array($kind,['energy_bonus_claim','energy_hidden_tap'],true)) {
          $saved=json_decode($receipt['result_json']??'',true);
          if(($saved['kind']??null)!==$kind||($saved['operationId']??null)!==$key||count($args)!==0)throw new MobileError('operation_conflict',409);
        }
        $pdo->commit(); return mobile_profile($current);
      }
      $wallet=mobile_wallet($current,$config); $premium=$wallet['plusUntil']>$now;
      if(mobile_energy_is_v2($wallet) && $kind!=='google_privacy') {
        $testGrantReceipt=mobile_energy_operation($pdo,$current,$wallet,$kind,$args,$key,$now,mobile_energy_config($config,$now),$prefix);
      } else {
      switch ($kind) {
        case 'google_privacy':
          if(!is_bool($args['hide']??null))throw new MobileError('privacy_invalid');
          $wallet['_hideGoogleAccount']=$args['hide'];break;
        case 'daily':
          $offset=(int)($current['timezone_offset']??180)*60;
          $today=gmdate('Y-m-d',(int)($now/1000)+$offset); $last=gmdate('Y-m-d',(int)($wallet['lastDailyAt']/1000)+$offset);
          if ($wallet['lastDailyAt'] && $last>=$today) throw new MobileError('daily_not_ready',409);
          $yesterday=gmdate('Y-m-d',(int)($now/1000)+$offset-86400);
          $wallet['dailyStreak']=$last===$yesterday?$wallet['dailyStreak']+1:1;
          $rewards=$config['dailyRewardTokens']??[2,4,9,16,32,64,81];
          $amount=$rewards?max(0,(int)$rewards[min(count($rewards)-1,$wallet['dailyStreak']-1)]):0;
          $wallet['tokens']+=(int)round($amount*($premium?($config['premiumDailyMultiplier']??2):1)); $wallet['lastDailyAt']=$now; break;
        case 'timed':
          $hours=max(0,min(720,(int)($config['timedBonusHours']??1)));
          if ($wallet['lastTimedAt'] && $now<$wallet['lastTimedAt']+$hours*3600000) throw new MobileError('timed_not_ready',409);
          $wallet['tokens']+=max(0,(int)($config['timedBonusTokens']??22)); $wallet['lastTimedAt']=$now; break;
        case 'watch_ad':
          $seconds=max(0,min(86400,(int)($config['watchAdCooldownSec']??60)));
          if ($wallet['lastAdAt'] && $now<$wallet['lastAdAt']+$seconds*1000) throw new MobileError('ad_not_ready',409);
          // Yandex has no SSV. Android reports the SDK reward event; the server
          // controls amount, cooldown and replay. This cannot prove an impression.
          $amount=0; foreach (($config['earnActions']??[]) as $action) if ($action['id']==='watch_ad') $amount=max(0,(int)$action['reward']);
          $wallet['tokens']+=$amount; $wallet['lastAdAt']=$now; break;
        case 'rent_jump': case 'rent_helmet':
          $ability=$kind==='rent_jump'?'jump':'helmet'; $hour=!empty($args['hour']);
          $cost=max(0,(int)($config[$ability . 'Rental' . ($hour?'Hour':'') . 'Cost']??0));
          $minutes=max(1,min(1440,(int)($config[$ability . 'Rental' . ($hour?'Hour':'') . 'Minutes']??10)));
          if ($wallet['tokens']<$cost) throw new MobileError('insufficient_crystals',409);
          $wallet['tokens']-=$cost; $field=$ability . 'Until'; $wallet[$field]=max($now,$wallet[$field])+$minutes*60000; break;
        case 'lives':
          $pack=null; foreach (($config['lifePacks']??[]) as $offer) if ((int)$offer['lives']===(int)($args['lives']??0)) $pack=$offer;
          if (!$pack) throw new MobileError('offer_invalid');
          $cost=max(0,(int)($pack['costTokens']??$pack['cost']??0));
          if ($wallet['tokens']<$cost) throw new MobileError('insufficient_crystals',409);
          $wallet['tokens']-=$cost; $wallet['lives']+=max(0,(int)$pack['lives']); break;
        case 'earn':
          $id=$args['id']??'';
          if (in_array($id,$wallet['claimed'],true)) throw new MobileError('bonus_already_claimed',409);
          if ($id!=='install_bonus' && !in_array($id,$wallet['unlocked'],true)) throw new MobileError('bonus_locked',409);
          $action=null; foreach (($config['earnActions']??[]) as $offer) if ($offer['id']===$id) $action=$offer;
          if (!$action || !in_array($id,['install_bonus','survive_10s','record_20s','risks_5'],true)) throw new MobileError('bonus_invalid');
          $wallet['tokens']+=max(0,(int)$action['reward']); $wallet['claimed'][]=$id; break;
        default: throw new MobileError('operation_invalid');
      }
      }
      mobile_wallet_write($pdo,$player['id'],$wallet,$prefix);
      if($testGrantReceipt!==null)$pdo->prepare("INSERT INTO $operations (id,player_id,created_at,result_json) VALUES (?,?,?,?)")
        ->execute([$key,$player['id'],$now,json_encode($testGrantReceipt)]);
      else $pdo->prepare("INSERT INTO $operations (id,player_id,created_at) VALUES (?,?,?)")->execute([$key,$player['id'],$now]);
      $pdo->commit(); $current['wallet_json']=json_encode($wallet); $current['wallet_version']++; return mobile_profile($current);
    } catch (Throwable $error) {
      if ($pdo->inTransaction()) $pdo->rollBack();
      $testGrantReceipt=null;
      if(in_array($kind,['energy_hidden_tap','energy_bonus_claim'],true)&&$error instanceof PDOException&&(int)($error->errorInfo[1]??0)===1062)throw new MobileError('operation_conflict',409);
      throw $error;
    }
}
