<?php
/**
 * Общие хелперы Telegram Mini App: PDO, initData, каталог Stars, кошелёк.
 */

function tg_json_headers() {
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-Telegram-Init-Data');
}

function tg_bot_config() {
    static $cfg = null;
    if ($cfg !== null) return $cfg;
    $file = __DIR__ . '/bot_config.php';
    if (!file_exists($file)) {
        $cfg = [];
        return $cfg;
    }
    $loaded = @include $file;
    $cfg = is_array($loaded) ? $loaded : [];
    return $cfg;
}

function tg_bot_token() {
    $cfg = tg_bot_config();
    $token = trim((string)($cfg['token'] ?? ''));
    return $token !== '' && $token !== 'YOUR_BOT_TOKEN' ? $token : '';
}

function tg_api_base() {
    $cfg = tg_bot_config();
    $base = trim((string)($cfg['api_base'] ?? 'https://api.telegram.org'));
    if ($base === '') $base = 'https://api.telegram.org';
    return rtrim($base, '/');
}

function tg_api_proxy() {
    $cfg = tg_bot_config();
    return trim((string)($cfg['proxy'] ?? ''));
}

function tg_firebase_rc() {
    return [
        'apiKey' => 'AIzaSyBQ5iCD9OAotliddp-j0Dp-GfbeyqSKTsY',
        'projectId' => 'game-box-b30d4',
        'appId' => '1:332169968823:android:a485d65569bb1269d4e132',
    ];
}

function tg_local_gameplay_config() {
    $file = dirname(__DIR__) . '/config/gameplay-config.json';
    if (!is_file($file)) return [];
    $raw = @file_get_contents($file);
    $data = json_decode((string)$raw, true);
    return is_array($data) ? $data : [];
}

function tg_rc_cache_file() {
    return __DIR__ . '/rc_economy_cache.json';
}

function tg_read_rc_cache() {
    $file = tg_rc_cache_file();
    if (!is_file($file)) return null;
    $data = json_decode((string)@file_get_contents($file), true);
    return is_array($data) ? $data : null;
}

function tg_write_rc_cache($payload) {
    $file = tg_rc_cache_file();
    @file_put_contents($file, json_encode($payload, JSON_UNESCAPED_UNICODE));
}

function tg_http_post_json($url, $payload, $timeoutSec = 5) {
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeoutSec);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 4);
        if (defined('CURL_IPRESOLVE_V4')) {
            curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
        }
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        $raw = curl_exec($ch);
        $err = curl_error($ch);
        curl_close($ch);
        if ($raw === false) {
            throw new Exception($err !== '' ? $err : 'curl failed');
        }
        return $raw;
    }
    $ctx = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => "Content-Type: application/json\r\n",
            'content' => $json,
            'timeout' => $timeoutSec,
            'ignore_errors' => true,
        ],
    ]);
    $raw = @file_get_contents($url, false, $ctx);
    if ($raw === false) {
        throw new Exception('HTTP POST failed');
    }
    return $raw;
}

function tg_fetch_firebase_economy() {
    $fb = tg_firebase_rc();
    $url = 'https://firebaseremoteconfig.googleapis.com/v1/projects/'
        . $fb['projectId'] . '/namespaces/firebase:fetch?key=' . $fb['apiKey'];
    $raw = tg_http_post_json($url, [
        'appId' => $fb['appId'],
        'appInstanceId' => 'tg_php_host',
    ], 5);
    $data = json_decode($raw, true);
    if (!is_array($data) || empty($data['entries']) || !is_array($data['entries'])) {
        throw new Exception('Firebase RC: empty entries');
    }
    $economyRaw = $data['entries']['economy'] ?? null;
    if (is_array($economyRaw) && isset($economyRaw['value'])) {
        $economyRaw = $economyRaw['value'];
    }
    if (is_string($economyRaw)) {
        $economy = json_decode($economyRaw, true);
    } elseif (is_array($economyRaw)) {
        $economy = $economyRaw;
    } else {
        throw new Exception('Firebase RC: no economy');
    }
    if (!is_array($economy)) {
        throw new Exception('Firebase RC: economy is not JSON');
    }
    return $economy;
}

function tg_remote_economy() {
    $ttl = 180;
    $now = time();
    $cache = tg_read_rc_cache();
    if (is_array($cache) && isset($cache['economy']) && is_array($cache['economy'])) {
        $age = $now - (int)($cache['ts'] ?? 0);
        if ($age >= 0 && $age < $ttl) {
            $cache['_fresh'] = true;
            $cache['_source'] = 'firebase';
            return $cache;
        }
    }
    try {
        $economy = tg_fetch_firebase_economy();
        $payload = [
            'ts' => $now,
            'source' => 'firebase',
            'economy' => $economy,
        ];
        tg_write_rc_cache($payload);
        $payload['_fresh'] = true;
        $payload['_source'] = 'firebase';
        return $payload;
    } catch (Exception $e) {
        if (is_array($cache) && isset($cache['economy']) && is_array($cache['economy'])) {
            $cache['_fresh'] = false;
            $cache['_source'] = 'firebase_cache';
            $cache['_error'] = $e->getMessage();
            return $cache;
        }
        return [
            'ts' => 0,
            'source' => 'local',
            'economy' => [],
            '_fresh' => false,
            '_source' => 'local',
            '_error' => $e->getMessage(),
        ];
    }
}

function tg_load_economy() {
    static $eco = null;
    if ($eco !== null) return $eco;
    $local = tg_local_gameplay_config();
    $base = isset($local['economy']) && is_array($local['economy']) ? $local['economy'] : [];
    $remote = tg_remote_economy();
    $overlay = isset($remote['economy']) && is_array($remote['economy']) ? $remote['economy'] : [];
    $eco = array_merge($base, $overlay);
    $eco['_catalog_source'] = $remote['_source'] ?? 'local';
    if (!empty($remote['_error'])) $eco['_catalog_error'] = $remote['_error'];
    return $eco;
}

