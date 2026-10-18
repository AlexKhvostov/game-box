"""Check the built bundle and source reachability; never delete source assets."""
import argparse,json,re,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--apk',type=Path,required=True);args=p.parse_args()
excluded=json.loads((root/'docs/ANDROID_ASSET_EXCLUSIONS.json').read_text(encoding='utf-8'))
with zipfile.ZipFile(args.apk)as apk:
    names=set(apk.namelist())
    for item in excluded:
        assert (root/item['file']).is_file(),item
        assert 'assets/flutter_assets/'+item['file']not in names,item
sources={p.resolve():p.read_text(encoding='utf-8')for p in (root/'lib').rglob('*.dart')}
seen=set();pending=[(root/'lib/main.dart').resolve()]
while pending:
    source=pending.pop()
    if source in seen:continue
    seen.add(source)
    for uri in re.findall(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]",sources.get(source,'')):
        if ':'not in uri:pending.append((source.parent/uri).resolve())
assert (root/'lib/features/balance/legacy_energy_sheet.dart').resolve()not in seen
assert (root/'lib/features/balance/energy_services.dart').resolve()in seen
for name in ['firebase_auth','cloud_firestore','firebase_analytics','cupertino_icons']:
    assert name not in (root/'pubspec.lock').read_text(encoding='utf-8'),name
for file in ['lib/data/firebase_bootstrap.dart','lib/data/firestore_scores_source.dart','fixtures/features/balance/legacy_energy_sheet.dart']:
    assert (root/'legacy/flutter'/file).is_file(),file
print(json.dumps({'assetsExcluded':len(excluded),'uncompressedBytesExcluded':sum(x['bytes']for x in excluded),'allSourceAssetsRetained':True,'legacyEnergyUnreachableFromMain':True,'activeEnergyServicesReachable':True}))
