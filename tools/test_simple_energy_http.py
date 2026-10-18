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
         'mobile_store.php', 'mobile_identity.php', 'mobile_google_nickname.php',
         'mobile_wallet.php', 'mobile_google.php', 'mobile_play.php', 'mobile_invites.php',
         'mobile_energy.php', 'mobile_energy_bonus.php', 'mobile_energy_feedback.php']


def run():
    db = 'untouch_energy_http_' + secrets.token_hex(8)
    assert re.fullmatch(r'untouch_energy_http_[a-f0-9]{16}', db)
    runtime = ROOT / '.private/android-simple-energy-20261016' / ('http-' + secrets.token_hex(8))
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
        config['economy']['androidEnergyV2']['simpleBonus'] = {'enabled': True}
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
            if data and data.get('economyVersion') == 3:
                data = {**data, 'economyVersion': 2, 'energyContract': 3}
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
        _, result = rpc({'action':'guest','installation':installation,'secret':secret,'economyVersion':3})
        wallet=result['profile']['wallet']
        check(wallet['energy']==50 and wallet['simpleBonus']['nextAt']==0,'HTTP v3 guest50, ready bonus')
        check(wallet['energyConfig']['rewards']['ad']==40 and wallet['energyConfig']['rewards']['invite']==60,'HTTP actual40/60 policy')
        def op(kind, key=None, token=secret, **extra):
            return rpc({'action':'wallet_operation','operationId':key or secrets.token_hex(32),'kind':kind,'args':{},'economyVersion':3,**extra},token)
        key=secrets.token_hex(32)
        status,result=op('energy_bonus_claim',key)
        check(status==200 and result['profile']['wallet']['energy']==80 and result['bonusClaim']['amount']==30,'HTTP confirmed claim30')
        next_at=result['profile']['wallet']['simpleBonus']['nextAt']
        check(next_at-result['bonusClaim']['claimedAt']==28800000,'HTTP server freezes8h')
        check(op('energy_bonus_claim',key)[1]['profile']['wallet']['energy']==80,'HTTP retry identical operation stays80')
        check(op('energy_bonus_claim')[1]['error']=='bonus_not_ready','HTTP different request cannot collect before8h')
        check(op('energy_claim')[1]['error']=='update_required','HTTP legacy partial claim rejected after transition')
        check(op('energy_bonus_claim',clientNow=9999999999999)[1]['error']=='bonus_not_ready','HTTP forged device time ignored')
        check(op('watch_ad')[1]['profile']['wallet']['energy']==120,'HTTP reward video40')
        check(op('watch_ad')[1]['error']=='ad_not_ready','HTTP server video cooldown')
        hidden=secrets.token_hex(32)
        before=op('energy_hidden_tap',hidden)[1]['profile']['wallet']['energy']
        check(before==140,'HTTP hidden+20 confirmed')
        check(op('energy_hidden_tap',hidden)[1]['profile']['wallet']['energy']==before,'HTTP hidden ACK replay once')
        check(op('energy_hidden_tap')[1]['profile']['wallet']['energy']==before+20,'HTTP new five-tap series repeatable')
        for retired in ['energy_test_grant','beta_free_crystals']:
            check(op(retired)[1]['error']=='operation_invalid','HTTP retired credit rejected '+retired)
        for helmet,jump,cost in [(False,False,1),(True,False,2),(True,True,3)]:
            rid=secrets.token_hex(32)
            data={'action':'round_start','requestId':rid,'rulesRevision':revision,'economyVersion':3,'helmet':helmet,'jump':jump}
            status,result=rpc(data,secret);check(status==200 and result['attemptCost']==cost,'HTTP real attempt cost '+str(cost))
            balance=result['profile']['wallet']['energy']
            check(rpc(data,secret)[1]['profile']['wallet']['energy']==balance,'HTTP multitap retry debit once '+str(cost))
            canceled=rpc({'action':'round_cancel','requestId':rid,'economyVersion':3},secret)[1]
            check(canceled['profile']['wallet']['energy']==balance+cost,'HTTP prestart cancellation returns exact cost '+str(cost))
        old_secret=secrets.token_hex(32)
        _,old=rpc({'action':'guest','installation':secrets.token_hex(16),'secret':old_secret,'economyVersion':2})
        check(old['profile']['wallet']['energy']==20 and 'simpleBonus' not in old['profile']['wallet'],'HTTP old client remains original contract')
        _,converted=rpc({'action':'profile','economyVersion':3},old_secret)
        check(converted['profile']['wallet']['energy']==40 and converted['profile']['wallet']['simpleBonusMigration']['settled']==20,'HTTP existing wallet saved plus accrued charge')
        _,again=rpc({'action':'profile','economyVersion':3},old_secret)
        check(again['profile']['wallet']['energy']==40,'HTTP migration idempotent')
        check(rpc({'action':'profile','economyVersion':2},old_secret)[1]['profile']['wallet']['energy']==40,'HTTP old client can still read transitioned balance')
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
