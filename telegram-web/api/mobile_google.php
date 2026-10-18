<?php
spl_autoload_register(function($class) {
    $prefix='Firebase\\JWT\\';
    if (strncmp($class,$prefix,strlen($prefix))!==0) return;
    $name=substr($class,strlen($prefix));
    if (!preg_match('/^[A-Za-z]+$/D',$name)) return;
    $path=__DIR__ . '/vendor/php-jwt/src/' . $name . '.php';
    if (is_file($path)) require_once $path;
});

function mobile_private_config() {
    $path=__DIR__ . '/mobile_config.php';
    if (!is_file($path)) return [];
    $config=require $path;
    return is_array($config)?$config:[];
}

function mobile_google_keys() {
    $path=__DIR__ . '/config-data/google-certs.json';
    $cached=json_decode(@file_get_contents($path)?:'{}',true);
    if (is_array($cached) && ($cached['expires']??0)>time() && is_array($cached['keys']??null)) return $cached['keys'];
    $curl=curl_init('https://www.googleapis.com/oauth2/v1/certs');
    curl_setopt_array($curl,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>8,CURLOPT_CONNECTTIMEOUT=>3]);
    $body=curl_exec($curl); $status=curl_getinfo($curl,CURLINFO_HTTP_CODE); curl_close($curl);
    $keys=json_decode($body?:'',true);
    if ($status!==200 || !is_array($keys) || !$keys) throw new MobileError('google_unavailable',503);
    // Cache public certificates only; keys and cache are never accepted from callers.
    @file_put_contents($path,json_encode(['expires'=>time()+300,'keys'=>$keys]),LOCK_EX);
    return $keys;
}

function mobile_google_claims($token, $audience, $keys) {
    if (!is_string($token) || strlen($token)>12000 || !is_string($audience) || $audience==='') throw new MobileError('google_not_configured',503);
    try {
      $trusted=[];
      foreach ($keys as $id=>$key) $trusted[$id]=new Firebase\JWT\Key($key,'RS256');
      $payload=Firebase\JWT\JWT::decode($token,$trusted);
      if (!isset($payload->aud,$payload->iss,$payload->exp,$payload->sub) || $payload->aud!==$audience ||
          !in_array($payload->iss,['accounts.google.com','https://accounts.google.com'],true) ||
          !is_string($payload->sub) || !preg_match('/^[0-9]{1,255}$/D',$payload->sub)) throw new RuntimeException('claims');
      $name=isset($payload->name)&&is_string($payload->name)?trim($payload->name):null;
      if($name!==null)$name=mb_substr(preg_replace('/[\p{C}<>]/u','',$name),0,128);
      $email=($payload->email_verified??false)===true && is_string($payload->email??null) && filter_var($payload->email,FILTER_VALIDATE_EMAIL) ? $payload->email : null;
      return ['sub'=>$payload->sub,'name'=>$name?:null,'email'=>$email];
    } catch (Throwable $error) { throw new MobileError('google_token_invalid',401); }
}

function mobile_google_link(PDO $pdo, $player, $subject, $prefix='') {
    $players=mobile_table('mobile_players',$prefix);
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE"); $query->execute([$player['id']]); $current=$query->fetch();
      if (!$current) throw new MobileError('unauthorized',401);
      if ($current['google_sub'] && $current['google_sub']!==$subject) throw new MobileError('google_already_linked',409);
      $query=$pdo->prepare("SELECT id FROM $players WHERE google_sub=?"); $query->execute([$subject]); $other=$query->fetchColumn();
      if ($other && (int)$other!==(int)$player['id']) throw new MobileError('google_profile_exists',409);
      $pdo->prepare("UPDATE $players SET google_sub=? WHERE id=?")->execute([$subject,$player['id']]);
      $pdo->commit(); $current['google_sub']=$subject; return mobile_profile($current);
    } catch (Throwable $error) {
      if ($pdo->inTransaction()) $pdo->rollBack();
      if ($error instanceof PDOException && (int)($error->errorInfo[1]??0)===1062) throw new MobileError('google_profile_exists',409);
      throw $error;
    }
}

