<?php
/** Read-only launch authentication. No DB, wallets, messages or auth logging. */
require_once __DIR__ . '/tg_common.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');

function launch_reply($status, $error = null) {
    http_response_code($status);
    echo json_encode($error === null ? ['ok' => true, 'verified' => true] : ['ok' => false, 'error' => $error]);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    launch_reply(405, 'method_not_allowed');
}
if (strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0])) !== 'application/json') launch_reply(415, 'invalid_request');
$raw = file_get_contents('php://input', false, null, 0, 65537);
if ($raw === false || strlen($raw) > 65536) launch_reply(413, 'invalid_request');
$input = json_decode($raw, true);
if (!is_array($input) || !isset($input['initData']) || !is_string($input['initData']) || strlen($input['initData']) > 32768 || $input['initData'] === '') launch_reply(400, 'invalid_request');
// Platform is an unsigned SDK policy signal; it does not attest a native client.
if (!isset($input['platform']) || !is_string($input['platform']) || !in_array($input['platform'], ['android', 'ios', 'tdesktop', 'macos'], true)) launch_reply(403, 'unsupported_platform');
$fields = [];
foreach (explode('&', $input['initData']) as $part) {
    $pair = explode('=', $part, 2);
    $key = urldecode($pair[0]);
    if (!preg_match('/^[A-Za-z0-9_]+$/D', $key) || count($pair) !== 2 || array_key_exists($key, $fields)) launch_reply(403, 'invalid_launch');
    $fields[$key] = urldecode($pair[1]);
    if (count($fields) > 32) launch_reply(403, 'invalid_launch');
}
if (!isset($fields['auth_date']) || !preg_match('/^[0-9]{1,12}$/D', $fields['auth_date']) || (int)$fields['auth_date'] < 1) launch_reply(403, 'invalid_launch');
$age = time() - (int)$fields['auth_date'];
if ($age > 86400 || $age < -300) launch_reply(403, 'expired_launch');
if (!isset($fields['hash']) || !preg_match('/^[a-f0-9]{64}$/D', $fields['hash'])) launch_reply(403, 'invalid_launch');
$user = isset($fields['user']) ? json_decode($fields['user']) : null;
if (!($user instanceof stdClass) || !isset($user->id) || !is_int($user->id) || $user->id <= 0) launch_reply(403, 'invalid_launch');
try {
    if (tg_bot_token() === '') launch_reply(503, 'launch_unavailable');
    $auth = tg_validate_init_data($input['initData']);
    if (empty($auth['ok']) || empty($auth['userId'])) launch_reply(403, 'invalid_launch');
} catch (Throwable $error) {
    launch_reply(503, 'launch_unavailable');
}
launch_reply(200);
