<?php
require_once __DIR__ . '/mobile_identity.php';
require_once __DIR__ . '/mobile_energy.php';
// Android identity is independent of Telegram and device identifiers are not credentials.
class MobileError extends RuntimeException {
    public $status;
    public function __construct($message, $status = 400) { parent::__construct($message); $this->status = $status; }
}

// CGI/FastCGI hosts may expose Authorization only through getallheaders().
function mobile_request_authorization($server = null, $headers = null) {
    $server = $server ?? $_SERVER;
    foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $key) {
        if (isset($server[$key]) && is_string($server[$key]) && $server[$key] !== '') return $server[$key];
    }
    $headers = $headers ?? (function_exists('getallheaders') ? getallheaders() : []);
    foreach ($headers as $name => $value) {
        if (strcasecmp($name, 'Authorization') === 0 && is_string($value)) return $value;
    }
    return '';
}

function mobile_rate_file($identity,$directory) {
    return $directory . '/mobile-rate-' . hash_hmac('sha256',$identity,tg_webhook_secret()?:__DIR__) . '.json';
}
function mobile_rate_limit($identity,$limit,$now,$directory=null) {
    $directory=$directory??(__DIR__ . '/config-data');
    $file=mobile_rate_file($identity,$directory); $handle=@fopen($file,'c+');
    if (!$handle || !flock($handle,LOCK_EX)) {
        if ($handle) fclose($handle);
        throw new MobileError('service_unavailable',503);
    }
    try {
        $state=json_decode(stream_get_contents($handle),true)?:[];
        $window=(int)floor($now/60000);
        $count=($state['window']??-1)===$window?(int)($state['count']??0):0;
        if ($count >= $limit) throw new MobileError('rate_limited',429);
        rewind($handle); ftruncate($handle,0);
        $data=json_encode(['window'=>$window,'count'=>$count+1]);
        if (fwrite($handle,$data)!==strlen($data)) throw new MobileError('service_unavailable',503);
        fflush($handle);
    } finally { flock($handle,LOCK_UN); fclose($handle); }
}

function mobile_table($name, $prefix = '') {
    if (!preg_match('/^[a-z0-9_]*$/D', $prefix) || !in_array($name, ['mobile_players','mobile_names','mobile_rounds','mobile_devices','mobile_operations','mobile_purchases','scores'], true)) throw new InvalidArgumentException('Invalid table');
    return '`' . $prefix . $name . '`';
}

function mobile_name_key($name) { return hash('sha256', mb_strtolower(trim($name), 'UTF-8')); }
function mobile_name($value) {
    if (!is_string($value)) throw new MobileError('nickname_invalid');
    $value = trim($value);
    if (mb_strlen($value) < 5 || mb_strlen($value) > 40 || preg_match('/[\p{C}<>]/u', $value)) throw new MobileError('nickname_invalid');
    return $value;
}

