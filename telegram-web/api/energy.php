<?php
require_once __DIR__ . '/tg_common.php';
require_once __DIR__ . '/energy_store.php';
tg_json_headers();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
try {
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
    $auth = tg_require_user($input);
    [$pdo] = tg_connect_pdo();
    if (!$pdo) throw new RuntimeException('Сервер временно недоступен');
    $result = energy_request($pdo, $auth['userId'], $input);
    echo json_encode(['ok' => true] + $result, JSON_UNESCAPED_UNICODE);
} catch (Throwable $error) {
    http_response_code($error instanceof DomainException ? 409 : 503);
    echo json_encode(['ok' => false, 'error' => $error instanceof DomainException ? $error->getMessage() : 'Не удалось связаться с сервером. Попробуйте ещё раз.'], JSON_UNESCAPED_UNICODE);
    if (!($error instanceof DomainException)) error_log('[energy] ' . $error->getMessage());
}
