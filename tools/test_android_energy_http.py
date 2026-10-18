"""Exact Android HTTP API against a disposable localhost database and frozen files."""
import hashlib
import json
import pathlib
import re
import secrets
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
PHP = pathlib.Path('C:/xampp/php/php.exe')
MYSQL = pathlib.Path('C:/xampp/mysql/bin/mysql.exe')
FILES = ['mobile.php', 'tg_common.php', 'gameplay_config.php', 'mobile_pace.php',
         'mobile_store.php', 'mobile_identity.php', 'mobile_beta.php', 'mobile_google_nickname.php',
         'mobile_wallet.php', 'mobile_google.php', 'mobile_play.php', 'mobile_invites.php',
         'mobile_energy.php', 'mobile_energy_bonus.php', 'mobile_energy_feedback.php']


def run():
    db = 'untouch_energy_http_' + secrets.token_hex(8)
    assert re.fullmatch(r'untouch_energy_http_[a-f0-9]{16}', db)
    runtime = ROOT / '.private/android-energy-20261015' / ('http-' + secrets.token_hex(8))
    public = runtime / 'public'; api = public / 'api'; api.mkdir(parents=True)
    (api / 'config-data').mkdir(); (public / 'config').mkdir()
    passed = []; process = None; created = False; cleaned = False; failure = None; frozen = []

    def check(ok, label):
        if not ok: raise AssertionError(label)
        passed.append(label)

    def sql(query):
        p = subprocess.run([str(MYSQL), '--protocol=tcp', '--host=127.0.0.1', '--port=43317',
                            '--user=root', '--batch', '--skip-column-names', '--execute=' + query],
                           capture_output=True, text=True, timeout=10)
        if p.returncode: raise RuntimeError('Disposable database command failed')
        return p.stdout.strip()

    try:
        check(sql('SELECT @@port') == '43317', 'Local isolated MariaDB port verified')
        check(not sql("SHOW DATABASES LIKE '" + db + "'"), 'Unique test database absent before creation')
        sql('CREATE DATABASE `' + db + '` CHARACTER SET utf8mb4'); created = True
        for name in FILES:
            source = ROOT / 'telegram-web/api' / name; target = api / name
            shutil.copyfile(source, target)
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            check(hashlib.sha256(target.read_bytes()).hexdigest() == digest, 'Frozen exact source ' + name)
            frozen.append({'path': source.relative_to(ROOT).as_posix(), 'sha256': digest})
        shutil.copytree(ROOT / 'telegram-web/api/vendor', api / 'vendor')
        config = json.loads((ROOT / 'telegram-web/config/gameplay-config.json').read_text(encoding='utf-8'))
        config['economy']['androidEnergyV2']['enabled'] = True
        config['economy']['initialLives'] = 7; config['economy']['initialTokens'] = 13
        (public / 'config/gameplay-config.json').write_text(json.dumps(config), encoding='utf-8')
        # Guard executes before production connector's fallback attempts.
        (api / 'db_config.php').write_text("<?php $guard=new PDO('mysql:host=127.0.0.1;port=43317;dbname=" + db + ";charset=utf8mb4','root',''); if($guard->query('SELECT DATABASE()')->fetchColumn()!=='" + db + "')throw new RuntimeException('Fixture guard');return ['host'=>'127.0.0.1','port'=>43317,'database'=>'" + db + "','username'=>'root','password'=>'','charset'=>'utf8mb4'];", encoding='utf-8')
        (api / 'mobile_config.php').write_text("<?php return ['energy_products'=>['energy_100_v2'=>['kind'=>'energy','amount'=>100,'revision'=>'v2']]];", encoding='utf-8')
        bootstrap = runtime / 'bootstrap.php'
        bootstrap.write_text("<?php require __DIR__.'/public/api/tg_common.php'; require __DIR__.'/public/api/mobile_store.php'; require __DIR__.'/public/api/mobile_wallet.php'; require __DIR__.'/public/api/mobile_invites.php'; [$pdo]=tg_connect_pdo(); if(!$pdo||$pdo->query('SELECT DATABASE()')->fetchColumn()!=='" + db + "')exit(2); $pdo->exec('CREATE TABLE scores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,score_day DATE,user_id VARCHAR(64),player_name VARCHAR(128),hide_telegram TINYINT,time_ms INT,run_distance INT,risk_count INT,score BIGINT,had_jump TINYINT,had_helmet TINYINT,created_at BIGINT) ENGINE=InnoDB');mobile_migrate($pdo);mobile_invites_migrate($pdo);mobile_energy_migrate_schema($pdo);tg_schema_complete($pdo,'mobile',1);", encoding='utf-8')
        boot = subprocess.run([str(PHP), str(bootstrap)], capture_output=True, timeout=10)
        check(boot.returncode == 0, 'Explicit schema bootstrap completed')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
        log = (runtime / 'server.log').open('wb')
        process = subprocess.Popen([str(PHP), '-S', '127.0.0.1:' + str(port), '-t', str(public)], stdout=log, stderr=log,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        endpoint = 'http://127.0.0.1:' + str(port) + '/api/mobile.php'

        def rpc(data=None, token=None):
            headers = {'Content-Type': 'application/json'}
            if token: headers['Authorization'] = 'Bearer ' + token
            request = urllib.request.Request(endpoint, data=json.dumps(data).encode() if data is not None else None, headers=headers)
            try:
                with urllib.request.urlopen(request, timeout=10) as reply: return reply.status, json.load(reply)
            except urllib.error.HTTPError as error: return error.code, json.load(error)

        health = None
        for _ in range(50):
            try:
                health = rpc()[1]; break
            except urllib.error.URLError: time.sleep(.1)
        check(health and health['schemaReady'], 'Real HTTP endpoint ready')
        revision = health['rulesRevision']; secret = secrets.token_hex(32); installation = secrets.token_hex(16)
        _, result = rpc({'action': 'guest', 'installation': installation, 'secret': secret, 'economyVersion': 2})
        wallet = result['profile']['wallet']; check(wallet['energy'] == 20 and wallet['batteries'][0]['initialUnits'] == 20, 'HTTP new player20 plus full20')
        check(result['profile']['serverNow'] > 0 and wallet['energyGoogleReady'] is False, 'HTTP authoritative time and Google fact')
        claim_id = secrets.token_hex(32)
        for _ in range(2):
            _, result = rpc({'action': 'wallet_operation', 'operationId': claim_id, 'kind': 'energy_claim', 'args': {}, 'economyVersion': 2}, secret)
            check(result['profile']['wallet']['energy'] == 40, 'HTTP charge receipt replay stays40')
        status, denied = rpc({'action': 'wallet_operation', 'operationId': secrets.token_hex(32), 'kind': 'daily', 'args': {}, 'economyVersion': 2}, secret)
        check(status == 409 and denied['error'] == 'update_required', 'HTTP migrated owner rejects legacy mutation')
        start_id = secrets.token_hex(32)
        start_data = {'action': 'round_start', 'requestId': start_id, 'rulesRevision': revision, 'economyVersion': 2, 'helmet': True, 'jump': True}
        _, result = rpc(start_data, secret); check(result['attemptCost'] == 3 and result['profile']['wallet']['energy'] == 37, 'HTTP loadout snapshot spends3')
        _, replay = rpc({**start_data, 'rulesRevision': 'obsolete'}, secret)
        check(replay['profile']['wallet']['energy'] == 37, 'HTTP replay checked before changed revision')
        _, canceled = rpc({'action': 'round_cancel', 'requestId': start_id, 'economyVersion': 2}, secret)
        check(canceled['profile']['wallet']['energy'] == 40, 'HTTP prestart cancel restores3')
        next_id = secrets.token_hex(32)
        rpc({**start_data, 'requestId': next_id, 'helmet': False, 'jump': False}, secret)
        _, active = rpc({'action': 'round_activate', 'requestId': next_id, 'economyVersion': 2}, secret)
        check(active['activated'], 'HTTP activates accepted attempt')
        status, denied = rpc({'action': 'round_cancel', 'requestId': next_id, 'economyVersion': 2}, secret)
        check(status == 409 and denied['error'] == 'round_already_started', 'HTTP active attempt cannot refund')
        _, replay = rpc({**start_data, 'requestId': next_id}, secret)
        check(replay['activated'] and not replay['finished'], 'HTTP replay distinguishes active attempt')
        feedback = {'action': 'wallet_operation', 'operationId': secrets.token_hex(32), 'kind': 'energy_feedback',
                    'args': {'comment': 'Тестовый комментарий для локального приёмочного теста', 'rating': 1}, 'economyVersion': 2}
        _, result = rpc(feedback, secret)
        check(result['profile']['wallet']['energy'] == 59, 'HTTP feedback first20 independent of stars')
        check(sql('SELECT delivery_state FROM `' + db + '`.mobile_energy_feedback') == 'pending', 'HTTP feedback outbox remains unsent')
        _, quote = rpc({'action': 'play_quote', 'requestId': secrets.token_hex(32), 'productId': 'energy_100_v1', 'economyVersion': 2}, secret)
        check(quote['quote']['terms']['amount'] == 100, 'HTTP immutable prepayment quote')
        # A prepared SKU can be selected remotely without a new client build.
        config['economy']['androidEnergyV2']['packages'][0] = {'id': 'energy_100_v2', 'productId': 'energy_100_v2', 'energy': 100}
        (public / 'config/gameplay-config.json').write_text(json.dumps(config), encoding='utf-8')
        _, profile = rpc({'action': 'profile', 'economyVersion': 2}, secret)
        check(profile['profile']['wallet']['energyConfig']['packages'][0]['productId'] == 'energy_100_v2', 'HTTP prepared SKU publication visible remotely')
        _, quote = rpc({'action': 'play_quote', 'requestId': secrets.token_hex(32), 'productId': 'energy_100_v2', 'economyVersion': 2}, secret)
        check(quote['quote']['terms']['amount'] == 100 and quote['quote']['terms']['revision'] == 'v2', 'HTTP prepared version quote from private immutable registry')
        legacy_secret = secrets.token_hex(32)
        _, legacy = rpc({'action': 'guest', 'installation': secrets.token_hex(16), 'secret': legacy_secret, 'economyVersion': 1})
        check('energyVersion' not in legacy['profile']['wallet'], 'HTTP old guest remains legacy without V2 marker')
        _, migrated = rpc({'action': 'profile', 'economyVersion': 2}, legacy_secret)
        check(migrated['profile']['wallet']['energy'] == 33, 'HTTP existing migration7 plus2times13')
        config['economy']['androidEnergyV2']['enabled'] = False
        (public / 'config/gameplay-config.json').write_text(json.dumps(config), encoding='utf-8')
        _, disabled = rpc({'action': 'guest', 'installation': secrets.token_hex(16), 'secret': secrets.token_hex(32), 'economyVersion': 2})
        check('energyVersion' not in disabled['profile']['wallet'], 'HTTP disabled server preserves legacy fallback')
    except Exception as error:
        failure = type(error).__name__ + ': ' + str(error)
    finally:
        if process:
            process.terminate(); process.wait(timeout=10); log.close()
        if created:
            sql('DROP DATABASE `' + db + '`'); cleaned = not sql("SHOW DATABASES LIKE '" + db + "'")
    result = {'ok': failure is None and cleaned, 'passed': passed, 'checks': len(passed), 'cleaned': cleaned,
              'phpStopped': process is not None and process.poll() is not None, 'frozenSources': frozen, 'failure': failure}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(run())
