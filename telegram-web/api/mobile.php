<?php
require_once __DIR__ . '/tg_common.php';
require_once __DIR__ . '/gameplay_config.php';
require_once __DIR__ . '/mobile_store.php';
require_once __DIR__ . '/mobile_google_nickname.php';
require_once __DIR__ . '/mobile_wallet.php';
require_once __DIR__ . '/mobile_google.php';
require_once __DIR__ . '/mobile_play.php';
require_once __DIR__ . '/mobile_invites.php';
function mobile_rules_revision() {
  // Match config.php's effective public JSON, not the admin publication nonce.
  return hash('sha256',json_encode(gameplay_snapshot()['config'],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
}
tg_json_headers(); header('Cache-Control: no-store');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD']==='OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD']==='GET') {
  [$pdo]=tg_connect_pdo(); $identity=json_decode(ltrim(@file_get_contents(__DIR__.'/mobile-release.json')?:'{}',"\xEF\xBB\xBF"),true);
  echo json_encode(['ok'=>true,'buildId'=>$identity['buildId']??null,
    'schemaReady'=>$pdo && tg_schema_ready($pdo,'mobile',1),
    'rulesRevision'=>mobile_rules_revision(),
    'googleConfigured'=>!empty(mobile_private_config()['google_web_client_id']),
    'playConfigured'=>!empty(mobile_private_config()['play_service_account_path'])]); exit;
}
if ($_SERVER['REQUEST_METHOD']!=='POST') { http_response_code(405); echo '{"ok":false,"error":"method_not_allowed"}'; exit; }
try {
  $body=file_get_contents('php://input',false,null,0,16385);
  if (strlen($body)>16384) throw new MobileError('request_too_large',413);
  $input=json_decode($body,true); if (!is_array($input)) throw new MobileError('request_invalid');
  [$pdo]=tg_connect_pdo(); if (!$pdo) throw new MobileError('service_unavailable',503);
  if (!tg_schema_ready($pdo,'mobile',1)) throw new MobileError('maintenance_required',503);
  $action=$input['action'] ?? ''; $now=(int)round(microtime(true)*1000);
  $energyContract=$input['energyContract']??$input['economyVersion']??1;
  if ($action==='google_restore') {
    mobile_rate_limit('restore:' . ($_SERVER['REMOTE_ADDR']??''),30,$now);
    $config=mobile_private_config();
    $claims=mobile_google_verified_claims($input['idToken']??null);$subject=$claims['sub'];
    $restored=mobile_google_restore($pdo,$subject,$input['secret']??null,$input['installation']??null);
    $result=['profile'=>mobile_google_save_details($pdo,(int)substr($restored['id'],8),$claims)];
  }
  elseif ($action==='guest') {
    mobile_rate_limit('guest:' . ($_SERVER['REMOTE_ADDR']??''),30,$now);
    $result=['profile'=>mobile_guest($pdo,$input['installation']??null,$input['secret']??null,$now,'',$input['timezoneOffset']??180,$energyContract)];
  }
  else {
    $header=mobile_request_authorization(); $player=mobile_auth($pdo,strncmp($header,'Bearer ',7)===0 ? substr($header,7) : '');
    mobile_rate_limit('player:' . $player['id'],240,$now);
    $player=mobile_energy_prepare($pdo,$player,$now,$energyContract);
    switch ($action) {
      case 'invites_state': case 'invites_bind': case 'invites_list':
        $result=mobile_invites_action($pdo,$player,$input,$now); break;
      case 'google_link':
        $firstGoogleLink=empty($player['google_sub']);
        $config=mobile_private_config();
        $claims=mobile_google_verified_claims($input['idToken']??null);$subject=$claims['sub'];
        $linked=mobile_google_link($pdo,$player,$subject);
        $profile=mobile_google_save_details($pdo,$player['id'],$claims);
        $result=['profile'=>$firstGoogleLink ? mobile_google_nickname($pdo,$player) : $profile]; break;
      case 'google_details':
        $claims=mobile_google_verified_claims($input['idToken']??null);
        $result=['profile'=>mobile_google_save_details($pdo,$player['id'],$claims)];break;
      case 'google_unlink':
        $result=['profile'=>mobile_google_unlink($pdo,$player,$input['operationId']??null,$now)];break;
      case 'profile': $result=['profile'=>mobile_profile($player)]; break;
      case 'play_verify': $result=['profile'=>mobile_play_verify($pdo,$player,$input['productId']??'', $input['purchaseToken']??null,$now)]; break;
      case 'play_sync': $result=['profile'=>mobile_play_sync($pdo,$player,$now)]; break;
      case 'play_quote': $result=['quote'=>mobile_energy_quote($pdo,$player,$input['productId']??'',$input['requestId']??null,$now)];break;
      case 'wallet_operation':
        $testGrantReceipt=null;
        $result=['profile'=>mobile_wallet_mutate($pdo,$player,$input['operationId']??null,$input['kind']??null,$input['args']??[],$now,tg_load_economy(),'',null,$testGrantReceipt)];
        if($testGrantReceipt!==null)$result[($testGrantReceipt['kind']??null)==='energy_bonus_claim'?'bonusClaim':'energyGrant']=$testGrantReceipt;
        break;
      case 'rename': $result=['profile'=>mobile_rename($pdo,$player,$input['nickname']??null)]; break;
      case 'round_start':
        $result=mobile_round_start($pdo,$player,$now,'',$input['requestId']??null,(string)($input['rulesRevision']??''),
          ['currentRevision'=>mobile_rules_revision(),'economyVersion'=>$input['economyVersion']??1,'helmet'=>$input['helmet']??false,'jump'=>$input['jump']??false]); break;
      case 'round_cancel': $result=mobile_round_cancel($pdo,$player,$input['requestId']??null,$now);break;
      case 'round_activate': $result=mobile_round_activate($pdo,$player,$input['requestId']??null,$now);break;
      case 'round_finish': $result=mobile_round_finish($pdo,$player,$input,$now); break;
      default: throw new MobileError('action_invalid');
    }
  }
  if(isset($result['profile']['id'])&&in_array((int)$energyContract,[2,3],true)) {
    $q=$pdo->prepare('SELECT * FROM mobile_players WHERE id=?');$q->execute([(int)substr($result['profile']['id'],8)]);$fresh=$q->fetch();
    if($fresh)$result['profile']=mobile_profile(mobile_energy_prepare($pdo,$fresh,$now,$energyContract));
  }
  // Existing operations have committed; invitation rewards use their own atomic transaction.
  $inviteActor=isset($result['profile']['id']) ? (int)substr($result['profile']['id'],8) : (int)($player['id']??0);
  if ($inviteActor>0) $result=mobile_invites_after_action($pdo,$action,$inviteActor,$result,$now);
  echo json_encode(['ok'=>true]+$result,JSON_UNESCAPED_UNICODE);
} catch (MobileError $error) { http_response_code($error->status); echo json_encode(['ok'=>false,'error'=>$error->getMessage()]); }
catch (Throwable $error) { error_log('mobile: ' . get_class($error)); http_response_code(503); echo '{"ok":false,"error":"service_unavailable"}'; }
