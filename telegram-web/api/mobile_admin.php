<?php
require_once __DIR__.'/mobile_store.php';
require_once __DIR__.'/mobile_wallet.php';
function mobile_admin_fingerprint($row) {
    return hash('sha256',json_encode([$row['id'],$row['nickname'],$row['google_sub'],(int)$row['wallet_version']]));
}
function mobile_admin_users(PDO $pdo, $q, $filter, $page, $today, $week, $prefix='') {
    $players=mobile_table('mobile_players',$prefix);$rounds=mobile_table('mobile_rounds',$prefix);$scores=mobile_table('scores',$prefix);
    $where=['1=1'];$params=[];
    if($q!=='') {
      $where[]="(CAST(p.id AS CHAR) LIKE ? OR CONCAT('android:',p.id) LIKE ? OR p.nickname LIKE ? OR p.google_sub LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.wallet_json,'$._googleIdentity.email')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.wallet_json,'$._googleIdentity.name')) LIKE ?)";
      $params=array_fill(0,6,'%'.$q.'%');
    }
    if(in_array($filter,['today','week','new_today','new_week'],true)){
      $where[]=(strpos($filter,'new_')===0?'p.created_at':'COALESCE(r.last_seen,p.created_at)').'>=?';$params[]=strpos($filter,'week')!==false?$week:$today;
    }elseif($filter==='played'||$filter==='started')$where[]='r.last_seen IS NOT NULL';
    elseif($filter==='blocked')$where[]='0=1';
    elseif($filter==='premium'){$where[]="CAST(JSON_EXTRACT(p.wallet_json,'$.plusUntil') AS UNSIGNED)>?";$params[]=(int)round(microtime(true)*1000);}
    $from="FROM $players p LEFT JOIN (SELECT player_id,MAX(started_at) last_seen,COUNT(*) games FROM $rounds GROUP BY player_id) r ON r.player_id=p.id";
    $whereSql=implode(' AND ',$where);$stmt=$pdo->prepare("SELECT COUNT(*) $from WHERE $whereSql");$stmt->execute($params);$total=(int)$stmt->fetchColumn();
    $limit=50;$offset=($page-1)*$limit;$stmt=$pdo->prepare("SELECT p.*,r.games,COALESCE(r.last_seen,p.created_at) last_seen $from WHERE $whereSql ORDER BY last_seen DESC,p.id DESC LIMIT $limit OFFSET $offset");$stmt->execute($params);$items=[];
    foreach($stmt as $row){$identity=mobile_identity_private($row);$items[]=[
      'userId'=>'android:'.$row['id'],'platform'=>'android','nickname'=>$row['nickname'],
      'googleName'=>$identity['googleName'],'googleEmail'=>$identity['googleEmail'],'googleLinked'=>!empty($row['google_sub']),
      'googleSubject'=>$row['google_sub'],'hideGoogleAccount'=>$identity['hideGoogleAccount'],
      'username'=>'','firstName'=>$identity['googleName']??'','lastName'=>'','language'=>'','isPremium'=>false,'blocked'=>false,
      'firstSeenAt'=>(int)$row['created_at'],'lastSeenAt'=>(int)$row['last_seen'],'messageCount'=>0,'startCount'=>(int)($row['games']??0),
      'lastKind'=>empty($row['google_sub'])?'Гость':'Google','lastText'=>'','played'=>!empty($row['games']),'invitedBy'=>'',
      'deleteFingerprint'=>mobile_admin_fingerprint($row)];}
    return ['ok'=>true,'page'=>$page,'pages'=>max(1,(int)ceil($total/$limit)),'total'=>$total,'filter'=>$filter,'q'=>$q,'items'=>$items];
}
function mobile_admin_delete(PDO $pdo,$id,$confirmed,$fingerprint,$prefix='') {
    if(!is_string($id)||!preg_match('/^android:([1-9][0-9]*)$/D',$id,$m)||$confirmed!==$id)throw new MobileError('delete_confirmation_required');
    $number=(int)$m[1];$players=mobile_table('mobile_players',$prefix);$pdo->beginTransaction();
    try{
      $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");$q->execute([$number]);$row=$q->fetch();
      if(!$row)throw new MobileError('profile_not_found',404);
      if(!is_string($fingerprint)||!hash_equals(mobile_admin_fingerprint($row),$fingerprint))throw new MobileError('profile_changed',409);
      foreach(['mobile_rounds','mobile_devices','mobile_operations','mobile_purchases'] as $name){$table=mobile_table($name,$prefix);$pdo->prepare("DELETE FROM $table WHERE player_id=?")->execute([$number]);}
      $names=mobile_table('mobile_names',$prefix);$scores=mobile_table('scores',$prefix);
      $pdo->prepare("DELETE FROM $names WHERE owner=?")->execute([$id]);$pdo->prepare("DELETE FROM $scores WHERE user_id=?")->execute([$id]);
      $pdo->prepare("DELETE FROM $players WHERE id=?")->execute([$number]);$pdo->commit();
      error_log('admin: deleted Android profile '.$id);
      return ['ok'=>true,'deletedId'=>$id];
    }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
}
