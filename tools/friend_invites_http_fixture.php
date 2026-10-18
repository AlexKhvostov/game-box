<?php
// Copied only into a private loopback test tree; never deploy this controller.
function fixture_meta() {
    $path=dirname(__DIR__,2).'/control.json';
    $meta=json_decode(@file_get_contents($path)?:'',true);
    if (!is_array($meta) || ($meta['dsn']??'')!=='mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4') throw new RuntimeException('Fixture configuration guard');
    return $meta;
}
function fixture_pdo() {
    $m=fixture_meta();
    $pdo=new PDO($m['dsn'],'root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
    if ($pdo->query('SELECT DATABASE()')->fetchColumn()!=='untouch_friend_invites_tests' || (int)$pdo->query('SELECT @@port')->fetchColumn()!==43317) throw new RuntimeException('Fixture database guard');
    return $pdo;
}
function fixture_tables() {
    return ['mobile_invite_ledger','mobile_invites','mobile_invite_codes','mobile_operations','mobile_purchases','mobile_names','mobile_devices','mobile_rounds','mobile_players','scores','schema_versions'];
}
if (PHP_SAPI==='cli') {
    if (($argv[1]??'')!=='--cleanup') exit(2);
    try {
        $pdo=fixture_pdo();$owned=fixture_tables();
        foreach ($owned as $table) $pdo->exec('DROP TABLE IF EXISTS `'.$table.'`');
        echo json_encode(['remaining'=>$pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN)]);exit;
    } catch (Throwable $error) { fwrite(STDERR,'Fixture cleanup failed');exit(1); }
}
header('Content-Type: application/json');
try {
    $meta=fixture_meta();
    if (($_SERVER['REMOTE_ADDR']??'')!=='127.0.0.1' || !hash_equals($meta['controlSecret'],$_SERVER['HTTP_X_FIXTURE_CONTROL']??'')) { http_response_code(404);echo '{}';exit; }
    require_once __DIR__.'/tg_common.php';require_once __DIR__.'/gameplay_config.php';
    require_once __DIR__.'/mobile_store.php';require_once __DIR__.'/mobile_wallet.php';
    require_once __DIR__.'/mobile_google.php';require_once __DIR__.'/mobile_google_nickname.php';
    require_once __DIR__.'/mobile_invites.php';
    $body=json_decode(file_get_contents('php://input'),true)?:[];
    $pdo=fixture_pdo();$action=$body['action']??'';
    if ($action==='bootstrap') {
        if ($pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN)) throw new RuntimeException('Fixture database must start empty');
        $pdo->exec("CREATE TABLE scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day VARCHAR(10),user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT DEFAULT 0,risk_count INT DEFAULT 0,score BIGINT DEFAULT 0,had_jump TINYINT DEFAULT 0,had_helmet TINYINT DEFAULT 0,created_at BIGINT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        mobile_migrate($pdo);tg_schema_complete($pdo,'mobile',1);
        $key=openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA,'config'=>'C:/xampp/php/extras/ssl/openssl.cnf']);
        if (!$key || !openssl_pkey_export($key,$private,null,['config'=>'C:/xampp/php/extras/ssl/openssl.cnf'])) throw new RuntimeException('Synthetic signing key generation');
        $public=openssl_pkey_get_details($key)['key'];
        file_put_contents(dirname(__DIR__,2).'/fixture-private.pem',$private);
        file_put_contents(__DIR__.'/config-data/google-certs.json',json_encode(['expires'=>time()+3600,'keys'=>['fixture-only'=>$public]]));
        $result=['tableCount'=>count($pdo->query('SHOW TABLES')->fetchAll())];
    } elseif ($action==='migrate_invites') {
        mobile_invites_migrate($pdo);$result=['ready'=>mobile_invites_schema_ready($pdo)];
    } elseif ($action==='token') {
        $sub=(string)($body['subject']??'');
        if (!preg_match('/^[0-9]{1,10}$/D',$sub)) throw new RuntimeException('Synthetic subject only');
        $key=file_get_contents(dirname(__DIR__,2).'/fixture-private.pem');
        $token=Firebase\JWT\JWT::encode(['iss'=>'https://accounts.google.com','aud'=>'fixture-local.apps.googleusercontent.com','sub'=>$sub,'iat'=>time()-10,'exp'=>time()+1800,'name'=>'Fixture Person '.$sub,'email'=>'fixture'.$sub.'@example.test','email_verified'=>true],$key,'RS256','fixture-only');
        $result=['idToken'=>$token];
    } elseif ($action==='seed') {
        $player=mobile_auth($pdo,$body['playerSecret']??'');
        $wallet=mobile_wallet($player,tg_load_economy());
        $wallet=array_replace($wallet,['lives'=>100,'tokens'=>(int)($body['tokens']??17),'bestTimeMs'=>(int)($body['bestTimeMs']??25000),'plusUntil'=>(int)round(microtime(true)*1000)+36000000,'claimed'=>['install_bonus'],'unlocked'=>['survive_10s'],'_fixturePreserve'=>$body['marker']??'unchanged']);
        mobile_wallet_write($pdo,$player['id'],$wallet);$result=['seeded'=>true];
    } elseif ($action==='history') {
        $player=mobile_auth($pdo,$body['playerSecret']??'');$now=(int)round(microtime(true)*1000);
        $q=$pdo->prepare('INSERT INTO mobile_rounds (id,player_id,started_at,finished_at,result_json,context_json) VALUES (?,?,?,?,?,?)');
        for($i=0;$i<5;$i++)$q->execute([bin2hex(random_bytes(32)),$player['id'],$now-10000,$now-9000,json_encode(['ok'=>true,'score'=>0]),json_encode(['economy'=>tg_load_economy(),'hadJump'=>false,'hadHelmet'=>false])]);
        $result=['stagedHistoricalFinishedRows'=>5];
    } elseif ($action==='inspect') {
        $id=isset($body['playerId'])?(int)$body['playerId']:(int)mobile_auth($pdo,$body['playerSecret']??'')['id'];
        $player=mobile_invites_player($pdo,$id);
        $q=$pdo->prepare('SELECT COUNT(*) FROM mobile_rounds WHERE player_id=? AND finished_at IS NOT NULL');$q->execute([$id]);$finished=(int)$q->fetchColumn();
        $has=mobile_invites_schema_ready($pdo);$count=0;$sum=0;
        if($has){$q=$pdo->prepare('SELECT COUNT(*),COALESCE(SUM(amount),0) FROM mobile_invite_ledger WHERE recipient_id=?');$q->execute([$id]);[$count,$sum]=$q->fetch(PDO::FETCH_NUM);}
        $result=['finished'=>$finished,'wallet'=>mobile_wallet($player,tg_load_economy()),'ledgerRows'=>(int)$count,'ledgerSum'=>(int)$sum,'tables'=>$pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN)];
    } else throw new RuntimeException('Unknown fixture action');
    echo json_encode(['ok'=>true]+$result);
} catch (Throwable $error) { http_response_code(500);echo json_encode(['ok'=>false,'error'=>'fixture_failed','kind'=>get_class($error)]); }