// This is an authenticated game-account operation, not a call to Google.
// The durable receipt must win over any later link: replaying a lost unlink
// response cannot disconnect a newly linked account.
function mobile_google_unlink(PDO $pdo,$player,$operationId,$now,$prefix='') {
    if(!is_string($operationId)||!preg_match('/^[a-f0-9]{64}$/D',$operationId))throw new MobileError('operation_invalid');
    $players=mobile_table('mobile_players',$prefix);$operations=mobile_table('mobile_operations',$prefix);
    $pdo->beginTransaction();
    try {
      $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$q->execute([$player['id']]);$current=$q->fetch(PDO::FETCH_ASSOC);
      if(!$current)throw new MobileError('unauthorized',401);
      $q=$pdo->prepare("SELECT player_id FROM $operations WHERE id=?");$q->execute([$operationId]);$receiptOwner=$q->fetchColumn();
      if($receiptOwner!==false) {
        if((int)$receiptOwner!==(int)$current['id'])throw new MobileError('operation_conflict',409);
        $pdo->commit();return mobile_profile($current);
      }
      $raw=$current['wallet_json']??null;
      $wallet=$raw===null||$raw===''?mobile_wallet($current,tg_load_economy()):json_decode($raw,true);
      if(!is_array($wallet))throw new MobileError('wallet_unavailable',503);
      $changed=$current['google_sub']!==null||array_key_exists('_googleIdentity',$wallet)||($wallet['_hideGoogleAccount']??true)!==true;
      if($changed) {
        unset($wallet['_googleIdentity']);$wallet['_hideGoogleAccount']=true;
        $pdo->prepare("UPDATE $players SET google_sub=NULL WHERE id=?")->execute([$current['id']]);
        mobile_wallet_write($pdo,$current['id'],$wallet,$prefix);
        $current['google_sub']=null;$current['wallet_json']=json_encode($wallet);$current['wallet_version']++;
      }
      $pdo->prepare("INSERT INTO $operations (id,player_id,created_at) VALUES (?,?,?)")->execute([$operationId,$current['id'],$now]);
      $pdo->commit();return mobile_profile($current);
    }catch(Throwable $error) {
      if($pdo->inTransaction())$pdo->rollBack();
      // Two different authenticated owners can race for an identical key. The
      // unique receipt rejects the loser and rolls back its unlink atomically.
      if($error instanceof PDOException&&(int)($error->errorInfo[1]??0)===1062)throw new MobileError('operation_conflict',409);
      throw $error;
    }
}

function mobile_google_restore(PDO $pdo, $subject, $newSecret, $installation, $prefix='') {
    if (!is_string($newSecret) || !preg_match('/^[a-f0-9]{64}$/D',$newSecret)) throw new MobileError('credentials_invalid');
    if (!is_string($installation) || !preg_match('/^[a-f0-9]{32}$/D',$installation)) throw new MobileError('credentials_invalid');
    $players=mobile_table('mobile_players',$prefix);
    $pdo->beginTransaction();
    try {
      $query=$pdo->prepare("SELECT * FROM $players WHERE google_sub=? FOR UPDATE"); $query->execute([$subject]); $row=$query->fetch();
      if (!$row) throw new MobileError('google_profile_not_found',404);
      // A verified Google token adds this device; other phones retain their own secrets.
      $devices=mobile_table('mobile_devices',$prefix);
      $pdo->prepare("INSERT INTO $devices (installation_hash,secret_hash,player_id) VALUES (?,?,?) ON DUPLICATE KEY UPDATE secret_hash=VALUES(secret_hash),player_id=VALUES(player_id)")->execute([hash('sha256',$installation),hash('sha256',$newSecret),$row['id']]);
      $pdo->commit(); return mobile_profile($row);
    } catch (Throwable $error) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $error; }
}

function mobile_google_verified_subject($token) {
    $config=mobile_private_config(); $audience=$config['google_web_client_id']??'';
    if (!is_string($audience) || $audience==='') throw new MobileError('google_not_configured',503);
    return mobile_google_subject($token,$audience,mobile_google_keys());
}

function mobile_google_subject($token,$audience,$keys) {return mobile_google_claims($token,$audience,$keys)['sub'];}
function mobile_google_verified_claims($token) {
    $config=mobile_private_config();$audience=$config['google_web_client_id']??'';
    if(!is_string($audience)||$audience==='')throw new MobileError('google_not_configured',503);
    return mobile_google_claims($token,$audience,mobile_google_keys());
}