function tg_products_fallback() {
    return [
        'pack_s' => [
            'id' => 'pack_s',
            'kind' => 'crystals',
            'crystals' => 40,
            'stars' => 49,
            'title' => 'Горсть',
            'description' => '40 кристаллов Untouch',
        ],
        'pack_m' => [
            'id' => 'pack_m',
            'kind' => 'crystals',
            'crystals' => 120,
            'stars' => 149,
            'title' => 'Стопка',
            'description' => '120 кристаллов Untouch',
        ],
        'pack_l' => [
            'id' => 'pack_l',
            'kind' => 'crystals',
            'crystals' => 350,
            'stars' => 349,
            'title' => 'Сундук',
            'description' => '350 кристаллов Untouch',
        ],
        'pack_xl' => [
            'id' => 'pack_xl',
            'kind' => 'crystals',
            'crystals' => 900,
            'stars' => 749,
            'title' => 'Сейф',
            'description' => '900 кристаллов Untouch',
        ],
        'plus_monthly' => [
            'id' => 'plus_monthly',
            'kind' => 'plus',
            'crystals' => 0,
            'stars' => 199,
            'days' => 30,
            'title' => 'Plus',
            'description' => 'Plus на 30 дней: ежедневный бонус ×2',
            'subscription_period' => 2592000,
        ],
    ];
}

function tg_products_from_economy($economy) {
    $shop = isset($economy['starsShop']) && is_array($economy['starsShop']) ? $economy['starsShop'] : [];
    $out = [];
    $packs = isset($shop['packs']) && is_array($shop['packs']) ? $shop['packs'] : [];
    foreach ($packs as $raw) {
        if (!is_array($raw)) continue;
        $id = trim((string)($raw['id'] ?? ''));
        $crystals = (int)($raw['crystals'] ?? 0);
        $stars = (int)($raw['stars'] ?? 0);
        if ($id === '' || $crystals <= 0 || $stars <= 0) continue;
        $title = trim((string)($raw['title'] ?? $id));
        if ($title === '') $title = $id;
        $out[$id] = [
            'id' => $id,
            'kind' => 'crystals',
            'crystals' => $crystals,
            'stars' => $stars,
            'title' => $title,
            'description' => $crystals . ' кристаллов Untouch',
        ];
    }
    $plus = isset($shop['plus']) && is_array($shop['plus']) ? $shop['plus'] : [];
    $plusId = trim((string)($plus['id'] ?? 'plus_monthly'));
    if ($plusId === '') $plusId = 'plus_monthly';
    $plusStars = (int)($plus['stars'] ?? 0);
    $plusDays = (int)($plus['days'] ?? 30);
    if ($plusDays < 1) $plusDays = 30;
    if ($plusStars > 0) {
        $plusTitle = trim((string)($plus['title'] ?? 'Plus'));
        if ($plusTitle === '') $plusTitle = 'Plus';
        $out[$plusId] = [
            'id' => $plusId,
            'kind' => 'plus',
            'crystals' => 0,
            'stars' => $plusStars,
            'days' => $plusDays,
            'title' => $plusTitle,
            'description' => 'Plus на ' . $plusDays . ' дней: ежедневный бонус ×2',
            'subscription_period' => $plusDays * 86400,
        ];
    }
    return $out;
}

function tg_products() {
    static $all = null;
    if ($all !== null) return $all;
    $fromRc = tg_products_from_economy(tg_load_economy());
    $all = $fromRc !== [] ? $fromRc : tg_products_fallback();
    return $all;
}

function tg_product($id) {
    $all = tg_products();
    return $all[$id] ?? null;
}

function tg_catalog_debug() {
    $eco = tg_load_economy();
    $all = tg_products();
    $plus = null;
    $packCount = 0;
    foreach ($all as $p) {
        if (($p['kind'] ?? '') === 'plus') $plus = $p;
        else $packCount++;
    }
    return [
        'source' => $eco['_catalog_source'] ?? 'local',
        'error' => $eco['_catalog_error'] ?? null,
        'packs' => $packCount,
        'plus_stars' => $plus ? (int)$plus['stars'] : null,
        'plus_days' => $plus ? (int)($plus['days'] ?? 30) : null,
    ];
}

/**
 * @return array{ok:bool,user:?array,userId:?string,error:?string}
 */
function tg_validate_init_data($initData) {
    $initData = is_string($initData) ? $initData : '';
    if ($initData === '') {
        return ['ok' => false, 'user' => null, 'userId' => null, 'error' => 'Нет initData'];
    }
    $token = tg_bot_token();
    if ($token === '') {
        return ['ok' => false, 'user' => null, 'userId' => null, 'error' => 'Бот не настроен'];
    }

    $params = [];
    parse_str($initData, $params);
    $hash = $params['hash'] ?? '';
    if ($hash === '') {
        return ['ok' => false, 'user' => null, 'userId' => null, 'error' => 'Нет hash'];
    }
    unset($params['hash']);
    ksort($params);
    $pairs = [];
    foreach ($params as $k => $v) {
        $pairs[] = $k . '=' . $v;
    }
    $dataCheck = implode("\n", $pairs);
    $secret = hash_hmac('sha256', $token, 'WebAppData', true);
    $calc = hash_hmac('sha256', $dataCheck, $secret);
    if (!hash_equals($calc, $hash)) {
        return ['ok' => false, 'user' => null, 'userId' => null, 'error' => 'Неверная подпись'];
    }

    $authDate = isset($params['auth_date']) ? (int)$params['auth_date'] : 0;
    if ($authDate > 0 && (time() - $authDate) > 604800) {
        return ['ok' => false, 'user' => null, 'userId' => null, 'error' => 'initData устарел'];
    }

    $user = null;
    if (!empty($params['user'])) {
        $user = json_decode($params['user'], true);
    }
    $userId = isset($user['id']) ? (string)$user['id'] : null;
    if ($userId === null || $userId === '') {
        return ['ok' => false, 'user' => $user, 'userId' => null, 'startParam' => null, 'error' => 'Нет user id'];
    }
    $startParam = isset($params['start_param']) ? trim((string)$params['start_param']) : '';
    return [
        'ok' => true,
        'user' => $user,
        'userId' => $userId,
        'startParam' => $startParam !== '' ? $startParam : null,
        'error' => null,
    ];
}

