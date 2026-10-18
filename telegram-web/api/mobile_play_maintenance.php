<?php
// CLI only: configure the hosting scheduler after deployment, never expose an
// administrative HTTP endpoint or embed secrets in a scheduler URL.
if (PHP_SAPI!=='cli') { http_response_code(404); exit; }
require_once __DIR__ . '/tg_common.php';
require_once __DIR__ . '/mobile_store.php';
require_once __DIR__ . '/mobile_wallet.php';
require_once __DIR__ . '/mobile_google.php';
require_once __DIR__ . '/mobile_play.php';
require_once __DIR__ . '/mobile_play_notifications.php';
try {
    [$pdo]=tg_connect_pdo(); if (!$pdo) throw new RuntimeException();
    $count=mobile_play_reconcile($pdo,(int)round(microtime(true)*1000));
    $pending=(int)$pdo->query("SELECT COUNT(*) FROM mobile_players WHERE JSON_UNQUOTE(JSON_EXTRACT(IF(JSON_VALID(wallet_json),wallet_json,'{}'),'$.energySubscription.awaitingReconciliation'))='true'")->fetchColumn();
    echo 'Play reconciliation completed: ' . $count . '; pending entitlements: ' . $pending . PHP_EOL;
    // Scheduler monitoring must alert on a failed/unresolved pass. Do not
    // silently treat a frozen subscription as an indefinitely active right.
    if($pending>0)exit(1);
} catch (Throwable $error) { fwrite(STDERR,'Play reconciliation failed; inspect service health and retry.' . PHP_EOL); exit(1); }
