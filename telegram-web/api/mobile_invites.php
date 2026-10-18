<?php
// Android invitations are independent of Telegram referrals. No DDL in player requests.
require_once __DIR__ . '/mobile_store.php';
require_once __DIR__ . '/mobile_wallet.php';

const MOBILE_INVITE_REWARD = 10;
const MOBILE_INVITE_REQUIRED_GAMES = 5;
const MOBILE_INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const MOBILE_INVITE_CODE_LENGTH = 12;

function mobile_invite_table($name, $prefix = '') {
    if (!is_string($prefix) || !preg_match('/^[a-z0-9_]{0,40}$/D', $prefix) ||
        !in_array($name, ['mobile_invite_codes', 'mobile_invites', 'mobile_invite_ledger'], true)) {
        throw new InvalidArgumentException('Invalid invitation table');
    }
    return '`' . $prefix . $name . '`';
}

function mobile_invites_schema_ready(PDO $pdo, $prefix = '') {
    $names = ['mobile_invite_codes', 'mobile_invites', 'mobile_invite_ledger'];
    foreach ($names as $name) mobile_invite_table($name, $prefix);
    $query = $pdo->prepare("SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN (?,?,?)");
    $query->execute(array_map(function ($name) use ($prefix) { return $prefix . $name; }, $names));
    $rows = $query->fetchAll(PDO::FETCH_ASSOC);
    if (count($rows) !== 3) return false;
    foreach ($rows as $row) if (strtoupper($row['ENGINE']) !== 'INNODB') return false;
    return true;
}

function mobile_invites_require_schema(PDO $pdo, $prefix = '') {
    if (!mobile_invites_schema_ready($pdo, $prefix)) throw new MobileError('invites_unavailable', 503);
}
function mobile_invites_energy_schema(PDO $pdo,$prefix='') {
    $q=$pdo->prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME='currency'");
    $q->execute([$prefix.'mobile_invite_ledger']);return (int)$q->fetchColumn()===1;
}

