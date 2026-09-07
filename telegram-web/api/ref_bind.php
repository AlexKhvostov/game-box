<?php
/**
 * Запись реферала с Cloudflare Worker в момент /start r123.
 * Подпись: sha256(inviteeId:inviterId:BOT_TOKEN)
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/tg_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Invalid JSON']);
    exit;
}

$inviteeId = isset($input['inviteeId']) ? preg_replace('/\D+/', '', (string)$input['inviteeId']) : '';
$inviterId = isset($input['inviterId']) ? preg_replace('/\D+/', '', (string)$input['inviterId']) : '';
$sig = isset($input['sig']) ? (string)$input['sig'] : '';
$token = tg_bot_token();

if ($inviteeId === '' || $inviterId === '' || $token === '' || $sig === '') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Bad request']);
    exit;
}

$expect = hash('sha256', $inviteeId . ':' . $inviterId . ':' . $token);
if (!hash_equals($expect, $sig)) {
    http_response_code(403);
    echo json_encode(['ok' => false, 'error' => 'Forbidden']);
    exit;
}

[$pdo, $dbError] = tg_connect_pdo();
if (!$pdo) {
    http_response_code(503);
    echo json_encode(['ok' => false, 'error' => $dbError ?: 'db']);
    exit;
}

$user = is_array($input['user'] ?? null) ? $input['user'] : [];
$bind = tg_bind_referral($pdo, $inviteeId, $inviterId, $user);
echo json_encode(['ok' => true, 'bind' => $bind]);
