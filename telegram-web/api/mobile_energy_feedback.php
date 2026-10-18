<?php
require_once __DIR__.'/mobile_energy.php';
// Delivery is explicitly scheduled by the operator. Wallet operations only
// persist the outbox; retries never revisit the energy grant.
function mobile_energy_deliver_feedback(PDO $pdo,callable $send,$now,$prefix='',$limit=25) {
    $table=mobile_energy_feedback_table($prefix);$limit=max(1,min(100,(int)$limit));$delivered=0;
    for($i=0;$i<$limit;$i++) {
      $pdo->beginTransaction();
      try {
        $q=$pdo->prepare("SELECT * FROM $table WHERE delivery_state='pending' OR (delivery_state='sending' AND last_attempt_at<?) ORDER BY created_at LIMIT 1 FOR UPDATE");
        $q->execute([$now-600000]);$row=$q->fetch(PDO::FETCH_ASSOC);
        if(!$row){$pdo->commit();break;}
        $pdo->prepare("UPDATE $table SET delivery_state='sending',attempts=attempts+1,last_attempt_at=? WHERE id=?")->execute([$now,$row['id']]);$pdo->commit();
        $ok=false;
        try {$ok=$send('support@untouch.fun','Untouch: отзыв игрока android:'.$row['player_id'],
          'ID: '.$row['id']."\n".'Оценка: '.($row['rating']??'не указана')."\n\n".$row['comment'])===true;}catch(Throwable $e){$ok=false;}
        $pdo->prepare("UPDATE $table SET delivery_state=?,delivered_at=? WHERE id=? AND delivery_state='sending' AND last_attempt_at=?")->execute([$ok?'delivered':'pending',$ok?$now:null,$row['id'],$now]);
        if($ok)$delivered++;else break; // back off instead of looping on one failure
      }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();throw $e;}
    }
    return $delivered;
}
