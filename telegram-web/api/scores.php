<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Telegram-Init-Data');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/tg_common.php';
require_once __DIR__ . '/schema_migrations.php';
require_once __DIR__ . '/mobile_store.php';
require_once __DIR__ . '/mobile_wallet.php';

// 1. Подключение к MySQL через db_config.php
$pdo = null;
$dbError = null;
$connectedHost = null;
$configFile = __DIR__ . '/db_config.php';

if (file_exists($configFile)) {
    $dbConfig = @include $configFile;
    if (is_array($dbConfig) && !empty($dbConfig['database']) && !empty($dbConfig['username'])) {
        $db      = $dbConfig['database'];
        $user    = $dbConfig['username'];
        $pass    = $dbConfig['password'] ?? '';
        $charset = $dbConfig['charset'] ?? 'utf8mb4';
        $port    = !empty($dbConfig['port']) ? (int)$dbConfig['port'] : 3308;

        // Попробуем варианты подключения (для MySQL 8.0 на HostLand порт 3308 обязателен)
        $customHost = !empty($dbConfig['host']) ? $dbConfig['host'] : '127.0.0.1';
        $configsToTry = [
            ['host' => $customHost, 'port' => $port],
            ['host' => '127.0.0.1', 'port' => 3308],
            ['host' => 'localhost', 'port' => 3308],
            ['host' => 'localhost', 'port' => null],
        ];

        $opt = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_TIMEOUT            => 3,
        ];

        $attemptErrors = [];
        $connectedPort = null;
        foreach ($configsToTry as $cfg) {
            $tryHost = $cfg['host'];
            $tryPort = $cfg['port'];
            try {
                $portPart = $tryPort ? ";port={$tryPort}" : "";
                $dsn = "mysql:host={$tryHost}{$portPart};dbname={$db};charset={$charset}";
                $testPdo = new PDO($dsn, $user, $pass, $opt);
                // Проверяем живое соединение
                $testPdo->query("SELECT 1");
                $pdo = $testPdo;
                $connectedHost = $tryHost;
                $connectedPort = $tryPort;
                $dbError = null;
                break;
            } catch (Exception $e) {
                $attemptErrors[] = "[{$tryHost}:{$tryPort}]: " . $e->getMessage();
            }
        }

        if ($pdo === null) {
            $dbError = implode(' | ', $attemptErrors);
            error_log('[scores.php] MySQL connection failed: ' . $dbError);

            // Пробуем выяснить, какие базы доступны этому пользователю
            $visibleDatabases = [];
            try {
                $probeDsn = "mysql:host=127.0.0.1;port={$port};charset={$charset}";
                $probePdo = new PDO($probeDsn, $user, $pass, $opt);
                $visibleDatabases = $probePdo->query("SHOW DATABASES")->fetchAll(PDO::FETCH_COLUMN);
            } catch (Exception $probeEx) {
                $visibleDatabases = ['probe_error' => $probeEx->getMessage()];
            }
        } else {
            // Соединение успешно — проверяем/создаем таблицу
            try {
                tg_ensure_score_tables($pdo);
            } catch (Exception $e) {
                $dbError = "Table init error: " . $e->getMessage();
                error_log('[scores.php] ' . $dbError);
            }
        }
    } else {
        $dbError = 'db_config.php returned invalid array or empty credentials';
    }
} else {
    $dbError = 'db_config.php not found in ' . __DIR__;
}

// 2. Файловый резерв (fallback), если MySQL временно недоступна
$dataFile = __DIR__ . '/scores.json';

