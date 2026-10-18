<?php
// CLI only. Install outside webroot after explicit authorization for a request.
if (PHP_SAPI!=='cli') { http_response_code(404); exit; }
require __DIR__ . '/../telegram-web/api/tg_common.php';
require __DIR__ . '/../telegram-web/api/mobile_store.php';
require __DIR__ . '/mobile_account_deletion.php';
try {
    $options=getopt('', ['id:', 'execute', 'challenge:', 'fingerprint:', 'confirm:', 'maintenance-confirmed']);
    [$pdo]=tg_connect_pdo(); if (!$pdo) throw new RuntimeException('Database unavailable');
    $id=$options['id']??'';
    if (isset($options['execute'])) {
        if (!isset($options['maintenance-confirmed'])) throw new RuntimeException('Stop Android writes and drain requests first');
        $result=mobile_deletion_execute($pdo,$id,$options['challenge']??'', $options['fingerprint']??'', $options['confirm']??'');
    } else $result=mobile_deletion_review($pdo,$id);
    echo json_encode($result,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . PHP_EOL;
} catch (Throwable $error) {
    fwrite(STDERR,$error->getMessage() . PHP_EOL); exit(1);
}