// Explicit maintenance only. Existing account, wallet, round and schema-version tables stay intact.
function mobile_invites_migrate(PDO $pdo, $prefix = '') {
    if ($pdo->inTransaction()) throw new RuntimeException('Invitation maintenance needs a dedicated connection');
    $players = mobile_table('mobile_players', $prefix);
    $codes = mobile_invite_table('mobile_invite_codes', $prefix);
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $ledger = mobile_invite_table('mobile_invite_ledger', $prefix);
    // Explicit short names also support disposable prefixes near MySQL's 64-character limit.
    $fkTag = substr(hash('sha256', $prefix), 0, 16);
    $query = $pdo->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?');
    $query->execute([$prefix . 'mobile_players']);
    if (strtoupper((string)$query->fetchColumn()) !== 'INNODB') throw new RuntimeException('Invitation maintenance requires existing InnoDB accounts');
    $pdo->exec("CREATE TABLE IF NOT EXISTS $codes (
        code CHAR(12) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
        player_id INT UNSIGNED NULL UNIQUE, created_at BIGINT UNSIGNED NOT NULL,
        CONSTRAINT `fi_code_owner_$fkTag` FOREIGN KEY (player_id) REFERENCES $players (id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS $invites (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        invitee_id INT UNSIGNED NULL UNIQUE, inviter_id INT UNSIGNED NULL,
        inviter_code CHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        source VARCHAR(16) CHARACTER SET ascii NOT NULL,
        bound_at BIGINT UNSIGNED NOT NULL, rewarded_at BIGINT UNSIGNED NULL,
        KEY inviter_pending (inviter_id,rewarded_at,id),
        CONSTRAINT `fi_invite_guest_$fkTag` FOREIGN KEY (invitee_id) REFERENCES $players (id) ON DELETE SET NULL,
        CONSTRAINT `fi_invite_host_$fkTag` FOREIGN KEY (inviter_id) REFERENCES $players (id) ON DELETE SET NULL,
        CONSTRAINT `fi_invite_code_$fkTag` FOREIGN KEY (inviter_code) REFERENCES $codes (code)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS $ledger (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        invitation_id BIGINT UNSIGNED NOT NULL,
        side ENUM('inviter','invitee') NOT NULL,
        recipient_id INT UNSIGNED NULL,
        amount INT UNSIGNED NOT NULL, currency VARCHAR(16) NOT NULL DEFAULT 'crystals', revision VARCHAR(128) NULL, rewarded_at BIGINT UNSIGNED NOT NULL,
        UNIQUE invitation_side (invitation_id,side),
        KEY recipient_history (recipient_id,side,id),
        CONSTRAINT `fi_ledger_invite_$fkTag` FOREIGN KEY (invitation_id) REFERENCES $invites (id),
        CONSTRAINT `fi_ledger_player_$fkTag` FOREIGN KEY (recipient_id) REFERENCES $players (id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $column=$pdo->prepare("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME='currency'");
    $column->execute([$prefix.'mobile_invite_ledger']);
    if(!(int)$column->fetchColumn())$pdo->exec("ALTER TABLE $ledger ADD currency VARCHAR(16) NOT NULL DEFAULT 'crystals', ADD revision VARCHAR(128) NULL");
    mobile_invites_require_schema($pdo, $prefix);
}

function mobile_invite_code($value) {
    if (!is_string($value) || strlen($value) > 64) throw new MobileError('invite_code_invalid');
    $code = strtoupper(trim($value));
    if (!preg_match('/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}$/D', $code)) throw new MobileError('invite_code_invalid');
    return $code;
}

function mobile_invite_random_code() {
    $bytes = random_bytes(MOBILE_INVITE_CODE_LENGTH);
    $code = '';
    for ($i = 0; $i < MOBILE_INVITE_CODE_LENGTH; $i++) $code .= MOBILE_INVITE_ALPHABET[ord($bytes[$i]) & 31];
    return $code;
}

function mobile_invites_transaction(PDO $pdo, callable $work) {
    if ($pdo->inTransaction()) throw new RuntimeException('Invitation work cannot nest account transactions');
    for ($attempt = 0; $attempt < 4; $attempt++) {
        $pdo->beginTransaction();
        try {
            $result = $work();
            $pdo->commit();
            return $result;
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            if ($error instanceof PDOException && in_array((int)($error->errorInfo[1] ?? 0), [1213, 1205], true) && $attempt < 3) {
                usleep(10000 * ($attempt + 1));
                continue;
            }
            throw $error;
        }
    }
}

// Every invitation writer locks accounts in ascending order before invitation/ledger rows.
function mobile_invites_lock_players(PDO $pdo, array $ids, $prefix) {
    $ids = array_unique(array_map('intval', $ids));
    sort($ids, SORT_NUMERIC);
    $players = mobile_table('mobile_players', $prefix);
    $rows = [];
    $query = $pdo->prepare("SELECT * FROM $players WHERE id=? FOR UPDATE");
    foreach ($ids as $id) {
        $query->execute([$id]);
        $row = $query->fetch(PDO::FETCH_ASSOC);
        if ($row) $rows[$id] = $row;
    }
    return $rows;
}

function mobile_invites_player(PDO $pdo, $id, $prefix = '') {
    $query = $pdo->prepare('SELECT * FROM ' . mobile_table('mobile_players', $prefix) . ' WHERE id=?');
    $query->execute([(int)$id]);
    $row = $query->fetch(PDO::FETCH_ASSOC);
    if (!$row) throw new MobileError('unauthorized', 401);
    return $row;
}

function mobile_invites_own_code(PDO $pdo, $id, $now, $prefix = '') {
    $codes = mobile_invite_table('mobile_invite_codes', $prefix);
    return mobile_invites_transaction($pdo, function () use ($pdo, $id, $now, $prefix, $codes) {
        $players = mobile_invites_lock_players($pdo, [$id], $prefix);
        if (!isset($players[(int)$id])) throw new MobileError('unauthorized', 401);
        $query = $pdo->prepare("SELECT code FROM $codes WHERE player_id=? FOR UPDATE");
        $query->execute([(int)$id]);
        $existing = $query->fetchColumn();
        if ($existing !== false) return $existing;
        for ($attempt = 0; $attempt < 8; $attempt++) {
            $code = mobile_invite_random_code();
            try {
                $pdo->prepare("INSERT INTO $codes (code,player_id,created_at) VALUES (?,?,?)")->execute([$code, (int)$id, $now]);
                return $code;
            } catch (PDOException $error) {
                if ((int)($error->errorInfo[1] ?? 0) !== 1062) throw $error;
                // The player's lock prevents concurrent owner inserts. Only a random-code collision remains.
            }
        }
        throw new MobileError('invites_unavailable', 503);
    });
}

// The count is intentionally capped at the activation threshold, not an all-time statistic.
function mobile_invites_completed_games(PDO $pdo, $id, $prefix = '') {
    $rounds = mobile_table('mobile_rounds', $prefix);
    $query = $pdo->prepare("SELECT id FROM $rounds WHERE player_id=? AND finished_at IS NOT NULL AND (result_json IS NULL OR result_json NOT LIKE '%\"canceled\":true%') LIMIT 5");
    $query->execute([(int)$id]);
    return count($query->fetchAll(PDO::FETCH_COLUMN));
}

function mobile_invites_bind(PDO $pdo, $id, $value, $source, $now, $prefix = '') {
    mobile_invites_require_schema($pdo, $prefix);
    $code = mobile_invite_code($value);
    if (!is_string($source) || !in_array($source, ['manual', 'app_link', 'install_referrer'], true)) throw new MobileError('invite_source_invalid');
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $codes = mobile_invite_table('mobile_invite_codes', $prefix);
    $query = $pdo->prepare("SELECT inviter_code FROM $invites WHERE invitee_id=?");
    $query->execute([(int)$id]);
    $existing = $query->fetchColumn();
    if ($existing !== false) {
        if (!hash_equals($existing, $code)) throw new MobileError('invite_already_bound', 409);
        return false;
    }
    $query = $pdo->prepare("SELECT player_id FROM $codes WHERE code=?");
    $query->execute([$code]);
    $owner = $query->fetchColumn();
    if (!$owner) throw new MobileError('invite_not_found', 404);
    if ((int)$owner === (int)$id) throw new MobileError('invite_self', 409);
    return mobile_invites_transaction($pdo, function () use ($pdo, $id, $owner, $code, $source, $now, $prefix, $invites, $codes) {
        $players = mobile_invites_lock_players($pdo, [$id, $owner], $prefix);
        if (!isset($players[(int)$id])) throw new MobileError('unauthorized', 401);
        if (!isset($players[(int)$owner])) throw new MobileError('invite_not_found', 404);
        $query = $pdo->prepare("SELECT player_id FROM $codes WHERE code=? FOR UPDATE");
        $query->execute([$code]);
        if ((int)$query->fetchColumn() !== (int)$owner) throw new MobileError('invite_not_found', 404);
        $query = $pdo->prepare("SELECT inviter_code FROM $invites WHERE invitee_id=? FOR UPDATE");
        $query->execute([(int)$id]);
        $existing = $query->fetchColumn();
        if ($existing !== false) {
            if (!hash_equals($existing, $code)) throw new MobileError('invite_already_bound', 409);
            return false;
        }
        $pdo->prepare("INSERT INTO $invites (invitee_id,inviter_id,inviter_code,source,bound_at) VALUES (?,?,?,?,?)")
            ->execute([(int)$id, (int)$owner, $code, $source, $now]);
        return true;
    });
}

function mobile_invites_pay(PDO $pdo, $invitationId, $now, $prefix = '') {
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $ledger = mobile_invite_table('mobile_invite_ledger', $prefix);
    $query = $pdo->prepare("SELECT invitee_id,inviter_id FROM $invites WHERE id=?");
    $query->execute([$invitationId]);
    $candidate = $query->fetch(PDO::FETCH_ASSOC);
    if (!$candidate || !$candidate['invitee_id'] || !$candidate['inviter_id']) return false;
    return mobile_invites_transaction($pdo, function () use ($pdo, $candidate, $invitationId, $now, $prefix, $invites, $ledger) {
        $players = mobile_invites_lock_players($pdo, [$candidate['invitee_id'], $candidate['inviter_id']], $prefix);
        $query = $pdo->prepare("SELECT * FROM $invites WHERE id=? FOR UPDATE");
        $query->execute([$invitationId]);
        $invite = $query->fetch(PDO::FETCH_ASSOC);
        if (!$invite || $invite['rewarded_at'] !== null || !$invite['inviter_id'] || !$invite['invitee_id']) return false;
        $inviter = $players[(int)$invite['inviter_id']] ?? null;
        $invitee = $players[(int)$invite['invitee_id']] ?? null;
        if (!$inviter || !$invitee || empty($inviter['google_sub']) || empty($invitee['google_sub']) ||
            mobile_invites_completed_games($pdo, $invitee['id'], $prefix) < MOBILE_INVITE_REQUIRED_GAMES) return false;
        $config = tg_load_economy();
        foreach (['inviter' => $inviter, 'invitee' => $invitee] as $side => $player) {
            $wallet = mobile_wallet($player, $config);
            $v2=mobile_energy_is_v2($wallet);$energyConfig=mobile_energy_config($config);
            $amount=$v2?max(0,(int)$energyConfig['rewards']['invite']):MOBILE_INVITE_REWARD;
            if($v2&&$side==='inviter'&&mobile_bonus_is_active($wallet))$amount=mobile_bonus_policy($energyConfig)['inviterReward'];
            if(mobile_invites_energy_schema($pdo,$prefix))$pdo->prepare("INSERT INTO $ledger (invitation_id,side,recipient_id,amount,currency,revision,rewarded_at) VALUES (?,?,?,?,?,?,?)")
                ->execute([$invite['id'], $side, $player['id'], $amount,$v2?'energy':'crystals',$v2?$energyConfig['revision']:null, $now]);
            else {if($v2)throw new MobileError('maintenance_required',503);$pdo->prepare("INSERT INTO $ledger (invitation_id,side,recipient_id,amount,rewarded_at) VALUES (?,?,?,?,?)")->execute([$invite['id'],$side,$player['id'],$amount,$now]);}
            $field=$v2?'energy':'tokens';$wallet[$field]=(int)$wallet[$field]+$amount;
            mobile_wallet_write($pdo, $player['id'], $wallet, $prefix);
        }
        $pdo->prepare("UPDATE $invites SET rewarded_at=? WHERE id=?")->execute([$now, $invite['id']]);
        return true;
    });
}

// No recipient-count cap: linking the inviter must cover every eligible waiting invitation.
function mobile_invites_reconcile(PDO $pdo, $id, $now, $prefix = '') {
    mobile_invites_require_schema($pdo, $prefix);
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $players = mobile_table('mobile_players', $prefix);
    $query = $pdo->prepare("SELECT r.id FROM $invites r
        JOIN $players a ON a.id=r.inviter_id JOIN $players b ON b.id=r.invitee_id
        WHERE (r.invitee_id=? OR r.inviter_id=?) AND r.rewarded_at IS NULL
        AND a.google_sub IS NOT NULL AND a.google_sub<>'' AND b.google_sub IS NOT NULL AND b.google_sub<>'' ORDER BY r.id");
    $query->execute([(int)$id, (int)$id]);
    $ids = $query->fetchAll(PDO::FETCH_COLUMN);
    $paid = 0;
    foreach ($ids as $invitationId) if (mobile_invites_pay($pdo, $invitationId, $now, $prefix)) $paid++;
    return $paid;
}

function mobile_invites_paid_list(PDO $pdo, $id, $before = null, $limit = 50, $prefix = '', $pendingBefore = null) {
    if (!is_int($limit) || $limit < 1 || $limit > 100) throw new MobileError('invite_page_invalid');
    if ($before !== null && (!is_string($before) || !preg_match('/^[1-9][0-9]{0,18}$/D', $before))) throw new MobileError('invite_page_invalid');
    $ledger = mobile_invite_table('mobile_invite_ledger', $prefix);
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $players = mobile_table('mobile_players', $prefix);
    $ownerWallet=mobile_wallet(mobile_invites_player($pdo,$id,$prefix),tg_load_economy());$v2=mobile_energy_is_v2($ownerWallet);
    $hasCurrency=mobile_invites_energy_schema($pdo,$prefix);$currencySelect=$hasCurrency?'l.currency':"'crystals' AS currency";
    $sum=$v2?($hasCurrency?"CASE WHEN currency='energy' THEN amount ELSE amount*2 END":"amount*2"):"amount";
    $query = $pdo->prepare("SELECT COALESCE(SUM($sum),0) FROM $ledger WHERE recipient_id=? AND side='inviter'");
    $query->execute([(int)$id]);
    $total = (int)$query->fetchColumn();
    $where = "l.recipient_id=? AND l.side='inviter'";
    $params = [(int)$id];
    if ($before !== null) { $where .= ' AND l.id<?'; $params[] = $before; }
    $take = $limit + 1;
    $query = $pdo->prepare("SELECT l.id,l.amount,$currencySelect,l.rewarded_at,p.nickname
        FROM $ledger l JOIN $invites r ON r.id=l.invitation_id LEFT JOIN $players p ON p.id=r.invitee_id
        WHERE $where ORDER BY l.id DESC LIMIT $take");
    $query->execute($params);
    $rows = $query->fetchAll(PDO::FETCH_ASSOC);
    $more = count($rows) > $limit;
    $rows = array_slice($rows, 0, $limit);
    $items = [];
    foreach ($rows as $row) $items[] = ['id' => (string)$row['id'], 'nickname' => $row['nickname'],
        'rewardedAt' => (int)$row['rewarded_at'],'originalAmount'=>(int)$row['amount'],'originalCurrency'=>$row['currency'],
        'currency'=>$v2?'energy':$row['currency'],'energyEquivalent'=>(int)$row['amount']*($row['currency']!=='energy'?2:1),
        'amount' => (int)$row['amount']*($v2&&$row['currency']!=='energy'?2:1)];
    $pending=[];$invitedCount=null;$pendingCursor=null;
    if($pendingBefore!==null&&(!is_string($pendingBefore)||!preg_match('/^[1-9][0-9]{0,18}$/D',$pendingBefore)))throw new MobileError('invite_page_invalid');
    if(mobile_bonus_is_active($ownerWallet)) {
      $rounds=mobile_table('mobile_rounds',$prefix);
      $query=$pdo->prepare("SELECT COUNT(*) FROM $invites WHERE inviter_id=?");$query->execute([(int)$id]);$invitedCount=(int)$query->fetchColumn();
      $pendingWhere=$pendingBefore!==null?' AND r.id<?':'';
      $query=$pdo->prepare("SELECT r.id,p.nickname,p.google_sub,(SELECT COUNT(*) FROM $rounds g WHERE g.player_id=r.invitee_id AND g.finished_at IS NOT NULL AND (g.result_json IS NULL OR g.result_json NOT LIKE '%\"canceled\":true%')) AS games FROM $invites r LEFT JOIN $players p ON p.id=r.invitee_id WHERE r.inviter_id=? AND r.rewarded_at IS NULL $pendingWhere ORDER BY r.id DESC LIMIT 101");
      $query->execute($pendingBefore!==null?[(int)$id,$pendingBefore]:[(int)$id]);$pendingRaw=$query->fetchAll(PDO::FETCH_ASSOC);$pendingMore=count($pendingRaw)>100;$pendingRaw=array_slice($pendingRaw,0,100);if($pendingMore)$pendingCursor=(string)$pendingRaw[99]['id'];foreach($pendingRaw as $row)$pending[]=['id'=>(string)$row['id'],'nickname'=>$row['nickname'],'games'=>min(5,(int)$row['games']),'googleLinked'=>!empty($row['google_sub'])];
    }
    return ['profileId' => 'android:' . (int)$id, 'reward' => $v2?(int)mobile_energy_config()['rewards']['invite']:MOBILE_INVITE_REWARD,
        'inviterReward'=>mobile_bonus_is_active($ownerWallet)?mobile_bonus_policy(mobile_energy_config())['inviterReward']:($v2?(int)mobile_energy_config()['rewards']['invite']:MOBILE_INVITE_REWARD),
        'pendingRows'=>$pending,'pendingNextCursor'=>$pendingCursor,'invitedCount'=>$invitedCount,
        'requiredGames' => MOBILE_INVITE_REQUIRED_GAMES, 'rewardTotal' => $total,'currency'=>$v2?'energy':'crystals','energyRewardTotal'=>$v2?$total:$total*2,
        'paidRows' => $items, 'nextCursor' => $more ? (string)$rows[count($rows) - 1]['id'] : null];
}

function mobile_invites_state(PDO $pdo, $id, $now, $prefix = '', $before = null, $limit = 50) {
    mobile_invites_require_schema($pdo, $prefix);
    $ownCode = mobile_invites_own_code($pdo, $id, $now, $prefix);
    mobile_invites_reconcile($pdo, $id, $now, $prefix);
    $player = mobile_invites_player($pdo, $id, $prefix);
    $invites = mobile_invite_table('mobile_invites', $prefix);
    $players = mobile_table('mobile_players', $prefix);
    $query = $pdo->prepare("SELECT r.inviter_code,r.rewarded_at,r.inviter_id,p.google_sub
        FROM $invites r LEFT JOIN $players p ON p.id=r.inviter_id WHERE r.invitee_id=?");
    $query->execute([(int)$id]);
    $invite = $query->fetch(PDO::FETCH_ASSOC);
    $completed = mobile_invites_completed_games($pdo, $id, $prefix);
    $status = 'unbound';
    if ($invite) {
        $status = $invite['rewarded_at'] !== null ? 'rewarded' :
            (!$invite['inviter_id'] ? 'inviter_unavailable' :
            ($completed < MOBILE_INVITE_REQUIRED_GAMES ? 'waiting_games' : 'waiting_google'));
    }
    return ['profile' => mobile_profile($player), 'invites' => mobile_invites_paid_list($pdo, $id, $before, $limit, $prefix) +
        ['ownCode' => $ownCode, 'inviteUrl' => 'https://untouch.fun/a/' . $ownCode,
         'inviterAssigned' => (bool)$invite, 'inviterCode' => $invite ? $invite['inviter_code'] : null,
         'completedGames' => $completed, 'googleLinked' => !empty($player['google_sub']),
         'bonusStatus' => $status]];
}

// One authenticated API contract, also usable by the isolated integration fixture.
function mobile_invites_action(PDO $pdo, $player, $input, $now, $prefix = '') {
    mobile_invites_require_schema($pdo, $prefix);
    $id = (int)$player['id']; // Caller authenticated the canonical account; ignore IDs supplied in input.
    $before = $input['before'] ?? null;
    $limit = $input['limit'] ?? 50;
    $action = $input['action'] ?? '';
    if ($action === 'invites_bind') {
        $created = mobile_invites_bind($pdo, $id, $input['code'] ?? null, $input['source'] ?? 'manual', $now, $prefix);
        return mobile_invites_state($pdo, $id, $now, $prefix) + ['bindingCreated' => $created];
    }
    if ($action === 'invites_state') return mobile_invites_state($pdo, $id, $now, $prefix, $before, $limit);
    if ($action === 'invites_list') {
        mobile_invites_reconcile($pdo, $id, $now, $prefix);
        return ['profile' => mobile_profile(mobile_invites_player($pdo, $id, $prefix)),
            'invites' => mobile_invites_paid_list($pdo, $id, $before, $limit, $prefix, $input['beforePending']??null)];
    }
    throw new MobileError('action_invalid');
}

// Run only AFTER an old operation committed. Invite failure must not undo Google/round acknowledgement.
function mobile_invites_after_action(PDO $pdo, $action, $actorId, $result, $now, $prefix = '') {
    if (!in_array($action, ['profile', 'round_finish', 'google_link', 'google_restore', 'google_details'], true)) return $result;
    try {
        if (!mobile_invites_schema_ready($pdo, $prefix)) return $result;
        $paid = mobile_invites_reconcile($pdo, $actorId, $now, $prefix);
        if ($paid && isset($result['profile'])) $result['profile'] = mobile_profile(mobile_invites_player($pdo, $actorId, $prefix));
    } catch (Throwable $error) {
        error_log('mobile_invites: reconciliation deferred (' . get_class($error) . ')');
    }
    return $result;
}