function tg_read_init_data_from_request($input = null) {
    $header = $_SERVER['HTTP_X_TELEGRAM_INIT_DATA'] ?? '';
    if (is_string($header) && $header !== '') return $header;
    if (is_array($input) && !empty($input['initData']) && is_string($input['initData'])) {
        return $input['initData'];
    }
    if (!empty($_GET['initData']) && is_string($_GET['initData'])) {
        return $_GET['initData'];
    }
    return '';
}

function tg_require_user($input = null) {
    $auth = tg_validate_init_data(tg_read_init_data_from_request($input));
    if (!$auth['ok']) {
        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => $auth['error'] ?? 'Unauthorized']);
        exit;
    }
    return $auth;
}

function tg_connect_pdo() {
    $configFile = __DIR__ . '/db_config.php';
    if (!file_exists($configFile)) {
        return [null, 'db_config.php not found'];
    }
    $dbConfig = @include $configFile;
    if (!is_array($dbConfig) || empty($dbConfig['database']) || empty($dbConfig['username'])) {
        return [null, 'invalid db_config.php'];
    }
    $db      = $dbConfig['database'];
    $user    = $dbConfig['username'];
    $pass    = $dbConfig['password'] ?? '';
    $charset = $dbConfig['charset'] ?? 'utf8mb4';
    $port    = !empty($dbConfig['port']) ? (int)$dbConfig['port'] : 3308;
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
    $errors = [];
    foreach ($configsToTry as $cfg) {
        try {
            $portPart = $cfg['port'] ? ";port={$cfg['port']}" : '';
            $dsn = "mysql:host={$cfg['host']}{$portPart};dbname={$db};charset={$charset}";
            $pdo = new PDO($dsn, $user, $pass, $opt);
            $pdo->query('SELECT 1');
            return [$pdo, null];
        } catch (Exception $e) {
            $errors[] = $e->getMessage();
        }
    }
    return [null, implode(' | ', $errors)];
}