// Explicit maintenance only: never create tables in an ordinary player request.
function mobile_migrate(PDO $pdo, $prefix = '') {
    $players = mobile_table('mobile_players', $prefix);
    $names = mobile_table('mobile_names', $prefix);
    $rounds = mobile_table('mobile_rounds', $prefix);
    $devices = mobile_table('mobile_devices', $prefix);
    $scores = mobile_table('scores', $prefix);
    $pdo->exec("CREATE TABLE IF NOT EXISTS $players (
      id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, installation_hash CHAR(64) CHARACTER SET ascii NOT NULL UNIQUE,
      secret_hash CHAR(64) CHARACTER SET ascii NOT NULL, nickname VARCHAR(128) NULL,
      created_at BIGINT UNSIGNED NOT NULL, google_sub VARCHAR(255) NULL UNIQUE
      ,wallet_json TEXT NULL, wallet_version BIGINT UNSIGNED NOT NULL DEFAULT 0, timezone_offset INT NOT NULL DEFAULT 180
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS $devices (
      installation_hash CHAR(64) CHARACTER SET ascii PRIMARY KEY, secret_hash CHAR(64) CHARACTER SET ascii NOT NULL UNIQUE,
      player_id INT UNSIGNED NOT NULL, KEY device_player (player_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("INSERT IGNORE INTO $devices (installation_hash,secret_hash,player_id) SELECT installation_hash,secret_hash,id FROM $players");
    $operations=mobile_table('mobile_operations',$prefix);
    $pdo->exec("CREATE TABLE IF NOT EXISTS $operations (id CHAR(64) CHARACTER SET ascii PRIMARY KEY,player_id INT UNSIGNED NOT NULL,created_at BIGINT UNSIGNED NOT NULL, KEY player_created (player_id,created_at)) ENGINE=InnoDB");
    $purchases=mobile_table('mobile_purchases',$prefix);
    $pdo->exec("CREATE TABLE IF NOT EXISTS $purchases (token_hash CHAR(64) CHARACTER SET ascii PRIMARY KEY,player_id INT UNSIGNED NOT NULL,
      product_id VARCHAR(128) NOT NULL,kind VARCHAR(32) NOT NULL,token_sealed TEXT NOT NULL,expires_at BIGINT UNSIGNED NOT NULL DEFAULT 0,created_at BIGINT UNSIGNED NOT NULL,
      KEY player_kind (player_id,kind)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS $names (
      name_key CHAR(64) CHARACTER SET ascii PRIMARY KEY, owner VARCHAR(64) CHARACTER SET ascii NOT NULL,
      nickname VARCHAR(128) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS $rounds (
      id CHAR(64) CHARACTER SET ascii PRIMARY KEY, player_id INT UNSIGNED NOT NULL,
      rules_revision CHAR(64) CHARACTER SET ascii NOT NULL DEFAULT '',
      context_json TEXT NULL,
      started_at BIGINT UNSIGNED NOT NULL, finished_at BIGINT UNSIGNED NULL,
      result_json TEXT NULL, score_id INT UNSIGNED NULL,
      KEY player_started (player_id,started_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    // Preserve legacy duplicate names, but reserve them against future registrations.
    $insert = $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?) ON DUPLICATE KEY UPDATE owner=IF(owner=VALUES(owner),owner,'legacy')");
    foreach ($pdo->query("SELECT DISTINCT player_name,user_id FROM $scores WHERE player_name<>''") as $row) {
      $name = trim($row['player_name']);
      if (mb_strtolower($name,'UTF-8')==='игрок') continue;
      $owner=$row['user_id'] ? (strpos($row['user_id'],'android:')===0 ? $row['user_id'] : 'telegram:' . $row['user_id']) : 'legacy';
      $insert->execute([mobile_name_key($name), $owner, $name]);
    }
}

function mobile_profile($row) {
    $wallet=mobile_wallet($row,tg_load_economy());
    $now=(int)round(microtime(true)*1000);
    if(mobile_energy_is_v2($wallet)){$wallet['energyConfig']=mobile_energy_config(null,$now);mobile_energy_apply_charge_policy($wallet,$wallet['energyConfig'],$now);
      foreach($wallet['batteries']??[]as$index=>$battery){$cutoff=$index>0&&isset($wallet['energySubscription'])?(int)$wallet['energySubscription']['expiresAt']:null;
        if(isset($battery['chargePolicy']))$wallet['batteries'][$index]=mobile_energy_public_battery($battery,$cutoff,$now);}
      if(mobile_bonus_is_active($wallet)){
        $wallet['simpleBonus']=mobile_bonus_public($wallet,$wallet['energyConfig'],$now);
        $policy=mobile_bonus_policy($wallet['energyConfig']);
        $wallet['energyConfig']['initialEnergy']=$policy['initialEnergy'];
        $wallet['energyConfig']['watchAdCooldownSec']=$policy['videoCooldownSec'];
        $wallet['energyConfig']['rewards']['ad']=$policy['videoReward'];
        $wallet['energyConfig']['rewards']['invite']=$policy['inviterReward'];
      }
      $wallet['energyGoogleReady']=!empty($row['google_sub']);
}
    return mobile_identity_private($row)+['id'=>'android:' . $row['id'], 'nickname'=>$row['nickname'], 'googleLinked'=>!empty($row['google_sub']),
    'serverNow'=>$now,
    'wallet'=>$wallet,'walletVersion'=>(int)($row['wallet_version']??0),'timezoneOffset'=>(int)($row['timezone_offset']??180)]; }

// Caller owns the transaction: keep reservation and Telegram profile update atomic.
function mobile_reserve_telegram(PDO $pdo, $userId, $name, $prefix = '') {
    $names=mobile_table('mobile_names',$prefix); $scores=mobile_table('scores',$prefix);
    $key=mobile_name_key($name); $owner='telegram:' . $userId;
    $query=$pdo->prepare("SELECT owner FROM $names WHERE name_key=? FOR UPDATE"); $query->execute([$key]); $taken=$query->fetchColumn();
    if ($taken && $taken!==$owner) {
      // Existing duplicates stay unchanged; this exception never grants a new owner.
      $query=$pdo->prepare("SELECT player_name FROM $scores WHERE user_id=?"); $query->execute([$userId]); $existing=false;
      foreach ($query as $row) if (mobile_name_key($row['player_name'])===$key) $existing=true;
      if (!$existing) throw new MobileError('nickname_taken',409);
      return;
    }
    if (!$taken) $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?)")->execute([$key,$owner,$name]);
    $pdo->prepare("DELETE FROM $names WHERE owner=? AND name_key<>?")->execute([$owner,$key]);
}

function mobile_guest(PDO $pdo, $installation, $secret, $now, $prefix = '', $timezoneOffset = 180, $economyVersion=1) {
    if (!is_string($installation) || !preg_match('/^[a-f0-9]{32}$/D', $installation) || !is_string($secret) || !preg_match('/^[a-f0-9]{64}$/D', $secret)) throw new MobileError('credentials_invalid');
    $players = mobile_table('mobile_players', $prefix); $names = mobile_table('mobile_names', $prefix); $devices=mobile_table('mobile_devices',$prefix);
    $installationHash = hash('sha256', $installation); $secretHash = hash('sha256', $secret);
    for ($attempt=0; $attempt<20; $attempt++) {
      $pdo->beginTransaction();
      try {
        $query = $pdo->prepare("SELECT p.*,d.secret_hash AS auth_secret_hash FROM $players p JOIN $devices d ON p.id=d.player_id WHERE d.installation_hash=? FOR UPDATE"); $query->execute([$installationHash]); $row = $query->fetch();
        if ($row) {
          if (!hash_equals($row['auth_secret_hash'], $secretHash)) throw new MobileError('unauthorized',401);
          $pdo->commit(); return mobile_profile($row);
        }
        $timezoneOffset=is_int($timezoneOffset)?max(-840,min(840,$timezoneOffset)):180;
        $insert = $pdo->prepare("INSERT INTO $players (installation_hash,secret_hash,created_at,timezone_offset) VALUES (?,?,?,?)"); $insert->execute([$installationHash,$secretHash,$now,$timezoneOffset]);
        $id = (int)$pdo->lastInsertId();
        if ($id>99999999) throw new MobileError('registration_unavailable',503);
        $nickname = 'user' . str_pad((string)$id,8,'0',STR_PAD_LEFT);
        $reserve = $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?)"); $reserve->execute([mobile_name_key($nickname),'android:' . $id,$nickname]);
        $pdo->prepare("UPDATE $players SET nickname=? WHERE id=?")->execute([$nickname,$id]);
        $pdo->prepare("INSERT INTO $devices (installation_hash,secret_hash,player_id) VALUES (?,?,?)")->execute([$installationHash,$secretHash,$id]);
        $wallet=mobile_wallet_seed(tg_load_economy());
        $energyConfig=mobile_energy_config(null,$now);
        if(in_array((int)$economyVersion,[2,3],true)&&!empty($energyConfig['enabled'])){
          $wallet=mobile_energy_migrate_wallet($wallet,$energyConfig,$now,true);
          if((int)$economyVersion===3)mobile_bonus_migrate($wallet,$energyConfig,$now,true);
        }
        mobile_wallet_write($pdo,$id,$wallet,$prefix);
        $pdo->commit(); return mobile_profile(['id'=>$id,'nickname'=>$nickname,'google_sub'=>null,'wallet_json'=>json_encode($wallet),'wallet_version'=>1,'timezone_offset'=>$timezoneOffset]);
      } catch (Throwable $error) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if ($error instanceof PDOException && in_array((int)($error->errorInfo[1] ?? 0), [1062,1213,1205],true)) { usleep(20000); continue; }
        throw $error;
      }
    }
    throw new MobileError('registration_busy',503);
}

function mobile_auth(PDO $pdo, $token, $prefix = '') {
    if (!is_string($token) || !preg_match('/^[a-f0-9]{64}$/D',$token)) throw new MobileError('unauthorized',401);
    $query = $pdo->prepare('SELECT p.* FROM ' . mobile_table('mobile_players',$prefix) . ' p JOIN ' . mobile_table('mobile_devices',$prefix) . ' d ON p.id=d.player_id WHERE d.secret_hash=?');
    $query->execute([hash('sha256',$token)]); $row = $query->fetch();
    if (!$row) throw new MobileError('unauthorized',401);
    return $row;
}

function mobile_rename(PDO $pdo, $player, $value, $prefix = '') {
    $name = mobile_name($value); $players = mobile_table('mobile_players',$prefix); $names = mobile_table('mobile_names',$prefix); $scores = mobile_table('scores',$prefix); $owner = 'android:' . $player['id'];
    $pdo->beginTransaction();
    try {
      $query = $pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE"); $query->execute([$player['id']]); $current = $query->fetch();
      if (!$current) throw new MobileError('unauthorized',401);
      $key = mobile_name_key($name); $oldKey = mobile_name_key($current['nickname']);
      $query = $pdo->prepare("SELECT owner FROM $names WHERE name_key=? FOR UPDATE"); $query->execute([$key]); $taken = $query->fetchColumn();
      if ($taken && $taken !== $owner) throw new MobileError('nickname_taken',409);
      if (!$taken) $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?)")->execute([$key,$owner,$name]);
      else $pdo->prepare("UPDATE $names SET nickname=? WHERE name_key=? AND owner=?")->execute([$name,$key,$owner]);
      $pdo->prepare("UPDATE $players SET nickname=? WHERE id=?")->execute([$name,$player['id']]);
      $pdo->prepare("UPDATE $scores SET player_name=? WHERE user_id=?")->execute([$name,$owner]);
      if ($key !== $oldKey) $pdo->prepare("DELETE FROM $names WHERE name_key=? AND owner=?")->execute([$oldKey,$owner]);
      $pdo->commit(); $current['nickname']=$name; return mobile_profile($current);
    } catch (Throwable $error) {
      if ($pdo->inTransaction()) $pdo->rollBack();
      if ($error instanceof PDOException && (int)($error->errorInfo[1] ?? 0) === 1062) throw new MobileError('nickname_taken',409);
      throw $error;
    }
}

function mobile_round_start(PDO $pdo, $player, $now, $prefix = '', $requestId = null, $revision = '', $options=[]) {
    $rounds=mobile_table('mobile_rounds',$prefix);
    $id=$requestId ?? bin2hex(random_bytes(32));
    if (!is_string($id) || !preg_match('/^[a-f0-9]{64}$/D',$id)) throw new MobileError('round_invalid');
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare('SELECT * FROM ' . mobile_table('mobile_players',$prefix) . ' WHERE id=? FOR UPDATE'); $query->execute([$player['id']]); $player=$query->fetch();
      if (!$player) throw new MobileError('unauthorized',401);
      $query=$pdo->prepare("SELECT player_id,context_json,result_json,finished_at FROM $rounds WHERE id=?"); $query->execute([$id]); $existing=$query->fetch();
      if ($existing) {
        if ((int)$existing['player_id']!==(int)$player['id']) throw new MobileError('round_conflict',409);
        $context=json_decode($existing['context_json'],true)?:[];
        $outcome=json_decode($existing['result_json']??'',true)?:[];
        if(!empty($outcome['canceled']))throw new MobileError('round_canceled',409);
        $pdo->commit(); return ['roundId'=>$id,'profile'=>mobile_profile($player),'attemptCost'=>(int)($context['attemptCost']??1),
          'hadJump'=>!empty($context['hadJump']),'hadHelmet'=>!empty($context['hadHelmet']),
          'activated'=>!empty($context['activatedAt']),'finished'=>$existing['finished_at']!==null];
      }
      if(isset($options['currentRevision'])&&($revision===''||!hash_equals((string)$options['currentRevision'],$revision)))throw new MobileError('rules_changed',409);
      $config=tg_load_economy(); $wallet=mobile_wallet($player,$config);
      $game=tg_local_gameplay_config()['game']??[];
      $context=['economy'=>$config,'hadJump'=>($game['jumpEnabled']??true) && $wallet['jumpUntil']>$now,'hadHelmet'=>($game['helmetEnabled']??true) && $wallet['helmetUntil']>$now];
      if(mobile_energy_is_v2($wallet)) {
        if(!in_array((int)($options['economyVersion']??1),[2,3],true))throw new MobileError('update_required',409);
        foreach(['helmet','jump'] as $field)if(isset($options[$field])&&!is_bool($options[$field]))throw new MobileError('loadout_invalid');
        $energyConfig=mobile_energy_config($config,$now);
        if(empty($energyConfig['enabled']))throw new MobileError('energy_unavailable',409);
        mobile_energy_expire($wallet,$now,$energyConfig);
        $context['hadJump']=($game['jumpEnabled']??true)&&!empty($options['jump']);
        $context['hadHelmet']=($game['helmetEnabled']??true)&&!empty($options['helmet']);
        $cost=max(0,(int)$energyConfig['baseAttemptCost'])+($context['hadHelmet']?max(0,(int)$energyConfig['helmetExtraCost']):0)+($context['hadJump']?max(0,(int)$energyConfig['jumpExtraCost']):0);
        if($wallet['energy']<$cost)throw new MobileError('insufficient_energy',409);
        $wallet['energy']-=$cost;$context['energyVersion']=2;$context['attemptCost']=$cost;
        $context['energyConfig']=$energyConfig;
      } else {
        if($wallet['lives']<1)throw new MobileError('insufficient_lives',409);
        $wallet['lives']--;
      }
      $wallet['gamesStarted']++;
      $pdo->prepare("INSERT INTO $rounds (id,player_id,started_at,rules_revision,context_json) VALUES (?,?,?,?,?)")->execute([$id,$player['id'],$now,$revision,json_encode($context)]);
      mobile_wallet_write($pdo,$player['id'],$wallet,$prefix); $player['wallet_json']=json_encode($wallet); $player['wallet_version']++;
      $pdo->commit(); return ['roundId'=>$id,'profile'=>mobile_profile($player),'attemptCost'=>(int)($context['attemptCost']??1),
        'hadJump'=>!empty($context['hadJump']),'hadHelmet'=>!empty($context['hadHelmet']),'activated'=>false,'finished'=>false];
    } catch (Throwable $error) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $error; }
}

