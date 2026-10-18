<?php
/** All mutations lock one user's wallet and commit the ledger in the same transaction. */
function energy_settings() {
    $cfg = tg_local_gameplay_config()['economy']['energy'] ?? null;
    if (!$cfg) throw new DomainException('Эта версия игры использует жизни и кристаллы. Откройте приложение заново.');
    return $cfg;
}

function energy_ensure_tables(PDO $pdo) {
    if (tg_schema_ready($pdo, 'energy', 1)) return;
    $pdo->exec("CREATE TABLE IF NOT EXISTS `energy_wallets` (
        user_id VARCHAR(64) NOT NULL PRIMARY KEY, revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
        base INT UNSIGNED NOT NULL, reserve BIGINT UNSIGNED NOT NULL DEFAULT 0,
        regen_at BIGINT UNSIGNED NOT NULL, stars_seen BIGINT UNSIGNED NOT NULL DEFAULT 0, energy_paid_seen BIGINT UNSIGNED NOT NULL DEFAULT 0,
        migrated TINYINT UNSIGNED NOT NULL DEFAULT 0, daily_day INT NOT NULL DEFAULT 0,
        daily_streak INT UNSIGNED NOT NULL DEFAULT 0, timed_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
        ad_at BIGINT UNSIGNED NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS `energy_events` (
        user_id VARCHAR(64) NOT NULL, event_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        delta BIGINT NOT NULL, kind VARCHAR(32) NOT NULL, result_json TEXT NOT NULL, created_at BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (user_id, event_key), KEY idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS `energy_rounds` (
        user_id VARCHAR(64) NOT NULL, round_id VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
        cost INT UNSIGNED NOT NULL, started_at BIGINT UNSIGNED NOT NULL, finished_at BIGINT UNSIGNED DEFAULT NULL,
        loadout_json TEXT NOT NULL, result_json TEXT DEFAULT NULL,
        PRIMARY KEY (user_id, round_id), KEY idx_started (started_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    tg_schema_complete($pdo, 'energy', 1);
}

function energy_regenerate(array $wallet, array $cfg, $now) {
    $cap = (int)$cfg['cap'];
    $interval = max(1, (int)round($cfg['refillSeconds'] * 1000 / $cap));
    $elapsed = max(0, $now - (int)$wallet['regen_at']);
    $gain = intdiv($elapsed, $interval);
    $wallet['base'] = min($cap, (int)$wallet['base'] + $gain);
    $wallet['regen_at'] = $wallet['base'] >= $cap ? $now : (int)$wallet['regen_at'] + $gain * $interval;
    return $wallet;
}

function energy_loadout(array $raw, array $cfg) {
    $jumps = (int)($raw['jumps'] ?? 0);
    if (!in_array($jumps, [0, 2, 3], true)) throw new DomainException('Выберите 0, 2 или 3 прыжка');
    $loadout = ['shield' => !empty($raw['shield']), 'jumps' => $jumps, 'impulse' => !empty($raw['impulse'])];
    $cost = (int)$cfg['roundCost'] + ($loadout['shield'] ? (int)$cfg['shieldCost'] : 0)
        + ($jumps === 2 ? (int)$cfg['jump2Cost'] : ($jumps === 3 ? (int)$cfg['jump3Cost'] : 0))
        + ($loadout['impulse'] ? (int)$cfg['impulseCost'] : 0);
    return ['loadout' => $loadout, 'cost' => $cost];
}

function energy_ability_rules(array $cfg) {
    return [
        'jump' => ['cost' => (int)($cfg['jumpUseCost'] ?? 2), 'cooldownMs' => (int)round(($cfg['jumpRechargeSec'] ?? 4) * 1000)],
        'impulse' => ['cost' => (int)$cfg['impulseCost'], 'cooldownMs' => (int)round(($cfg['impulseRechargeSec'] ?? 8) * 1000)],
        'shield' => ['cost' => (int)$cfg['shieldCost'], 'cooldownMs' => (int)round(($cfg['shieldRechargeSec'] ?? 10) * 1000)],
    ];
}

function energy_snapshot(array $wallet, array $cfg, $now) {
    $interval = max(1, (int)round($cfg['refillSeconds'] * 1000 / $cfg['cap']));
    return [
        'base' => (int)$wallet['base'], 'reserve' => (int)$wallet['reserve'],
        'total' => (int)$wallet['base'] + (int)$wallet['reserve'], 'cap' => (int)$cfg['cap'],
        'serverNowMs' => $now, 'regenAtMs' => (int)$wallet['regen_at'], 'intervalMs' => $interval,
        'dailyDay' => (int)$wallet['daily_day'], 'dailyStreak' => (int)$wallet['daily_streak'],
        'timedAtMs' => (int)$wallet['timed_at'], 'adAtMs' => (int)$wallet['ad_at'],
        'migrated' => (bool)$wallet['migrated'],
        'revision' => (int)$wallet['revision'],
    ];
}

function energy_request(PDO $pdo, $uid, array $input) {
    tg_ensure_commerce_tables($pdo);
    energy_ensure_tables($pdo);
    $cfg = energy_settings();
    $now = (int)(microtime(true) * 1000);
    $action = (string)($input['action'] ?? 'wallet');
    if ($action === 'referrals') tg_ensure_social_tables($pdo);
    $key = (string)($input['requestId'] ?? '');
    if ($action !== 'wallet' && !preg_match('/^[a-zA-Z0-9_-]{8,80}$/D', $key)) throw new DomainException('Неверный идентификатор запроса');
    $pdo->beginTransaction();
    try {
        $pdo->prepare('INSERT INTO `energy_wallets` (user_id, base, regen_at) VALUES (:uid, :base, :now) ON DUPLICATE KEY UPDATE user_id = user_id')->execute([':uid' => (string)$uid, ':base' => (int)$cfg['initial'], ':now' => $now]);
        $query = $pdo->prepare('SELECT * FROM `energy_wallets` WHERE user_id = :uid FOR UPDATE');
        $query->execute([':uid' => (string)$uid]);
        $wallet = energy_regenerate($query->fetch(), $cfg, $now);
        // Purchased legacy credits are a monotonic source. Never credit a stale
        // browser balance or overwrite a newer server wallet.
        $paid = $pdo->prepare('SELECT stars_tokens FROM `wallets` WHERE user_id = :uid');
        $paid->execute([':uid' => (string)$uid]);
        $stars = (int)$paid->fetchColumn();
        $direct = $pdo->prepare('SELECT COALESCE(SUM(energy),0) AS energy, COALESCE(SUM(crystals),0) AS crystals FROM `energy_payments` WHERE user_id=:uid');
        $direct->execute([':uid' => (string)$uid]);
        $paidEnergy = $direct->fetch();
        $stars = max(0, $stars - (int)$paidEnergy['crystals']);
        $paidDelta = max(0, $stars - (int)$wallet['stars_seen']);
        $directDelta = max(0, (int)$paidEnergy['energy'] - (int)$wallet['energy_paid_seen']);
        $wallet['reserve'] += $directDelta;
        $wallet['energy_paid_seen'] = max((int)$paidEnergy['energy'], (int)$wallet['energy_paid_seen']);
        $wallet['reserve'] += $paidDelta * (int)$cfg['legacyCrystalEnergy'];
        $wallet['stars_seen'] = max($stars, (int)$wallet['stars_seen']);
        $result = [];
        if ($action !== 'wallet') {
            $previous = $pdo->prepare('SELECT result_json, kind FROM `energy_events` WHERE user_id = :uid AND event_key = :key');
            $previous->execute([':uid' => (string)$uid, ':key' => $key]);
            $saved = $previous->fetch();
            if ($saved) {
                if ($saved['kind'] !== $action) throw new DomainException('Запрос уже использован');
                if ($action === 'ability') {
                    $receipt = json_decode($saved['result_json'], true)['ability'] ?? [];
                    if (($receipt['roundId'] ?? '') !== ($input['roundId'] ?? '') || ($receipt['kind'] ?? '') !== ($input['ability'] ?? '') || ($receipt['atMs'] ?? -1) !== (int)($input['atMs'] ?? -2)) throw new DomainException('Состав запроса изменился');
                }
                $pdo->rollBack();
                $current = energy_request($pdo, $uid, ['action' => 'wallet']);
                return array_replace(json_decode($saved['result_json'], true), ['wallet' => $current['wallet']]);
            }
        }
        $before = (int)$wallet['base'] + (int)$wallet['reserve'];
        if ($action === 'migrate') {
            if (!$wallet['migrated']) {
                $legacy = is_array($input['legacy'] ?? null) ? $input['legacy'] : [];
                // Old balances existed only in localStorage; these bounded,
                // one-time compatibility credits cannot be independently proved.
                $lives = min((int)$cfg['migrationMaxLives'], max(0, (int)($legacy['lives'] ?? 0)));
                $tokens = min((int)$cfg['migrationMaxCrystals'], max(0, (int)($legacy['tokens'] ?? 0) - max(0, (int)($legacy['appliedStarsTokens'] ?? 0))));
                $wallet['reserve'] += max(0, $lives * (int)$cfg['legacyLifeEnergy'] - (int)$wallet['base']) + $tokens * (int)$cfg['legacyCrystalEnergy'];
                $economy = tg_load_economy();
                foreach (['jump', 'helmet'] as $kind) {
                    $minutes = min((int)($economy[$kind . 'RentalHourMinutes'] ?? 60), max(0, ((int)($legacy[$kind . 'RentalUntil'] ?? 0) - $now) / 60000));
                    $perMinute = max((float)($economy[$kind . 'RentalCost'] ?? 0) / max(1, (int)($economy[$kind . 'RentalMinutes'] ?? 10)), (float)($economy[$kind . 'RentalHourCost'] ?? 0) / max(1, (int)($economy[$kind . 'RentalHourMinutes'] ?? 60)));
                    $wallet['reserve'] += (int)ceil($minutes * $perMinute * (int)$cfg['legacyCrystalEnergy']);
                }
                $wallet['migrated'] = 1;
                $result['migrationEnergy'] = (int)$wallet['base'] + (int)$wallet['reserve'] - $before;
            }
        } elseif ($action === 'start') {
            $run = energy_loadout(is_array($input['loadout'] ?? null) ? $input['loadout'] : [], $cfg);
            if (($input['model'] ?? '') === 'abilities-v2') {
                $run = ['cost' => (int)$cfg['roundCost'], 'loadout' => ['shield' => false, 'jumps' => 0, 'impulse' => false, 'model' => 'abilities-v2', 'rules' => energy_ability_rules($cfg), 'uses' => []]];
            }
            if (isset($input['expectedCost']) && (int)$input['expectedCost'] !== $run['cost']) throw new DomainException('Стоимость изменилась. Обновите приложение перед запуском.');
            $game = tg_local_gameplay_config()['game'];
            if ($run['loadout']['jumps'] && empty($game['jumpEnabled']) || $run['loadout']['shield'] && empty($game['helmetEnabled'])) throw new DomainException('Усиление временно отключено');
            if ($before < $run['cost']) throw new DomainException('Не хватает ' . ($run['cost'] - $before) . ' энергии');
            $fromBase = min((int)$wallet['base'], $run['cost']);
            $wallet['base'] -= $fromBase;
            $wallet['reserve'] -= $run['cost'] - $fromBase;
            $pdo->prepare('INSERT INTO `energy_rounds` (user_id, round_id, cost, started_at, loadout_json) VALUES (:uid, :id, :cost, :now, :loadout)')->execute([':uid' => (string)$uid, ':id' => $key, ':cost' => $run['cost'], ':now' => $now, ':loadout' => json_encode($run['loadout'])]);
            $result['round'] = ['id' => $key] + $run;
        } elseif ($action === 'ability') {
            $roundId = (string)($input['roundId'] ?? '');
            $kind = (string)($input['ability'] ?? '');
            $at = $input['atMs'] ?? null;
            if (!in_array($kind, ['jump', 'impulse', 'shield'], true) || !is_numeric($at) || $at < 0 || $at > 3600000) throw new DomainException('Неверная способность');
            $query = $pdo->prepare('SELECT * FROM `energy_rounds` WHERE user_id=:uid AND round_id=:id FOR UPDATE');
            $query->execute([':uid' => (string)$uid, ':id' => $roundId]);
            $round = $query->fetch();
            if (!$round || $round['finished_at'] !== null) throw new DomainException('Попытка недоступна');
            $loadout = json_decode($round['loadout_json'], true);
            if (($loadout['model'] ?? '') !== 'abilities-v2') throw new DomainException('Старая модель попытки');
            if ((int)$at > max(0, $now - (int)$round['started_at']) + 2000) throw new DomainException('Неверное время способности');
            $rule = $loadout['rules'][$kind];
            $game = tg_local_gameplay_config()['game'];
            if ($kind === 'jump' && empty($game['jumpEnabled']) || $kind === 'shield' && empty($game['helmetEnabled'])) throw new DomainException('Способность отключена');
            if (isset($loadout['uses'][$kind]) && (int)$at - (int)$loadout['uses'][$kind] < $rule['cooldownMs']) throw new DomainException('Способность восстанавливается');
            $cost = (int)$rule['cost'];
            if (isset($input['expectedCost']) && (int)$input['expectedCost'] !== $cost) throw new DomainException('Стоимость способности изменилась');
            if ($before < $cost) throw new DomainException('Не хватает энергии');
            $fromBase = min((int)$wallet['base'], $cost);
            $wallet['base'] -= $fromBase; $wallet['reserve'] -= $cost - $fromBase;
            $loadout['uses'][$kind] = (int)$at;
            if ($kind === 'jump') $loadout['jumps']++;
            else $loadout[$kind] = true;
            $pdo->prepare('UPDATE `energy_rounds` SET loadout_json=:loadout WHERE user_id=:uid AND round_id=:id')->execute([':loadout' => json_encode($loadout), ':uid' => (string)$uid, ':id' => $roundId]);
            $result['ability'] = ['roundId' => $roundId, 'kind' => $kind, 'atMs' => (int)$at, 'cost' => $cost];
        } elseif ($action === 'daily') {
            $day = intdiv($now, 86400000); // UTC; client uses the same boundary.
            if ((int)$wallet['daily_day'] >= $day) throw new DomainException('Сегодня бонус уже получен');
            $wallet['daily_streak'] = (int)$wallet['daily_day'] === $day - 1 ? (int)$wallet['daily_streak'] + 1 : 1;
            $wallet['daily_day'] = $day;
            $rewards = $cfg['dailyRewards'];
            $reward = (int)$rewards[min(count($rewards) - 1, $wallet['daily_streak'] - 1)];
            $premium = $pdo->prepare('SELECT plus_until_ms FROM `wallets` WHERE user_id = :uid');
            $premium->execute([':uid' => (string)$uid]);
            if ((int)$premium->fetchColumn() > $now) $reward *= (int)(tg_load_economy()['premiumDailyMultiplier'] ?? 2);
            $wallet['reserve'] += $reward;
            $result['reward'] = $reward;
        } elseif ($action === 'timed') {
            if ($now < (int)$wallet['timed_at'] + (int)$cfg['timedCooldownSeconds'] * 1000) throw new DomainException('Бонус ещё восстанавливается');
            $wallet['timed_at'] = $now;
            $wallet['reserve'] += (int)$cfg['timedReward'];
            $result['reward'] = (int)$cfg['timedReward'];
        } elseif ($action === 'referrals') {
            $query = $pdo->prepare('SELECT invitee_id FROM `referrals` r WHERE inviter_id=:uid AND rewarded=0 AND EXISTS (SELECT 1 FROM `energy_rounds` er WHERE er.user_id=r.invitee_id AND er.finished_at IS NOT NULL AND CAST(JSON_UNQUOTE(JSON_EXTRACT(er.result_json,\'$.timeMs\')) AS UNSIGNED) >= :time) LIMIT 50 FOR UPDATE');
            $query->execute([':uid' => (string)$uid, ':time' => (int)(tg_load_economy()['earnSurviveSeconds'] ?? 10) * 1000]);
            $friends = $query->fetchAll();
            foreach ($friends as $friend) {
                $pdo->prepare('UPDATE `referrals` SET rewarded=1,rewarded_at=:now WHERE invitee_id=:friend')->execute([':now' => $now, ':friend' => $friend['invitee_id']]);
            }
            $result['friends'] = count($friends);
            $result['reward'] = count($friends) * (int)($cfg['referralReward'] ?? 60);
            $wallet['reserve'] += $result['reward'];
        } elseif ($action === 'ad_open') {
            if ($now < (int)$wallet['ad_at'] + (int)$cfg['adCooldownSeconds'] * 1000) throw new DomainException('Реклама ещё восстанавливается');
            $result['sessionId'] = $key;
        } elseif ($action === 'ad_finish') {
            $session = (string)($input['sessionId'] ?? '');
            $open = $pdo->prepare('SELECT kind, created_at FROM `energy_events` WHERE user_id=:uid AND event_key=:key');
            $open->execute([':uid' => (string)$uid, ':key' => $session]);
            $ad = $open->fetch();
            if (!$ad || $ad['kind'] !== 'ad_open' || $now - (int)$ad['created_at'] > 600000) throw new DomainException('Рекламная сессия истекла');
            if ($now < (int)$wallet['ad_at'] + (int)$cfg['adCooldownSeconds'] * 1000) throw new DomainException('Реклама ещё восстанавливается');
            $used = $pdo->prepare('SELECT COUNT(*) FROM `energy_events` WHERE user_id=:uid AND event_key=:key');
            $used->execute([':uid' => (string)$uid, ':key' => 'ad_used_' . $session]);
            if ($used->fetchColumn()) throw new DomainException('Награда за рекламу уже получена');
            $wallet['ad_at'] = $now;
            $wallet['reserve'] += (int)$cfg['adReward'];
            $result['reward'] = (int)$cfg['adReward'];
            $pdo->prepare('INSERT INTO `energy_events` (user_id,event_key,delta,kind,result_json,created_at) VALUES (:uid,:key,0,\'ad_used\',\'{}\',:now)')->execute([':uid' => (string)$uid, ':key' => 'ad_used_' . $session, ':now' => $now]);
        } elseif ($action === 'finish') {
            $roundId = (string)($input['roundId'] ?? '');
            $query = $pdo->prepare('SELECT * FROM `energy_rounds` WHERE user_id=:uid AND round_id=:id FOR UPDATE');
            $query->execute([':uid' => (string)$uid, ':id' => $roundId]);
            $round = $query->fetch();
            if (!$round) throw new DomainException('Попытка не найдена');
            if ($round['finished_at'] !== null) throw new DomainException('Попытка уже завершена');
            $time = max(0, (int)($input['timeMs'] ?? 0));
            $steps = max(0, (int)($input['steps'] ?? 0));
            $risks = max(0, (int)($input['risks'] ?? 0));
            $elapsed = max(0, $now - (int)$round['started_at']);
            if ($time > $elapsed + 2000 || $time > 3600000 || $steps > ($elapsed / 1000 + 1) * 300 || $risks > ($elapsed / 1000 + 1) * 20) throw new DomainException('Результат требует проверки');
            $economy = tg_load_economy();
            $reward = intdiv($risks, max(1, (int)($economy['riskRewardEvery'] ?? 8))) * (int)($economy['riskRewardTokens'] ?? 0)
                + intdiv($steps, max(1, (int)($economy['runRewardEvery'] ?? 400))) * (int)($economy['runRewardTokens'] ?? 0);
            $reward = min((int)$cfg['runRewardCap'], intdiv((int)$round['cost'], 2), max(0, $reward));
            $wallet['reserve'] += $reward;
            $result['reward'] = $reward;
            $result['result'] = ['timeMs' => $time, 'steps' => $steps, 'risks' => $risks];
            $result['roundId'] = $roundId;
            $pdo->prepare('UPDATE `energy_rounds` SET finished_at=:now,result_json=:result WHERE user_id=:uid AND round_id=:id')->execute([':now' => $now, ':result' => json_encode($result['result']), ':uid' => (string)$uid, ':id' => $roundId]);
        } elseif ($action !== 'wallet') {
            throw new DomainException('Неизвестное действие');
        }
        $wallet['revision'] = (int)$wallet['revision'] + 1;
        $pdo->prepare('UPDATE `energy_wallets` SET revision=revision+1, base=:base, reserve=:reserve, regen_at=:regen, stars_seen=:stars, energy_paid_seen=:paid_energy, migrated=:migrated, daily_day=:day, daily_streak=:streak, timed_at=:timed, ad_at=:ad WHERE user_id=:uid')->execute([
            ':base' => (int)$wallet['base'], ':reserve' => (int)$wallet['reserve'], ':regen' => (int)$wallet['regen_at'], ':stars' => (int)$wallet['stars_seen'], ':paid_energy' => (int)$wallet['energy_paid_seen'], ':migrated' => (int)$wallet['migrated'], ':day' => (int)$wallet['daily_day'], ':streak' => (int)$wallet['daily_streak'], ':timed' => (int)$wallet['timed_at'], ':ad' => (int)$wallet['ad_at'], ':uid' => (string)$uid,
        ]);
        $result['wallet'] = energy_snapshot($wallet, $cfg, $now);
        if ($action !== 'wallet' || $paidDelta > 0 || $directDelta > 0) {
            $eventKey = $action === 'wallet' ? 'stars_' . $wallet['stars_seen'] . '_' . $wallet['energy_paid_seen'] : $key;
            $pdo->prepare('INSERT INTO `energy_events` (user_id, event_key, delta, kind, result_json, created_at) VALUES (:uid,:key,:delta,:kind,:result,:now)')->execute([':uid' => (string)$uid, ':key' => $eventKey, ':delta' => (int)$wallet['base'] + (int)$wallet['reserve'] - $before + $paidDelta * (int)$cfg['legacyCrystalEnergy'] + $directDelta, ':kind' => $action, ':result' => json_encode($result), ':now' => $now]);
        }
        $pdo->commit();
        return $result;
    } catch (Throwable $error) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $error;
    }
}
