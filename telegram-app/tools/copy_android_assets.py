from pathlib import Path
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[2]
baseline=json.loads((ROOT/'docs/release-evidence/telegram-port/P0/baseline.json').read_text(encoding='utf-8'))
for manifest in ['asset-baseline.json','addendum.json']:
    value=json.loads((ROOT/f'docs/release-evidence/telegram-port/P0/{manifest}').read_text(encoding='utf-8'))
    source=ROOT/value.get('privateSnapshot',baseline['privateSnapshot'])
    for name,digest in value['files'].items():
        if not name.startswith('assets/'):continue
        data=(source/name).read_bytes()
        if hashlib.sha256(data).hexdigest()!=digest:raise SystemExit(f'Source asset changed: {name}')
        target=ROOT/'telegram-app/public'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
target=ROOT/'telegram-app/src/generated/android-config.json';target.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/baseline['privateSnapshot']/'assets/config/android-firebase.json',target)
print('Frozen Android assets/config copied byte-for-byte; no image regeneration')
