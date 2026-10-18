"""Short-lived, token-gated release maintenance; no secrets leave the host."""
import io
import json
import secrets
import urllib.request


def run(ftp, webhook=False, mobile=False):
    name = 'api/_release_migrate_' + secrets.token_hex(12) + '.php'
    token = secrets.token_hex(32)
    source = '''<?php
header('Content-Type: application/json'); header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !hash_equals('__TOKEN__', $_SERVER['HTTP_X_UNTOUCH_TEST'] ?? '')) { http_response_code(404); exit; }
require __DIR__ . '/tg_common.php';
require __DIR__ . '/energy_store.php';
require __DIR__ . '/schema_migrations.php';
if (__MOBILE__) { require __DIR__ . '/mobile_store.php'; require __DIR__ . '/mobile_wallet.php'; }
try {
 [$pdo] = tg_connect_pdo(); if (!$pdo) throw new Exception('Database unavailable');
 if (__WEBHOOK__) {
  $url = 'https://untouch-tg-api.lihach-ok.workers.dev/webhook';
  $existing = tg_api('getWebhookInfo', []);
  if (!empty($existing['url']) && $existing['url'] !== $url) throw new Exception('Unexpected existing webhook destination');
  $secret = tg_webhook_secret(); if ($secret === '') throw new Exception('Bot token unavailable');
  tg_api('setWebhook', ['url'=>$url,'secret_token'=>$secret,'drop_pending_updates'=>false]);
  $verified = tg_api('getWebhookInfo', []);
  if (($verified['url'] ?? '') !== $url) throw new Exception('Webhook verification failed');
  echo '{"ok":true,"versions":"authenticated webhook configured; pending updates preserved"}'; exit;
 }
 if (!$pdo->query("SELECT GET_LOCK('untouch_release_schema', 20)")->fetchColumn()) throw new Exception('Maintenance busy');
 try {
  if (__MOBILE__) {
   if (!tg_schema_ready($pdo,'scores',2)) throw new Exception('Existing score schema required');
   if (!tg_schema_ready($pdo,'mobile',1)) { mobile_migrate($pdo); tg_schema_complete($pdo,'mobile',1); }
  } else {
   tg_ensure_commerce_tables($pdo); energy_ensure_tables($pdo);
   tg_ensure_social_tables($pdo); tg_ensure_bot_admin_tables($pdo); tg_ensure_score_tables($pdo);
  }
  echo json_encode(['ok'=>true,'versions'=>$pdo->query('SELECT component,version FROM `schema_versions` ORDER BY component')->fetchAll()]);
 } finally { $pdo->query("SELECT RELEASE_LOCK('untouch_release_schema')"); }
} catch (Throwable $error) { http_response_code(500); echo json_encode(['ok'=>false,'error'=>$error->getMessage()]); }
'''.replace('__TOKEN__', token).replace('__WEBHOOK__', 'true' if webhook else 'false').replace('__MOBILE__', 'true' if mobile else 'false')
    try:
        ftp.storbinary('STOR ' + name, io.BytesIO(source.encode()))
        request = urllib.request.Request('https://untouch.ballaball.xyz/' + name, data=b'{}', headers={'X-Untouch-Test': token, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
        if not result.get('ok'):
            raise RuntimeError('Migration failed')
        print('Schema maintenance verified:', json.dumps(result['versions']), flush=True)
    finally:
        ftp.delete(name)
        print('Temporary maintenance endpoint removed', flush=True)
