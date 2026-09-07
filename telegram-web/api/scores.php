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
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS `scores` (
                        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                        `score_day` VARCHAR(10) NOT NULL DEFAULT '',
                        `user_id` VARCHAR(64) NULL,
                        `username` VARCHAR(64) NULL,
                        `first_name` VARCHAR(128) NULL,
                        `last_name` VARCHAR(128) NULL,
                        `player_name` VARCHAR(128) NOT NULL,
                        `photo_url` VARCHAR(512) NULL,
                        `time_ms` INT UNSIGNED NOT NULL,
                        `run_distance` INT UNSIGNED NOT NULL DEFAULT 0,
                        `risk_count` INT UNSIGNED NOT NULL DEFAULT 0,
                        `score` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                        `had_jump` TINYINT(1) NOT NULL DEFAULT 0,
                        `had_helmet` TINYINT(1) NOT NULL DEFAULT 0,
                        `created_at` BIGINT UNSIGNED NOT NULL,
                        KEY `idx_score_day` (`score_day`),
                        KEY `idx_user_day` (`user_id`, `score_day`),
                        KEY `idx_time_ms` (`time_ms`),
                        KEY `idx_score` (`score`),
                        KEY `idx_user_id` (`user_id`),
                        KEY `idx_username` (`username`),
                        KEY `idx_created_at` (`created_at`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ");

                // Если таблица уже была создана раньше без колонки score — добавим её
                try {
                    $pdo->exec("ALTER TABLE `scores` ADD COLUMN `score` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `risk_count`");
                    $pdo->exec("ALTER TABLE `scores` ADD INDEX `idx_score` (`score`)");
                } catch (Exception $colEx) {}

                // Если таблица создана без колонки score_day — добавим её
                try {
                    $pdo->exec("ALTER TABLE `scores` ADD COLUMN `score_day` VARCHAR(10) NOT NULL DEFAULT '' AFTER `id`");
                    $pdo->exec("ALTER TABLE `scores` ADD INDEX `idx_score_day` (`score_day`)");
                    $pdo->exec("ALTER TABLE `scores` ADD INDEX `idx_user_day` (`user_id`, `score_day`)");
                } catch (Exception $colEx) {}

                // Если таблица создана без колонки hide_telegram — добавим её
                try {
                    $pdo->exec("ALTER TABLE `scores` ADD COLUMN `hide_telegram` TINYINT(1) NOT NULL DEFAULT 0 AFTER `photo_url`");
                } catch (Exception $colEx) {}

                // Пробег больше не в метрах, а в шагах — старый рейтинг несовместим.
                // Один раз очищаем таблицу и scores.json; флаг остаётся на хосте.
                $resetFlag = __DIR__ . '/scores_steps_v1.flag';
                if (!is_file($resetFlag)) {
                    try {
                        $pdo->exec('TRUNCATE TABLE `scores`');
                    } catch (Exception $wipeEx) {
                        error_log('[scores.php] scores unit reset: ' . $wipeEx->getMessage());
                    }
                    @unlink(__DIR__ . '/scores.json');
                    @file_put_contents($resetFlag, date('c') . "\n");
                }

                // Заполняем score_day для старых записей, где он пуст
                try {
                    $pdo->exec("UPDATE `scores` SET `score_day` = DATE_FORMAT(FROM_UNIXTIME(`created_at` / 1000), '%Y-%m-%d') WHERE `score_day` = ''");
                } catch (Exception $e) {}

                // Очистка дубликатов за один и тот же день для одного и того же пользователя:
                // Оставляем только лучшую запись (с максимальным time_ms) за каждый день.
                try {
                    $dupRows = $pdo->query("
                        SELECT id, user_id, username, player_name, score_day, time_ms 
                        FROM `scores` 
                        ORDER BY score_day DESC, time_ms DESC
                    ")->fetchAll();

                    if (!empty($dupRows)) {
                        $bestSeen = [];
                        $idsToDelete = [];
                        foreach ($dupRows as $row) {
                            $ukey = !empty($row['user_id']) ? "id_" . $row['user_id'] : (!empty($row['username']) ? "u_" . strtolower($row['username']) : "p_" . $row['player_name']);
                            $dayKey = ($row['score_day'] ?: 'today') . "_" . $ukey;
                            if (!isset($bestSeen[$dayKey])) {
                                $bestSeen[$dayKey] = $row['id'];
                            } else {
                                $idsToDelete[] = (int)$row['id'];
                            }
                        }
                        if (!empty($idsToDelete)) {
                            $inList = implode(',', $idsToDelete);
                            $pdo->exec("DELETE FROM `scores` WHERE `id` IN ($inList)");
                        }
                    }
                } catch (Exception $cleanEx) {
                    error_log('[scores.php] Duplicate cleanup notice: ' . $cleanEx->getMessage());
                }
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
    // 1) Топ-150 за всё время по времени
    $topStmt = $pdo->query("
        SELECT id, user_id as userId, username, first_name as firstName, last_name as lastName,
               player_name as playerName, photo_url as photoUrl, hide_telegram as hideTelegram,
               time_ms as timeMs, run_distance as runDistance, risk_count as riskCount, score,
               had_jump as hadJump, had_helmet as hadHelmet, created_at as createdAt,
               score_day as scoreDay
        FROM `scores`
        ORDER BY `time_ms` DESC
        LIMIT 150
    ");
    $topRows = $topStmt->fetchAll();

    // 2) Свежие заезды за 35 дней (для Day / Week / Month)
    $since35Days = (int)((time() - 35 * 86400) * 1000);
    $recentStmt = $pdo->prepare("
        SELECT id, user_id as userId, username, first_name as firstName, last_name as lastName,
               player_name as playerName, photo_url as photoUrl, hide_telegram as hideTelegram,
               time_ms as timeMs, run_distance as runDistance, risk_count as riskCount, score,
               had_jump as hadJump, had_helmet as hadHelmet, created_at as createdAt,
               score_day as scoreDay
        FROM `scores`
        WHERE `created_at` >= :since
        ORDER BY `created_at` DESC
        LIMIT 300
    ");
    $recentStmt->execute([':since' => $since35Days]);
    $recentRows = $recentStmt->fetchAll();

    $byId = [];
    foreach ($topRows as $r) {
        $byId[$r['id']] = $r;
    }
    foreach ($recentRows as $r) {
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

    return $formatted;
}

// Авто-перенос существующих рекордов из scores.json в MySQL (если MySQL таблица пока пуста)
if ($pdo !== null) {
    try {
        $cntStmt = $pdo->query("SELECT COUNT(*) FROM `scores`");
        if ($cntStmt && (int)$cntStmt->fetchColumn() === 0) {
            $existingFileScores = getFileScores($dataFile);
            if (!empty($existingFileScores)) {
                $migStmt = $pdo->prepare("
                    INSERT INTO `scores` (
                        `user_id`, `username`, `first_name`, `last_name`, `player_name`, `photo_url`,
                        `time_ms`, `run_distance`, `risk_count`, `score`, `had_jump`, `had_helmet`, `created_at`
                    ) VALUES (
                        :user_id, :username, :first_name, :last_name, :player_name, :photo_url,
                        :time_ms, :run_distance, :risk_count, :score, :had_jump, :had_helmet, :created_at
                    )
                ");
                foreach ($existingFileScores as $fs) {
                    $tMs = (int)($fs['timeMs'] ?? 0);
                    $rDist = (int)($fs['runDistance'] ?? 0);
                    $rCount = (int)($fs['riskCount'] ?? 0);
                    $calcScore = (int)round(($tMs / 1000.0) * $rDist * (1 + $rCount));
                    $migStmt->execute([
                        ':user_id'      => $fs['userId'] ?? null,
                        ':username'     => $fs['username'] ?? null,
                        ':first_name'   => $fs['firstName'] ?? null,
                        ':last_name'    => $fs['lastName'] ?? null,
                        ':player_name'  => $fs['playerName'] ?? 'Игрок',
                        ':photo_url'    => $fs['photoUrl'] ?? null,
                        ':time_ms'      => $tMs,
                        ':run_distance' => $rDist,
                        ':risk_count'   => $rCount,
                        ':score'        => $calcScore,
                        ':had_jump'     => !empty($fs['hadJump']) ? 1 : 0,
                        ':had_helmet'   => !empty($fs['hadHelmet']) ? 1 : 0,
                        ':created_at'   => (int)($fs['createdAt'] ?? (time() * 1000)),
                    ]);
                }
            }
        }
    } catch (Exception $migEx) {
        error_log('[scores.php] Migration from JSON to MySQL notice: ' . $migEx->getMessage());
    }
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
                'error' => $dbError,
                'scores' => [],
            ]);
            exit;
        }
    }

    echo json_encode([
        'ok' => false,
        'source' => 'none',
        'dbStatus' => 'error',
        'error' => $dbError ?: 'База недоступна',
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

        $playerName = isset($input['playerName']) ? trim(strip_tags((string)$input['playerName'])) : 'Игрок';
        if ($playerName === '') $playerName = 'Игрок';
        if (mb_strlen($playerName) > 40) $playerName = mb_substr($playerName, 0, 40);

        $firstName = isset($input['firstName']) ? trim(strip_tags((string)$input['firstName'])) : null;
        $lastName = isset($input['lastName']) ? trim(strip_tags((string)$input['lastName'])) : null;
        $photoUrl = isset($input['photoUrl']) ? filter_var((string)$input['photoUrl'], FILTER_SANITIZE_URL) : null;

        $updatedRows = 0;

        if ($pdo !== null) {
            try {
                // Обновляем все записи игрока в таблице scores по userId или username
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
                if ($matchUser !== null && $matchUser !== '') {
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
    $runDistance = isset($input['runDistance']) ? max(0, (int)$input['runDistance']) : 0;
    $riskCount = isset($input['riskCount']) ? max(0, (int)$input['riskCount']) : 0;
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

    $scoreDay = date('Y-m-d', (int)($createdAt / 1000));

    if ($pdo !== null) {
        try {
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
                        WHERE `id` = :id
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
            $dbError = 'INSERT/UPDATE failed: ' . $e->getMessage();
            error_log('[scores.php] ' . $dbError);
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => $dbError, 'source' => 'mysql']);
            exit;
        }
    }

    http_response_code(503);
    echo json_encode([
        'ok' => false,
        'error' => $dbError ?: 'База недоступна',
        'source' => 'none',
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
