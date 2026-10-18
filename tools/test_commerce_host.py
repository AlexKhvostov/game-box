"""Check payment transactions on isolated MySQL tables via a temporary gated endpoint."""
import concurrent.futures
import io
import json
import pathlib
import secrets
import time
import urllib.request


def run(ftp):
    nonce = secrets.token_hex(8)
    token = secrets.token_hex(32)
    wallet_table = '_untouch_test_wallets_' + nonce
    payment_table = '_untouch_test_payments_' + nonce
    order_table = '_untouch_test_orders_' + nonce
    energy_payment_table = '_untouch_test_energy_payments_' + nonce
    schema_table = '_untouch_test_schema_' + nonce
    candidate = 'api/_commerce_candidate_' + nonce + '.php'
    endpoint = 'api/_commerce_test_' + nonce + '.php'
    source = pathlib.Path(__file__).resolve().parent.parent / 'telegram-web/api/tg_common.php'
    helper = '''<?php
header('Content-Type: application/json');
header('Cache-Control: no-store');
if (!hash_equals('__TOKEN__', $_SERVER['HTTP_X_UNTOUCH_TEST'] ?? '')) { http_response_code(403); exit; }
$source = file_get_contents(__DIR__ . '/__CANDIDATE__');
$source = str_replace(['`wallets`', '`star_payments`', '`star_orders`', '`energy_payments`', '`schema_versions`'], ['`__WALLET__`', '`__PAYMENTS__`', '`__ORDERS__`', '`__ENERGY_PAYMENTS__`', '`__SCHEMA__`'], $source);
eval('namespace UntouchAudit; use \\PDO; use \\Exception; use \\Throwable; use \\RuntimeException; ' . substr($source, strpos($source, '<?php') + 5));
try {
    [$pdo, $error] = \\UntouchAudit\\tg_connect_pdo();
    if (!$pdo) throw new Exception('Test database connection unavailable');
    $input = json_decode(file_get_contents('php://input'), true) ?: [];
    $action = $input['action'] ?? '';
    if ($action === 'cleanup') {
        $pdo->exec('DROP TABLE IF EXISTS `__WALLET__`');
        $pdo->exec('DROP TABLE IF EXISTS `__PAYMENTS__`');
        $pdo->exec('DROP TABLE IF EXISTS `__ORDERS__`');
        $pdo->exec('DROP TABLE IF EXISTS `__ENERGY_PAYMENTS__`');
        $pdo->exec('DROP TABLE IF EXISTS `__SCHEMA__`');
        echo json_encode(['ok'=>true]); exit;
    }
    \\UntouchAudit\\tg_ensure_commerce_tables($pdo);
    if ($action === 'init') {
        $products = \\UntouchAudit\\tg_products();
        $packs = array_values(array_filter($products, function($p) { return $p['kind'] === 'crystals'; }));
        $plus = array_values(array_filter($products, function($p) { return $p['kind'] === 'plus'; }));
        echo json_encode(['ok'=>true,'pack'=>$packs[0] ?? null,'plus'=>$plus[0] ?? null]); exit;
    }
    $uid = (string)($input['uid'] ?? '');
    if (!preg_match('/^audit-[a-f0-9]{16}-[1-4]$/D', $uid)) throw new Exception('Invalid test user');
    if ($action === 'order') {
        $product = $input['product'];
        $payload = \\UntouchAudit\\tg_create_order($pdo, $uid, $product);
        echo json_encode(['ok'=>true,'payload'=>$payload]); exit;
    }
    if ($action === 'invoice') {
        $wallet = \\UntouchAudit\\tg_apply_invoice($pdo, $uid, $input['payment']);
    } elseif ($action === 'check') {
        $order = \\UntouchAudit\\tg_check_order($pdo, $input['payload'], $uid, $input['currency'], $input['amount']);
        echo json_encode(['ok'=>true,'order'=>$order]); exit;
    } elseif ($action === 'apply') {
        $wallet = \\UntouchAudit\\tg_apply_product($pdo, $uid, (string)$input['product'], (string)$input['charge']);
    } else $wallet = \\UntouchAudit\\tg_wallet_snapshot($pdo, $uid);
    $count = $pdo->prepare('SELECT COUNT(*) FROM `__PAYMENTS__` WHERE user_id = :uid');
    $count->execute([':uid'=>$uid]);
    $users = $pdo->prepare('SELECT COUNT(*) FROM `__WALLET__` WHERE user_id = :uid');
    $users->execute([':uid'=>$uid]);
    echo json_encode(['ok'=>true,'wallet'=>$wallet,'payments'=>(int)$count->fetchColumn(),'walletRows'=>(int)$users->fetchColumn(),'serverNowMs'=>(int)(microtime(true)*1000)]);
} catch (Throwable $error) { echo json_encode(['ok'=>false,'error'=>$error->getMessage()]); }
'''
    for key, value in {'__TOKEN__': token, '__CANDIDATE__': pathlib.PurePosixPath(candidate).name, '__WALLET__': wallet_table, '__PAYMENTS__': payment_table, '__ORDERS__': order_table, '__ENERGY_PAYMENTS__': energy_payment_table, '__SCHEMA__': schema_table}.items():
        helper = helper.replace(key, value)
    uploaded = []
    initialized = False

    def rpc(action, uid=1, **extra):
        request = urllib.request.Request(
            'https://untouch.ballaball.xyz/' + endpoint,
            data=json.dumps({'action': action, 'uid': f'audit-{nonce}-{uid}', **extra}).encode(),
            headers={'Content-Type': 'application/json', 'X-Untouch-Test': token},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    def apply(uid, product, charge):
        result = rpc('apply', uid, product=product, charge=f'audit-{nonce}-{charge}')
        assert result.get('ok'), result
        return result

    try:
        for name, contents in [(candidate, source.read_bytes()), (endpoint, helper.encode())]:
            ftp.storbinary('STOR ' + name, io.BytesIO(contents))
            uploaded.append(name)
        initial = rpc('init')
        assert initial.get('ok') and initial.get('pack'), initial
        initialized = True
        pack = initial['pack']
        product, credits = pack['id'], int(pack['crystals'])
        apply(1, product, 'initial')
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda i: apply(1, product, f'different-{i}'), range(4)))
        result = rpc('read')
        assert result['wallet']['tokens'] == 5 * credits and result['payments'] == 5, result
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: apply(1, product, 'same-charge'), range(4)))
        result = rpc('read')
        assert result['wallet']['tokens'] == 6 * credits and result['payments'] == 6, result
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda i: apply(2, product, f'first-wallet-{i}'), range(4)))
        result = rpc('read', 2)
        assert result['wallet']['tokens'] == 4 * credits and result['payments'] == 4, result
        result = rpc('apply', 3, product='missing-test-product', charge=f'audit-{nonce}-invalid')
        assert not result['ok'], result
        result = rpc('read', 3)
        assert result['walletRows'] == 0 and result['payments'] == 0, result
        result = rpc('apply', 4, product=product, charge=f'audit-{nonce}-same-charge')
        assert not result['ok'], result
        result = rpc('read', 4)
        assert result['walletRows'] == 0 and result['payments'] == 0, result
        if initial.get('plus'):
            plus = initial['plus']
            started = rpc('read')['serverNowMs']
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                list(pool.map(lambda i: apply(1, plus['id'], f'plus-{i}'), range(2)))
            result = rpc('read')
            expected = 2 * int(plus['days']) * 86400000
            assert started + expected <= result['wallet']['plusUntilMs'] <= result['serverNowMs'] + expected, result
            before = result['wallet']['plusUntilMs']
            assert apply(1, plus['id'], 'plus-0')['wallet']['plusUntilMs'] == before
        print('PASS: real MySQL concurrent credits, first-wallet race, repeated charge, wrong owner, rollback, concurrent Plus and replay', flush=True)
        frozen = dict(pack, id='removed-audit-product', crystals=17, stars=11)
        order = rpc('order', 3, product=frozen)
        assert order['ok'], order
        payload = order['payload']
        assert rpc('check', 3, payload=payload, currency='XTR', amount=11)['order']['product'] == frozen
        for uid, currency, amount in [(4, 'XTR', 11), (3, 'USD', 11), (3, 'XTR', 12)]:
            assert not rpc('check', uid, payload=payload, currency=currency, amount=amount)['ok']
        payment = dict(invoice_payload=payload, currency='XTR', total_amount=11, telegram_payment_charge_id=f'audit-{nonce}-frozen')
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: rpc('invoice', 3, payment=payment), range(4)))
        assert all(r['ok'] for r in results), results
        assert rpc('read', 3)['wallet']['tokens'] == 17
        assert not rpc('invoice', 3, payment=dict(payment, telegram_payment_charge_id=f'audit-{nonce}-second'))['ok']
        assert not rpc('invoice', 4, payment=payment)['ok']
        subscription = dict(id='audit-subscription', kind='plus', crystals=0, stars=5, days=30, subscription_period=2592000)
        order = rpc('order', 4, product=subscription)
        expiration = rpc('read', 4)['serverNowMs'] // 1000 + 2592000
        payment = dict(invoice_payload=order['payload'], currency='XTR', total_amount=5, subscription_expiration_date=expiration, telegram_payment_charge_id=f'audit-{nonce}-subscription-1')
        assert rpc('invoice', 4, payment=payment)['wallet']['plusUntilMs'] == expiration * 1000
        payment.update(subscription_expiration_date=expiration+2592000, telegram_payment_charge_id=f'audit-{nonce}-subscription-2')
        assert rpc('invoice', 4, payment=payment)['wallet']['plusUntilMs'] == (expiration+2592000)*1000
        print('PASS: frozen/removed product, owner/currency/amount, concurrent replay, single-use invoice and subscription expiration', flush=True)
    finally:
        try:
            if uploaded:
                cleanup = rpc('cleanup')
                assert cleanup.get('ok'), 'Test table cleanup failed'
                print('Isolated test tables removed; no player tables changed', flush=True)
        finally:
            for name in reversed(uploaded):
                ftp.delete(name)
            if uploaded:
                print('Temporary test endpoints removed', flush=True)
