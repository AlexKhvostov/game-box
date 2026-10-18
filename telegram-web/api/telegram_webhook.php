<?php
require_once __DIR__ . '/tg_common.php';

$cfg = tg_bot_config();
$secret = tg_webhook_secret();
if ($secret === '') { http_response_code(503); echo 'retry'; exit; }
{
    $got = $_SERVER['HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN'] ?? '';
    if (!hash_equals($secret, $got)) {
        tg_webhook_mark(['status' => 'forbidden_secret']);
        http_response_code(403);
        echo 'forbidden';
        exit;
    }
}

$raw = file_get_contents('php://input');
$update = json_decode($raw, true);
if (!is_array($update)) {
    tg_webhook_mark(['status' => 'empty']);
    http_response_code(200);
    echo 'ok';
    exit;
}

try {
    $text = trim((string)($update['message']['text'] ?? ''));
    $isStart = (bool)preg_match('/^\/start(?:@\w+)?(?:\s|$)/u', $text);
    tg_webhook_mark([
        'status' => 'ok',
        'keys' => array_keys($update),
        'text' => $text !== '' ? substr($text, 0, 40) : '',
        'start' => $isStart,
    ]);
    try {
        [$touchPdo] = tg_connect_pdo();
        if ($touchPdo) {
            tg_record_bot_update($touchPdo, $update);
        }
    } catch (Exception $touchErr) {
        error_log('[telegram_webhook] bot_users: ' . $touchErr->getMessage());
    }
    if (isset($update['pre_checkout_query']['id'])) {
        $qid = $update['pre_checkout_query']['id'];
        $query = $update['pre_checkout_query'];
        [$pdo] = tg_connect_pdo();
        if (!$pdo) throw new Exception('Checkout database unavailable');
        tg_ensure_commerce_tables($pdo);
        $ok = false;
        try {
            $order = tg_check_order($pdo, $query['invoice_payload'] ?? '', $query['from']['id'] ?? '', $query['currency'] ?? '', $query['total_amount'] ?? 0);
            $ok = $order['chargeId'] === null || !empty($order['product']['subscription_period']);
        } catch (Exception $invalid) {
            // Reject before payment; the player can create a fresh invoice.
        }
        $answer = [
            'pre_checkout_query_id' => $qid,
            'ok' => $ok,
        ];
        if (!$ok) $answer['error_message'] = 'Счёт недействителен. Откройте магазин и создайте новый.';
        tg_api('answerPreCheckoutQuery', $answer);
        echo 'ok';
        exit;
    }

    $payment = $update['message']['successful_payment']
        ?? $update['edited_message']['successful_payment']
        ?? null;
    if (is_array($payment)) {
        $userId = (string)($update['message']['from']['id'] ?? $update['edited_message']['from']['id'] ?? '');
        if ($userId === '') throw new Exception('Payment sender missing');
        [$pdo] = tg_connect_pdo();
        if (!$pdo) throw new Exception('Payment database unavailable');
        tg_apply_invoice($pdo, $userId, $payment);
    }

    $msg = $update['message'] ?? null;
    if (is_array($msg) && isset($msg['write_access_allowed'])) {
        $fromId = $msg['from']['id'] ?? null;
        if ($fromId) {
            [$flagsPdo] = tg_connect_pdo();
            if ($flagsPdo) {
                tg_set_write_access($flagsPdo, $fromId, true);
            }
        }
    }
    if (is_array($msg) && !isset($msg['successful_payment'])) {
        $text = trim((string)($msg['text'] ?? ''));
        if (preg_match('/^\/start(?:@\w+)?(?:\s+(.*))?$/u', $text, $startMatch)) {
            $chatId = $msg['chat']['id'] ?? null;
            if ($chatId) {
                try {
                    $startPayload = isset($startMatch[1]) ? trim((string)$startMatch[1]) : '';
                    $from = is_array($msg['from'] ?? null) ? $msg['from'] : [];
                    $fromId = isset($from['id']) ? (string)$from['id'] : '';
                    $inviterId = tg_parse_ref_param($startPayload);
                    $refBound = null;
                    if ($fromId !== '' && $inviterId) {
                        [$refPdo] = tg_connect_pdo();
                        if ($refPdo) {
                            $refBound = tg_bind_referral($refPdo, $fromId, $inviterId, $from);
                        }
                    }
                    tg_send_start($chatId, $startPayload);
                    tg_webhook_mark([
                        'status' => 'ok',
                        'keys' => array_keys($update),
                        'text' => substr($text, 0, 40),
                        'start' => true,
                        'replied' => true,
                        'ref' => $startPayload,
                        'ref_bound' => $refBound,
                    ]);
                } catch (Exception $sendErr) {
                    tg_webhook_mark([
                        'status' => 'send_failed',
                        'keys' => array_keys($update),
                        'text' => substr($text, 0, 40),
                        'start' => true,
                        'replied' => false,
                        'send_error' => $sendErr->getMessage(),
                    ]);
                    throw $sendErr;
                }
            }
        }
    }
} catch (Throwable $e) {
    error_log('[telegram_webhook] ' . $e->getMessage());
    if (isset($update['pre_checkout_query']) || isset($payment) && is_array($payment)) {
        tg_webhook_mark(['status' => 'payment_retry', 'update_id' => $update['update_id'] ?? null]);
        http_response_code(500);
        echo 'retry';
        exit;
    }
}

http_response_code(200);
echo 'ok';
