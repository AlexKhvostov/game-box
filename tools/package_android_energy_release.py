"""Prepare an allowlisted offline release; never connects to production."""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'releases/android-energy-server-20261015-0310'
DEPLOY = [
    'api/mobile_energy.php', 'api/mobile_energy_feedback.php',
    'api/mobile.php', 'api/mobile_store.php', 'api/mobile_wallet.php',
    'api/mobile_invites.php', 'api/mobile_play.php',
    'api/mobile_play_notifications.php', 'api/mobile_play_maintenance.php',
    'api/gameplay_config.php', 'admin/config-schema.json',
]
OPERATOR = ['tools/maintain_mobile_energy.php', 'tools/prepare_android_energy_config.py']


def main():
    if OUT.exists():
        raise SystemExit('Immutable output already exists; choose a fresh release directory')
    OUT.mkdir(parents=True)
    for rel in DEPLOY:
        target = OUT / 'deploy' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'telegram-web' / rel, target)
    for rel in OPERATOR:
        target = OUT / 'operator' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / rel, target)
    reference = OUT / 'reference'
    reference.mkdir()
    shutil.copyfile(ROOT / 'telegram-web/api/mobile_config.example.php', reference / 'mobile_config.example.php')
    shutil.copyfile(ROOT / 'docs/ANDROID_ENERGY_V2_CONTRACT.md', reference / 'ANDROID_ENERGY_V2_CONTRACT.md')
    shutil.copyfile(ROOT / 'docs/ANDROID_ENERGY_RELEASE.md', OUT / 'README.md')
    block = json.loads((ROOT / 'telegram-web/config/gameplay-config.json').read_text(encoding='utf-8-sig'))['economy']['androidEnergyV2']
    assert block['enabled'] is False
    # The merge helper only needs this Android block, never the game's defaults.
    defaults = OUT / 'operator/telegram-web/config/gameplay-config.json'
    defaults.parent.mkdir(parents=True)
    defaults.write_text(json.dumps({'economy': {'androidEnergyV2': block}}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    catalog = {
        'platform': 'Google Play', 'referenceCurrency': 'USD',
        'notGoogleBulkImport': True, 'actualPriceSource': 'Google ProductDetails',
        'oneTime': [{'id': f'energy_{n}_v1', 'energy': n, 'referencePrice': price}
                    for n, price in [(100, 2), (250, 4), (500, 6), (1000, 9)]],
        'subscriptions': [
            {'id': 'energy_batteries_2_v1', 'basePlanId': 'weekly', 'periodDays': 7,
             'additionalBatteries': 1, 'totalBatteries': 2, 'referencePrice': 1},
            {'id': 'energy_batteries_5_v1', 'basePlanId': 'weekly', 'periodDays': 7,
             'additionalBatteries': 4, 'totalBatteries': 5, 'referencePrice': 3},
        ],
        'paidBatteryCapacity': 20, 'paidChargeHours': 12,
        'compositionImmutablePerSku': True,
    }
    (reference / 'play-catalog-reference.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    files = []
    for path in sorted(OUT.rglob('*')):
        if not path.is_file():
            continue
        rel = path.relative_to(OUT).as_posix()
        assert not any(s in rel for s in ['db_config.php', 'mobile_config.php', 'published.json', 'config-data/', '.private/'])
        files.append({'path': rel, 'bytes': path.stat().st_size,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest = {'enabled': False, 'published': False, 'deployFiles': len(DEPLOY), 'files': files}
    (OUT / 'manifest-sha256.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    archive = OUT.with_suffix('.zip')
    assert not archive.exists()
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for path in sorted(OUT.rglob('*')):
            if path.is_file():
                z.write(path, path.relative_to(OUT).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for item in files:
            assert hashlib.sha256(z.read(item['path'])).hexdigest() == item['sha256']
    print(json.dumps({'ok': True, 'deployFiles': len(DEPLOY), 'files': len(files) + 1,
                      'archive': str(archive.relative_to(ROOT)),
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