function mobile_round_cancel(PDO $pdo,$player,$id,$now,$prefix='') {
    if(!is_string($id)||!preg_match('/^[a-f0-9]{64}$/D',$id))throw new MobileError('round_invalid');
    $rounds=mobile_table('mobile_rounds',$prefix);$players=mobile_table('mobile_players',$prefix);$pdo->beginTransaction();
    try {
      $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$q->execute([$player['id']]);$current=$q->fetch();
      $q=$pdo->prepare("SELECT * FROM $rounds WHERE id=? AND player_id=? FOR UPDATE");$q->execute([$id,$player['id']]);$round=$q->fetch();
      if(!$round)throw new MobileError('round_not_found',404);
      $result=json_decode($round['result_json']??'',true)?:[];
      if($round['finished_at']!==null) {if(empty($result['canceled']))throw new MobileError('round_finished',409);$pdo->commit();return ['profile'=>mobile_profile($current),'canceled'=>true];}
      if($now<(int)$round['started_at']||$now>(int)$round['started_at']+5000)throw new MobileError('round_cancel_expired',409);
      $context=json_decode($round['context_json'],true)?:[];$wallet=mobile_wallet($current,tg_load_economy());
      if(!empty($context['activatedAt']))throw new MobileError('round_already_started',409);
      if((int)($context['energyVersion']??0)!==2)throw new MobileError('round_cancel_unavailable',409);
      $wallet['energy']+=(int)$context['attemptCost'];$wallet['gamesStarted']=max(0,(int)$wallet['gamesStarted']-1);
      mobile_wallet_write($pdo,$current['id'],$wallet,$prefix);$current['wallet_json']=json_encode($wallet);$current['wallet_version']++;
      $pdo->prepare("UPDATE $rounds SET finished_at=?,result_json=? WHERE id=?")->execute([$now,json_encode(['ok'=>true,'canceled'=>true]),$id]);
      $pdo->commit();return ['profile'=>mobile_profile($current),'canceled'=>true];
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}

function mobile_round_activate(PDO $pdo,$player,$id,$now,$prefix='') {
    if(!is_string($id)||!preg_match('/^[a-f0-9]{64}$/D',$id))throw new MobileError('round_invalid');
    $rounds=mobile_table('mobile_rounds',$prefix);$players=mobile_table('mobile_players',$prefix);$pdo->beginTransaction();
    try {
      $q=$pdo->prepare("SELECT id FROM $players WHERE id=? FOR UPDATE");$q->execute([$player['id']]);
      if(!$q->fetchColumn())throw new MobileError('unauthorized',401);
      $q=$pdo->prepare("SELECT * FROM $rounds WHERE id=? AND player_id=? FOR UPDATE");$q->execute([$id,$player['id']]);$round=$q->fetch();
      if(!$round)throw new MobileError('round_not_found',404);
      if($round['finished_at']!==null)throw new MobileError('round_finished',409);
      $context=json_decode($round['context_json'],true)?:[];
      if(empty($context['activatedAt'])){$context['activatedAt']=$now;$pdo->prepare("UPDATE $rounds SET context_json=? WHERE id=?")->execute([json_encode($context),$id]);}
      $pdo->commit();return ['activated'=>true,'roundId'=>$id];
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}

function mobile_round_finish(PDO $pdo, $player, $input, $now, $prefix = '') {
    $rounds=mobile_table('mobile_rounds',$prefix); $scores=mobile_table('scores',$prefix); $id=$input['roundId'] ?? '';
    if (!is_string($id) || !preg_match('/^[a-f0-9]{64}$/D',$id)) throw new MobileError('round_invalid');
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare('SELECT * FROM ' . mobile_table('mobile_players',$prefix) . ' WHERE id=? FOR UPDATE');
      $query->execute([$player['id']]); $player=$query->fetch();
      if (!$player) throw new MobileError('unauthorized',401);
      $query=$pdo->prepare("SELECT * FROM $rounds WHERE id=? AND player_id=? FOR UPDATE"); $query->execute([$id,$player['id']]); $round=$query->fetch();
      if (!$round) throw new MobileError('round_not_found',404);
      if ($round['finished_at'] !== null) { $oldResult=json_decode($round['result_json'],true);if(!empty($oldResult['canceled']))throw new MobileError('round_canceled',409);$pdo->commit(); return $oldResult; }
      foreach (['timeMs'=>3600000,'runDistance'=>10000000,'riskCount'=>10000] as $key=>$max) if (!isset($input[$key]) || !is_int($input[$key]) || $input[$key]<0 || $input[$key]>$max) throw new MobileError('result_invalid');
      $time=$input['timeMs']; if ($time<1 || $time>$now-(int)$round['started_at']+1200) throw new MobileError('result_time_invalid');
      $context=json_decode($round['context_json'],true); $config=$context['economy']; $wallet=mobile_wallet($player,$config);
      if (!empty($input['hadJump'])!==!empty($context['hadJump']) || !empty($input['hadHelmet'])!==!empty($context['hadHelmet'])) throw new MobileError('result_boost_invalid');
      $score=(int)round($time/1000*$input['runDistance']*(1+$input['riskCount'])); $day=gmdate('Y-m-d',(int)($now/1000));
      $query=$pdo->prepare("INSERT INTO $scores (score_day,user_id,player_name,hide_telegram,time_ms,run_distance,risk_count,score,had_jump,had_helmet,created_at) VALUES (?,?,?,1,?,?,?,?,?,?,?)");
      $query->execute([$day,'android:' . $player['id'],$player['nickname'],$time,$input['runDistance'],$input['riskCount'],$score,!empty($input['hadJump'])?1:0,!empty($input['hadHelmet'])?1:0,$now]);
      $result=['ok'=>true,'scoreId'=>(string)$pdo->lastInsertId(),'score'=>$score];
      $wallet['bestTimeMs']=max($wallet['bestTimeMs'],$time);
      $runUnits=intdiv($input['runDistance'],max(1,(int)($config['runRewardEvery']??200)));
      $riskUnits=intdiv($input['riskCount'],max(1,(int)($config['riskRewardEvery']??5)));
      if(mobile_energy_is_v2($wallet)) {
        $reward=(int)($context['energyVersion']??0)===2?$runUnits+$riskUnits:
          2*($runUnits*max(0,(int)($config['runRewardTokens']??1))+$riskUnits*max(0,(int)($config['riskRewardTokens']??1)));
        $wallet['energy']+=$reward;$result['energyReward']=$reward;
      } else $wallet['tokens']+=$runUnits*max(0,(int)($config['runRewardTokens']??1))+$riskUnits*max(0,(int)($config['riskRewardTokens']??1));
      foreach (['survive_10s'=>$time>=1000*($config['earnSurviveSeconds']??10),'record_20s'=>$wallet['bestTimeMs']>=1000*($config['earnRecordSeconds']??20),'risks_5'=>$input['riskCount']>=($config['earnRisksInRun']??5)] as $bonus=>$unlocked)
        if ($unlocked && !in_array($bonus,$wallet['unlocked'],true)) $wallet['unlocked'][]=$bonus;
      mobile_wallet_write($pdo,$player['id'],$wallet,$prefix);
      $pdo->prepare("UPDATE $rounds SET finished_at=?,result_json=?,score_id=? WHERE id=?")->execute([$now,json_encode($result),$result['scoreId'],$id]);
      $pdo->commit(); return $result;
    } catch (Throwable $error) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $error; }
}
