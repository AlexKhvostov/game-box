"""Prepare/publish approved economy through the existing admin API.

Credentials via DPAPI stdin; admin secret is read only into memory, never saved.
"""
import argparse
import copy
from datetime import datetime, timezone
import ftplib
import hashlib
import hmac
import io
import json
from pathlib import Path
import re
import ssl
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'tmp/economy-20261013'
OUT = ROOT / 'docs/release-evidence/economy-20261013'
counts = {'pack_s': 20, 'pack_m': 50, 'pack_l': 200, 'pack_xl': 1000}
prices = {'pack_s': 99, 'pack_m': 199, 'pack_l': 399, 'pack_xl': 999}
fields = {
    'lifePackSize': 1, 'lifePackCostTokens': 1,
    'lifePacks': [{'lives': lives, 'costTokens': cost} for cost, lives in [(1,1),(10,15),(25,50),(49,100)]],
    'dailyRewardTokens': [2,4,8,12,18,24,36], 'timedBonusTokens': 4, 'timedBonusHours': 1,
    'jumpRentalCost': 10, 'jumpRentalMinutes': 10, 'jumpRentalHourCost': 20, 'jumpRentalHourMinutes': 60,
    'helmetRentalCost': 10, 'helmetRentalMinutes': 10, 'helmetRentalHourCost': 20, 'helmetRentalHourMinutes': 60,
}


def update(config):
    config = copy.deepcopy(config)
    economy = config['economy']
    economy.update(fields)
    for item in economy['earnActions']:
        if item['id'] == 'watch_ad':
            item['reward'] = 10
    for pack in economy['starsShop']['packs']:
        if pack['id'] in counts:
            pack['crystals'] = counts[pack['id']]
    economy['androidShop'] = {'currency': 'USD', 'packs': [
        {'id': key, 'crystals': counts[key], 'usdCents': prices[key]} for key in counts]}
    return config


