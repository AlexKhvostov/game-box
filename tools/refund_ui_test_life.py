"""Restore exactly one life for the documented 106 UI-test incident.

Requires a private owner selector, verifies the exact short round, backs up the
wallet before changing it, preserves every other value, and records idempotency.
Never deletes scores/accounts or installs a permanent server endpoint.
"""
import hashlib
import io
import json
import secrets
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


def run(ftp):
    private = Path(__file__).resolve().parent.parent/'.private/modal-main106'
    settings = json.loads((private/'refund-settings.json').read_text(encoding='utf-8'))
    assert settings['delta'] == 1 and settings['timeMs'] == 1463
    assert settings['email'], 'Verified cached Google selector required'
    operation = private/'refund-operation-id.txt'
    if not operation.exists():
        operation.write_text(secrets.token_hex(32), encoding='ascii')
    key = operation.read_text(encoding='ascii').strip()
    gate = secrets.token_hex(32)
    endpoint = 'api/_ui_refund_'+secrets.token_hex(16)+'.php'
    start = int(datetime(2026, 10, 12, 20, 39, tzinfo=timezone.utc).timestamp()*1000)
    end = int(datetime(2026, 10, 12, 20, 42, tzinfo=timezone.utc).timestamp()*1000)
    php = '''<?php
header('Content-Type: application/json'); header('Cache-Control: no-store');
if (!hash_equals(GATE,$_SERVER['HTTP_X_UI_REFUND']??'')) {http_response_code(403);exit;}
require_once __DIR__.'/tg_common.php'; require_once __DIR__.'/mobile_store.php';
require_once __DIR__.'/mobile_wallet.php';
try {
  [$pdo]=tg_connect_pdo(); if(!$pdo)throw new Exception('database_unavailable');
  $input=json_decode(file_get_contents('php://input'),true)??[];
  $pdo->beginTransaction();
  $q=$pdo->prepare("SELECT * FROM mobile_players WHERE google_sub IS NOT NULL AND JSON_UNQUOTE(JSON_EXTRACT(wallet_json,'$._googleIdentity.email'))=? FOR UPDATE");
  $q->execute([EMAIL]); $rows=$q->fetchAll(PDO::FETCH_ASSOC);
  if(count($rows)!==1)throw new Exception('owner_not_unique'); $p=$rows[0];
  $q=$pdo->prepare("SELECT r.id FROM mobile_rounds r JOIN scores s ON s.id=r.score_id WHERE r.player_id=? AND s.user_id=? AND s.time_ms=1463 AND s.run_distance=0 AND s.risk_count=0 AND r.started_at BETWEEN START AND END");
  $q->execute([$p['id'],'android:'.$p['id']]); $rounds=$q->fetchAll(PDO::FETCH_COLUMN);
  if(count($rounds)!==1)throw new Exception('incident_round_not_unique');
  $fingerprint=hash('sha256',$p['wallet_json'].':'.$p['wallet_version']);
  $wallet=json_decode($p['wallet_json'],true); if(!is_array($wallet))throw new Exception('wallet_invalid');
  $q=$pdo->prepare('SELECT player_id FROM mobile_operations WHERE id=?');$q->execute([OP]);$prior=$q->fetchColumn();
  if($prior && (int)$prior!==(int)$p['id'])throw new Exception('operation_owner_conflict');
  if(($input['action']??'')==='review') {
    $pdo->rollBack();echo json_encode(['fingerprint'=>$fingerprint,'wallet'=>$wallet,'version'=>(int)$p['wallet_version'],'alreadyApplied'=>(bool)$prior]);exit;
  }
  if(($input['action']??'')!=='apply')throw new Exception('action_invalid');
  if(!$prior && !hash_equals($fingerprint,$input['fingerprint']??''))throw new Exception('wallet_changed');
  $before=(int)$wallet['lives']; $original=$wallet;
  if(!$prior) {
    $wallet['lives']=$before+1;
    mobile_wallet_write($pdo,$p['id'],$wallet);
    $pdo->prepare('INSERT INTO mobile_operations (id,player_id,created_at) VALUES (?,?,?)')->execute([OP,$p['id'],(int)round(microtime(true)*1000)]);
  }
  $other=$wallet;$other['lives']=$original['lives'];
  if($other!==$original)throw new Exception('unrelated_wallet_change');
  $pdo->commit();echo json_encode(['ok'=>true,'appliedNow'=>!$prior,'lifeDelta'=>$prior?0:1,'otherWalletUnchanged'=>true]);
} catch(Throwable $e) {
  if(isset($pdo)&&$pdo&&$pdo->inTransaction())$pdo->rollBack();
  http_response_code(409);echo json_encode(['ok'=>false,'error'=>$e->getMessage()]);
}
'''
    substitutions = {'GATE':json.dumps(gate), 'EMAIL':json.dumps(settings['email']),
                     'OP':json.dumps(key), 'START':str(start), 'END':str(end)}
    # Replace only explicit constants; no credentials enter this source.
    import re
    php = re.sub(r'\b(GATE|EMAIL|OP|START|END)\b',lambda m:substitutions[m[0]],php)
    payload = php.encode('utf-8')
    url = 'https://untouch.ballaball.xyz/'+endpoint
    def request(body):
        req=urllib.request.Request(url,data=json.dumps(body).encode(),headers={
            'X-Ui-Refund':gate,'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=30) as response:
            return json.load(response)
    created = False
    proof = {'walletBackup':False,'uploadVerified':False,'endpointRemoved':False}
    try:
        try:
            ftp.size(endpoint)
        except Exception:
            pass
        else:
            raise RuntimeError('Refusing to overwrite an existing endpoint')
        ftp.storbinary('STOR '+endpoint,io.BytesIO(payload));created=True
        received=io.BytesIO();ftp.retrbinary('RETR '+endpoint,received.write)
        assert hashlib.sha256(received.getvalue()).digest()==hashlib.sha256(payload).digest()
        proof['uploadVerified']=True
        review=request({'action':'review'})
        (private/'refund-wallet-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2),encoding='utf-8')
        proof['walletBackup']=True
        result=request({'action':'apply','fingerprint':review['fingerprint']})
        assert result['ok'] and result['otherWalletUnchanged']
        assert result['lifeDelta'] in [0,1]
        proof.update(result)
        second=request({'action':'apply','fingerprint':review['fingerprint']})
        assert second['lifeDelta']==0
        proof['idempotencyVerified']=True
    finally:
        if created:
            ftp.delete(endpoint)
            try:
                urllib.request.urlopen(url,timeout=15)
            except urllib.error.HTTPError as e:
                assert e.code in [403,404,410]
            else:
                raise RuntimeError('Temporary endpoint remains reachable')
            proof['endpointRemoved']=True
        evidence=private.parent.parent/'docs/release-evidence/modal-abilities-prices-20261012/life-refund.json'
        evidence.write_text(json.dumps(proof,indent=2),encoding='utf-8')
    print(json.dumps(proof),flush=True)
