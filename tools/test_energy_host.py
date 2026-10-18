"""Real MySQL energy tests, using only random isolated test tables and no bot API."""
import concurrent.futures
import io
import json
import pathlib
import secrets
import urllib.request


def run(ftp):
    nonce, token = secrets.token_hex(8), secrets.token_hex(32)
    root = pathlib.Path(__file__).resolve().parent.parent
    tables = {name: '_untouch_test_' + name + '_' + nonce for name in ['schema_versions', 'wallets', 'star_payments', 'star_orders', 'energy_payments', 'energy_wallets', 'energy_events', 'energy_rounds', 'referrals', 'user_flags']}
    files = {'common': 'api/_energy_common_' + nonce + '.php', 'energy': 'api/_energy_store_' + nonce + '.php', 'endpoint': 'api/_energy_test_' + nonce + '.php'}
    helper = '''<?php
header('Content-Type: application/json'); header('Cache-Control: no-store');
if (!hash_equals('__TOKEN__', $_SERVER['HTTP_X_UNTOUCH_TEST'] ?? '')) { http_response_code(403); exit; }
$names = __NAMES__; $replacement = __REPLACEMENTS__;
foreach (['__COMMON__', '__ENERGY__'] as $file) {
 $source = str_replace($names, $replacement, file_get_contents(__DIR__ . '/' . $file));
 eval('namespace UntouchEnergyAudit; use \\PDO; use \\Exception; use \\Throwable; use \\DomainException; use \\RuntimeException; ' . substr($source, 5));
}
try {
 [$pdo] = \\UntouchEnergyAudit\\tg_connect_pdo(); if (!$pdo) throw new Exception('Test database unavailable');
 $input = json_decode(file_get_contents('php://input'), true) ?: [];
 if (($input['action'] ?? '') === 'cleanup') { foreach (__TABLES__ as $table) $pdo->exec('DROP TABLE IF EXISTS `' . $table . '`'); echo '{"ok":true}'; exit; }
 $uid = (string)($input['uid'] ?? ''); if (!preg_match('/^audit-[a-f0-9]{16}-[1-4]$/D', $uid)) throw new Exception('Invalid test user');
 if (($input['action'] ?? '') === 'age') {
  $pdo->prepare('UPDATE `__ENERGY_WALLET__` SET regen_at = regen_at - :elapsed WHERE user_id = :uid')->execute([':elapsed'=>$input['elapsed'], ':uid'=>$uid]);
  echo '{"ok":true}'; exit;
 }
 if (($input['action'] ?? '') === 'purchase') {
  $packs = array_values(array_filter(\\UntouchEnergyAudit\\tg_products(), function($p) { return $p['kind'] === 'crystals'; }));
  $wallet = \\UntouchEnergyAudit\\tg_apply_product($pdo, $uid, $packs[0]['id'], 'audit-__NONCE__-purchase');
  echo json_encode(['ok'=>true, 'credits'=>$packs[0]['crystals']]); exit;
 }
 if (($input['action'] ?? '') === 'frozen_purchase') {
  $product = ['id'=>'audit_frozen_energy','kind'=>'crystals','crystals'=>1,'energy'=>777,'stars'=>1];
  \\UntouchEnergyAudit\\tg_apply_product($pdo,$uid,$product['id'],'audit-__NONCE__-frozen',$product);
  echo '{"ok":true}'; exit;
 }
 if (($input['action'] ?? '') === 'ref_seed') {
  \\UntouchEnergyAudit\\tg_ensure_social_tables($pdo);
  $friend = 'audit-__NONCE__-4';
  $pdo->prepare("INSERT INTO `__REFERRALS__` (invitee_id,inviter_id,invitee_name,created_at) VALUES (:friend,:uid,'Audit',:now)")->execute([':friend'=>$friend,':uid'=>$uid,':now'=>time()*1000]);
  echo '{"ok":true}'; exit;
 }
 if (($input['action'] ?? '') === 'age_round') {
  $pdo->prepare('UPDATE `__ROUNDS__` SET started_at=started_at-20000 WHERE user_id=:uid AND round_id=:id')->execute([':uid'=>$uid,':id'=>$input['roundId']]);
  echo '{"ok":true}'; exit;
 }
 $result = \\UntouchEnergyAudit\\energy_request($pdo, $uid, $input['input'] ?? []);
 $count = $pdo->prepare('SELECT COUNT(*) FROM `__EVENTS__` WHERE user_id=:uid'); $count->execute([':uid'=>$uid]);
 echo json_encode(['ok'=>true, 'cfg'=>\\UntouchEnergyAudit\\energy_settings(), 'events'=>(int)$count->fetchColumn()] + $result);
} catch (Throwable $error) { echo json_encode(['ok'=>false, 'error'=>$error->getMessage()]); }
'''
    replacements = {
        '__TOKEN__': token, '__NONCE__': nonce,
        '__COMMON__': pathlib.PurePosixPath(files['common']).name,
        '__ENERGY__': pathlib.PurePosixPath(files['energy']).name,
        '__NAMES__': '[' + ','.join("'`" + n + "`'" for n in tables) + ']',
        '__REPLACEMENTS__': '[' + ','.join("'`" + n + "`'" for n in tables.values()) + ']',
        '__TABLES__': '[' + ','.join("'" + n + "'" for n in tables.values()) + ']',
        '__ENERGY_WALLET__': tables['energy_wallets'], '__EVENTS__': tables['energy_events'],
        '__REFERRALS__': tables['referrals'], '__ROUNDS__': tables['energy_rounds'],
    }
    for key, value in replacements.items(): helper = helper.replace(key, value)
    uploaded = []
    cfg_json = json.dumps(json.loads((root / 'telegram-web/config/gameplay-config.json').read_text(encoding='utf-8-sig'))['economy']['energy'])
    energy_source = (root / 'telegram-web/api/energy_store.php').read_text(encoding='utf-8-sig').replace("return tg_local_gameplay_config()['economy']['energy'];", "return json_decode('" + cfg_json + "', true);")

    def rpc(action='wallet', uid=1, **extra):
        data = {'uid': f'audit-{nonce}-{uid}', 'input': {'action': action, **extra}}
        if action in ['cleanup', 'age', 'purchase', 'frozen_purchase', 'ref_seed', 'age_round']: data.update(action=action, **extra)
        request = urllib.request.Request('https://untouch.ballaball.xyz/' + files['endpoint'], data=json.dumps(data).encode(), headers={'Content-Type': 'application/json', 'X-Untouch-Test': token})
        with urllib.request.urlopen(request, timeout=30) as response: return json.load(response)

    def good(*args, **kwargs):
        result = rpc(*args, **kwargs)
        assert result['ok'], result
        return result

    try:
        for name, content in [(files['common'], (root / 'telegram-web/api/tg_common.php').read_bytes()), (files['energy'], energy_source.encode()), (files['endpoint'], helper.encode())]:
            uploaded.append(name)
            ftp.storbinary('STOR ' + name, io.BytesIO(content))
        cfg = good()['cfg']
        cost = cfg['roundCost']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: good('start', requestId='same-round-test', loadout={}), range(4)))
        assert good()['wallet']['total'] == cfg['initial'] - cost
        assert good()['events'] == 1
        good('age', elapsed=cfg['refillSeconds'] * 1000)
        assert good()['wallet']['base'] == cfg['cap']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda i: good('start', requestId=f'round-different-{i}', loadout={}), range(4)))
        assert good()['wallet']['total'] == cfg['cap'] - 4 * cost
        good('migrate', 2, requestId='legacy-migration-test', legacy={'lives': 20, 'tokens': 10, 'appliedStarsTokens': 2})
        migrated = good('wallet', 2)['wallet']['total']
        assert migrated == max(cfg['initial'], 20 * cfg['legacyLifeEnergy']) + 8 * cfg['legacyCrystalEnergy']
        good('migrate', 2, requestId='legacy-migration-again', legacy={'lives': 99999, 'tokens': 99999})
        assert good('wallet', 2)['wallet']['total'] == migrated
        paid = good('purchase', 2)
        assert good('wallet', 2)['wallet']['total'] == migrated + paid['credits'] * cfg['legacyCrystalEnergy']
        before_frozen = good('wallet', 2)['wallet']['total']
        good('frozen_purchase', 2)
        assert good('wallet', 2)['wallet']['total'] == before_frozen + 777
        assert good('wallet', 2)['wallet']['total'] == before_frozen + 777
        good('age', 2, elapsed=cfg['refillSeconds'] * 1000 * 2)
        assert good('wallet', 2)['wallet']['reserve'] == migrated - cfg['initial'] + paid['credits'] * cfg['legacyCrystalEnergy'] + 777
        before = good('wallet', 3)['wallet']['total']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: good('daily', 3, requestId='daily-repeat-test'), range(4)))
        assert good('wallet', 3)['wallet']['total'] == before + cfg['dailyRewards'][0]
        assert not rpc('daily', 3, requestId='daily-second-test')['ok']
        good('timed', 3, requestId='timed-reward-test')
        assert not rpc('timed', 3, requestId='timed-second-test')['ok']
        assert not rpc('start', 3, requestId='invalid-jumps-test', loadout={'jumps': 4})['ok']
        initial = good('wallet', 4)['wallet']['total']
        for i in range(initial // cost): good('start', 4, requestId=f'drain-round-test-{i}', loadout={})
        assert not rpc('start', 4, requestId='drain-too-many-test')['ok']
        assert good('wallet', 4)['wallet']['total'] == initial % cost
        assert not rpc('daily', 1, requestId='same-round-test')['ok']
        opened = good('ad_open', 3, requestId='ad-open-session-test')
        assert not rpc('ad_finish', 3, requestId='ad-invalid-test', sessionId='fake-session')['ok']
        before = good('wallet', 3)['wallet']['total']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: good('ad_finish', 3, requestId='ad-finish-session-test', sessionId=opened['sessionId']), range(4)))
        assert good('wallet', 3)['wallet']['total'] == before + cfg['adReward']
        assert not rpc('ad_finish', 3, requestId='ad-second-session-test', sessionId=opened['sessionId'])['ok']
        assert not rpc('ad_open', 3, requestId='ad-cooldown-session-test')['ok']
        run = good('start', 2, requestId='round-finish-valid-test', loadout={'jumps': 2, 'shield': True, 'impulse': True})
        assert run['round']['cost'] == cfg['roundCost'] + cfg['jump2Cost'] + cfg['shieldCost'] + cfg['impulseCost']
        assert not rpc('finish', 1, requestId='wrong-owner-finish-test', roundId=run['round']['id'], timeMs=1)['ok']
        assert not rpc('finish', 2, requestId='impossible-finish-test', roundId=run['round']['id'], timeMs=3600001)['ok']
        result = good('finish', 2, requestId='valid-finish-test', roundId=run['round']['id'], timeMs=100, steps=0, risks=0)
        assert result['reward'] == 0
        assert good('finish', 2, requestId='valid-finish-test', roundId=run['round']['id'], timeMs=100)['reward'] == 0
        assert not rpc('finish', 2, requestId='finish-twice-test', roundId=run['round']['id'], timeMs=100)['ok']
        assert good('referrals', 1, requestId='empty-referrals-test')['reward'] == 0
        assert not rpc('start', 2, requestId='wrong-price-test', expectedCost=9999)['ok']
        good('ref_seed', 1)
        assert good('referrals', 1, requestId='unqualified-friend-test')['reward'] == 0
        good('age', 4, elapsed=cfg['refillSeconds'] * 1000)
        friend_run = good('start', 4, requestId='qualified-friend-round', loadout={})
        good('age_round', 4, roundId=friend_run['round']['id'])
        good('finish', 4, requestId='qualified-friend-finish', roundId=friend_run['round']['id'], timeMs=11000, steps=0, risks=0)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: good('referrals', 1, requestId='qualified-friend-reward'), range(4)))
        assert good('referrals', 1, requestId='qualified-friend-reward')['reward'] == cfg['referralReward']
        assert good('referrals', 1, requestId='qualified-friend-recheck')['reward'] == 0
        v2 = good('start', 2, requestId='v2-ability-round', model='abilities-v2', expectedCost=cost, loadout={'jumps':3,'shield':True})
        assert v2['round']['cost'] == cost and v2['round']['loadout']['jumps'] == 0
        v2id = v2['round']['id']
        before = good('wallet', 2)['wallet']['total']
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: good('ability', 2, requestId='v2-jump-identical', roundId=v2id, ability='jump', atMs=0, expectedCost=cfg['jumpUseCost']), range(4)))
        assert good('wallet', 2)['wallet']['total'] == before - cfg['jumpUseCost']
        assert not rpc('ability', 1, requestId='v2-wrong-owner', roundId=v2id, ability='jump', atMs=0)['ok']
        assert not rpc('ability', 2, requestId='v2-jump-identical', roundId=v2id, ability='shield', atMs=0)['ok']
        assert not rpc('ability', 2, requestId='v2-jump-too-soon', roundId=v2id, ability='jump', atMs=100)['ok']
        good('age_round', 2, roundId=v2id)
        good('ability', 2, requestId='v2-jump-after-recharge', roundId=v2id, ability='jump', atMs=cfg['jumpRechargeSec']*1000)
        good('ability', 2, requestId='v2-impulse-use', roundId=v2id, ability='impulse', atMs=0)
        good('ability', 2, requestId='v2-shield-use', roundId=v2id, ability='shield', atMs=0)
        assert not rpc('ability', 2, requestId='v2-impulse-too-soon', roundId=v2id, ability='impulse', atMs=100)['ok']
        assert not rpc('ability', 2, requestId='v2-shield-too-soon', roundId=v2id, ability='shield', atMs=100)['ok']
        assert not rpc('ability', 2, requestId='v2-impossible-time', roundId=v2id, ability='jump', atMs=3600001)['ok']
        good('finish', 2, requestId='v2-finish-round', roundId=v2id, timeMs=100, steps=0, risks=0)
        assert not rpc('ability', 2, requestId='v2-use-after-finish', roundId=v2id, ability='jump', atMs=10000)['ok']
        print('PASS: real MySQL energy and per-use abilities, offline refill, reserve, concurrent/idempotent spending, ownership, cooldowns, migration, rewards and shortage', flush=True)
    finally:
        try:
            if uploaded: assert rpc('cleanup')['ok'], 'Energy test cleanup failed'
        finally:
            for name in reversed(uploaded): ftp.delete(name)
            print('Isolated energy tables and temporary endpoints removed', flush=True)
