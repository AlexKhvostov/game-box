<?php
require_once __DIR__ . '/tg_common.php';

function payments_fail($code, $message) {
    // Не шлём 502/503: nginx HostLand подменяет тело на пустой Bad Gateway.
    http_response_code(200);
    echo json_encode(['ok' => false, 'error' => $message, 'code' => (int)$code], JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    tg_json_headers();

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }

    [$pdo, $dbError] = tg_connect_pdo();
    if ($pdo === null) {
        payments_fail(503, 'База недоступна');
    }

    try {
        tg_ensure_commerce_tables($pdo);
    } catch (Exception $e) {
        payments_fail(500, 'Кошелёк: ' . $e->getMessage());
    }

    $method = $_SERVER['REQUEST_METHOD'];
    $rawInput = file_get_contents('php://input');
    $input = json_decode($rawInput, true);
    if (!is_array($input)) $input = [];

    $action = $input['action'] ?? ($_GET['action'] ?? 'wallet');

    if ($method === 'GET' || $action === 'wallet') {
        $auth = tg_require_user($input);
        $snap = tg_wallet_snapshot($pdo, $auth['userId']);
        echo json_encode(['ok' => true, 'wallet' => $snap]);
        exit;
    }

    if ($method === 'POST' && $action === 'create_invoice') {
        $auth = tg_require_user($input);
        $productId = isset($input['productId']) ? (string)$input['productId'] : '';
        $product = tg_product($productId);
        if (!$product) {
            payments_fail(400, 'Unknown product');
        }
        if (tg_bot_token() === '') {
            payments_fail(503, 'Bot token not configured');
        }

        $nonce = bin2hex(function_exists('random_bytes') ? random_bytes(4) : openssl_random_pseudo_bytes(4));
        $payload = $auth['userId'] . ':' . $product['id'] . ':' . $nonce;
        $body = [
            'title' => $product['title'],
            'description' => $product['description'],
            'payload' => $payload,
            'currency' => 'XTR',
            'prices' => [
                ['label' => $product['title'], 'amount' => (int)$product['stars']],
            ],
        ];
        if (!empty($product['subscription_period'])) {
            $body['subscription_period'] = (int)$product['subscription_period'];
        }

        try {
            $invoiceUrl = tg_api('createInvoiceLink', $body);
            echo json_encode([
                'ok' => true,
                'invoiceUrl' => $invoiceUrl,
                'productId' => $product['id'],
                'crystals' => (int)$product['crystals'],
                'stars' => (int)$product['stars'],
            ]);
        } catch (Exception $e) {
            error_log('[payments.php] createInvoiceLink: ' . $e->getMessage());
            payments_fail(502, $e->getMessage());
        }
        exit;
    }

    payments_fail(405, 'Method not allowed');
} catch (Exception $e) {
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
        http_response_code(200);
    }
    echo json_encode(['ok' => false, 'error' => $e->getMessage()], JSON_UNESCAPED_UNICODE);
}
