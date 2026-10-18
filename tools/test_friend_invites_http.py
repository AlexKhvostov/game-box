"""Frozen production HTTP API + disposable localhost DB. No real secrets/Google/FTP."""
import hashlib
import argparse
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PHP = Path('C:/xampp/php/php.exe')
MYSQL = Path('C:/xampp/mysql/bin/mysql.exe')
DART = Path('C:/Users/alexe/develop/flutter/bin/cache/dart-sdk/bin/dart.exe')
FLUTTER = Path('C:/Users/alexe/develop/flutter/bin/cache/flutter_tools.snapshot')
DSN = 'mysql:host=127.0.0.1;port=43317;dbname=untouch_friend_invites_tests;charset=utf8mb4'
PUBLIC = ['mobile.php', 'tg_common.php', 'gameplay_config.php', 'mobile_pace.php',
          'mobile_store.php', 'mobile_identity.php', 'mobile_beta.php',
          'mobile_google_nickname.php', 'mobile_wallet.php', 'mobile_google.php',
          'mobile_play.php', 'mobile_invites.php']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(prefix):
    evidence = ROOT / 'docs/release-evidence/friend-invites-20261013/b6'
    evidence.mkdir(parents=True, exist_ok=True)
    runroot = ROOT / '.private/friend-invites-runtime-20261013' / ('http-' + secrets.token_hex(6))
    public = runroot / 'public'; api = public / 'api'
    api.mkdir(parents=True); (api / 'config-data').mkdir(); (public / 'config').mkdir()
    checks = []; process = None; result = {'checks': checks, 'cleaned': False, 'phpStopped': False}
    log = None
    def check(condition, label):
        if not condition: raise AssertionError(label)
        checks.append(label)
    def sql(query):
        proc = subprocess.run([str(MYSQL), '--host=127.0.0.1', '--port=43317', '--user=root',
             '--database=untouch_friend_invites_tests', '--batch', '--skip-column-names', '--execute='+query],
             capture_output=True, text=True, timeout=10)
        if proc.returncode: raise RuntimeError('Isolated SQL command failed')
        return proc.stdout.strip()
    try:
        listener = subprocess.run(['powershell', '-NoProfile', '-Command',
            "Get-NetTCPConnection -LocalPort 43317 -State Listen | Select-Object LocalAddress,OwningProcess | ConvertTo-Json -Compress"], capture_output=True, text=True, timeout=10)
        address = json.loads(listener.stdout)
        check(address['LocalAddress'] == '127.0.0.1' and address['OwningProcess'] == 37488, 'runtime: parent MariaDB loopback PID/port confirmed')
        check(sql('SELECT DATABASE(); SHOW TABLES;') == 'untouch_friend_invites_tests', 'runtime: exact disposable database initially empty')
        copied = []
        for name in PUBLIC:
            source = ROOT / 'telegram-web/api' / name; target = api / name
            shutil.copyfile(source, target); check(sha(source) == sha(target), 'frozen byte-for-byte '+name)
            copied.append({'source': source.relative_to(ROOT).as_posix(), 'sha256': sha(source)})
        vendor = ROOT / 'telegram-web/api/vendor/php-jwt/src'
        for source in vendor.glob('*.php'):
            target = api / 'vendor/php-jwt/src' / source.name; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target); check(sha(source) == sha(target), 'frozen JWT dependency '+source.name)
            copied.append({'source': source.relative_to(ROOT).as_posix(), 'sha256': sha(source)})
        result['frozenSources'] = copied
        client_sources = [{'source': p, 'sha256': sha(ROOT / p)} for p in [
            'lib/data/mobile_account.dart','lib/data/mobile_invites.dart','lib/data/mobile_wallet_bridge.dart',
            'lib/data/economy_store.dart','lib/data/invite_code.dart']]
        result['frozenClientSources'] = client_sources
        shutil.copyfile(ROOT / 'tools/friend_invites_http_fixture.php', api / 'fixture.php')
        control = secrets.token_hex(32)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
        endpoint = f'http://127.0.0.1:{port}/api/mobile.php'
        meta = {'dsn': DSN, 'controlSecret': control, 'endpoint': endpoint}
        (runroot / 'control.json').write_text(json.dumps(meta), encoding='utf-8')
        # A direct probe aborts before production tg_connect_pdo can try its fallback hosts.
        (api / 'db_config.php').write_text("<?php\nrequire_once __DIR__.'/fixture-db-guard.php'; fixture_db_probe(); return ['host'=>'127.0.0.1','port'=>43317,'database'=>'untouch_friend_invites_tests','username'=>'root','password'=>'','charset'=>'utf8mb4'];\n", encoding='utf-8')
        (api / 'fixture-db-guard.php').write_text("<?php\nfunction fixture_db_probe(){ $p=new PDO('"+DSN+"','root',''); if($p->query('SELECT DATABASE()')->fetchColumn()!=='untouch_friend_invites_tests'||(int)$p->query('SELECT @@port')->fetchColumn()!==43317)throw new RuntimeException('Fixture DB guard'); }\n", encoding='utf-8')
        (api / 'mobile_config.php').write_text("<?php return ['google_web_client_id'=>'fixture-local.apps.googleusercontent.com'];\n", encoding='utf-8')
        config = {'game': {'jumpEnabled': True, 'helmetEnabled': True}, 'economy': {
            'initialLives': 100, 'initialTokens': 0, 'runRewardEvery': 200, 'runRewardTokens': 1,
            'riskRewardEvery': 5, 'riskRewardTokens': 1, 'installBonusAutoClaim': False,
            'earnSurviveSeconds': 10, 'earnRecordSeconds': 20, 'earnRisksInRun': 5}}
        (public / 'config/gameplay-config.json').write_text(json.dumps(config), encoding='utf-8')
        env = os.environ.copy(); env.update({'HTTPS_PROXY': 'http://127.0.0.1:1', 'ALL_PROXY': 'http://127.0.0.1:1'})
        log = (runroot / 'php.log').open('w', encoding='utf-8')
        process = subprocess.Popen([str(PHP), '-S', f'127.0.0.1:{port}', '-t', str(public)], cwd=public,
            env=env, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        # This opener never uses the caller's network proxy and accepts only our endpoint.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        def http(body, actor=None, fixture=False, expected=200):
            url = endpoint.replace('mobile.php', 'fixture.php') if fixture else endpoint
            headers = {'Content-Type': 'application/json'}
            if fixture: headers['X-Fixture-Control'] = control
            elif actor: headers['Authorization'] = 'Bearer '+actor['secret']
            request = urllib.request.Request(url, json.dumps(body).encode(), headers)
            try:
                response = opener.open(request, timeout=12); status = response.status; data = json.load(response)
            except urllib.error.HTTPError as error:
                status = error.code; data = json.load(error)
            if status != expected: raise AssertionError(f'HTTP {body.get("action")}: expected {expected}, got {status}, error={data.get("error")}')
            return data
        for _ in range(60):
            try:
                opener.open(endpoint, timeout=.3).close(); break
            except Exception: time.sleep(.1)
        else: raise RuntimeError('Local PHP did not start')
        boot = http({'action': 'bootstrap'}, fixture=True); check(boot['tableCount']==8, 'bootstrap: only legacy seven tables + schema marker')
        health = json.load(opener.open(endpoint)); revision = health['rulesRevision']
        def guest():
            actor = {'installation': secrets.token_hex(16), 'secret': secrets.token_hex(32)}
            data = http({'action': 'guest', **actor}); actor['id'] = data['profile']['id']; return actor
        def profile(actor): return http({'action': 'profile'}, actor)['profile']
        def state(actor): return http({'action': 'invites_state'}, actor)['invites']
        def token(subject): return http({'action': 'token', 'subject': str(subject)}, fixture=True)['idToken']
        def google(actor, subject): return http({'action': 'google_link', 'idToken': token(subject)}, actor)
        def inspect(actor): return http({'action':'inspect','playerId':int(actor['id'].split(':')[1])}, fixture=True)
        def finish(actor):
            start = http({'action':'round_start','requestId':secrets.token_hex(32),'rulesRevision':revision}, actor)
            body = {'action':'round_finish','roundId':start['roundId'],'timeMs':1000,'runDistance':0,'riskCount':0,'hadJump':False,'hadHelmet':False}
            return body, http(body, actor)
        legacy = guest()
        check(http({'action':'invites_state'},legacy,expected=503)['error']=='invites_unavailable','missing invitation schema: HTTP 503 specific error')
        check(profile(legacy)['id']==legacy['id'],'missing invitation schema: legacy profile works')
        oldfinish, ack = finish(legacy); check(ack['ok'] and 'scoreId' in ack,'missing invitation schema: legacy finish acknowledgement retained')
        check(google(legacy,900)['profile']['googleLinked'],'missing invitation schema: legacy verified fixture Google link works')
        check(http({'action':'round_finish',**{k:v for k,v in oldfinish.items() if k!='action'}},legacy)['scoreId']==ack['scoreId'],'missing schema: repeated finish retains score acknowledgement')
        check(not any(x.startswith('mobile_invite') for x in inspect(legacy)['tables']),'missing schema: player requests performed no invite DDL')
        http({'action':'migrate_invites'},fixture=True)
        check(http({'action':'profile','secret':legacy['secret'],'playerId':legacy['id']},expected=401)['error']=='unauthorized','auth: body secret/id cannot replace Bearer')
        check(http({'action':'profile'}, {'secret':'f'*64}, expected=401)['error']=='unauthorized','auth: invalid Bearer rejected')
        a,b = guest(),guest()
        for actor, amount, name in [(a,31,'HttpInviter'),(b,17,'HttpFriend')]:
            http({'action':'seed','playerSecret':actor['secret'],'tokens':amount},fixture=True)
            http({'action':'rename','nickname':name},actor)
        google(a,101);google(b,102)
        ac,bc=state(a)['ownCode'],state(b)['ownCode']
        check(http({'action':'invites_bind','code':'AAAAAAAAAAAA'},b,expected=404)['error']=='invite_not_found','unknown code: HTTP rejection does not bind')
        check(http({'action':'invites_bind','code':bc},b,expected=409)['error']=='invite_self','self code: authenticated canonical self rejected')
        check(not state(b)['inviterAssigned'],'unknown/self: slot remains available')
        bound=http({'action':'invites_bind','code':ac,'playerId':a['id'],'inviterId':b['id'],'reward':999,'tokens':999},b)
        check(bound['invites']['profileId']==b['id'] and bound['invites']['inviterCode']==ac,'valid bind: Bearer actor overrides injected player IDs')
        check(profile(b)['wallet']['tokens']==17 and state(a)['paidRows']==[],'bind/caller credit: no early money or unpaid history')
        for n in range(1,6):
            last, ack=finish(b)
            check(inspect(b)['finished']==n,f'HTTP round {n}: real finished row persisted')
            check(profile(b)['wallet']['tokens']==(17 if n<5 else 27),f'HTTP round {n}: invitee reward threshold')
            check(profile(a)['wallet']['tokens']==(31 if n<5 else 41),f'HTTP round {n}: inviter reward threshold')
        paid=state(a)
        check(paid['rewardTotal']==10 and len(paid['paidRows'])==1 and paid['paidRows'][0]['nickname']=='HttpFriend','paid-only history: actual nickname/time/+10 and total')
        check(inspect(b)['ledgerRows']==1 and inspect(a)['ledgerRows']==1,'atomic reward: exactly one ledger entry per side')
        check(http(last,b)['scoreId']==ack['scoreId'],'repeated finish: original acknowledgement unchanged')
        http({'action':'invites_bind','code':ac},b);state(b);profile(a)
        check(inspect(b)['ledgerRows']==1 and profile(a)['wallet']['tokens']==41 and profile(b)['wallet']['tokens']==27,'finish/bind/refresh retries: no duplicate credit')
        check(http({'action':'wallet_operation','operationId':secrets.token_hex(32),'kind':'invite_reward','args':{'amount':999}},b,expected=400)['error']=='operation_invalid','wallet API: arbitrary invitation credit forbidden')
        historical=guest();google(historical,103)
        for _ in range(5): finish(historical)
        check(profile(historical)['wallet']['tokens']==0,'historical games: no credit before code')
        late=http({'action':'invites_bind','code':ac},historical)
        check(late['invites']['bonusStatus']=='rewarded' and profile(historical)['wallet']['tokens']==10 and inspect(historical)['finished']==5,'late code: five old real finishes reward immediately without extra game')
        d,e=guest(),guest();google(e,105); dc=state(d)['ownCode']
        http({'action':'invites_bind','code':dc},e)
        for _ in range(5): finish(e)
        check(state(e)['bonusStatus']=='waiting_google' and inspect(d)['ledgerRows']==0 and profile(e)['wallet']['tokens']==0,'one Google only: no payout after five games')
        linked=google(d,104)
        check(linked['profile']['wallet']['tokens']==10 and profile(e)['wallet']['tokens']==10,'late inviter Google: production controller hook pays pending invitee immediately')
        r,s,requester=guest(),guest(),guest();google(r,201);google(s,202);rc=state(r)['ownCode']
        http({'action':'invites_bind','code':rc},s)
        http({'action':'history','playerSecret':s['secret']},fixture=True)
        restored=http({'action':'google_restore','idToken':token(201),'installation':requester['installation'],'secret':requester['secret'],'playerId':s['id']})
        check(restored['profile']['id']==r['id'] and restored['profile']['wallet']['tokens']==10 and inspect(s)['wallet']['tokens']==10,'canonical restore: hook uses restored result actor, not requester/body ID')
        check(inspect(requester)['wallet']['tokens']==0,'canonical restore: separate guest wallet stays unchanged')
        check(http({'action':'invites_bind','code':dc},b,expected=409)['error']=='invite_already_bound' and state(b)['inviterCode']==ac,'assigned inviter immutable across additional code attempts')
        # Real Flutter client test receives only the private control-file path, not any key/token in CLI output.
        dart_env=os.environ.copy();dart_env['UNTOUCH_FRIEND_INVITES_CONTROL_FILE']=str(runroot/'control.json')
        dart_log=evidence/(prefix+'-dart-http.txt')
        with dart_log.open('w',encoding='utf-8') as stream:
            dart=subprocess.run([str(DART),str(FLUTTER),'test','--no-pub','test/friend_invites_http_integration_test.dart','--reporter','expanded'],cwd=ROOT,env=dart_env,stdout=stream,stderr=stream,timeout=180)
        matched = re.search(r'Actual loopback HTTP requests: ([0-9]+)', dart_log.read_text(encoding='utf-8'))
        requests = int(matched.group(1)) if matched else 0
        check(dart.returncode==0 and requests>45,'real Dart account/invites/wallet: live controller+SQL chain passes without skipped/mock transport')
        result['dartHttpRequests'] = requests
        cache = json.loads((api / 'config-data/google-certs.json').read_text(encoding='utf-8'))
        check(cache['expires'] > time.time(),'synthetic certificate cache fresh throughout; production verifier returns cache before network branch')
        result['googleFixture']={'syntheticRS256': True, 'realOAuth': False, 'cacheFreshThroughEnd': True,
            'childHttpsAndAllProxy': 'http://127.0.0.1:1', 'keyTokenCacheLocation':'private runtime only'}
        check(all(sha(ROOT/item['source'])==item['sha256'] for item in copied),'production dependencies remained frozen through execution')
        check(all(sha(ROOT/item['source'])==item['sha256'] for item in client_sources),'production Dart account/invites/wallet sources unchanged through live HTTP run')
        result['passed']=True
    except Exception as error:
        result['passed']=False;result['failure']=str(error)[:300]
    finally:
        # Cleanup CLI uses a whitelist and exact direct DSN even when the HTTP process failed.
        if (runroot/'control.json').exists():
            cleanup=subprocess.run([str(PHP),str(api/'fixture.php'),'--cleanup'],capture_output=True,text=True,timeout=15)
            try:
                remaining=json.loads(cleanup.stdout)['remaining'];result['cleaned']=cleanup.returncode==0 and remaining==[];result['remainingTableCount']=len(remaining)
            except Exception: result['cleaned']=False
        if process is not None:
            process.terminate()
            try: process.wait(timeout=8)
            except subprocess.TimeoutExpired: process.kill();process.wait(timeout=5)
            result['phpStopped']=process.poll() is not None
        if log is not None: log.close()
        result['checkCount']=len(checks)
        (evidence/(prefix+'-http-controller-result.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({'passed':result.get('passed'), 'checkCount':len(checks),'cleaned':result['cleaned'],'phpStopped':result['phpStopped'],'failure':result.get('failure')}))
    return 0 if result.get('passed') and result['cleaned'] and result['phpStopped'] else 1

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-prefix',default='executor',help='Fresh ASCII evidence name; existing artifacts are never overwritten')
    args=parser.parse_args()
    prefix=args.evidence_prefix
    if not re.fullmatch(r'[a-z][a-z0-9_-]{0,63}',prefix):
        parser.error('Evidence prefix must be 1-64 lowercase ASCII letters/digits/underscore/hyphen, starting with a letter')
    evidence=ROOT/'docs/release-evidence/friend-invites-20261013/b6'
    if any((evidence/(prefix+suffix)).exists() for suffix in ['-http-controller-result.json','-dart-http.txt']):
        parser.error('Evidence prefix already exists; choose a fresh prefix')
    sys.exit(run(prefix))
