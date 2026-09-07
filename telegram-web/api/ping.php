<?php
header('Content-Type: application/json; charset=utf-8');

$info = [
    'ok' => true,
    'php' => PHP_VERSION,
    'curl' => function_exists('curl_init'),
    'fopen' => (bool)ini_get('allow_url_fopen'),
    'bot_config' => file_exists(__DIR__ . '/bot_config.php'),
    'db_config' => file_exists(__DIR__ . '/db_config.php'),
    'telegram' => null,
];

require_once __DIR__ . '/tg_common.php';
$token = tg_bot_token();
$info['token_set'] = $token !== '';
$info['api_base'] = tg_api_base();
$info['proxy_set'] = tg_api_proxy() !== '';
$info['stars_shop'] = tg_catalog_debug();
$lastFile = __DIR__ . '/webhook_last.json';
$info['incoming_last'] = is_file($lastFile)
    ? json_decode((string)@file_get_contents($lastFile), true)
    : null;

if ($token !== '') {
    try {
        $me = tg_api('getMe', []);
        $info['telegram'] = [
            'ok' => true,
            'username' => isset($me['username']) ? $me['username'] : null,
        ];
    } catch (Exception $e) {
        $info['telegram'] = [
            'ok' => false,
            'error' => $e->getMessage(),
        ];
    }
    try {
        $wh = tg_api('getWebhookInfo', []);
        $info['webhook'] = [
            'url' => isset($wh['url']) ? $wh['url'] : '',
            'pending' => isset($wh['pending_update_count']) ? $wh['pending_update_count'] : 0,
            'last_error' => isset($wh['last_error_message']) ? $wh['last_error_message'] : null,
            'last_error_date' => isset($wh['last_error_date']) ? $wh['last_error_date'] : null,
            'allowed_updates' => isset($wh['allowed_updates']) ? $wh['allowed_updates'] : null,
            'has_custom_certificate' => !empty($wh['has_custom_certificate']),
        ];
    } catch (Exception $e) {
        $info['webhook'] = [
            'ok' => false,
            'error' => $e->getMessage(),
        ];
    }
}

echo json_encode($info, JSON_UNESCAPED_UNICODE);
