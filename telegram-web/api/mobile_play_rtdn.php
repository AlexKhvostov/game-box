<?php
require_once __DIR__ . '/tg_common.php';
require_once __DIR__ . '/mobile_store.php';
require_once __DIR__ . '/mobile_wallet.php';
require_once __DIR__ . '/mobile_google.php';
require_once __DIR__ . '/mobile_play.php';
require_once __DIR__ . '/mobile_play_notifications.php';
header('Content-Type: application/json'); header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD']!=='POST') { http_response_code(405); exit; }
try {
    $config=mobile_private_config(); $header=mobile_request_authorization();
    if (strncmp($header,'Bearer ',7)!==0 || strlen($header)>12000) throw new MobileError('play_notification_unauthorized',401);
    mobile_play_push_claims(substr($header,7),$config,mobile_google_keys());
    $body=file_get_contents('php://input',false,null,0,32769);
    if (strlen($body)>32768) throw new MobileError('request_too_large',413);
    $event=mobile_play_event($body,$config);
    [$pdo]=tg_connect_pdo(); if (!$pdo) throw new MobileError('service_unavailable',503);
    mobile_play_notification($pdo,$event,(int)round(microtime(true)*1000));
    http_response_code(204);
} catch (MobileError $error) {
    http_response_code($error->status); echo json_encode(['ok'=>false,'error'=>$error->getMessage()]);
} catch (Throwable $error) {
    // No tokens, request payloads or credentials in output/log messages.
    http_response_code(503); echo '{"ok":false,"error":"play_notification_retry"}';
}