function tg_ensure_commerce_tables(PDO $pdo) {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `wallets` (
            `user_id` VARCHAR(64) NOT NULL,
            `stars_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
            `plus_until_ms` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `updated_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `star_payments` (
            `charge_id` VARCHAR(128) NOT NULL,
            `user_id` VARCHAR(64) NOT NULL,
            `product_id` VARCHAR(32) NOT NULL,
            `stars` INT UNSIGNED NOT NULL DEFAULT 0,
            `crystals` INT UNSIGNED NOT NULL DEFAULT 0,
            `created_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`charge_id`),
            KEY `idx_user_id` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function tg_wallet_snapshot(PDO $pdo, $userId) {
    tg_ensure_commerce_tables($pdo);
    $stmt = $pdo->prepare('SELECT stars_tokens, plus_until_ms FROM `wallets` WHERE `user_id` = :uid LIMIT 1');
    $stmt->execute([':uid' => (string)$userId]);
    $row = $stmt->fetch();
    $plusUntil = $row ? (int)$row['plus_until_ms'] : 0;
    $now = (int)(microtime(true) * 1000);
    return [
        'tokens' => $row ? (int)$row['stars_tokens'] : 0,
        'plusUntilMs' => $plusUntil,
        'hasPremium' => $plusUntil > $now,
    ];
}

function tg_apply_product(PDO $pdo, $userId, $productId, $chargeId) {
    tg_ensure_commerce_tables($pdo);
    $product = tg_product($productId);
    if (!$product) {
        throw new Exception('Unknown product');
    }
    $now = (int)(microtime(true) * 1000);
    $pdo->beginTransaction();
    try {
        $exists = $pdo->prepare('SELECT charge_id FROM `star_payments` WHERE `charge_id` = :id LIMIT 1');
        $exists->execute([':id' => $chargeId]);
        if ($exists->fetch()) {
            $pdo->commit();
            return tg_wallet_snapshot($pdo, $userId);
        }

        $pdo->prepare('
            INSERT INTO `star_payments` (`charge_id`, `user_id`, `product_id`, `stars`, `crystals`, `created_at`)
            VALUES (:charge_id, :user_id, :product_id, :stars, :crystals, :created_at)
        ')->execute([
            ':charge_id' => $chargeId,
            ':user_id' => (string)$userId,
            ':product_id' => $productId,
            ':stars' => (int)$product['stars'],
            ':crystals' => (int)$product['crystals'],
            ':created_at' => $now,
        ]);

        $cur = $pdo->prepare('SELECT stars_tokens, plus_until_ms FROM `wallets` WHERE `user_id` = :uid LIMIT 1');
        $cur->execute([':uid' => (string)$userId]);
        $row = $cur->fetch();
        $tokens = $row ? (int)$row['stars_tokens'] : 0;
        $plusUntil = $row ? (int)$row['plus_until_ms'] : 0;
        $tokens += (int)$product['crystals'];
        if ($product['kind'] === 'plus') {
            $days = (int)($product['days'] ?? 30);
            if ($days < 1) $days = 30;
            $base = max($plusUntil, $now);
            $plusUntil = $base + $days * 86400 * 1000;
        }

        if ($row) {
            $pdo->prepare('
                UPDATE `wallets` SET `stars_tokens` = :tokens, `plus_until_ms` = :plus_until, `updated_at` = :upd
                WHERE `user_id` = :uid
            ')->execute([
                ':tokens' => $tokens,
                ':plus_until' => $plusUntil,
                ':upd' => $now,
                ':uid' => (string)$userId,
            ]);
        } else {
            $pdo->prepare('
                INSERT INTO `wallets` (`user_id`, `stars_tokens`, `plus_until_ms`, `updated_at`)
                VALUES (:uid, :tokens, :plus_until, :upd)
            ')->execute([
                ':uid' => (string)$userId,
                ':tokens' => $tokens,
                ':plus_until' => $plusUntil,
                ':upd' => $now,
            ]);
        }
        $pdo->commit();
    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    return tg_wallet_snapshot($pdo, $userId);
}

function tg_api($method, $payload) {
    $token = tg_bot_token();
    if ($token === '') {
        throw new Exception('Bot token missing');
    }
    $url = tg_api_base() . '/bot' . $token . '/' . $method;
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
    $raw = null;
    $code = 0;
    $proxy = tg_api_proxy();

    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 8);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
        if (defined('CURL_IPRESOLVE_V4')) {
            curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
        }
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        if ($proxy !== '') {
            curl_setopt($ch, CURLOPT_PROXY, $proxy);
            if (stripos($proxy, 'socks5') === 0 && defined('CURLPROXY_SOCKS5_HOSTNAME')) {
                curl_setopt($ch, CURLOPT_PROXYTYPE, CURLPROXY_SOCKS5_HOSTNAME);
            }
        }
        $raw = curl_exec($ch);
        $err = curl_error($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($raw === false) {
            throw new Exception('Telegram curl: ' . $err);
        }
    } else {
        $ctx = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => "Content-Type: application/json\r\n",
                'content' => $json,
                'timeout' => 20,
                'ignore_errors' => true,
            ],
        ]);
        $raw = @file_get_contents($url, false, $ctx);
        if (isset($http_response_header[0]) && preg_match('/\s(\d{3})\s/', $http_response_header[0], $m)) {
            $code = (int)$m[1];
        }
        if ($raw === false) {
            throw new Exception('Telegram HTTP: allow_url_fopen/curl disabled');
        }
    }

    $data = json_decode($raw, true);
    if (!is_array($data) || empty($data['ok'])) {
        $desc = is_array($data) ? ($data['description'] ?? $raw) : $raw;
        throw new Exception('Telegram API ' . $code . ': ' . $desc);
    }
    return $data['result'];
}

function tg_api_upload($method, $fields, $timeoutSec = 20) {
    $token = tg_bot_token();
    if ($token === '') {
        throw new Exception('Bot token missing');
    }
    if (!function_exists('curl_init')) {
        throw new Exception('curl required for file upload');
    }
    $url = tg_api_base() . '/bot' . $token . '/' . $method;
    $proxy = tg_api_proxy();
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $fields);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, $timeoutSec);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 8);
    if (defined('CURL_IPRESOLVE_V4')) {
        curl_setopt($ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
    }
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
    if ($proxy !== '') {
        curl_setopt($ch, CURLOPT_PROXY, $proxy);
        if (stripos($proxy, 'socks5') === 0 && defined('CURLPROXY_SOCKS5_HOSTNAME')) {
            curl_setopt($ch, CURLOPT_PROXYTYPE, CURLPROXY_SOCKS5_HOSTNAME);
        }
    }
    $raw = curl_exec($ch);
    $err = curl_error($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($raw === false) {
        throw new Exception('Telegram upload curl: ' . $err);
    }
    $data = json_decode($raw, true);
    if (!is_array($data) || empty($data['ok'])) {
        $desc = is_array($data) ? ($data['description'] ?? $raw) : $raw;
        throw new Exception('Telegram API ' . $code . ': ' . $desc);
    }
    return $data['result'];
}

function tg_webhook_mark($payload) {
    $payload['at'] = date('c');
    @file_put_contents(
        __DIR__ . '/webhook_last.json',
        json_encode($payload, JSON_UNESCAPED_UNICODE)
    );
}

function tg_webapp_url() {
    $cfg = tg_bot_config();
    $url = trim((string)($cfg['webapp_url'] ?? 'https://untouch.ballaball.xyz/'));
    if ($url === '') $url = 'https://untouch.ballaball.xyz/';
    return $url;
}

function tg_start_text() {
    return "Untouch — кубик, которого нельзя касаться.\n\n"
        . "Уводите героя от красных. Риски и шаги дают кристаллы. Бейте свой рекорд.\n\n"
        . "Жмите Играть 👇";
}

function tg_bot_username() {
    $cfg = tg_bot_config();
    $name = trim((string)($cfg['bot_username'] ?? 'UntouchGameBot'));
    $name = ltrim($name, '@');
    return $name !== '' ? $name : 'UntouchGameBot';
}

function tg_invite_start_url($userId) {
    $id = preg_replace('/\D+/', '', (string)$userId);
    if ($id === '') {
        return 'https://t.me/' . tg_bot_username();
    }
    return 'https://t.me/' . tg_bot_username() . '?start=r' . $id;
}

function tg_invite_link_label() {
    return 'Перейти в бот с игрой';
}

function tg_invite_photo_url() {
    return rtrim(tg_webapp_url(), '/') . '/assets/branding/botfather_webapp_640x360.jpg';
}

function tg_invite_photo_path() {
    return dirname(__DIR__) . '/assets/branding/botfather_webapp_640x360.jpg';
}

function tg_invite_photo_cache_file() {
    return __DIR__ . '/invite_photo_file_id.json';
}

function tg_photo_file_id_from_message($sent) {
    $photos = isset($sent['photo']) && is_array($sent['photo']) ? $sent['photo'] : [];
    if (!$photos) return '';
    $best = $photos[0];
    foreach ($photos as $p) {
        if ((int)($p['file_size'] ?? 0) >= (int)($best['file_size'] ?? 0)) {
            $best = $p;
        }
    }
    return (string)($best['file_id'] ?? '');
}

function tg_read_invite_photo_file_id() {
    $path = tg_invite_photo_path();
    $mtime = is_file($path) ? (int)filemtime($path) : 0;
    $cacheFile = tg_invite_photo_cache_file();
    if (!is_file($cacheFile)) return '';
    $data = json_decode((string)@file_get_contents($cacheFile), true);
    if (!is_array($data) || empty($data['file_id'])) return '';
    if ($mtime > 0 && (int)($data['mtime'] ?? 0) !== $mtime) return '';
    return (string)$data['file_id'];
}

function tg_write_invite_photo_file_id($fileId) {
    $path = tg_invite_photo_path();
    @file_put_contents(tg_invite_photo_cache_file(), json_encode([
        'file_id' => (string)$fileId,
        'mtime' => is_file($path) ? (int)filemtime($path) : 0,
    ], JSON_UNESCAPED_UNICODE));
}

function tg_upload_invite_photo($chatId) {
    $path = tg_invite_photo_path();
    if (is_file($path) && class_exists('CURLFile')) {
        $sent = tg_api_upload('sendPhoto', [
            'chat_id' => (string)$chatId,
            'disable_notification' => 'true',
            'photo' => new CURLFile($path, 'image/jpeg', 'untouch.jpg'),
        ]);
    } else {
        $sent = tg_api('sendPhoto', [
            'chat_id' => $chatId,
            'photo' => tg_invite_photo_url(),
            'disable_notification' => true,
        ]);
    }
    $fileId = tg_photo_file_id_from_message($sent);
    if ($fileId === '') {
        throw new Exception('Invite photo file_id missing');
    }
    $mid = isset($sent['message_id']) ? (int)$sent['message_id'] : 0;
    if ($mid > 0) {
        try {
            tg_api('deleteMessage', [
                'chat_id' => $chatId,
                'message_id' => $mid,
            ]);
        } catch (Exception $e) {
            error_log('[tg] delete invite photo: ' . $e->getMessage());
        }
    }
    tg_write_invite_photo_file_id($fileId);
    return $fileId;
}

function tg_ensure_invite_photo_file_id($userId) {
    $cached = tg_read_invite_photo_file_id();
    if ($cached !== '') return $cached;
    return tg_upload_invite_photo($userId);
}

function tg_invite_message_html($userId, $timeLabel, $bonus) {
    $url = htmlspecialchars(tg_invite_start_url($userId), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $label = htmlspecialchars(tg_invite_link_label(), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $timeLabel = trim(strip_tags((string)$timeLabel));
    $bonus = max(0, (int)$bonus);
    if ($timeLabel !== '') {
        $record = 'Заходи, попробуй побить мой рекорд! Я продержался '
            . htmlspecialchars($timeLabel, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')
            . ' сек.';
    } else {
        $record = 'Заходи, попробуй Untouch — уводи кубик от красных и бей рекорд.';
    }
    $gift = $bonus > 0
        ? ' Если зайдёшь сейчас, получишь бонус новичка — ' . $bonus . ' кристаллов.'
        : '';
    return $record . $gift . "\n\n" . '<a href="' . $url . '">' . $label . '</a>';
}

function tg_invite_reply_markup($userId) {
    return [
        'inline_keyboard' => [[
            [
                'text' => tg_invite_link_label(),
                'url' => tg_invite_start_url($userId),
            ],
        ]],
    ];
}

function tg_prepare_invite_share($userId, $timeLabel, $bonus) {
    $html = tg_invite_message_html($userId, $timeLabel, $bonus);
    $markup = tg_invite_reply_markup($userId);
    $id = 'inv' . preg_replace('/\D+/', '', (string)$userId) . substr((string)time(), -5);
    try {
        $fileId = tg_ensure_invite_photo_file_id($userId);
        return tg_api('savePreparedInlineMessage', [
            'user_id' => (int)$userId,
            'allow_user_chats' => true,
            'allow_bot_chats' => false,
            'allow_group_chats' => true,
            'allow_channel_chats' => false,
            'result' => [
                'type' => 'photo',
                'id' => $id,
                'photo_file_id' => $fileId,
                'title' => 'Untouch',
                'description' => tg_invite_link_label(),
                'caption' => $html,
                'parse_mode' => 'HTML',
                'reply_markup' => $markup,
            ],
        ]);
    } catch (Exception $e) {
        error_log('[tg] prepare photo invite: ' . $e->getMessage());
        return tg_api('savePreparedInlineMessage', [
            'user_id' => (int)$userId,
            'allow_user_chats' => true,
            'allow_bot_chats' => false,
            'allow_group_chats' => true,
            'allow_channel_chats' => false,
            'result' => [
                'type' => 'article',
                'id' => $id . 'a',
                'title' => 'Untouch',
                'description' => tg_invite_link_label(),
                'input_message_content' => [
                    'message_text' => $html,
                    'parse_mode' => 'HTML',
                    'link_preview_options' => ['is_disabled' => true],
                ],
                'reply_markup' => $markup,
            ],
        ]);
    }
}

function tg_send_invite_to_self($userId, $timeLabel, $bonus) {
    $html = tg_invite_message_html($userId, $timeLabel, $bonus);
    $markup = tg_invite_reply_markup($userId);
    try {
        $photo = tg_read_invite_photo_file_id();
        if ($photo === '') {
            $photo = tg_ensure_invite_photo_file_id($userId);
        }
        return tg_api('sendPhoto', [
            'chat_id' => $userId,
            'photo' => $photo,
            'caption' => $html,
            'parse_mode' => 'HTML',
            'reply_markup' => $markup,
        ]);
    } catch (Exception $e) {
        error_log('[tg] sendPhoto invite: ' . $e->getMessage());
        return tg_api('sendMessage', [
            'chat_id' => $userId,
            'text' => $html,
            'parse_mode' => 'HTML',
            'link_preview_options' => ['is_disabled' => true],
            'disable_web_page_preview' => true,
            'reply_markup' => $markup,
        ]);
    }
}

function tg_mini_app_link($startParam = '') {
    $link = 'https://t.me/UntouchGameBot/untouch';
    $param = trim((string)$startParam);
    if ($param !== '' && preg_match('/^[A-Za-z0-9_-]{1,64}$/', $param)) {
        $link .= '?startapp=' . rawurlencode($param);
    }
    return $link;
}

function tg_parse_ref_param($param) {
    $param = trim((string)$param);
    if ($param === '') return null;
    if (preg_match('/^r(\d{1,20})$/', $param, $m)) return $m[1];
    return null;
}

function tg_user_display_name($user) {
    if (!is_array($user)) return 'Игрок';
    $full = trim((string)($user['first_name'] ?? '') . ' ' . (string)($user['last_name'] ?? ''));
    if ($full !== '') return mb_substr($full, 0, 40);
    if (!empty($user['username'])) return '@' . ltrim((string)$user['username'], '@');
    return 'Игрок';
}

function tg_ensure_social_tables(PDO $pdo) {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `referrals` (
            `invitee_id` VARCHAR(64) NOT NULL,
            `inviter_id` VARCHAR(64) NOT NULL,
            `invitee_name` VARCHAR(128) NOT NULL DEFAULT '',
            `invitee_username` VARCHAR(64) NULL,
            `invitee_photo` VARCHAR(512) NULL,
            `created_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `rewarded` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `rewarded_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`invitee_id`),
            KEY `idx_inviter` (`inviter_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
    $cols = [];
    try {
        $cols = $pdo->query('SHOW COLUMNS FROM `referrals`')->fetchAll(PDO::FETCH_COLUMN);
    } catch (Exception $e) {
        $cols = [];
    }
    $have = array_map('strtolower', $cols);
    if (!in_array('rewarded', $have, true)) {
        $pdo->exec('ALTER TABLE `referrals` ADD COLUMN `rewarded` TINYINT UNSIGNED NOT NULL DEFAULT 0');
    }
    if (!in_array('rewarded_at', $have, true)) {
        $pdo->exec('ALTER TABLE `referrals` ADD COLUMN `rewarded_at` BIGINT UNSIGNED NOT NULL DEFAULT 0');
    }
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `user_flags` (
            `user_id` VARCHAR(64) NOT NULL,
            `write_access` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `updated_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function tg_bind_referral(PDO $pdo, $inviteeId, $inviterId, $user = null) {
    tg_ensure_social_tables($pdo);
    $inviteeId = (string)$inviteeId;
    $inviterId = (string)$inviterId;
    if ($inviteeId === '' || $inviterId === '' || $inviteeId === $inviterId) {
        return ['bound' => false, 'reason' => 'invalid'];
    }
    if (!preg_match('/^\d{1,20}$/', $inviteeId) || !preg_match('/^\d{1,20}$/', $inviterId)) {
        return ['bound' => false, 'reason' => 'invalid'];
    }

    $check = $pdo->prepare('SELECT `inviter_id` FROM `referrals` WHERE `invitee_id` = :id LIMIT 1');
    $check->execute([':id' => $inviteeId]);
    $existing = $check->fetch();
    if ($existing) {
        return ['bound' => false, 'reason' => 'already', 'inviterId' => (string)$existing['inviter_id']];
    }

    $name = tg_user_display_name($user);
    $username = null;
    if (is_array($user) && !empty($user['username'])) {
        $username = '@' . ltrim((string)$user['username'], '@');
    }
    $photo = null;
    if (is_array($user) && !empty($user['photo_url'])) {
        $photo = filter_var((string)$user['photo_url'], FILTER_SANITIZE_URL) ?: null;
    }
    $now = (int)(microtime(true) * 1000);

    try {
        $pdo->prepare('
            INSERT INTO `referrals`
                (`invitee_id`, `inviter_id`, `invitee_name`, `invitee_username`, `invitee_photo`, `created_at`)
            VALUES
                (:invitee, :inviter, :name, :username, :photo, :created)
        ')->execute([
            ':invitee' => $inviteeId,
            ':inviter' => $inviterId,
            ':name' => $name,
            ':username' => $username,
            ':photo' => $photo,
            ':created' => $now,
        ]);
        return ['bound' => true, 'inviterId' => $inviterId];
    } catch (Exception $e) {
        return ['bound' => false, 'reason' => 'already'];
    }
}

function tg_list_invited(PDO $pdo, $inviterId) {
    tg_ensure_social_tables($pdo);
    $stmt = $pdo->prepare('
        SELECT `invitee_id`, `invitee_name`, `invitee_username`, `invitee_photo`, `created_at`
        FROM `referrals`
        WHERE `inviter_id` = :id
        ORDER BY `created_at` DESC
        LIMIT 50
    ');
    $stmt->execute([':id' => (string)$inviterId]);
    $out = [];
    foreach ($stmt->fetchAll() as $row) {
        $out[] = [
            'userId' => (string)$row['invitee_id'],
            'name' => (string)$row['invitee_name'],
            'username' => $row['invitee_username'] !== null ? (string)$row['invitee_username'] : null,
            'photoUrl' => $row['invitee_photo'] !== null ? (string)$row['invitee_photo'] : null,
            'createdAt' => (int)$row['created_at'],
        ];
    }
    return $out;
}

function tg_claim_pending_invite_rewards(PDO $pdo, $inviterId) {
    tg_ensure_social_tables($pdo);
    $inviterId = (string)$inviterId;
    if ($inviterId === '') return 0;
    $now = (int)(microtime(true) * 1000);
    $stmt = $pdo->prepare('
        UPDATE `referrals`
        SET `rewarded` = 1, `rewarded_at` = :at
        WHERE `inviter_id` = :id AND `rewarded` = 0
    ');
    $stmt->execute([
        ':at' => $now,
        ':id' => $inviterId,
    ]);
    return (int)$stmt->rowCount();
}

function tg_set_write_access(PDO $pdo, $userId, $granted = true) {
    tg_ensure_social_tables($pdo);
    $userId = (string)$userId;
    if ($userId === '') return false;
    $now = (int)(microtime(true) * 1000);
    $pdo->prepare('
        INSERT INTO `user_flags` (`user_id`, `write_access`, `updated_at`)
        VALUES (:id, :flag, :at)
        ON DUPLICATE KEY UPDATE
            `write_access` = VALUES(`write_access`),
            `updated_at` = VALUES(`updated_at`)
    ')->execute([
        ':id' => $userId,
        ':flag' => $granted ? 1 : 0,
        ':at' => $now,
    ]);
    return true;
}

function tg_has_write_access(PDO $pdo, $userId) {
    tg_ensure_social_tables($pdo);
    $stmt = $pdo->prepare('SELECT `write_access` FROM `user_flags` WHERE `user_id` = :id LIMIT 1');
    $stmt->execute([':id' => (string)$userId]);
    $row = $stmt->fetch();
    return $row ? ((int)$row['write_access'] === 1) : false;
}

function tg_send_start($chatId, $startParam = '') {
    $button = ['text' => '🎮 Играть', 'web_app' => ['url' => tg_webapp_url()]];
    tg_api('sendMessage', [
        'chat_id' => $chatId,
        'text' => tg_start_text(),
        'reply_markup' => [
            'inline_keyboard' => [[$button]],
        ],
    ]);
}

function tg_admin_tz() {
    return new DateTimeZone('Europe/Moscow');
}

function tg_admin_key() {
    $cfg = tg_bot_config();
    $key = trim((string)($cfg['admin_key'] ?? ''));
    if ($key === '') {
        $key = trim((string)($cfg['diag_key'] ?? ''));
    }
    return $key;
}

function tg_admin_day_start_ms($daysBack = 0) {
    $d = new DateTime('now', tg_admin_tz());
    $d->setTime(0, 0, 0);
    if ((int)$daysBack > 0) {
        $d->modify('-' . (int)$daysBack . ' days');
    }
    return (int)$d->format('U') * 1000;
}

function tg_admin_today_ymd() {
    return (new DateTime('now', tg_admin_tz()))->format('Y-m-d');
}

function tg_ensure_bot_admin_tables(PDO $pdo) {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `bot_users` (
            `user_id` VARCHAR(64) NOT NULL,
            `username` VARCHAR(64) NULL,
            `first_name` VARCHAR(128) NULL,
            `last_name` VARCHAR(128) NULL,
            `language_code` VARCHAR(16) NULL,
            `is_premium` TINYINT(1) NOT NULL DEFAULT 0,
            `blocked` TINYINT(1) NOT NULL DEFAULT 0,
            `first_seen_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `last_seen_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `message_count` INT UNSIGNED NOT NULL DEFAULT 0,
            `start_count` INT UNSIGNED NOT NULL DEFAULT 0,
            `last_kind` VARCHAR(32) NOT NULL DEFAULT 'message',
            `last_text` VARCHAR(160) NULL,
            `last_start_payload` VARCHAR(64) NULL,
            PRIMARY KEY (`user_id`),
            KEY `idx_last_seen` (`last_seen_at`),
            KEY `idx_first_seen` (`first_seen_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `bot_daily` (
            `stat_day` DATE NOT NULL,
            `user_id` VARCHAR(64) NOT NULL,
            `messages` INT UNSIGNED NOT NULL DEFAULT 0,
            `starts` INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`stat_day`, `user_id`),
            KEY `idx_stat_day` (`stat_day`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}

function tg_backfill_bot_users(PDO $pdo) {
    tg_ensure_bot_admin_tables($pdo);
    try {
        $pdo->exec("
            INSERT IGNORE INTO `bot_users`
                (`user_id`, `username`, `first_name`, `last_name`, `first_seen_at`, `last_seen_at`, `message_count`, `start_count`, `last_kind`)
            SELECT
                `user_id`,
                MIN(`username`),
                MIN(`first_name`),
                MIN(`last_name`),
                MIN(`created_at`),
                MAX(`created_at`),
                0,
                0,
                'backfill'
            FROM `scores`
            WHERE `user_id` IS NOT NULL AND `user_id` != ''
            GROUP BY `user_id`
        ");
    } catch (Exception $e) {
        error_log('[bot_users] backfill scores: ' . $e->getMessage());
    }
    try {
        $pdo->exec("
            INSERT IGNORE INTO `bot_users`
                (`user_id`, `username`, `first_name`, `first_seen_at`, `last_seen_at`, `message_count`, `start_count`, `last_kind`, `last_start_payload`)
            SELECT
                `invitee_id`,
                `invitee_username`,
                `invitee_name`,
                `created_at`,
                `created_at`,
                0,
                1,
                'start',
                CONCAT('r', `inviter_id`)
            FROM `referrals`
            WHERE `invitee_id` IS NOT NULL AND `invitee_id` != ''
        ");
    } catch (Exception $e) {
        error_log('[bot_users] backfill referrals: ' . $e->getMessage());
    }
    try {
        $pdo->exec("
            INSERT IGNORE INTO `bot_users`
                (`user_id`, `first_seen_at`, `last_seen_at`, `message_count`, `start_count`, `last_kind`)
            SELECT `user_id`, `updated_at`, `updated_at`, 0, 0, 'backfill'
            FROM `wallets`
            WHERE `user_id` IS NOT NULL AND `user_id` != ''
        ");
    } catch (Exception $e) {
        error_log('[bot_users] backfill wallets: ' . $e->getMessage());
    }
}

function tg_touch_bot_user(PDO $pdo, $from, $opts = []) {
    if (!is_array($from) || empty($from['id']) || !empty($from['is_bot'])) {
        return false;
    }
    tg_ensure_bot_admin_tables($pdo);
    $now = isset($opts['nowMs']) ? (int)$opts['nowMs'] : (int)(microtime(true) * 1000);
    $userId = (string)$from['id'];
    $kind = isset($opts['kind']) ? substr((string)$opts['kind'], 0, 32) : 'message';
    $incMessage = isset($opts['incMessage']) ? (int)$opts['incMessage'] : 1;
    $incStart = !empty($opts['incStart']) ? 1 : 0;
    $text = isset($opts['text']) ? mb_substr(trim((string)$opts['text']), 0, 160) : '';
    $payload = isset($opts['startPayload']) ? mb_substr(trim((string)$opts['startPayload']), 0, 64) : '';
    $hasBlocked = array_key_exists('blocked', $opts) && $opts['blocked'] !== null;
    $blocked = $hasBlocked ? (!empty($opts['blocked']) ? 1 : 0) : 0;
    $username = isset($from['username']) ? mb_substr((string)$from['username'], 0, 64) : '';
    $firstName = isset($from['first_name']) ? mb_substr((string)$from['first_name'], 0, 128) : '';
    $lastName = isset($from['last_name']) ? mb_substr((string)$from['last_name'], 0, 128) : '';
    $lang = isset($from['language_code']) ? mb_substr((string)$from['language_code'], 0, 16) : '';
    $premium = !empty($from['is_premium']) ? 1 : 0;

    $stmt = $pdo->prepare("
        INSERT INTO `bot_users` (
            `user_id`, `username`, `first_name`, `last_name`, `language_code`, `is_premium`,
            `blocked`, `first_seen_at`, `last_seen_at`, `message_count`, `start_count`,
            `last_kind`, `last_text`, `last_start_payload`
        ) VALUES (
            :id, :username, :first_name, :last_name, :lang, :premium,
            :blocked, :now1, :now2, :msg, :starts,
            :kind, :text, :payload
        )
        ON DUPLICATE KEY UPDATE
            `username` = COALESCE(NULLIF(VALUES(`username`), ''), `username`),
            `first_name` = COALESCE(NULLIF(VALUES(`first_name`), ''), `first_name`),
            `last_name` = COALESCE(NULLIF(VALUES(`last_name`), ''), `last_name`),
            `language_code` = COALESCE(NULLIF(VALUES(`language_code`), ''), `language_code`),
            `is_premium` = VALUES(`is_premium`),
            `blocked` = IF(:has_blocked = 1, :blocked_upd, IF(VALUES(`last_kind`) IN ('start','message','callback','payment','webapp'), 0, `blocked`)),
            `last_seen_at` = VALUES(`last_seen_at`),
            `message_count` = `message_count` + VALUES(`message_count`),
            `start_count` = `start_count` + VALUES(`start_count`),
            `last_kind` = VALUES(`last_kind`),
            `last_text` = IF(VALUES(`last_text`) = '', `last_text`, VALUES(`last_text`)),
            `last_start_payload` = IF(VALUES(`last_start_payload`) = '', `last_start_payload`, VALUES(`last_start_payload`))
    ");
    $blockedInsert = $blocked === null ? 0 : $blocked;
    $stmt->execute([
        ':id' => $userId,
        ':username' => $username,
        ':first_name' => $firstName,
        ':last_name' => $lastName,
        ':lang' => $lang,
        ':premium' => $premium,
        ':blocked' => $blockedInsert,
        ':now1' => $now,
        ':now2' => $now,
        ':msg' => max(0, $incMessage),
        ':starts' => $incStart,
        ':kind' => $kind,
        ':text' => $text,
        ':payload' => $payload,
        ':has_blocked' => $hasBlocked ? 1 : 0,
        ':blocked_upd' => $blocked,
    ]);

    if ($incMessage > 0 || $incStart > 0) {
        $day = tg_admin_today_ymd();
        $daily = $pdo->prepare("
            INSERT INTO `bot_daily` (`stat_day`, `user_id`, `messages`, `starts`)
            VALUES (:day, :id, :msg, :starts)
            ON DUPLICATE KEY UPDATE
                `messages` = `messages` + VALUES(`messages`),
                `starts` = `starts` + VALUES(`starts`)
        ");
        $daily->execute([
            ':day' => $day,
            ':id' => $userId,
            ':msg' => max(0, $incMessage),
            ':starts' => $incStart,
        ]);
    }
    return true;
}

function tg_record_bot_update(PDO $pdo, array $update) {
    $from = null;
    $kind = 'message';
    $text = '';
    $payload = '';
    $blocked = null;
    $incMessage = 1;
    $incStart = 0;

    if (isset($update['message']) && is_array($update['message'])) {
        $msg = $update['message'];
        $from = is_array($msg['from'] ?? null) ? $msg['from'] : null;
        $text = trim((string)($msg['text'] ?? ''));
        if (preg_match('/^\/start(?:@\w+)?(?:\s+(.*))?$/u', $text, $m)) {
            $kind = 'start';
            $incStart = 1;
            $payload = isset($m[1]) ? trim((string)$m[1]) : '';
        } elseif (isset($msg['successful_payment'])) {
            $kind = 'payment';
        } elseif (isset($msg['web_app_data'])) {
            $kind = 'webapp';
        } elseif (isset($msg['write_access_allowed'])) {
            $kind = 'write_access';
        }
    } elseif (isset($update['edited_message']['from']) && is_array($update['edited_message']['from'])) {
        $from = $update['edited_message']['from'];
        $kind = 'edit';
        $text = trim((string)($update['edited_message']['text'] ?? ''));
    } elseif (isset($update['callback_query']['from']) && is_array($update['callback_query']['from'])) {
        $from = $update['callback_query']['from'];
        $kind = 'callback';
        $text = (string)($update['callback_query']['data'] ?? '');
    } elseif (isset($update['inline_query']['from']) && is_array($update['inline_query']['from'])) {
        $from = $update['inline_query']['from'];
        $kind = 'inline';
        $text = (string)($update['inline_query']['query'] ?? '');
    } elseif (isset($update['pre_checkout_query']['from']) && is_array($update['pre_checkout_query']['from'])) {
        $from = $update['pre_checkout_query']['from'];
        $kind = 'checkout';
    } elseif (isset($update['my_chat_member']['from']) && is_array($update['my_chat_member']['from'])) {
        $from = $update['my_chat_member']['from'];
        $kind = 'member';
        $incMessage = 0;
        $status = (string)($update['my_chat_member']['new_chat_member']['status'] ?? '');
        $blocked = in_array($status, ['kicked', 'left'], true);
        $text = $status;
    }

    if (!$from) {
        return false;
    }
    $opts = [
        'kind' => $kind,
        'text' => $text,
        'startPayload' => $payload,
        'incMessage' => $incMessage,
        'incStart' => $incStart,
    ];
    if ($blocked !== null) {
        $opts['blocked'] = $blocked;
    }
    return tg_touch_bot_user($pdo, $from, $opts);
}

function tg_parse_payload($payload) {
    $parts = explode(':', (string)$payload);
    if (count($parts) < 2) return [null, null];
    return [$parts[0], $parts[1]];
}