def assert_scope(before, after):
    cleaned = copy.deepcopy(after)
    be, ae = before['economy'], cleaned['economy']
    for key in fields:
        if key in be: ae[key] = be[key]
        else: ae.pop(key, None)
    ae['earnActions'] = be['earnActions']
    ae['starsShop'] = be['starsShop']
    if 'androidShop' in be: ae['androidShop'] = be['androidShop']
    else: ae.pop('androidShop', None)
    assert cleaned == before, 'Unrelated config changed'
    assert after['economy']['premiumDailyMultiplier'] == be['premiumDailyMultiplier']
    assert all(p['stars'] == next(x['stars'] for x in be['starsShop']['packs'] if x['id'] == p['id'])
               for p in after['economy']['starsShop']['packs'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'publish'])
    mode = parser.parse_args().mode
    credentials = json.load(sys.stdin)
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    def read(name):
        context = ssl.create_default_context()
        context.maximum_version = ssl.TLSVersion.TLSv1_2
        ftp = ftplib.FTP_TLS(context=context, timeout=30)
        ftp.connect(credentials['host'], int(credentials.get('port',21)))
        ftp.auth(); ftp.login(credentials['user'],credentials['password']); ftp.prot_p(); ftp.cwd('/')
        body = io.BytesIO()
        try: ftp.retrbinary('RETR ' + name, body.write)
        finally: ftp.close()
        return body.getvalue()

    secret_source = read('api/bot_config.php').decode('utf-8-sig')
    match = re.search(r"['\"]admin_key['\"]\s*=>\s*['\"]([^'\"]+)['\"]", secret_source)
    if not match:
        raise RuntimeError('Configured admin key not located; no secrets printed')
    key = match.group(1)
    secret_source = None

    def api(action, data=None):
        session = hmac.new(key.encode(), b'untouch-admin-v1', hashlib.sha256).hexdigest()
        headers = {'Cookie':'untouch_admin='+session, 'Cache-Control':'no-cache'}
        if data is not None: headers['Content-Type'] = 'application/json'
        request = urllib.request.Request('https://untouch.ballaball.xyz/api/admin.php?action='+action,
            data=None if data is None else json.dumps(data, ensure_ascii=False).encode(), headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response: result = json.load(response)
        if not result.get('ok'): raise RuntimeError('Admin operation rejected')
        return result

    snapshot = api('config_get')
    if mode == 'prepare':
        backup = ROOT / 'archives' / ('economy-before-' + datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S'))
        backup.mkdir(parents=True, exist_ok=False)
        original = read('api/config-data/published.json')
        (backup / 'published.json').write_bytes(original)
        (backup / 'sha256.txt').write_text(hashlib.sha256(original).hexdigest()+'\n', encoding='ascii')
        clean = {k:v for k,v in snapshot.items() if k not in ['csrf','ok']}
        (WORK / 'before.json').write_text(json.dumps(clean, ensure_ascii=False, indent=2), encoding='utf-8')
        candidate = update(snapshot['config'])
        assert_scope(snapshot['config'], candidate)
        (WORK / 'candidate.json').write_text(json.dumps(candidate, ensure_ascii=False, indent=2), encoding='utf-8')
        # Separate tiny API release for the beta catalogue only.
        original_beta = read('api/mobile_beta.php')
        marker = read('api/mobile-release.json')
        (WORK / 'api-source').mkdir(exist_ok=True)
        beta = original_beta.decode('utf-8-sig')
        old = "'pack_s' => 30, 'pack_m' => 80, 'pack_l' => 200, 'pack_xl' => 500"
        new = "'pack_s' => 20, 'pack_m' => 50, 'pack_l' => 200, 'pack_xl' => 1000"
        assert beta.count(old) == 1
        (WORK / 'api-source/mobile_beta.php').write_text(beta.replace(old,new), encoding='utf-8')
        (WORK / 'api-expected.json').write_text(json.dumps({
            'api/mobile_beta.php': hashlib.sha256(original_beta).hexdigest(),
            'api/mobile-release.json': hashlib.sha256(marker).hexdigest()}, indent=2), encoding='utf-8')
        (WORK / 'backup.json').write_text(json.dumps({'path':str(backup),'sha256':hashlib.sha256(original).hexdigest()},indent=2),encoding='utf-8')
        # Future builds and fallback receive identical approved values.
        basepath = ROOT / 'telegram-web/config/gameplay-config.json'
        base = json.loads(basepath.read_text(encoding='utf-8-sig'))
        basepath.write_text(json.dumps(update(base), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        bundled = {'ok':True, **clean, 'config':candidate, 'source':'approved-economy-20261013'}
        (ROOT / 'assets/config/published-gameplay.json').write_text(json.dumps(bundled,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('Approved economy prepared; original publication archived; unrelated config preserved')
    else:
        before = json.loads((WORK / 'before.json').read_text(encoding='utf-8'))
        candidate = json.loads((WORK / 'candidate.json').read_text(encoding='utf-8'))
        if snapshot['revision'] != before['revision']:
            raise RuntimeError('Publication changed since preparation; refusing stale overwrite')
        assert_scope(before['config'],candidate)
        published = api('config_save', {'config':candidate,'revision':snapshot['revision'],'csrf':snapshot['csrf']})
        with urllib.request.urlopen('https://untouch.ballaball.xyz/api/config.php',timeout=30) as response:
            public = json.load(response)
        assert public['config'] == candidate and published['config'] == candidate
        (ROOT / 'assets/config/published-gameplay.json').write_text(json.dumps(public,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        record = {'ok':True,'adminRevision':published['revision'],'publicRevision':public['revision'],
            'httpsVerified':True,'unrelatedConfigPreserved':True,'playerBalancesTouched':False,
            'backup':json.loads((WORK/'backup.json').read_text(encoding='utf-8')),
            'economy':public['config']['economy'],'googlePlayPriceCatalogChanged':False}
        (OUT / 'published-economy.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
        print('Economy published through admin revision/CSRF; HTTPS exact config verified; balances preserved')
    key = None
