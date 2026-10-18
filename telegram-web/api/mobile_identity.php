<?php
// Personal Google details are returned only in the authenticated owner profile.
function mobile_identity_private($row) {
    $wallet=json_decode($row['wallet_json']??'',true)?:[];
    $identity=is_array($wallet['_googleIdentity']??null)?$wallet['_googleIdentity']:[];
    $linked=!empty($row['google_sub']);
    return ['googleName'=>$linked?($identity['name']??null):null,
      'googleEmail'=>$linked?($identity['email']??null):null,
      'hideGoogleAccount'=>($wallet['_hideGoogleAccount']??true)!==false];
}
function mobile_identity_public_name($row) {
    $details=mobile_identity_private($row);
    return $details['hideGoogleAccount']?null:$details['googleName'];
}
function mobile_google_save_details(PDO $pdo, $playerId, $claims, $prefix='') {
    $players=mobile_table('mobile_players',$prefix);
    $pdo->beginTransaction();
    try {
      $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$q->execute([$playerId]);$row=$q->fetch();
      if(!$row || empty($row['google_sub']) || !hash_equals($row['google_sub'],$claims['sub'])) throw new MobileError('google_account_mismatch',409);
      $wallet=mobile_wallet($row,tg_load_economy());
      $wallet['_googleIdentity']=['name'=>$claims['name'],'email'=>$claims['email']];
      if(!isset($wallet['_hideGoogleAccount']))$wallet['_hideGoogleAccount']=true;
      mobile_wallet_write($pdo,$playerId,$wallet,$prefix);
      $row['wallet_json']=json_encode($wallet);$row['wallet_version']++;
      $pdo->commit();return mobile_profile($row);
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}
function mobile_identity_public_scores(PDO $pdo, $scores, $prefix='') {
    $ids=[];
    foreach($scores as $score)if(preg_match('/^android:([0-9]+)$/D',$score['userId']??'', $m))$ids[]=(int)$m[1];
    if(!$ids)return $scores;
    $players=mobile_table('mobile_players',$prefix);$names=[];
    $q=$pdo->prepare("SELECT id,google_sub,wallet_json FROM $players WHERE id IN (".implode(',',array_fill(0,count($ids),'?')).")");$q->execute($ids);
    foreach($q as $row)$names['android:'.$row['id']]=mobile_identity_public_name($row);
    foreach($scores as &$score)if(strpos($score['userId']??'','android:')===0){
      // Clear legacy personal fields for Android even when public display is opted in.
      $score['username']=null;$score['firstName']=null;$score['lastName']=null;$score['photoUrl']=null;$score['hideTelegram']=true;
      $score['googleName']=$names[$score['userId']]??null;
    }
    unset($score);return $scores;
}
