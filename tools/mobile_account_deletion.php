<?php
// Private operator library. Never expose this file as a web endpoint.
function mobile_deletion_id($publicId) {
    if (!is_string($publicId) || !preg_match('/^android:([1-9][0-9]{0,7})$/D', $publicId, $match))
        throw new InvalidArgumentException('Exact Android public ID required');
    return (int)$match[1];
}
function mobile_deletion_conditions($id) {
    return ['mobile_rounds'=>['player_id',$id], 'mobile_purchases'=>['player_id',$id],
      'mobile_operations'=>['player_id',$id], 'mobile_names'=>['owner','android:' . $id],
      'mobile_devices'=>['player_id',$id], 'scores'=>['user_id','android:' . $id],
      'mobile_players'=>['id',$id]];
}
function mobile_deletion_counts(PDO $pdo, $id, $prefix) {
    $counts=[];
    foreach (mobile_deletion_conditions($id) as $table=>[$column,$value]) {
        $query=$pdo->prepare('SELECT COUNT(*) FROM ' . mobile_table($table,$prefix) . " WHERE `$column`=?");
        $query->execute([$value]); $counts[$table]=(int)$query->fetchColumn();
    }
    return $counts;
}
function mobile_deletion_review(PDO $pdo, $publicId, $prefix='') {
    $id=mobile_deletion_id($publicId);
    // No migrations, writes, exports, nickname matching, or credentials in output.
    $query=$pdo->prepare('SELECT id,created_at,nickname FROM ' . mobile_table('mobile_players',$prefix) . ' WHERE id=?');
    $query->execute([$id]); $row=$query->fetch(PDO::FETCH_ASSOC);
    return ['id'=>$publicId,'exists'=>(bool)$row,'counts'=>mobile_deletion_counts($pdo,$id,$prefix),
      'fingerprint'=>$row?hash('sha256',json_encode($row)):null];
}
function mobile_deletion_execute(PDO $pdo, $publicId, $challengeNickname, $fingerprint, $confirmation, $prefix='', $testPurchases=false) {
    $id=mobile_deletion_id($publicId);
    if ($confirmation!=='DELETE ' . $publicId || !is_string($challengeNickname) || $challengeNickname==='')
        throw new InvalidArgumentException('Ownership challenge and exact confirmation required');
    if ($pdo->inTransaction()) throw new RuntimeException('A dedicated connection is required');
    foreach (array_keys(mobile_deletion_conditions($id)) as $table) {
        $query=$pdo->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?');
        $query->execute([$prefix . $table]);
        if (strtoupper((string)$query->fetchColumn())!=='INNODB')
            throw new RuntimeException('All seven tables must support transactions; nothing deleted');
    }
    // Production purchase retention requires a separate reviewed policy.
    if ($testPurchases && !preg_match('/^_untouch_mobile_test_[a-f0-9]+_$/D',$prefix))
        throw new RuntimeException('Purchase override is restricted to disposable fixtures');
    $pdo->beginTransaction();
    try {
        $query=$pdo->prepare('SELECT id,created_at,nickname FROM ' . mobile_table('mobile_players',$prefix) . ' WHERE id=? FOR UPDATE');
        $query->execute([$id]); $row=$query->fetch(PDO::FETCH_ASSOC);
        if (!$row) throw new RuntimeException('Profile not found; nothing deleted');
        if (!hash_equals((string)$row['nickname'],$challengeNickname) ||
            !is_string($fingerprint) || !hash_equals(hash('sha256',json_encode($row)),$fingerprint))
            throw new RuntimeException('Ownership challenge or review changed; nothing deleted');
        $counts=mobile_deletion_counts($pdo,$id,$prefix);
        if ($counts['mobile_purchases']>0 && !$testPurchases)
            throw new RuntimeException('Purchase records require a reviewed retention/refund procedure');
        foreach (mobile_deletion_conditions($id) as $table=>[$column,$value]) {
            $query=$pdo->prepare('DELETE FROM ' . mobile_table($table,$prefix) . " WHERE `$column`=?");
            $query->execute([$value]);
        }
        $remaining=mobile_deletion_counts($pdo,$id,$prefix);
        if (array_sum($remaining)!==0) throw new RuntimeException('Remaining linked data; rolled back');
        $pdo->commit();
        return ['id'=>$publicId,'deleted'=>$counts,'remaining'=>$remaining];
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $error;
    }
}
