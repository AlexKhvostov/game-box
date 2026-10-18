<?php
// Derive a public nickname only from email previously verified by Google.
// The registry's unique key is the authority, including simultaneous sign-ins.
function mobile_google_nickname(PDO $pdo, $player, $prefix = '') {
    $players=mobile_table('mobile_players',$prefix);
    $names=mobile_table('mobile_names',$prefix);
    $scores=mobile_table('scores',$prefix);
    $owner='android:'.$player['id'];
    $pdo->beginTransaction();
    try {
        $q=$pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");
        $q->execute([$player['id']]); $current=$q->fetch();
        if (!$current) throw new MobileError('unauthorized',401);
        $identity=mobile_identity_private($current);
        $email=$identity['googleEmail'];
        if (empty($current['google_sub']) ||
            !preg_match('/^user[0-9]{8}$/D',$current['nickname']) ||
            !is_string($email) || !filter_var($email,FILTER_VALIDATE_EMAIL)) {
            $pdo->commit(); return mobile_profile($current);
        }
        $local=trim(strstr($email,'@',true));
        $local=preg_replace('/[\p{C}<>]/u','',$local);
        if ($local==='') { $pdo->commit(); return mobile_profile($current); }
        $oldKey=mobile_name_key($current['nickname']);
        for ($counter=1;$counter<=1000;$counter++) {
            $suffix=mb_strlen($local)<5 ? '_'.str_pad((string)$counter,3,'0',STR_PAD_LEFT)
                : ($counter===1 ? '' : '_'.$counter);
            $name=mobile_name(mb_substr($local,0,40-mb_strlen($suffix)).$suffix);
            $key=mobile_name_key($name);
            if ($key===$oldKey) { $pdo->commit(); return mobile_profile($current); }
            try {
                $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?)")
                    ->execute([$key,$owner,$name]);
            } catch (PDOException $error) {
                if ((int)($error->errorInfo[1]??0)===1062) continue;
                throw $error;
            }
            $pdo->prepare("UPDATE $players SET nickname=? WHERE id=?")->execute([$name,$player['id']]);
            $pdo->prepare("UPDATE $scores SET player_name=? WHERE user_id=?")->execute([$name,$owner]);
            $pdo->prepare("DELETE FROM $names WHERE name_key=? AND owner=?")->execute([$oldKey,$owner]);
            $pdo->commit(); $current['nickname']=$name; return mobile_profile($current);
        }
        // Sign-in remains successful even if the nickname space is exhausted.
        $pdo->commit(); return mobile_profile($current);
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $error;
    }
}
