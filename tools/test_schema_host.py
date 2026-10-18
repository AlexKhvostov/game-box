"""Exercise candidate schema/leaderboard SQL against random disposable tables."""
import io
import json
import pathlib
import secrets
import urllib.request


def run(ftp):
    nonce, token = secrets.token_hex(8), secrets.token_hex(32)
    root = pathlib.Path(__file__).resolve().parent.parent / 'telegram-web/api'
    names = {n: '_untouch_test_' + n + '_' + nonce for n in ['scores', 'schema_versions']}
    files = ['api/_schema_' + nonce + '.php']
    common = (root / 'tg_common.php').read_text(encoding='utf-8-sig')
    schema = (root / 'schema_migrations.php').read_text(encoding='utf-8-sig').replace("__DIR__ . '/scores.json'", "'/unused-audit-json'")
    scores = (root / 'scores.php').read_text(encoding='utf-8-sig')
    score_function = scores[scores.index('function fetchMergedScoresFromMysql'):scores.index('// Диагностика')]
    candidate = '\n'.join([common[5:], schema[5:], score_function])
    for name, replacement in names.items(): candidate = candidate.replace('`' + name + '`', '`' + replacement + '`')
    body = '''<?php
namespace UntouchSchemaAudit;
use \\PDO; use \\Exception;
header('Content-Type: application/json'); header('Cache-Control: no-store');
if (!hash_equals('__TOKEN__', $_SERVER['HTTP_X_UNTOUCH_TEST'] ?? '')) { http_response_code(404); exit; }
__SOURCE__
try {
 [$pdo] = tg_connect_pdo(); if (!$pdo) throw new Exception('Database unavailable');
 $input = json_decode(file_get_contents('php://input'),true) ?: [];
 if (($input['action'] ?? '') === 'cleanup') { foreach (__TABLES__ as $table) $pdo->exec('DROP TABLE IF EXISTS `' . $table . '`'); echo '{"ok":true}'; exit; }
 tg_ensure_score_tables($pdo);
 if (($input['action'] ?? '') === 'seed') {
  $q = $pdo->prepare("INSERT INTO `__SCORES__` (user_id,player_name,time_ms,created_at,score_day) VALUES (:uid,'Audit',:time,:at,:day)");
  $now = (int)(microtime(true)*1000);
  for ($i=0;$i<500;$i++) $q->execute([':uid'=>'repeat-audit',':time'=>5000+$i,':at'=>$now,':day'=>gmdate('Y-m-d')]);
  $q->execute([':uid'=>'older-audit',':time'=>99000,':at'=>$now-60*86400000,':day'=>gmdate('Y-m-d',time()-60*86400)]);
  $q->execute([':uid'=>'today-audit',':time'=>4000,':at'=>$now,':day'=>gmdate('Y-m-d')]);
 }
 $_GET['period'] = $input['period'] ?? 'all';
 echo json_encode(['ok'=>true,'count'=>$pdo->query('SELECT COUNT(*) FROM `__SCORES__`')->fetchColumn(),'scores'=>fetchMergedScoresFromMysql($pdo)]);
} catch (\\Throwable $e) { echo json_encode(['ok'=>false,'error'=>$e->getMessage()]); }
'''
    body = body.replace('__TOKEN__', token).replace('__SOURCE__', candidate).replace('__SCORES__', names['scores']).replace('__TABLES__', '[' + ','.join("'" + n + "'" for n in names.values()) + ']')
    def rpc(**data):
        req = urllib.request.Request('https://untouch.ballaball.xyz/' + files[0], data=json.dumps(data).encode(), headers={'X-Untouch-Test': token, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=30) as response: result = json.load(response)
        assert result['ok'], result
        return result
    try:
        ftp.storbinary('STOR ' + files[0], io.BytesIO(body.encode()))
        seeded = rpc(action='seed')
        assert seeded['count'] == 502
        assert [s['userId'] for s in seeded['scores']] == ['older-audit', 'repeat-audit', 'today-audit']
        for period in ['day', 'week', 'month']:
            rows = rpc(period=period)['scores']
            assert [s['userId'] for s in rows] == ['repeat-audit', 'today-audit'], (period, rows)
            assert rows[0]['timeMs'] == 5499
        assert rpc()['count'] == 502, 'Repeated migration must preserve every record'
        print('PASS: real MySQL schema, repeated maintenance without lost data, best per player, 500 duplicate rows, old all-time record and UTC period filters', flush=True)
    finally:
        try: rpc(action='cleanup')
        finally:
            ftp.delete(files[0])
            print('Isolated schema tables and endpoint removed', flush=True)
