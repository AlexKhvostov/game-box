<?php
require_once __DIR__ . '/gameplay_config.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    http_response_code(405);
    header('Allow: GET');
    echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
    exit;
}
try {
    $snapshot = gameplay_snapshot();
    // Runtime defaults can add a new block without rewriting the administrator's
    // saved publication. The public cache identity must match the effective JSON.
    $snapshot['revision'] = hash('sha256', json_encode($snapshot['config'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    $etag = '"' . $snapshot['revision'] . '"';
    header('ETag: ' . $etag);
    if (($_SERVER['HTTP_IF_NONE_MATCH'] ?? '') === $etag) {
        http_response_code(304);
        exit;
    }
    echo json_encode(['ok' => true] + $snapshot, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
} catch (Throwable $e) {
    error_log('[config] ' . $e->getMessage());
    http_response_code(503);
    echo json_encode(['ok' => false, 'error' => 'Конфигурация временно недоступна']);
}
