<?php
/**
 * Админка Untouch. Вход по admin_key (или diag_key) из bot_config.php.
 */
header('X-Robots-Tag: noindex, nofollow');

require_once __DIR__ . '/tg_common.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$action = isset($_GET['action']) ? (string)$_GET['action'] : '';
$input = [];
if ($method === 'POST') {
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $input = $decoded;
    } else {
        $input = $_POST;
    }
    if ($action === '' && !empty($input['action'])) {
        $action = (string)$input['action'];
    }
}
if ($action === '') {
    $action = 'stats';
}

function admin_json($payload, $code = 200) {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function admin_cookie_name() {
    return 'untouch_admin';
}

function admin_cookie_value($key) {
    return hash_hmac('sha256', 'untouch-admin-v1', $key);
}

function admin_set_session($key) {
    $secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || ((int)($_SERVER['SERVER_PORT'] ?? 0) === 443);
    setcookie(admin_cookie_name(), admin_cookie_value($key), [
        'expires' => time() + 60 * 60 * 24 * 30,
        'path' => '/',
        'secure' => $secure,
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

function admin_clear_session() {
    setcookie(admin_cookie_name(), '', [
        'expires' => time() - 3600,
        'path' => '/',
        'samesite' => 'Lax',
    ]);
}

function admin_request_key($input) {
    if (!empty($input['key']) && is_string($input['key'])) {
        return trim($input['key']);
    }
    if (!empty($_GET['key']) && is_string($_GET['key'])) {
        return trim($_GET['key']);
    }
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (stripos($auth, 'Bearer ') === 0) {
        return trim(substr($auth, 7));
    }
    return '';
}

function admin_is_authed($input) {
    $expected = tg_admin_key();
    if ($expected === '') {
        return false;
    }
    $cookie = $_COOKIE[admin_cookie_name()] ?? '';
    if (is_string($cookie) && $cookie !== '' && hash_equals(admin_cookie_value($expected), $cookie)) {
        return true;
    }
    $got = admin_request_key($input);
    return $got !== '' && hash_equals($expected, $got);
}

function admin_client_ip() {
    $ip = (string)($_SERVER['REMOTE_ADDR'] ?? '0');
    $clean = preg_replace('/[^0-9a-fA-F:.]/', '', $ip);
    return $clean !== '' ? $clean : '0';
}

function admin_guard_file() {
    return __DIR__ . '/admin_guard.json';
}

function admin_guard_load() {
    $file = admin_guard_file();
    if (!is_file($file)) return [];
    $data = json_decode((string)@file_get_contents($file), true);
    return is_array($data) ? $data : [];
}

function admin_guard_save(array $data) {
    $now = time();
    foreach ($data as $ip => $row) {
        $until = (int)($row['locked_until'] ?? 0);
        $fails = (int)($row['fails'] ?? 0);
        if ($until < $now && $fails < 1) {
            unset($data[$ip]);
        }
    }
    @file_put_contents(admin_guard_file(), json_encode($data), LOCK_EX);
}

function admin_lock_until() {
    $all = admin_guard_load();
    $row = $all[admin_client_ip()] ?? null;
    if (!$row) return 0;
    $until = (int)($row['locked_until'] ?? 0);
    return $until > time() ? $until : 0;
}

function admin_lock_message($until) {
    $min = max(1, (int)ceil(($until - time()) / 60));
    return 'Слишком много попыток. Попробуйте через ' . $min . ' мин.';
}

function admin_lock_fail() {
    $ip = admin_client_ip();
    $all = admin_guard_load();
    $row = $all[$ip] ?? ['fails' => 0, 'locked_until' => 0];
    $until = (int)($row['locked_until'] ?? 0);
    if ($until > time()) {
        return $until;
    }
    $fails = (int)($row['fails'] ?? 0) + 1;
    $row['fails'] = $fails;
    $row['locked_until'] = $fails >= 3 ? time() + 3600 : 0;
    $all[$ip] = $row;
    admin_guard_save($all);
    return (int)$row['locked_until'];
}

function admin_lock_clear() {
    $all = admin_guard_load();
    unset($all[admin_client_ip()]);
    admin_guard_save($all);
}

$key = tg_admin_key();

if ($action === 'login') {
    $locked = admin_lock_until();
    if ($locked) {
        admin_json(['ok' => false, 'error' => admin_lock_message($locked)], 429);
    }
    $got = admin_request_key($input);
    if ($key === '') {
        admin_json(['ok' => false, 'error' => 'Админка не настроена'], 503);
    }
    if ($got === '' || !hash_equals($key, $got)) {
        $until = admin_lock_fail();
        if ($until > time()) {
            admin_json(['ok' => false, 'error' => admin_lock_message($until)], 429);
        }
        admin_json(['ok' => false, 'error' => 'Неверный ключ'], 401);
    }
    admin_lock_clear();
    admin_set_session($key);
    admin_json(['ok' => true, 'action' => 'login']);
}

if ($action === 'logout') {
    admin_clear_session();
    admin_json(['ok' => true, 'action' => 'logout']);
}

if ($action === 'status') {
    admin_json([
        'ok' => true,
        'configured' => $key !== '',
        'authed' => admin_is_authed($input),
    ]);
}

if (!admin_is_authed($input)) {
    admin_json(['ok' => false, 'error' => 'Нужен вход'], 401);
}

function admin_count(PDO $pdo, $sql, $params = []) {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return (int)$stmt->fetchColumn();
}

function admin_table_exists(PDO $pdo, $name) {
    $safe = preg_replace('/[^a-z0-9_]/i', '', (string)$name);
    if ($safe === '') return false;
    $stmt = $pdo->query('SHOW TABLES LIKE ' . $pdo->quote($safe));
    return $stmt ? (bool)$stmt->fetchColumn() : false;
}

try {
    [$pdo, $dbError] = tg_connect_pdo();
    if (!$pdo) {
        admin_json(['ok' => false, 'error' => $dbError ?: 'База недоступна'], 503);
    }
    tg_ensure_bot_admin_tables($pdo);
    tg_ensure_social_tables($pdo);
    tg_ensure_commerce_tables($pdo);
    tg_backfill_bot_users($pdo);
} catch (Exception $e) {
    error_log('[admin.php] setup: ' . $e->getMessage());
    admin_json(['ok' => false, 'error' => 'База: ' . $e->getMessage()], 500);
}

if ($action === 'stats') {
  try {
    $todayStart = tg_admin_day_start_ms(0);
    $weekStart = tg_admin_day_start_ms(6);
    $monthStart = tg_admin_day_start_ms(29);
    $todayYmd = tg_admin_today_ymd();
    $weekYmd = (new DateTime('now', tg_admin_tz()))->modify('-6 days')->format('Y-m-d');

    $hasScores = admin_table_exists($pdo, 'scores');
    $hasRefs = admin_table_exists($pdo, 'referrals');
    $hasWallets = admin_table_exists($pdo, 'wallets');
    $hasFlags = admin_table_exists($pdo, 'user_flags');

    $chart = [];
    $chartStmt = $pdo->prepare("
        SELECT `stat_day`, COUNT(*) AS active, SUM(`messages`) AS messages, SUM(`starts`) AS starts
        FROM `bot_daily`
        WHERE `stat_day` >= :from
        GROUP BY `stat_day`
        ORDER BY `stat_day` ASC
    ");
    $fromDay = (new DateTime('now', tg_admin_tz()))->modify('-13 days')->format('Y-m-d');
    $chartStmt->execute([':from' => $fromDay]);
    $byDay = [];
    foreach ($chartStmt->fetchAll() as $row) {
        $byDay[$row['stat_day']] = [
            'active' => (int)$row['active'],
            'messages' => (int)$row['messages'],
            'starts' => (int)$row['starts'],
            'newUsers' => 0,
        ];
    }
    $newStmt = $pdo->query('SELECT `first_seen_at` FROM `bot_users` WHERE `first_seen_at` > 0');
    $tz = tg_admin_tz();
    foreach ($newStmt->fetchAll() as $row) {
        $ms = (int)$row['first_seen_at'];
        if ($ms < 1000) continue;
        $d = (new DateTime('@' . (int)floor($ms / 1000)))->setTimezone($tz)->format('Y-m-d');
        if ($d < $fromDay) continue;
        if (!isset($byDay[$d])) {
            $byDay[$d] = ['active' => 0, 'messages' => 0, 'starts' => 0, 'newUsers' => 0];
        }
        $byDay[$d]['newUsers']++;
    }
    $cursor = new DateTime($fromDay, $tz);
    $end = new DateTime($todayYmd, $tz);
    while ($cursor <= $end) {
        $keyDay = $cursor->format('Y-m-d');
        $row = $byDay[$keyDay] ?? ['active' => 0, 'messages' => 0, 'starts' => 0, 'newUsers' => 0];
        $row['day'] = $keyDay;
        $chart[] = $row;
        $cursor->modify('+1 day');
    }

    admin_json([
        'ok' => true,
        'timezone' => 'Europe/Moscow',
        'stats' => [
            'total' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users`'),
            'activeToday' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `last_seen_at` >= :t', [':t' => $todayStart]),
            'activeWeek' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `last_seen_at` >= :t', [':t' => $weekStart]),
            'activeMonth' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `last_seen_at` >= :t', [':t' => $monthStart]),
            'newToday' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `first_seen_at` >= :t', [':t' => $todayStart]),
            'newWeek' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `first_seen_at` >= :t', [':t' => $weekStart]),
            'newMonth' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `first_seen_at` >= :t', [':t' => $monthStart]),
            'startsToday' => admin_count($pdo, 'SELECT COALESCE(SUM(`starts`),0) FROM `bot_daily` WHERE `stat_day` = :d', [':d' => $todayYmd]),
            'startsWeek' => admin_count($pdo, 'SELECT COALESCE(SUM(`starts`),0) FROM `bot_daily` WHERE `stat_day` >= :d', [':d' => $weekYmd]),
            'startsTotal' => admin_count($pdo, 'SELECT COALESCE(SUM(`start_count`),0) FROM `bot_users`'),
            'messagesToday' => admin_count($pdo, 'SELECT COALESCE(SUM(`messages`),0) FROM `bot_daily` WHERE `stat_day` = :d', [':d' => $todayYmd]),
            'messagesWeek' => admin_count($pdo, 'SELECT COALESCE(SUM(`messages`),0) FROM `bot_daily` WHERE `stat_day` >= :d', [':d' => $weekYmd]),
            'messagesTotal' => admin_count($pdo, 'SELECT COALESCE(SUM(`message_count`),0) FROM `bot_users`'),
            'blocked' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `blocked` = 1'),
            'premium' => admin_count($pdo, 'SELECT COUNT(*) FROM `bot_users` WHERE `is_premium` = 1'),
            'players' => $hasScores
                ? admin_count($pdo, "SELECT COUNT(DISTINCT `user_id`) FROM `scores` WHERE `user_id` IS NOT NULL AND `user_id` != ''")
                : 0,
            'referrals' => $hasRefs ? admin_count($pdo, 'SELECT COUNT(*) FROM `referrals`') : 0,
            'paid' => $hasWallets ? admin_count($pdo, 'SELECT COUNT(*) FROM `wallets`') : 0,
            'writeAccess' => $hasFlags
                ? admin_count($pdo, 'SELECT COUNT(*) FROM `user_flags` WHERE `write_access` = 1')
                : 0,
        ],
        'chart' => $chart,
    ]);
  } catch (Exception $e) {
    error_log('[admin.php] stats: ' . $e->getMessage());
    admin_json(['ok' => false, 'error' => 'Статистика: ' . $e->getMessage()], 500);
  }
}

if ($action === 'users') {
  try {
    $q = trim((string)($input['q'] ?? $_GET['q'] ?? ''));
    $filter = trim((string)($input['filter'] ?? $_GET['filter'] ?? 'all'));
    $page = max(1, (int)($input['page'] ?? $_GET['page'] ?? 1));
    $limit = 50;
    $offset = ($page - 1) * $limit;
    $todayStart = tg_admin_day_start_ms(0);
    $weekStart = tg_admin_day_start_ms(6);
    $hasScores = admin_table_exists($pdo, 'scores');
    $hasRefs = admin_table_exists($pdo, 'referrals');

    $where = ['1=1'];
    $params = [];
    if ($q !== '') {
        $where[] = '(u.user_id LIKE :q OR u.username LIKE :q OR u.first_name LIKE :q OR u.last_name LIKE :q)';
        $params[':q'] = '%' . $q . '%';
    }
    if ($filter === 'today') {
        $where[] = 'u.last_seen_at >= :from';
        $params[':from'] = $todayStart;
    } elseif ($filter === 'week') {
        $where[] = 'u.last_seen_at >= :from';
        $params[':from'] = $weekStart;
    } elseif ($filter === 'new_today') {
        $where[] = 'u.first_seen_at >= :from';
        $params[':from'] = $todayStart;
    } elseif ($filter === 'new_week') {
        $where[] = 'u.first_seen_at >= :from';
        $params[':from'] = $weekStart;
    } elseif ($filter === 'started') {
        $where[] = 'u.start_count > 0';
    } elseif ($filter === 'played') {
        $where[] = $hasScores
            ? 'EXISTS (SELECT 1 FROM `scores` s WHERE s.user_id = u.user_id)'
            : '0=1';
    } elseif ($filter === 'blocked') {
        $where[] = 'u.blocked = 1';
    } elseif ($filter === 'premium') {
        $where[] = 'u.is_premium = 1';
    }

    $whereSql = implode(' AND ', $where);
    $countStmt = $pdo->prepare("SELECT COUNT(*) FROM `bot_users` u WHERE $whereSql");
    $countStmt->execute($params);
    $total = (int)$countStmt->fetchColumn();
    $pages = max(1, (int)ceil($total / $limit));

    $playedSelect = $hasScores
        ? 'EXISTS(SELECT 1 FROM `scores` s WHERE s.user_id = u.user_id) AS played'
        : '0 AS played';
    $invitedSelect = $hasRefs
        ? '(SELECT r.inviter_id FROM `referrals` r WHERE r.invitee_id = u.user_id LIMIT 1) AS invited_by'
        : 'NULL AS invited_by';

    $sql = "
        SELECT
            u.*,
            $playedSelect,
            $invitedSelect
        FROM `bot_users` u
        WHERE $whereSql
        ORDER BY u.last_seen_at DESC
        LIMIT $limit OFFSET $offset
    ";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $items = [];
    foreach ($stmt->fetchAll() as $row) {
        $items[] = [
            'userId' => (string)$row['user_id'],
            'username' => $row['username'] ?: '',
            'firstName' => $row['first_name'] ?: '',
            'lastName' => $row['last_name'] ?: '',
            'language' => $row['language_code'] ?: '',
            'isPremium' => (int)$row['is_premium'] === 1,
            'blocked' => (int)$row['blocked'] === 1,
            'firstSeenAt' => (int)$row['first_seen_at'],
            'lastSeenAt' => (int)$row['last_seen_at'],
            'messageCount' => (int)$row['message_count'],
            'startCount' => (int)$row['start_count'],
            'lastKind' => (string)$row['last_kind'],
            'lastText' => (string)($row['last_text'] ?? ''),
            'lastStartPayload' => (string)($row['last_start_payload'] ?? ''),
            'played' => (int)$row['played'] === 1,
            'invitedBy' => $row['invited_by'] ? (string)$row['invited_by'] : '',
        ];
    }

    admin_json([
        'ok' => true,
        'page' => $page,
        'pages' => $pages,
        'total' => $total,
        'filter' => $filter,
        'q' => $q,
        'items' => $items,
    ]);
  } catch (Exception $e) {
    error_log('[admin.php] users: ' . $e->getMessage());
    admin_json(['ok' => false, 'error' => 'Список: ' . $e->getMessage()], 500);
  }
}

admin_json(['ok' => false, 'error' => 'Unknown action'], 400);
