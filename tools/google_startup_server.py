"""Prepare a baseline-preserving API patch and test nickname allocation in own tables.

FTP credentials are supplied only via stdin from Windows DPAPI.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import ftplib
import hashlib
import io
import json
from pathlib import Path
import secrets
import ssl
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'tmp/google-startup-server'
OUT = ROOT / 'docs/release-evidence/google-startup-20261013'
args = argparse.ArgumentParser()
args.add_argument('mode', choices=['prepare', 'test'])
mode = args.parse_args().mode
credentials = json.load(sys.stdin)


def connect():
    context = ssl.create_default_context()
    context.maximum_version = ssl.TLSVersion.TLSv1_2
    ftp = ftplib.FTP_TLS(context=context, timeout=30)
    ftp.connect(credentials['host'], int(credentials.get('port', 21)))
    ftp.auth()
    ftp.login(credentials['user'], credentials['password'])
    ftp.prot_p()
    ftp.cwd('/')
    return ftp


if mode == 'prepare':
    hashes = {}
    for name in ['mobile.php', 'mobile-release.json']:
        ftp = connect()
        body = io.BytesIO()
        try:
            ftp.retrbinary('RETR api/' + name, body.write)
        finally:
            ftp.close()
        data = body.getvalue()
        dest = WORK / 'before' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        hashes['api/' + name] = hashlib.sha256(data).hexdigest()
    source = (WORK / 'before/mobile.php').read_text(encoding='utf-8-sig')
    require = "require_once __DIR__ . '/mobile_store.php';"
    case = "      case 'google_link':"
    result = "$result=['profile'=>mobile_google_save_details($pdo,$player['id'],$claims)]; break;"
    assert source.count(require) == source.count(case) == source.count(result) == 1
    source = source.replace(require, require + "\nrequire_once __DIR__ . '/mobile_google_nickname.php';")
    source = source.replace(case, case + "\n        $firstGoogleLink=empty($player['google_sub']);")
    source = source.replace(result, "$profile=mobile_google_save_details($pdo,$player['id'],$claims);\n        $result=['profile'=>$firstGoogleLink ? mobile_google_nickname($pdo,$player) : $profile]; break;")
    (WORK / 'source').mkdir(exist_ok=True)
    (WORK / 'source/mobile.php').write_text(source, encoding='utf-8')
    (WORK / 'source/mobile_google_nickname.php').write_bytes((ROOT / 'telegram-web/api/mobile_google_nickname.php').read_bytes())
    (WORK / 'expected.json').write_text(json.dumps(hashes, indent=2), encoding='utf-8')
    baseline = json.loads((WORK / 'before/mobile-release.json').read_text(encoding='utf-8-sig'))
    print('Published baseline:', baseline['buildId'])
    print('Prepared minimal patch: mobile.php + new nickname module; secrets/config unchanged')
else:
    nonce, gate = secrets.token_hex(8), secrets.token_hex(32)
    prefix = '_untouch_nick_test_' + nonce + '_'
    endpoint = 'api/_nick_test_' + nonce + '.php'
    module = (ROOT / 'telegram-web/api/mobile_google_nickname.php').read_text(encoding='utf-8')[5:]
    php = '''<?php
header('Content-Type: application/json'); header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD']!=='POST' || !hash_equals('__GATE__',$_SERVER['HTTP_X_UNTOUCH_TEST']??'')) {http_response_code(404);exit;}
require __DIR__.'/tg_common.php'; require __DIR__.'/mobile_store.php'; require __DIR__.'/mobile_wallet.php';
__MODULE__
try {
 [$pdo]=tg_connect_pdo(); $prefix='__PREFIX__'; $input=json_decode(file_get_contents('php://input'),true);
 $scores=mobile_table('scores',$prefix); $players=mobile_table('mobile_players',$prefix); $names=mobile_table('mobile_names',$prefix);
 $action=$input['action'];
 if($action==='cleanup') {
  foreach(['mobile_rounds','mobile_devices','mobile_operations','mobile_purchases','mobile_names','mobile_players','scores'] as $table) $pdo->exec('DROP TABLE IF EXISTS '.mobile_table($table,$prefix));
  echo '{"ok":true}'; exit;
 }
 if($action==='init') {
  $pdo->exec("CREATE TABLE $scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,user_id VARCHAR(64),player_name VARCHAR(128)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
  mobile_migrate($pdo,$prefix); echo '{"ok":true}'; exit;
 }
 if($action==='create') {
  $secret=bin2hex(random_bytes(32)); $p=mobile_guest($pdo,bin2hex(random_bytes(16)),$secret,2000000000000,$prefix);
  $player=mobile_auth($pdo,$secret,$prefix); $id=$player['id'];
  $wallet=mobile_wallet($player,tg_load_economy()); $wallet['_googleIdentity']=['email'=>$input['email']??null,'name'=>'Fixture'];
  $pdo->prepare("UPDATE $players SET google_sub=?,wallet_json=? WHERE id=?")->execute([empty($input['guest'])?(string)(100000+$id):null,json_encode($wallet),$id]);
  if(!empty($input['custom'])) mobile_rename($pdo,$player,$input['custom'],$prefix);
  $pdo->prepare("INSERT INTO $scores (user_id,player_name) VALUES (?,?)")->execute(['android:'.$id,$p['nickname']]);
  echo json_encode(['ok'=>true,'id'=>$id,'secret'=>$secret,'guestName'=>$p['nickname']]); exit;
 }
 if($action==='reserve') {
  $pdo->prepare("INSERT INTO $names (name_key,owner,nickname) VALUES (?,?,?)")->execute([mobile_name_key($input['name']),'telegram:fixture',$input['name']]);
  echo '{"ok":true}'; exit;
 }
 $player=mobile_auth($pdo,$input['secret'],$prefix);
 if($action==='allocate') {
  $before=mobile_profile($player); $p=mobile_google_nickname($pdo,$player,$prefix);
  $score=$pdo->prepare("SELECT player_name FROM $scores WHERE user_id=?"); $score->execute([$p['id']]);
  echo json_encode(['ok'=>true,'nickname'=>$p['nickname'],'walletPreserved'=>$p['wallet']===$before['wallet'],'scoreName'=>$score->fetchColumn()]); exit;
 }
 if($action==='manual') {
  mobile_rename($pdo,$player,'ManualChanged',$prefix);
  echo json_encode(['ok'=>true,'nickname'=>mobile_google_nickname($pdo,$player,$prefix)['nickname']]);exit;
 }
 throw new Exception('Unknown fixture action');
} catch(Throwable $error) { echo json_encode(['ok'=>false,'error'=>get_class($error).':'.$error->getMessage()]); }
'''.replace('__GATE__', gate).replace('__MODULE__', module).replace('__PREFIX__', prefix)

    def rpc(action, **fields):
        request = urllib.request.Request('https://untouch.ballaball.xyz/' + endpoint,
            data=json.dumps({'action': action, **fields}).encode(),
            headers={'Content-Type': 'application/json', 'X-Untouch-Test': gate})
        with urllib.request.urlopen(request, timeout=35) as response:
            result = json.load(response)
        if not result.get('ok'):
            raise RuntimeError('Isolated fixture failed: ' + str(result.get('error')))
        return result

    checks = []
    uploaded = False
    initialized = False
    try:
        ftp = connect()
        try:
            ftp.storbinary('STOR ' + endpoint, io.BytesIO(php.encode()))
            uploaded = True
        finally:
            ftp.close()
        initialized = True
        rpc('init')
        fresh = rpc('create', email='alexey.games@example.invalid')
        allocated = rpc('allocate', secret=fresh['secret'])
        assert allocated['nickname'] == 'alexey.games' and allocated['walletPreserved']
        assert allocated['scoreName'] == 'alexey.games'
        assert rpc('allocate', secret=fresh['secret'])['nickname'] == 'alexey.games'
        checks.append('first verified email prefix; wallet and score; replay unchanged')
        rpc('reserve', name='Collision')
        fixtures = [rpc('create', email='collision@example.invalid') for _ in range(4)]
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda f: rpc('allocate', secret=f['secret']), fixtures))
        assert {r['nickname'] for r in results} == {'collision_2', 'collision_3', 'collision_4', 'collision_5'}
        assert all(r['walletPreserved'] for r in results)
        checks.append('four simultaneous allocations; case-insensitive shared registry; counters 2..5')
        for email, options, expected in [
            ('custom@example.invalid', {'custom': 'MyCustomNick'}, 'MyCustomNick'),
            ('guest@example.invalid', {'guest': True}, None),
            (None, {}, None),
            ('ab@example.invalid', {}, 'ab_001'),
            ('a' * 55 + '@example.invalid', {}, 'a' * 40),
        ]:
            fixture = rpc('create', email=email, **options)
            result = rpc('allocate', secret=fixture['secret'])
            assert result['nickname'] == (expected or fixture['guestName']) and result['walletPreserved']
        changed = rpc('create', email='stale@example.invalid')
        assert rpc('manual', secret=changed['secret'])['nickname'] == 'ManualChanged'
        checks.append('custom/stale/manual names preserved; unlinked/missing email guests; short and long names')
        print('PASS: isolated MySQL Google nickname checks', flush=True)
    finally:
        cleanup_error = None
        try:
            if initialized:
                rpc('cleanup')
        except Exception as error:
            cleanup_error = error
        finally:
            if uploaded:
                ftp = connect()
                try:
                    ftp.delete(endpoint)
                finally:
                    ftp.close()
        if cleanup_error:
            raise cleanup_error
        print('Disposable nickname tables and gated endpoint removed', flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'server-nickname-checks.json').write_text(json.dumps({
        'ok': True, 'checks': checks, 'realPlayerDataTouched': False,
        'tablesAndEndpointRemoved': True, 'googleAuthentication': 'synthetic fixture details; no real account sign-in',
    }, ensure_ascii=False, indent=2), encoding='utf-8')
