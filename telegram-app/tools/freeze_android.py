"""Freeze public Android source/contract inputs without touching the working tree."""
from pathlib import Path
import datetime, hashlib, json, shutil, subprocess

ROOT = Path(__file__).resolve().parents[2]
STAMP = 'android-188-20261020'
DEST = ROOT / '.private/telegram-port/baselines' / STAMP
EVIDENCE = ROOT / 'docs/release-evidence/telegram-port/P0'

def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()

def selected():
    for directory, extensions in [
        ('lib', {'.dart', '.arb'}), ('assets/config', {'.json'}),
        ('supabase/functions', {'.mjs', '.ts', '.json'}),
        ('supabase/migrations', {'.sql'}), ('tools/replay', {'.dart'}),
        ('firebase-android', {'.json'}),
    ]:
        for path in (ROOT / directory).rglob('*'):
            if path.is_file() and path.suffix in extensions and 'node_modules' not in path.parts:
                yield path
    for name in ['pubspec.yaml', 'tools/build_android_replay.py']:
        yield ROOT / name

def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    if DEST.exists():
        manifest = json.loads((EVIDENCE / 'baseline.json').read_text(encoding='utf-8'))
        changed = [n for n, h in manifest['files'].items() if digest(DEST / n) != h]
        if changed: raise SystemExit(f'Frozen baseline modified: {changed}')
        print(f'Existing immutable baseline verified: {len(manifest["files"])} files')
        return
    DEST.mkdir(parents=True)
    files = {}
    for path in sorted(set(selected())):
        relative = path.relative_to(ROOT).as_posix()
        target = DEST / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        files[relative] = digest(target)
    manifest = dict(
        id=STAMP, createdAt=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).isoformat(),
        androidVersion='1.0.187+188', gitHead=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        sourceKind='actual-working-tree-including-uncommitted-changes', hashNormalization='CRLF-to-LF',
        publicConfig='assets/config/android-firebase.json', remoteConfigStatus='bundled-only-not-live-fetch',
        privateSnapshot=f'.private/telegram-port/baselines/{STAMP}', files=files)
    (EVIDENCE / 'baseline.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f'Frozen {len(files)} public source/contract files; no secrets read')

if __name__ == '__main__': main()
