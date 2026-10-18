<?php
// Local disposable fixtures only. No FTP, production configuration, Google tokens or player data.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
function tg_load_economy() {
    return ['initialLives'=>100,'initialTokens'=>0,'timedBonusTokens'=>4,'runRewardEvery'=>200,'runRewardTokens'=>1,
        'riskRewardEvery'=>5,'riskRewardTokens'=>1,'earnSurviveSeconds'=>10,'earnRecordSeconds'=>20,
        'earnRisksInRun'=>5,'installBonusAutoClaim'=>false];
}
function tg_local_gameplay_config() { return ['game'=>['jumpEnabled'=>true,'helmetEnabled'=>true]]; }
require_once __DIR__ . '/../telegram-web/api/mobile_invites.php';
require_once __DIR__ . '/../telegram-web/api/mobile_google.php';
require_once __DIR__ . '/../telegram-web/api/mobile_admin.php';
require_once __DIR__ . '/mobile_account_deletion.php';

function fi_connect() {
    $dsn = getenv('UNTOUCH_INVITES_TEST_DSN');
    if (!is_string($dsn) || !preg_match('/^mysql:host=127\.0\.0\.1;port=[0-9]+;dbname=untouch_friend_invites_tests;charset=utf8mb4$/D', $dsn)) {
        throw new RuntimeException('Only the isolated localhost invitation-test database is allowed');
    }
    $pdo = new PDO($dsn, getenv('UNTOUCH_INVITES_TEST_USER') ?: 'root', getenv('UNTOUCH_INVITES_TEST_PASSWORD') ?: '',
        [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES=>false, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
    $pdo->exec('SET SESSION innodb_lock_wait_timeout=3');
    return $pdo;
}
function fi_prefix($prefix) {
    if (!is_string($prefix) || !preg_match('/^_fi_[a-f0-9]{16}_$/D', $prefix)) throw new RuntimeException('Fixture prefix required');
    return $prefix;
}
function fi_check($condition, $label) {
    if (!$condition) throw new RuntimeException('Assertion failed: ' . $label);
    $GLOBALS['fi_checks'][] = $label;
}
function fi_error(callable $work, $expected, $label) {
    try { $work(); } catch (MobileError $error) { fi_check($error->getMessage()===$expected,$label); return; }
    throw new RuntimeException('Expected ' . $expected . ': ' . $label);
}
function fi_player(PDO $pdo, $prefix, $linked=false) {
    $installation=bin2hex(random_bytes(16)); $secret=bin2hex(random_bytes(32));
    $profile=mobile_guest($pdo,$installation,$secret,2000000000000,$prefix);
    $player=mobile_auth($pdo,$secret,$prefix);
    if($linked) mobile_google_link($pdo,$player,'fixture-google-'.$player['id'],$prefix);
    return ['id'=>(int)$player['id'],'installation'=>$installation,'secret'=>$secret];
}
function fi_row(PDO $pdo, $prefix, $who) { return mobile_invites_player($pdo,$who['id'],$prefix); }
function fi_wallet(PDO $pdo, $prefix, $who) { return mobile_wallet(fi_row($pdo,$prefix,$who),tg_load_economy()); }
function fi_call(PDO $pdo, $prefix, $who, $action, array $args=[]) {
    $player=mobile_auth($pdo,$who['secret'],$prefix);
    return mobile_invites_action($pdo,$player,['action'=>$action]+$args,2000001000000,$prefix);
}
function fi_code(PDO $pdo, $prefix, $who) { return fi_call($pdo,$prefix,$who,'invites_state')['invites']['ownCode']; }
function fi_round(PDO $pdo, $prefix, $who, $finish=true) {
    $started=mobile_round_start($pdo,fi_row($pdo,$prefix,$who),2000000000000,$prefix);
    if(!$finish) return $started['roundId'];
    $input=['roundId'=>$started['roundId'],'timeMs'=>1000,'runDistance'=>0,'riskCount'=>0,'hadJump'=>false,'hadHelmet'=>false];
    $result=mobile_round_finish($pdo,fi_row($pdo,$prefix,$who),$input,2000000001100,$prefix);
    return [$input,$result];
}
function fi_history(PDO $pdo, $prefix, $who, $count=5) {
    $rounds=mobile_table('mobile_rounds',$prefix);
    $query=$pdo->prepare("INSERT INTO $rounds (id,player_id,started_at,finished_at,result_json,context_json) VALUES (?,?,?,?,?,?)");
    for($i=0;$i<$count;$i++)$query->execute([bin2hex(random_bytes(32)),$who['id'],2000000000000,2000000001000,
        json_encode(['ok'=>true,'score'=>0]),json_encode(['economy'=>tg_load_economy(),'hadJump'=>false,'hadHelmet'=>false])]);
}
function fi_ledger(PDO $pdo, $prefix, $who) {
    $query=$pdo->prepare('SELECT COUNT(*),COALESCE(SUM(amount),0) FROM '.mobile_invite_table('mobile_invite_ledger',$prefix).' WHERE recipient_id=?');
    $query->execute([$who['id']]);return $query->fetch(PDO::FETCH_NUM);
}
function fi_batch($prefix, array $jobs) {
    fi_prefix($prefix);$processes=[];$at=sprintf('%.6f',microtime(true)+1.2);
    foreach($jobs as $job){
        $args=[PHP_BINARY,__FILE__,'--worker='.$job['kind'],'--prefix='.$prefix,'--id='.$job['id'],'--at='.$at];
        if(isset($job['code']))$args[]='--code='.$job['code'];
        $pipes=[];$process=proc_open($args,[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,null,['bypass_shell'=>true]);
        if(!is_resource($process))throw new RuntimeException('Could not start a concurrent fixture worker');
        fclose($pipes[0]);$processes[]=[$process,$pipes];
    }
    $results=[];
    foreach($processes as [$process,$pipes]){
        $stdout=stream_get_contents($pipes[1]);$stderr=stream_get_contents($pipes[2]);fclose($pipes[1]);fclose($pipes[2]);
        $exit=proc_close($process);$result=json_decode($stdout,true);
        if($exit!==0||!is_array($result))throw new RuntimeException('Concurrent worker failed: '.($stderr?:$stdout));
        $results[]=$result;
    }
    return $results;
}

$options=getopt('',['worker:','prefix:','id:','code:','at:']);
if(isset($options['worker'])){
    try{
        $prefix=fi_prefix($options['prefix']??'');$pdo=fi_connect();$id=(int)($options['id']??0);
        $at=(float)($options['at']??0);while(microtime(true)<$at)usleep(1000);
        if($options['worker']==='code')$result=['code'=>mobile_invites_own_code($pdo,$id,2000001000000,$prefix)];
        elseif($options['worker']==='pay')$result=['paid'=>mobile_invites_reconcile($pdo,$id,2000001000000,$prefix)];
        elseif($options['worker']==='wallet')$result=['profile'=>mobile_wallet_mutate($pdo,mobile_invites_player($pdo,$id,$prefix),bin2hex(random_bytes(32)),
            'timed',[],2000001000000,tg_load_economy(),$prefix,false)];
        elseif($options['worker']==='bind'){
            try{$result=['created'=>mobile_invites_bind($pdo,$id,$options['code']??'','manual',2000001000000,$prefix)];}
            catch(MobileError $e){$result=['error'=>$e->getMessage()];}
        }else throw new RuntimeException('Unknown fixture worker');
        echo json_encode($result);exit;
    }catch(Throwable $error){fwrite(STDERR,get_class($error).': '.$error->getMessage());exit(1);}
}

$prefix=fi_prefix('_fi_'.bin2hex(random_bytes(8)).'_');$longPrefix=$prefix.str_repeat('x',40-strlen($prefix));
$pdo=null;$checks=[];$GLOBALS['fi_checks']=[];$failure=null;$cleaned=false;
$oldTables=['scores','mobile_players','mobile_names','mobile_rounds','mobile_devices','mobile_operations','mobile_purchases'];
$newTables=['mobile_invite_codes','mobile_invites','mobile_invite_ledger'];
try{
    $pdo=fi_connect();$scores=mobile_table('scores',$prefix);
    $pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day VARCHAR(10),user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT DEFAULT 0,risk_count INT DEFAULT 0,score BIGINT DEFAULT 0,had_jump TINYINT DEFAULT 0,had_helmet TINYINT DEFAULT 0,created_at BIGINT) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    mobile_migrate($pdo,$prefix);
    $a=fi_player($pdo,$prefix,true);$b=fi_player($pdo,$prefix,true);$c=fi_player($pdo,$prefix,true);
    fi_check(!mobile_invites_schema_ready($pdo,$prefix),'missing-schema: no invitation tables');
    fi_error(function()use($pdo,$prefix,$a){fi_call($pdo,$prefix,$a,'invites_state');},'invites_unavailable','missing-schema: invite API unavailable, no auto-DDL');
    $legacy=['profile'=>mobile_profile(fi_row($pdo,$prefix,$a))];
    fi_check(mobile_invites_after_action($pdo,'profile',$a['id'],$legacy,2000001000000,$prefix)===$legacy,'missing-schema: old profile result unchanged');
    foreach(['google_link','google_restore','google_details'] as $action)
        fi_check(mobile_invites_after_action($pdo,$action,$a['id'],$legacy,2000001000000,$prefix)===$legacy,'missing-schema: old '.$action.' result unchanged');
    [$roundInput,$roundResult]=fi_round($pdo,$prefix,$a);
    fi_check(mobile_invites_after_action($pdo,'round_finish',$a['id'],$roundResult,2000001000000,$prefix)===$roundResult,'missing-schema: old round acknowledgement unchanged');
    $oldSchema=[];foreach($oldTables as $name){$row=$pdo->query('SHOW CREATE TABLE '.mobile_table($name,$prefix))->fetch(PDO::FETCH_NUM);$oldSchema[$name]=$row[1];}
    mobile_invites_migrate($pdo,$prefix);fi_check(mobile_invites_schema_ready($pdo,$prefix),'migration: three invitation tables ready');
    $pdo->exec('CREATE TABLE '.mobile_table('mobile_players',$longPrefix).' (id INT UNSIGNED PRIMARY KEY) ENGINE=InnoDB');
    mobile_invites_migrate($pdo,$longPrefix);
    fi_check(mobile_invites_schema_ready($pdo,$longPrefix),'migration: safe long fixture prefix supported');
    mobile_invites_migrate($pdo,$prefix);
    foreach($oldTables as $name){$row=$pdo->query('SHOW CREATE TABLE '.mobile_table($name,$prefix))->fetch(PDO::FETCH_NUM);fi_check($oldSchema[$name]===$row[1],'migration: existing schema preserved '.$name);}
    $aCode=fi_code($pdo,$prefix,$a);$bCode=fi_code($pdo,$prefix,$b);$cCode=fi_code($pdo,$prefix,$c);
    fi_check(strlen($aCode)===12 && mobile_invite_code(' '.strtolower($aCode).' ')===$aCode,'code: cryptographic format/case normalization');
    fi_check(fi_code($pdo,$prefix,$a)===$aCode && count(array_unique([$aCode,$bCode,$cCode]))===3,'code: stable unique owners');
    foreach([null,[],123,'','I23456789234','123456789234','ＡAAAAAAAAAAA',str_repeat('A',65),$aCode."\nX",'AA AA AA AA AA'] as $invalid){
        fi_error(function()use($pdo,$prefix,$b,$invalid){fi_call($pdo,$prefix,$b,'invites_bind',['code'=>$invalid]);},'invite_code_invalid','invalid-code: '.gettype($invalid).'/'.(is_string($invalid)?strlen($invalid):0));
    }
    fi_error(function()use($pdo,$prefix,$b){fi_call($pdo,$prefix,$b,'invites_bind',['code'=>'AAAAAAAAAAAA']);},'invite_not_found','code: nonexistent rejected');
    fi_error(function()use($pdo,$prefix,$b,$bCode){fi_call($pdo,$prefix,$b,'invites_bind',['code'=>$bCode]);},'invite_self','code: same canonical profile rejected');
    fi_error(function()use($pdo,$prefix,$b,$aCode){fi_call($pdo,$prefix,$b,'invites_bind',['code'=>$aCode,'source'=>'invented']);},'invite_source_invalid','code: invalid source rejected without binding');
    fi_check(fi_call($pdo,$prefix,$b,'invites_state')['invites']['inviterAssigned']===false,'invalid attempts: binding remains free');
    $bound=fi_call($pdo,$prefix,$b,'invites_bind',['code'=>$aCode,'playerId'=>$a['id'],'inviterId'=>$c['id']]);
    fi_check($bound['bindingCreated']===true && $bound['invites']['profileId']==='android:'.$b['id'] && $bound['invites']['inviterCode']===$aCode,'bind: authenticated profile overrides supplied IDs');
    fi_check($bound['invites']['bonusStatus']==='waiting_games' && fi_ledger($pdo,$prefix,$a)[0]==0,'bind: zero games does not pay');
    fi_check(fi_call($pdo,$prefix,$a,'invites_list')['invites']['paidRows']===[],'list: pending invitation hidden');
    fi_error(function()use($pdo,$prefix){mobile_auth($pdo,str_repeat('0',64),$prefix);},'unauthorized','authorization: unknown device secret cannot use canonical account');
    fi_error(function()use($pdo,$prefix){mobile_auth($pdo,null,$prefix);},'unauthorized','authorization: missing secret denied');
    $starts=[];for($i=0;$i<5;$i++)$starts[]=fi_round($pdo,$prefix,$b,false);
    fi_check(mobile_invites_completed_games($pdo,$b['id'],$prefix)===0 && fi_call($pdo,$prefix,$b,'invites_state')['invites']['bonusStatus']==='waiting_games','five starts/crashes: no activation');
    for($i=0;$i<4;$i++){
        $input=['roundId'=>$starts[$i],'timeMs'=>1000,'runDistance'=>0,'riskCount'=>0,'hadJump'=>false,'hadHelmet'=>false];
        $result=mobile_round_finish($pdo,fi_row($pdo,$prefix,$b),$input,2000000001100,$prefix);
        mobile_invites_after_action($pdo,'round_finish',$b['id'],$result,2000001000000,$prefix);
    }
    fi_check(mobile_invites_completed_games($pdo,$b['id'],$prefix)===4 && fi_ledger($pdo,$prefix,$a)[0]==0,'four finishes: no payout');
    $walletA=fi_wallet($pdo,$prefix,$a);$walletB=fi_wallet($pdo,$prefix,$b);
    $input=['roundId'=>$starts[4],'timeMs'=>1000,'runDistance'=>0,'riskCount'=>0,'hadJump'=>false,'hadHelmet'=>false];
    $result=mobile_round_finish($pdo,fi_row($pdo,$prefix,$b),$input,2000000001100,$prefix);
    fi_check(mobile_invites_after_action($pdo,'round_finish',$b['id'],$result,2000001000000,$prefix)===$result,'fifth finish: old acknowledgement preserved');
    $expectedA=$walletA;$expectedA['tokens']+=10;$expectedB=$walletB;$expectedB['tokens']+=10;
    fi_check(fi_wallet($pdo,$prefix,$a)===$expectedA && fi_wallet($pdo,$prefix,$b)===$expectedB,'fifth finish: exactly 10/10, other wallet fields unchanged');
    fi_check(fi_ledger($pdo,$prefix,$a)==[1,10] && fi_ledger($pdo,$prefix,$b)==[1,10],'fifth finish: two ledger operations only');
    $paidState=fi_call($pdo,$prefix,$b,'invites_state');
    fi_check($paidState['invites']['bonusStatus']==='rewarded' && $paidState['invites']['completedGames']===5,'state: activation threshold and reward');
    for($i=0;$i<3;$i++){
        mobile_round_finish($pdo,fi_row($pdo,$prefix,$b),$input,2000000001100,$prefix);
        mobile_invites_after_action($pdo,'round_finish',$b['id'],$result,2000001000000,$prefix);
        fi_check(fi_call($pdo,$prefix,$b,'invites_bind',['code'=>strtolower($aCode)])['bindingCreated']===false,'repeat: same code is idempotent '.$i);
    }
    fi_error(function()use($pdo,$prefix,$b,$cCode){fi_call($pdo,$prefix,$b,'invites_bind',['code'=>$cCode,'source'=>'install_referrer']);},'invite_already_bound','late second code cannot replace first');
    fi_check(fi_ledger($pdo,$prefix,$a)==[1,10] && fi_wallet($pdo,$prefix,$b)===$expectedB,'repeat/late source: no double payout');
    $hist=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$hist);
    $histState=fi_call($pdo,$prefix,$hist,'invites_bind',['code'=>$cCode]);
    fi_check($histState['invites']['bonusStatus']==='rewarded' && $histState['profile']['wallet']['tokens']===10,'historical five games: manual code pays immediately');
    $d=fi_player($pdo,$prefix,false);$e=fi_player($pdo,$prefix,false);$dCode=fi_code($pdo,$prefix,$d);fi_history($pdo,$prefix,$e);
    fi_call($pdo,$prefix,$e,'invites_bind',['code'=>$dCode]);
    fi_check(fi_ledger($pdo,$prefix,$d)[0]==0,'Google absent both: no payout');
    $eLinked=mobile_google_link($pdo,fi_row($pdo,$prefix,$e),'fixture-google-'.$e['id'],$prefix);
    mobile_invites_after_action($pdo,'google_link',$e['id'],['profile'=>$eLinked],2000001000000,$prefix);
    fi_check(fi_ledger($pdo,$prefix,$d)[0]==0,'Google invitee first: waits for inviter');
    $dLinked=mobile_google_link($pdo,fi_row($pdo,$prefix,$d),'fixture-google-'.$d['id'],$prefix);
    $dResult=mobile_invites_after_action($pdo,'google_link',$d['id'],['profile'=>$dLinked],2000001000000,$prefix);
    fi_check($dResult['profile']['wallet']['tokens']===10 && fi_ledger($pdo,$prefix,$e)==[1,10],'Google inviter later: both rewards and fresh profile');
    $first=fi_player($pdo,$prefix,true);$second=fi_player($pdo,$prefix,false);$firstCode=fi_code($pdo,$prefix,$first);fi_history($pdo,$prefix,$second);
    fi_call($pdo,$prefix,$second,'invites_bind',['code'=>$firstCode]);
    $secondLinked=mobile_google_link($pdo,fi_row($pdo,$prefix,$second),'fixture-google-'.$second['id'],$prefix);
    mobile_invites_after_action($pdo,'google_link',$second['id'],['profile'=>$secondLinked],2000001000000,$prefix);
    fi_check(fi_ledger($pdo,$prefix,$first)==[1,10],'Google inviter first: invitee later triggers payout');

    $bulk=fi_player($pdo,$prefix,false);$bulkCode=fi_code($pdo,$prefix,$bulk);$children=[];
    for($i=0;$i<51;$i++){
        $child=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$child);
        mobile_invites_bind($pdo,$child['id'],$bulkCode,'manual',2000001000000,$prefix);$children[]=$child;
    }
    $bulkLinked=mobile_google_link($pdo,fi_row($pdo,$prefix,$bulk),'fixture-google-'.$bulk['id'],$prefix);
    $bulkResult=mobile_invites_after_action($pdo,'google_link',$bulk['id'],['profile'=>$bulkLinked],2000001000000,$prefix);
    fi_check($bulkResult['profile']['wallet']['tokens']===510 && fi_ledger($pdo,$prefix,$bulk)==[51,510],'delayed inviter Google: all 51 paid, no recipient cap');
    $listed=[];$before=null;
    do{$page=fi_call($pdo,$prefix,$bulk,'invites_list',['limit'=>20,'before'=>$before])['invites'];
        fi_check($page['rewardTotal']===510,'pagination: total covers all paid rows');
        foreach($page['paidRows'] as $row)$listed[]=$row['id'];$before=$page['nextCursor'];
    }while($before!==null);
    fi_check(count($listed)===51 && count(array_unique($listed))===51,'pagination: all rows once across three pages');
    fi_error(function()use($pdo,$prefix,$bulk){fi_call($pdo,$prefix,$bulk,'invites_list',['limit'=>101]);},'invite_page_invalid','pagination: bounded page size');
    fi_error(function()use($pdo,$prefix,$bulk){fi_call($pdo,$prefix,$bulk,'invites_list',['before'=>'0 OR 1']);},'invite_page_invalid','pagination: cursor SQL text rejected');

    $g=fi_player($pdo,$prefix,false);$gWallet=fi_wallet($pdo,$prefix,$g);for($i=0;$i<6;$i++)fi_round($pdo,$prefix,$g);
    $guestBound=fi_call($pdo,$prefix,$g,'invites_bind',['code'=>$aCode,'source'=>'app_link']);
    fi_check($guestBound['invites']['bonusStatus']==='waiting_google' && fi_wallet($pdo,$prefix,$g)['tokens']===$gWallet['tokens'],'historical guest: games count, Google still required');
    $gLinked=mobile_google_link($pdo,fi_row($pdo,$prefix,$g),'fixture-google-'.$g['id'],$prefix);
    mobile_invites_after_action($pdo,'google_link',$g['id'],['profile'=>$gLinked],2000001000000,$prefix);
    fi_check(fi_wallet($pdo,$prefix,$g)['tokens']===10,'new Google on same guest: historical games retained');
    $old=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$old);
    $transient=fi_player($pdo,$prefix,false);fi_history($pdo,$prefix,$transient,7);
    $transientBefore=fi_wallet($pdo,$prefix,$transient);$oldBefore=fi_wallet($pdo,$prefix,$old);
    $restored=mobile_google_restore($pdo,'fixture-google-'.$old['id'],$transient['secret'],$transient['installation'],$prefix);
    $restoredWho=['id'=>$old['id'],'secret'=>$transient['secret'],'installation'=>$transient['installation']];
    $newAuth=mobile_auth($pdo,$transient['secret'],$prefix);
    fi_check($newAuth['id']===$old['id'] && $restored['id']==='android:'.$old['id'],'restore: credentials now select existing canonical account');
    fi_check(fi_wallet($pdo,$prefix,$old)===$oldBefore && fi_wallet($pdo,$prefix,$transient)===$transientBefore,'restore: guest wallet not merged');
    $restoredState=fi_call($pdo,$prefix,$restoredWho,'invites_bind',['code'=>$cCode,'source'=>'install_referrer']);
    fi_check($restoredState['invites']['bonusStatus']==='rewarded' && $restoredState['invites']['inviterCode']===$cCode,'restore: pending code applies to canonical historical profile');
    $oldFresh=fi_player($pdo,$prefix,true);$guestPlayed=fi_player($pdo,$prefix,false);fi_history($pdo,$prefix,$guestPlayed,6);
    mobile_google_restore($pdo,'fixture-google-'.$oldFresh['id'],$guestPlayed['secret'],$guestPlayed['installation'],$prefix);
    $freshWho=['id'=>$oldFresh['id'],'secret'=>$guestPlayed['secret'],'installation'=>$guestPlayed['installation']];
    $freshState=fi_call($pdo,$prefix,$freshWho,'invites_bind',['code'=>$cCode]);
    fi_check($freshState['invites']['bonusStatus']==='waiting_games' && $freshState['invites']['completedGames']===0,'restore: guest games cannot activate old canonical profile');

    $rollbackA=fi_player($pdo,$prefix,true);$rollbackB=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$rollbackB);$rollbackCode=fi_code($pdo,$prefix,$rollbackA);
    $players=mobile_table('mobile_players',$prefix);$trigger=$prefix.'reward_failure';
    $pdo->exec("CREATE TRIGGER `$trigger` BEFORE UPDATE ON $players FOR EACH ROW BEGIN IF NEW.id=".$rollbackB['id']." AND JSON_EXTRACT(NEW.wallet_json,'$.tokens')>JSON_EXTRACT(OLD.wallet_json,'$.tokens') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='fixture reward failure'; END IF; END");
    $failed=false;try{fi_call($pdo,$prefix,$rollbackB,'invites_bind',['code'=>$rollbackCode]);}catch(PDOException $error){$failed=true;}
    fi_check($failed && fi_wallet($pdo,$prefix,$rollbackA)['tokens']===0 && fi_wallet($pdo,$prefix,$rollbackB)['tokens']===0 && fi_ledger($pdo,$prefix,$rollbackA)[0]==0,'forced failure after first wallet: both wallets/ledger roll back');
    [$committedInput,$committedFinish]=fi_round($pdo,$prefix,$rollbackB);
    fi_check(mobile_invites_after_action($pdo,'round_finish',$rollbackB['id'],$committedFinish,2000001000000,$prefix)===$committedFinish,
        'deferred failed payout: committed round acknowledgement remains successful');
    fi_check(fi_ledger($pdo,$prefix,$rollbackA)[0]==0 && fi_wallet($pdo,$prefix,$rollbackA)['tokens']===0 && fi_wallet($pdo,$prefix,$rollbackB)['tokens']===0,
        'deferred failed payout: no half-credit left behind');
    $pdo->exec("DROP TRIGGER `$trigger`");
    $rollbackRetry=fi_call($pdo,$prefix,$rollbackB,'invites_bind',['code'=>$rollbackCode]);
    fi_check($rollbackRetry['bindingCreated']===false && fi_wallet($pdo,$prefix,$rollbackA)['tokens']===10 && fi_wallet($pdo,$prefix,$rollbackB)['tokens']===10,'retry after interrupted bind response: same relationship, one payout');

    $raceA=fi_player($pdo,$prefix,true);$raceB=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$raceB);$raceCode=fi_code($pdo,$prefix,$raceA);
    mobile_invites_bind($pdo,$raceB['id'],$raceCode,'manual',2000001000000,$prefix);
    $aVersion=(int)fi_row($pdo,$prefix,$raceA)['wallet_version'];$bVersion=(int)fi_row($pdo,$prefix,$raceB)['wallet_version'];
    $jobs=[];for($i=0;$i<8;$i++)$jobs[]=['kind'=>'pay','id'=>$i%2?$raceA['id']:$raceB['id']];
    $race=fi_batch($prefix,$jobs);$wins=array_sum(array_column($race,'paid'));
    fi_check($wins===1 && fi_ledger($pdo,$prefix,$raceA)==[1,10] && fi_ledger($pdo,$prefix,$raceB)==[1,10],'eight concurrent payouts: one winning pair');
    fi_check((int)fi_row($pdo,$prefix,$raceA)['wallet_version']===$aVersion+1 && (int)fi_row($pdo,$prefix,$raceB)['wallet_version']===$bVersion+1,'eight concurrent payouts: versions increment exactly once');
    $additiveA=fi_player($pdo,$prefix,true);$additiveB=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$additiveB);
    mobile_invites_bind($pdo,$additiveB['id'],fi_code($pdo,$prefix,$additiveA),'manual',2000001000000,$prefix);
    fi_batch($prefix,[['kind'=>'pay','id'=>$additiveA['id']],['kind'=>'wallet','id'=>$additiveA['id']],
        ['kind'=>'wallet','id'=>$additiveB['id']],['kind'=>'pay','id'=>$additiveB['id']]]);
    fi_check(fi_wallet($pdo,$prefix,$additiveA)['tokens']===14 && fi_wallet($pdo,$prefix,$additiveB)['tokens']===14,
        'concurrent old wallet operations: 4 timed plus 10 invite preserved for both');
    $raceBind=fi_player($pdo,$prefix,false);$jobs=[];for($i=0;$i<6;$i++)$jobs[]=['kind'=>'bind','id'=>$raceBind['id'],'code'=>$i%2?$aCode:$cCode];
    $bindRace=fi_batch($prefix,$jobs);$created=0;
    foreach($bindRace as $row){if(!empty($row['created']))$created++;fi_check(!isset($row['error'])||$row['error']==='invite_already_bound','concurrent bind: only expected conflict');}
    fi_check($created===1 && in_array(fi_call($pdo,$prefix,$raceBind,'invites_state')['invites']['inviterCode'],[$aCode,$cCode],true),'concurrent different codes: first committed valid binding wins');
    $raceCodePlayer=fi_player($pdo,$prefix,false);$jobs=[];for($i=0;$i<5;$i++)$jobs[]=['kind'=>'code','id'=>$raceCodePlayer['id']];
    fi_check(count(array_unique(array_column(fi_batch($prefix,$jobs),'code')))===1,'concurrent code allocation: one stable owner code');
    $cycleA=fi_player($pdo,$prefix,true);$cycleB=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$cycleA);fi_history($pdo,$prefix,$cycleB);
    $cycleACode=fi_code($pdo,$prefix,$cycleA);$cycleBCode=fi_code($pdo,$prefix,$cycleB);
    mobile_invites_bind($pdo,$cycleA['id'],$cycleBCode,'manual',2000001000000,$prefix);mobile_invites_bind($pdo,$cycleB['id'],$cycleACode,'manual',2000001000000,$prefix);
    fi_batch($prefix,[['kind'=>'pay','id'=>$cycleA['id']],['kind'=>'pay','id'=>$cycleB['id']],['kind'=>'pay','id'=>$cycleA['id']],['kind'=>'pay','id'=>$cycleB['id']]]);
    fi_check(fi_wallet($pdo,$prefix,$cycleA)['tokens']===20 && fi_wallet($pdo,$prefix,$cycleB)['tokens']===20,'different own profiles: reciprocal invitations allowed without lock failure');

    $privateWallet=fi_wallet($pdo,$prefix,$b);$privateWallet['_googleIdentity']=['name'=>'Private fixture','email'=>'fixture@example.test'];$privateWallet['_hideGoogleAccount']=false;
    $privateWallet['plusUntil']=2000009000000;$privateWallet['claimed']=['fixture_existing_bonus'];$privateWallet['opaqueFixture']=['preserve'=>true];
    mobile_wallet_write($pdo,$b['id'],$privateWallet,$prefix);
    $public=json_encode(fi_call($pdo,$prefix,$a,'invites_state')['invites']);
    fi_check(strpos($public,'fixture@example.test')===false && strpos($public,'fixture-google-')===false && strpos($public,'Private fixture')===false,'privacy: paid-only data contains no Google identity');
    $protectedA=fi_player($pdo,$prefix,true);$protectedB=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$protectedB);
    $walletProtected=fi_wallet($pdo,$prefix,$protectedB);$walletProtected['_googleIdentity']=['name'=>'Personal','email'=>'private@example.test'];$walletProtected['_hideGoogleAccount']=false;
    $walletProtected['plusUntil']=2000009999000;$walletProtected['claimed']=['install_bonus'];$walletProtected['opaqueFixture']=['nested'=>true];
    mobile_wallet_write($pdo,$protectedB['id'],$walletProtected,$prefix);
    fi_call($pdo,$prefix,$protectedB,'invites_bind',['code'=>fi_code($pdo,$prefix,$protectedA)]);$walletProtected['tokens']+=10;
    fi_check(fi_wallet($pdo,$prefix,$protectedB)===$walletProtected,'reward: private identity/Plus/claimed/custom wallet fields preserved');

    $deleteInviter=fi_player($pdo,$prefix,true);$deleteInvitee=fi_player($pdo,$prefix,true);$deletedCode=fi_code($pdo,$prefix,$deleteInviter);
    fi_call($pdo,$prefix,$deleteInvitee,'invites_bind',['code'=>$deletedCode]);
    $deleteRow=fi_row($pdo,$prefix,$deleteInviter);$publicId='android:'.$deleteInviter['id'];
    mobile_admin_delete($pdo,$publicId,$publicId,mobile_admin_fingerprint($deleteRow),$prefix);
    $deletedState=fi_call($pdo,$prefix,$deleteInvitee,'invites_state')['invites'];
    fi_check($deletedState['inviterAssigned']===true && $deletedState['inviterCode']===$deletedCode && $deletedState['bonusStatus']==='inviter_unavailable','deleted inviter: opaque binding remains locked');
    fi_error(function()use($pdo,$prefix,$deleteInvitee,$cCode){fi_call($pdo,$prefix,$deleteInvitee,'invites_bind',['code'=>$cCode]);},'invite_already_bound','deleted inviter: cannot rebind for another bonus');
    $unbound=fi_player($pdo,$prefix,true);
    fi_error(function()use($pdo,$prefix,$unbound,$deletedCode){fi_call($pdo,$prefix,$unbound,'invites_bind',['code'=>$deletedCode]);},'invite_not_found','deleted inviter: tombstone code cannot invite new profiles');
    $deletePaid=fi_player($pdo,$prefix,true);fi_history($pdo,$prefix,$deletePaid);fi_call($pdo,$prefix,$deletePaid,'invites_bind',['code'=>$cCode]);
    $historyBefore=fi_call($pdo,$prefix,$c,'invites_list')['invites'];$paidRow=fi_row($pdo,$prefix,$deletePaid);
    $publicId='android:'.$deletePaid['id'];$review=mobile_deletion_review($pdo,$publicId,$prefix);
    mobile_deletion_execute($pdo,$publicId,$paidRow['nickname'],$review['fingerprint'],'DELETE '.$publicId,$prefix);
    $historyAfter=fi_call($pdo,$prefix,$c,'invites_list')['invites'];
    fi_check($historyAfter['rewardTotal']===$historyBefore['rewardTotal'] && count($historyAfter['paidRows'])===count($historyBefore['paidRows']),'deleted paid invitee: inviter paid history and total preserved');
    fi_check(count(array_filter($historyAfter['paidRows'],function($row){return $row['nickname']===null;}))===1,'deleted paid invitee: nickname anonymized');
    $invites=mobile_invite_table('mobile_invites',$prefix);$ledger=mobile_invite_table('mobile_invite_ledger',$prefix);$codes=mobile_invite_table('mobile_invite_codes',$prefix);
    foreach([$deleteInviter['id'],$deletePaid['id']] as $removed){
        $q=$pdo->prepare("SELECT (SELECT COUNT(*) FROM $invites WHERE invitee_id=? OR inviter_id=?)+(SELECT COUNT(*) FROM $ledger WHERE recipient_id=?)+(SELECT COUNT(*) FROM $codes WHERE player_id=?)");$q->execute([$removed,$removed,$removed,$removed]);
        fi_check((int)$q->fetchColumn()===0,'deleted profile: no remaining identifiable invite references '.$removed);
    }
    $migrationWallet=fi_wallet($pdo,$prefix,$a);mobile_invites_migrate($pdo,$prefix);
    fi_check(fi_wallet($pdo,$prefix,$a)===$migrationWallet && fi_code($pdo,$prefix,$a)===$aCode,'migration replay: existing balances and codes preserved');
    $unchanged=['profile'=>mobile_profile(fi_row($pdo,$prefix,$a))];
    fi_check(mobile_invites_after_action($pdo,'wallet_operation',$a['id'],$unchanged,2000001000000,$prefix)===$unchanged,'scope: unrelated wallet action receives no invite hook');
}catch(Throwable $error){$failure=get_class($error).': '.$error->getMessage();}
finally{
    if($pdo){
        try{
            if($pdo->inTransaction())$pdo->rollBack();
            foreach(['mobile_invite_ledger','mobile_invites','mobile_invite_codes'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_invite_table($name,$prefix));
            foreach(['mobile_invite_ledger','mobile_invites','mobile_invite_codes'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_invite_table($name,$longPrefix));
            $pdo->exec('DROP TABLE IF EXISTS '.mobile_table('mobile_players',$longPrefix));
            foreach(['mobile_rounds','mobile_purchases','mobile_operations','mobile_names','mobile_devices','scores','mobile_players'] as $name)$pdo->exec('DROP TABLE IF EXISTS '.mobile_table($name,$prefix));
            $query=$pdo->prepare('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND LEFT(TABLE_NAME,?)=?');$query->execute([strlen($prefix),$prefix]);$cleaned=(int)$query->fetchColumn()===0;
        }catch(Throwable $cleanupError){$failure=($failure?$failure.'; ':'').'Cleanup failed: '.get_class($cleanupError);}
    }
}
echo json_encode(['ok'=>$failure===null && $cleaned,'checks'=>count($GLOBALS['fi_checks']),'passed'=>$GLOBALS['fi_checks'],
    'fixturePrefix'=>$prefix,'cleaned'=>$cleaned,'failure'=>$failure],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
exit($failure===null && $cleaned?0:1);
