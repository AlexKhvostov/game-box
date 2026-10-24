"""P0 supplementary public dependencies, without overwriting the original snapshot."""
from pathlib import Path
import hashlib,json,shutil,datetime
ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT/'docs/release-evidence/telegram-port/P0'
DEST=ROOT/'.private/telegram-port/baseline-addendum-20261020'
names=['pubspec.lock','tools/build_phone_apk.ps1','admin-console/package.json','admin-console/package-lock.json']
for folder in ['assets/branding/account','assets/branding/ranking','admin-console/src']:
    names += [p.relative_to(ROOT).as_posix() for p in (ROOT/folder).rglob('*') if p.is_file()]
files={}
for name in sorted(names):
    if not (ROOT/name).is_file():continue
    target=DEST/name
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():shutil.copyfile(ROOT/name,target)
    files[name]=hashlib.sha256(target.read_bytes()).hexdigest()
report={'baselineId':'android-188-20261020','privateSnapshot':DEST.relative_to(ROOT).as_posix(),
        'createdAt':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).isoformat(),'files':files}
target=EVIDENCE/'addendum.json'
if target.exists():
    old=json.loads(target.read_text(encoding='utf-8'))
    if old['files']!=files:raise SystemExit('Existing addendum mismatch')
else:target.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(f'Addendum verified: {len(files)} files; original baseline unchanged')