function getFileScores($file) {
    if (!file_exists($file)) return [];
    $raw = @file_get_contents($file);
    if (!$raw) return [];
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function saveFileScores($file, $scores) {
    usort($scores, function($a, $b) {
        return ($b['timeMs'] ?? 0) <=> ($a['timeMs'] ?? 0);
    });
    $scores = array_slice($scores, 0, 300);
    @file_put_contents($file, json_encode($scores, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), LOCK_EX);
    return $scores;
}

function fetchMergedScoresFromMysql($pdo) {
    $period = (string)($_GET['period'] ?? 'all');
    $now = time();
    $since = 0;
    if ($period === 'day') $since = strtotime(gmdate('Y-m-d', $now) . ' UTC') * 1000;
    elseif ($period === 'week') $since = ($now - 7 * 86400) * 1000;
    elseif ($period === 'month') $since = strtotime(gmdate('Y-m-01', $now) . ' UTC') * 1000;
    elseif ($period === 'year') $since = strtotime(gmdate('Y-01-01', $now) . ' UTC') * 1000;
    // Best row per player in the requested period. Daily rows outside an
    // arbitrary recent-row limit can no longer disappear from the rating.
    $topStmt = $pdo->query("
        SELECT id, user_id as userId, username, first_name as firstName, last_name as lastName,
               player_name as playerName, photo_url as photoUrl, hide_telegram as hideTelegram,
               time_ms as timeMs, run_distance as runDistance, risk_count as riskCount, score,
               had_jump as hadJump, had_helmet as hadHelmet, created_at as createdAt,
               score_day as scoreDay
        FROM (
            SELECT ranked.*, ROW_NUMBER() OVER (
                PARTITION BY CASE
                    WHEN user_id IS NOT NULL AND user_id != '' THEN CONCAT('id:',user_id)
                    WHEN username IS NOT NULL AND username != '' THEN CONCAT('user:',username)
                    ELSE CONCAT('name:',player_name) END
                ORDER BY time_ms DESC,id DESC
            ) AS player_rank
            FROM `scores` ranked WHERE created_at >= $since
        ) s
        WHERE s.player_rank = 1
        ORDER BY s.time_ms DESC, s.id DESC
        LIMIT 150
    ");
    $topRows = $topStmt->fetchAll();

    $byId = [];
    foreach ($topRows as $r) {
        $byId[$r['id']] = $r;
    }

    $formatted = array_map(function($r) {
        $tMs = (int)$r['timeMs'];
        $dist = (int)$r['runDistance'];
        $risk = (int)$r['riskCount'];
        $scoreVal = isset($r['score']) && (int)$r['score'] > 0
            ? (int)$r['score']
            : (int)round(($tMs / 1000.0) * $dist * (1 + $risk));

        $hideTg = !empty($r['hideTelegram']);
        $uname = $hideTg ? null : ($r['username'] ?: null);
        $createdAt = (int)$r['createdAt'];
        $scoreDay = trim((string)($r['scoreDay'] ?? ''));
        if ($scoreDay === '' && $createdAt > 0) {
            $scoreDay = date('Y-m-d', (int)($createdAt / 1000));
        }

        return [
            'id'           => (string)$r['id'],
            'userId'       => $r['userId'] !== null ? (string)$r['userId'] : null,
            'username'     => $uname,
            'hideTelegram' => $hideTg,
            'firstName'    => $r['firstName'] ?: null,
            'lastName'     => $r['lastName'] ?: null,
            'playerName'   => $r['playerName'],
            'photoUrl'     => $r['photoUrl'] ?: null,
            'timeMs'       => $tMs,
            'runDistance'  => $dist,
            'riskCount'    => $risk,
            'score'        => $scoreVal,
            'hadJump'      => (bool)$r['hadJump'],
            'hadHelmet'    => (bool)$r['hadHelmet'],
            'createdAt'    => $createdAt,
            'scoreDay'     => $scoreDay,
        ];
    }, array_values($byId));

    usort($formatted, function($a, $b) {
        return $b['timeMs'] <=> $a['timeMs'];
    });

    return mobile_identity_public_scores($pdo,$formatted);
}

// Диагностика только с ключом из bot_config.php (diag_key). Без ключа — 404.
if (isset($_GET['diag'])) {
    $diagKey = trim((string)(tg_bot_config()['diag_key'] ?? ''));
    $got = (string)$_GET['diag'];
    if ($diagKey === '' || $got !== $diagKey) {
        http_response_code(404);
        echo json_encode(['ok' => false, 'error' => 'not found']);
        exit;
    }
    echo json_encode([
        'ok' => true,
        'db_status' => ($pdo !== null ? 'connected' : 'error'),
        'scores_fallback' => count(getFileScores($dataFile)),
    ]);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

// --- GET: Загрузка списка рекордов ---
if ($method === 'GET') {
    if ($pdo !== null) {
        try {
            $formatted = fetchMergedScoresFromMysql($pdo);
            echo json_encode([
                'ok' => true,
                'source' => 'mysql',
                'dbStatus' => 'connected',
                'dbHost' => $connectedHost,
                'scores' => $formatted,
            ]);
            exit;
        } catch (Exception $e) {
            $dbError = 'SELECT failed: ' . $e->getMessage();
            error_log('[scores.php] ' . $dbError);
            echo json_encode([
                'ok' => false,
                'source' => 'mysql',
                'dbStatus' => 'error',
                'error' => 'Рейтинг временно недоступен',
                'scores' => [],
            ]);
            exit;
        }
    }

    echo json_encode([
        'ok' => false,
        'source' => 'none',
        'dbStatus' => 'error',
        'error' => 'Рейтинг временно недоступен',
        'scores' => [],
    ]);
    exit;
}

// --- POST: Сохранение результата заезда ИЛИ обновление профиля игрока ---
if ($method === 'POST') {
    $rawInput = file_get_contents('php://input');
    $input = json_decode($rawInput, true);
    if (!is_array($input)) {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'Invalid JSON']);
        exit;
    }

    $action = $input['action'] ?? 'save_score';

    $authUserId = null;
    $authUser = null;
    $authStartParam = '';
    if (tg_bot_token() !== '') {
        $auth = tg_validate_init_data(tg_read_init_data_from_request($input));
        if (!$auth['ok']) {
            http_response_code(401);
            echo json_encode(['ok' => false, 'error' => $auth['error'] ?? 'Unauthorized']);
            exit;
        }
        $authUserId = $auth['userId'];
        $authUser = is_array($auth['user'] ?? null) ? $auth['user'] : null;
        $authStartParam = isset($auth['startParam']) ? (string)$auth['startParam'] : '';
    }

    // 1) ОБНОВЛЕНИЕ ПРОФИЛЯ ИГРОКА (ник, скрытие telegram) В БАЗЕ ДАННЫХ
    if ($action === 'update_profile') {
        $profileMode = is_string($input['mode'] ?? null) ? $input['mode'] : '';
        if (($input['strictNickname'] ?? false) === true) $profileMode = 'rename';
        if ($profileMode === 'rename' || $profileMode === 'privacy') {
          for ($profileAttempt = 0; $profileAttempt < 3; $profileAttempt++) {
            try {
                // New partial writes require a verified owner and the shared registry.
                // The legacy branch below retains its existing compatibility behavior.
                if ($authUserId === null || $authUserId === '') throw new MobileError('unauthorized', 401);
                if ($pdo === null) throw new MobileError('profile_unavailable', 503);
                if (!tg_schema_ready($pdo, 'mobile', 1)) throw new MobileError('schema_unavailable', 503);
                if ($profileMode === 'privacy' && (!isset($input['hideTelegram']) || !is_bool($input['hideTelegram']))) throw new MobileError('profile_invalid', 400);
                $hideTelegram = $profileMode === 'privacy' ? $input['hideTelegram'] : null;
                $playerName = $profileMode === 'rename' ? mobile_name($input['playerName'] ?? null) : null;
                $username = !empty($authUser['username']) ? '@' . ltrim((string)$authUser['username'], '@') : null;
                if ($hideTelegram) $username = null;

                $pdo->beginTransaction();
                if ($profileMode === 'rename') {
                    $nameOwner = 'telegram:' . $authUserId;
                    $owned = $pdo->prepare('SELECT name_key,nickname FROM mobile_names WHERE owner=? FOR UPDATE');
                    $owned->execute([$nameOwner]);
                    $owned->fetchAll();
                    $nameKey = mobile_name_key($playerName);
                    $reserved = $pdo->prepare('SELECT owner FROM mobile_names WHERE name_key=? FOR UPDATE');
                    $reserved->execute([$nameKey]);
                    $taken = $reserved->fetchColumn();
                    // Strict rename never uses the helper's legacy-duplicate exception.
                    if ($taken && $taken !== $nameOwner) throw new MobileError('nickname_taken', 409);
                    mobile_reserve_telegram($pdo, $authUserId, $playerName);
                    $reserved->execute([$nameKey]);
                    if ($reserved->fetchColumn() !== $nameOwner) throw new MobileError('nickname_taken', 409);
                    $pdo->prepare('UPDATE mobile_names SET nickname=? WHERE name_key=? AND owner=?')->execute([$playerName, $nameKey, $nameOwner]);
                }
                $params = [':user_id' => $authUserId];
                // Privacy-only does not carry or reserve a draft and does not rename.
                if ($profileMode === 'rename') {
                    $setSql = '`player_name`=:player_name';
                    $params[':player_name'] = $playerName;
                } else {
                    $setSql = '`username`=:username, `hide_telegram`=:hide_telegram';
                    $params[':username'] = $username;
                    $params[':hide_telegram'] = $hideTelegram ? 1 : 0;
                }
                $update = $pdo->prepare("UPDATE scores SET $setSql WHERE `user_id`=:user_id");
                $update->execute($params);
                $updatedRows = $update->rowCount();
                // Refresh inside the transaction: a refresh error cannot follow an
                // already committed rename and falsely report it as refused.
                $formatted = fetchMergedScoresFromMysql($pdo);
                $pdo->commit();
                $reply = [
                    'ok' => true,
                    'action' => 'update_profile',
                    'mode' => $profileMode,
                    'updatedRows' => $updatedRows,
                    'source' => 'mysql',
                    'scores' => $formatted,
                ];
                if ($profileMode === 'rename') {
                    $reply['uniquenessVerified'] = true;
                    $reply['playerName'] = $playerName;
                } else {
                    $reply['username'] = $username;
                    $reply['hideTelegram'] = $hideTelegram;
                }
                echo json_encode($reply);
                exit;
            } catch (Throwable $error) {
                if ($pdo !== null && $pdo->inTransaction()) $pdo->rollBack();
                if ($error instanceof PDOException && in_array((int)($error->errorInfo[1] ?? 0), [1213, 1205], true) && $profileAttempt < 2) {
                    usleep(20000);
                    continue;
                }
                $code = $error instanceof MobileError ? $error->getMessage() : 'profile_unavailable';
                $status = $error instanceof MobileError ? $error->status : 503;
                if ($error instanceof PDOException && (int)($error->errorInfo[1] ?? 0) === 1062) {
                    $code = 'nickname_taken';
                    $status = 409;
                }
                http_response_code($status);
                echo json_encode(['ok' => false, 'error' => $code, 'code' => $code]);
                exit;
            }
          }
        }
        // Older authenticated clients remain supported, but cannot bypass the
        // shared registry through a spoofed userId or a file-only profile write.
        $legacyProfileError = $authUserId === null || $authUserId === '' ? 'unauthorized' :
            ($pdo === null ? 'profile_unavailable' : (!tg_schema_ready($pdo, 'mobile', 1) ? 'schema_unavailable' : null));
        if ($legacyProfileError !== null) {
            http_response_code($legacyProfileError === 'unauthorized' ? 401 : 503);
            echo json_encode(['ok'=>false,'error'=>$legacyProfileError,'code'=>$legacyProfileError]);
            exit;
        }
        $userId = isset($input['userId']) && $input['userId'] !== '' ? (string)$input['userId'] : null;
        if ($authUserId !== null) {
            $userId = $authUserId;
        }
        $rawUsername = isset($input['rawUsername']) ? trim(strip_tags((string)$input['rawUsername'])) : null;
        if ($rawUsername !== null && $rawUsername !== '' && mb_strpos($rawUsername, '@') !== 0) {
            $rawUsername = '@' . $rawUsername;
        }

        $hideTelegram = !empty($input['hideTelegram']) ? 1 : 0;
        $username = isset($input['username']) ? trim(strip_tags((string)$input['username'])) : null;
        if ($username !== null && $username !== '' && mb_strpos($username, '@') !== 0) {
            $username = '@' . $username;
        }
        if ($hideTelegram) {
            $username = null;
        }

        $nameProvided = array_key_exists('playerName', $input);
        $playerName = $nameProvided && is_string($input['playerName']) ? trim($input['playerName']) : null;

        $firstName = isset($input['firstName']) ? trim(strip_tags((string)$input['firstName'])) : null;
        $lastName = isset($input['lastName']) ? trim(strip_tags((string)$input['lastName'])) : null;
        $photoUrl = isset($input['photoUrl']) ? filter_var((string)$input['photoUrl'], FILTER_SANITIZE_URL) : null;

        $updatedRows = 0;

        if ($pdo !== null) {
            try {
                // Обновляем все записи игрока в таблице scores по userId или username
                $sharedNames = true;
                if ($sharedNames) {
                    $pdo->beginTransaction();
                    $nameOwner = 'telegram:' . $authUserId;
                    $owned = $pdo->prepare('SELECT name_key,nickname FROM mobile_names WHERE owner=? FOR UPDATE');
                    $owned->execute([$nameOwner]);
                    $ownedRows = $owned->fetchAll();
                    $currentName = $ownedRows ? $ownedRows[0]['nickname'] : null;
                    if ($currentName === null) {
                        $current = $pdo->prepare('SELECT player_name FROM scores WHERE user_id=? ORDER BY id DESC LIMIT 1 FOR UPDATE');
                        $current->execute([$authUserId]);
                        $stored = $current->fetchColumn();
                        if ($stored !== false) $currentName = $stored;
                    }
                    if (!$nameProvided) $playerName = $currentName ?? 'Игрок';
                    elseif ($playerName === null || $playerName !== $currentName) $playerName = mobile_name($input['playerName']);
                    $nameKey = mobile_name_key($playerName);
                    $reserved = $pdo->prepare('SELECT owner FROM mobile_names WHERE name_key=? FOR UPDATE');
                    $reserved->execute([$nameKey]);
                    $taken = $reserved->fetchColumn();
                    if ($taken && $taken !== $nameOwner) throw new MobileError('nickname_taken', 409);
                    mobile_reserve_telegram($pdo, $authUserId, $playerName);
                    $pdo->prepare('UPDATE mobile_names SET nickname=? WHERE name_key=? AND owner=?')->execute([$playerName, $nameKey, $nameOwner]);
                }
                $params = [
                    ':player_name'   => $playerName,
                    ':username'      => $username,
                    ':set_user_id'   => $userId,
                    ':hide_telegram' => $hideTelegram,
                    ':first_name'    => $firstName,
                    ':last_name'     => $lastName,
                    ':photo_url'     => $photoUrl,
                ];

                $whereParts = [];
                if ($userId !== null && $userId !== '') {
                    $params[':cond_user_id'] = $userId;
                    $whereParts[] = "`user_id` = :cond_user_id";
                }
                $matchUser = $rawUsername ?: $username;
                if ($authUserId === null && $matchUser !== null && $matchUser !== '') {
                    $cleanMatch = ltrim(strtolower($matchUser), '@');
                    $params[':cond_uname'] = $matchUser;
                    $params[':cond_uname_clean'] = $cleanMatch;
                    $whereParts[] = "(`username` = :cond_uname OR LOWER(REPLACE(`username`, '@', '')) = :cond_uname_clean)";
                }

                if (!empty($whereParts)) {
                    $whereSql = implode(' OR ', $whereParts);
                    $updStmt = $pdo->prepare("
                        UPDATE `scores` SET
                            `player_name`   = :player_name,
                            `username`      = :username,
                            `user_id`       = COALESCE(`user_id`, :set_user_id),
                            `hide_telegram` = :hide_telegram,
                            `first_name`    = COALESCE(:first_name, `first_name`),
                            `last_name`     = COALESCE(:last_name, `last_name`),
                            `photo_url`     = COALESCE(:photo_url, `photo_url`)
                        WHERE ($whereSql)
                    ");
                    $updStmt->execute($params);
                    $updatedRows = $updStmt->rowCount();
                }

                if ($sharedNames) $pdo->commit();
                $formatted = fetchMergedScoresFromMysql($pdo);
                echo json_encode([
                    'ok'          => true,
                    'action'      => 'update_profile',
                    'updatedRows' => $updatedRows,
                    'source'      => 'mysql',
                    'playerName'  => $playerName,
                    'username'    => $username,
                    'scores'      => $formatted,
                ]);
                exit;
            } catch (Exception $e) {
                if ($pdo->inTransaction()) $pdo->rollBack();
                if ($e instanceof MobileError || (isset($sharedNames) && $sharedNames)) {
                    http_response_code($e instanceof MobileError ? $e->status : 503);
                    $code = $e instanceof MobileError ? $e->getMessage() : 'profile_unavailable';
                    echo json_encode(['ok'=>false,'error'=>$code,'code'=>$code]);
                    exit;
                }
                error_log('[scores.php] update_profile MySQL error: ' . $e->getMessage());
            }
        }

        // Обновление в scores.json fallback
        $scores = getFileScores($dataFile);
        $changed = false;
        foreach ($scores as &$entry) {
            $matches = false;
            if ($userId !== null && isset($entry['userId']) && (string)$entry['userId'] === $userId) {
                $matches = true;
            } elseif ($rawUsername !== null && isset($entry['username']) && strtolower($entry['username']) === strtolower($rawUsername)) {
                $matches = true;
            }
            if ($matches) {
                $entry['playerName'] = $playerName;
                $entry['username'] = $username;
                $entry['hideTelegram'] = (bool)$hideTelegram;
                if ($photoUrl) $entry['photoUrl'] = $photoUrl;
                $changed = true;
                $updatedRows++;
            }
        }
        if ($changed) {
            saveFileScores($dataFile, $scores);
        }

        echo json_encode([
            'ok'          => true,
            'action'      => 'update_profile',
            'updatedRows' => $updatedRows,
            'source'      => 'file',
            'playerName'  => $playerName,
            'username'    => $username,
            'scores'      => array_slice($scores, 0, 50),
        ]);
        exit;
    }

    if ($action === 'sync_social' || $action === 'grant_write_access') {
        $invited = [];
        $bound = false;
        $writeAccess = false;
        $bindReason = null;
        $newlyRewarded = 0;

        if ($pdo !== null && $authUserId !== null) {
            try {
                if ($action === 'grant_write_access') {
                    tg_set_write_access($pdo, $authUserId, true);
                }
                $writeAccess = tg_has_write_access($pdo, $authUserId);

                $startParam = $authStartParam;
                if ($startParam === '' && !empty($input['startParam'])) {
                    $startParam = trim((string)$input['startParam']);
                }
                $inviterId = tg_parse_ref_param($startParam);
                if ($inviterId) {
                    $bind = tg_bind_referral($pdo, $authUserId, $inviterId, $authUser);
                    $bound = !empty($bind['bound']);
                    $bindReason = $bind['reason'] ?? null;
                }
                $newlyRewarded = tg_claim_pending_invite_rewards($pdo, $authUserId);
                $invited = tg_list_invited($pdo, $authUserId);
            } catch (Exception $e) {
                error_log('[scores.php] social: ' . $e->getMessage());
                http_response_code(500);
                echo json_encode(['ok' => false, 'error' => 'social failed']);
                exit;
            }
        }

        echo json_encode([
            'ok' => true,
            'action' => $action,
            'bound' => $bound,
            'bindReason' => $bindReason,
            'writeAccess' => $writeAccess,
            'invited' => $invited,
            'inviteCount' => count($invited),
            'newlyRewarded' => $newlyRewarded,
        ]);
        exit;
    }

    if ($action === 'prepare_invite') {
        if ($authUserId === null) {
            http_response_code(401);
            echo json_encode(['ok' => false, 'error' => 'Unauthorized']);
            exit;
        }
        $timeLabel = isset($input['timeSec']) ? trim(strip_tags((string)$input['timeSec'])) : '';
        $bonus = isset($input['bonus']) ? max(0, (int)$input['bonus']) : 40;
        $preparedId = null;
        $sentToChat = false;
        try {
            $prepared = tg_prepare_invite_share($authUserId, $timeLabel, $bonus);
            $preparedId = is_array($prepared) ? ($prepared['id'] ?? null) : null;
        } catch (Exception $e) {
            error_log('[scores.php] prepare_invite: ' . $e->getMessage());
            try {
                tg_send_invite_to_self($authUserId, $timeLabel, $bonus);
                $sentToChat = true;
            } catch (Exception $e2) {
                error_log('[scores.php] send_invite: ' . $e2->getMessage());
            }
        }
        echo json_encode([
            'ok' => true,
            'action' => 'prepare_invite',
            'preparedId' => $preparedId,
            'sentToChat' => $sentToChat,
            'inviteUrl' => tg_invite_start_url($authUserId),
        ]);
        exit;
    }

    // 2) СОХРАНЕНИЕ РЕЗУЛЬТАТА ЗАЕЗДА
    $timeMs = isset($input['timeMs']) ? (int)$input['timeMs'] : 0;
    if ($timeMs <= 0 || $timeMs > 3600000) {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'Invalid timeMs']);
        exit;
    }

    $playerName = isset($input['playerName']) ? trim(strip_tags((string)$input['playerName'])) : 'Игрок';
    if ($playerName === '') $playerName = 'Игрок';
    if (mb_strlen($playerName) > 40) $playerName = mb_substr($playerName, 0, 40);

    $username = isset($input['username']) ? trim(strip_tags((string)$input['username'])) : null;
    if ($username !== null && $username !== '' && mb_strpos($username, '@') !== 0) {
        $username = '@' . $username;
    }
    $firstName = isset($input['firstName']) ? trim(strip_tags((string)$input['firstName'])) : null;
    $lastName = isset($input['lastName']) ? trim(strip_tags((string)$input['lastName'])) : null;
    $photoUrl = isset($input['photoUrl']) ? filter_var((string)$input['photoUrl'], FILTER_SANITIZE_URL) : null;

    $userId = isset($input['userId']) && $input['userId'] !== '' ? (string)$input['userId'] : null;
    if ($authUserId !== null) {
        $userId = $authUserId;
    }
    // Android results require the authenticated mobile round protocol.
    if ($authUserId === null && $userId !== null && strpos($userId, 'android:') === 0) {
        http_response_code(401); echo '{"ok":false,"error":"Unauthorized"}'; exit;
    }
    $runDistance = isset($input['runDistance']) ? max(0, (int)$input['runDistance']) : 0;
    $riskCount = isset($input['riskCount']) ? max(0, (int)$input['riskCount']) : 0;
    if (!empty(tg_load_economy()['energy'])) {
        if ($authUserId === null || $pdo === null || empty($input['roundId'])) {
            http_response_code(401); echo json_encode(['ok'=>false,'error'=>'Требуется подтверждённая попытка Telegram']); exit;
        }
        $confirmed = $pdo->prepare('SELECT result_json, loadout_json, finished_at FROM `energy_rounds` WHERE user_id=:uid AND round_id=:id');
        $confirmed->execute([':uid'=>$authUserId, ':id'=>(string)$input['roundId']]);
        $round = $confirmed->fetch();
        $run = $round ? json_decode($round['result_json'] ?? '', true) : null;
        if (!$run || (int)$run['timeMs'] !== $timeMs || (int)$run['steps'] !== $runDistance || (int)$run['risks'] !== $riskCount) {
            http_response_code(409); echo json_encode(['ok'=>false,'error'=>'Попытка ещё не подтверждена']); exit;
        }
        $input['createdAt'] = (int)$round['finished_at'];
        $input['score'] = (int)round(($timeMs / 1000.0) * $runDistance * (1 + $riskCount));
        $loadout = json_decode($round['loadout_json'], true);
        $input['hadJump'] = !empty($loadout['jumps']); $input['hadHelmet'] = !empty($loadout['shield']);
    }
    $score = isset($input['score']) && is_numeric($input['score'])
        ? max(0, (int)$input['score'])
        : (int)round(($timeMs / 1000.0) * $runDistance * (1 + $riskCount));
    $hadJump = !empty($input['hadJump']) ? 1 : 0;
    $hadHelmet = !empty($input['hadHelmet']) ? 1 : 0;
    $hideTelegram = !empty($input['hideTelegram']) ? 1 : 0;
    if ($hideTelegram) {
        $username = null;
    }
    $createdAt = isset($input['createdAt']) && is_numeric($input['createdAt']) ? (int)$input['createdAt'] : (int)(microtime(true) * 1000);

    $scoreDay = gmdate('Y-m-d', (int)($createdAt / 1000));

    if ($pdo !== null) {
        try {
            $sharedNames = tg_schema_ready($pdo, 'mobile', 1);
            if ($sharedNames) {
                if ($authUserId === null) {
                    // A browser preview cannot claim or overwrite a reserved player name.
                    $reserved=$pdo->prepare('SELECT owner FROM mobile_names WHERE name_key=?');
                    $reserved->execute([mobile_name_key($playerName)]);
                    if ($reserved->fetchColumn()) throw new MobileError('nickname_taken',409);
                } else {
                    $pdo->beginTransaction();
                    // A late score uploads run data, not a new profile nickname.
                    // Lock the existing owner's reservation before the target,
                    // in the same order as profile rename. First-score bootstrap
                    // keeps its former behavior when this owner has no reservation.
                    $owned = $pdo->prepare('SELECT name_key,nickname FROM mobile_names WHERE owner=? FOR UPDATE');
                    $owned->execute(['telegram:' . $authUserId]);
                    $ownedRows = $owned->fetchAll();
                    if ($ownedRows && $ownedRows[0]['nickname'] !== '') $playerName = $ownedRows[0]['nickname'];
                    mobile_reserve_telegram($pdo, $authUserId, $playerName);
                }
            }
            // Ищем существующую запись этого игрока за СЕГОДНЯ
            $whereParts = ["`score_day` = :score_day"];
            $findParams = [':score_day' => $scoreDay];
            if ($userId !== null && $userId !== '') {
                $whereParts[] = "`user_id` = :f_user_id";
                $findParams[':f_user_id'] = $userId;
            } elseif ($username !== null && $username !== '') {
                $whereParts[] = "`username` = :f_username";
                $findParams[':f_username'] = $username;
            } else {
                $whereParts[] = "`player_name` = :f_player_name";
                $findParams[':f_player_name'] = $playerName;
            }

            $findSql = "
                SELECT id, time_ms, run_distance, risk_count, score 
                FROM `scores` 
                WHERE " . implode(' AND ', $whereParts) . "
                ORDER BY `time_ms` DESC
                LIMIT 1
            ";
            $findStmt = $pdo->prepare($findSql);
            $findStmt->execute($findParams);
            $existing = $findStmt->fetch();

            if ($existing) {
                $existingId = (int)$existing['id'];
                $existingTime = (int)$existing['time_ms'];

                if ($timeMs > $existingTime) {
                    // Новый личный рекорд за СЕГОДНЯ: обновляем время, пробег, риски, очки
                    $updSql = "
                        UPDATE `scores` SET
                            `time_ms`       = :time_ms,
                            `run_distance`  = :run_distance,
                            `risk_count`    = :risk_count,
                            `score`         = :score,
                            `had_jump`      = :had_jump,
                            `had_helmet`    = :had_helmet,
                            `created_at`    = :created_at,
                            `player_name`   = :player_name,
                            `username`      = :username,
                            `hide_telegram` = :hide_telegram,
                            `first_name`    = :first_name,
                            `last_name`     = :last_name,
                            `photo_url`     = :photo_url
                        WHERE `id` = :id AND `time_ms` < :new_best_time
                    ";
                    $updStmt = $pdo->prepare($updSql);
                    $updStmt->execute([
                        ':time_ms'       => $timeMs,
                        ':run_distance'  => $runDistance,
                        ':risk_count'    => $riskCount,
                        ':score'         => $score,
                        ':had_jump'      => $hadJump,
                        ':had_helmet'    => $hadHelmet,
                        ':created_at'    => $createdAt,
                        ':player_name'   => $playerName,
                        ':username'      => $username,
                        ':hide_telegram' => $hideTelegram,
                        ':first_name'    => $firstName,
                        ':last_name'     => $lastName,
                        ':photo_url'     => $photoUrl,
                        ':id'            => $existingId,
                        ':new_best_time' => $timeMs,
                    ]);
                } else {
                    // Попытка слабее рекорда за сегодня: рекорд НЕ ухудшаем, только обновляем аватар и имя
                    $updProfile = $pdo->prepare("
                        UPDATE `scores` SET
                            `player_name`   = :player_name,
                            `username`      = :username,
                            `hide_telegram` = :hide_telegram,
                            `first_name`    = :first_name,
                            `last_name`     = :last_name,
                            `photo_url`     = :photo_url
                        WHERE `id` = :id
                    ");
                    $updProfile->execute([
                        ':player_name'   => $playerName,
                        ':username'      => $username,
                        ':hide_telegram' => $hideTelegram,
                        ':first_name'    => $firstName,
                        ':last_name'     => $lastName,
                        ':photo_url'     => $photoUrl,
                        ':id'            => $existingId,
                    ]);
                }
            } else {
                // Первая запись этого игрока за СЕГОДНЯ: создаём новую суточную строку
                $insSql = "
                    INSERT INTO `scores` (
                        `score_day`, `user_id`, `username`, `hide_telegram`, `first_name`, `last_name`, `player_name`, `photo_url`,
                        `time_ms`, `run_distance`, `risk_count`, `score`, `had_jump`, `had_helmet`, `created_at`
                    ) VALUES (
                        :score_day, :user_id, :username, :hide_telegram, :first_name, :last_name, :player_name, :photo_url,
                        :time_ms, :run_distance, :risk_count, :score, :had_jump, :had_helmet, :created_at
                    )
                ";
                $insStmt = $pdo->prepare($insSql);
                $insStmt->execute([
                    ':score_day'     => $scoreDay,
                    ':user_id'       => $userId,
                    ':username'      => $username,
                    ':hide_telegram' => $hideTelegram,
                    ':first_name'    => $firstName,
                    ':last_name'     => $lastName,
                    ':player_name'   => $playerName,
                    ':photo_url'     => $photoUrl,
                    ':time_ms'       => $timeMs,
                    ':run_distance'  => $runDistance,
                    ':risk_count'    => $riskCount,
                    ':score'         => $score,
                    ':had_jump'      => $hadJump,
                    ':had_helmet'    => $hadHelmet,
                    ':created_at'    => $createdAt,
                ]);
            }

            if ($pdo->inTransaction()) $pdo->commit();
            $formatted = fetchMergedScoresFromMysql($pdo);
            echo json_encode([
                'ok' => true,
                'source' => 'mysql',
                'dbStatus' => 'connected',
                'dbHost' => $connectedHost,
                'scores' => $formatted,
            ]);
            exit;
        } catch (Exception $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            if ($e instanceof MobileError) {
                http_response_code($e->status); echo json_encode(['ok'=>false,'error'=>$e->getMessage()]); exit;
            }
            $dbError = 'INSERT/UPDATE failed: ' . $e->getMessage();
            error_log('[scores.php] ' . $dbError);
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => 'Рейтинг временно недоступен', 'source' => 'mysql']);
            exit;
        }
    }

    http_response_code(503);
    echo json_encode([
        'ok' => false,
        'error' => 'Рейтинг временно недоступен',
        'source' => 'none',
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
