"""Read-only inventory; lexical reachability is evidence, not proof of dead code."""
import json, re
import hashlib, zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[4]
files = sorted((root / 'lib').rglob('*.dart'))
sources = {p.relative_to(root).as_posix(): p.read_text(encoding='utf-8') for p in files}
edges = {}
for name, src in sources.items():
    refs = []
    for uri in re.findall(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]", src):
        if ':' not in uri:
            refs.append((root / name).parent.joinpath(uri).resolve().relative_to(root).as_posix())
    edges[name] = refs
seen, stack = set(), ['lib/main.dart']
while stack:
    name = stack.pop()
    if name in seen: continue
    seen.add(name)
    stack.extend(edges.get(name, []))
all_text = '\n'.join(sources.values())
result = {
    'note': 'All-platform lexical graph. Platform/feature guards require manual review.',
    'dart_files': len(files), 'dart_lines': sum(len(v.splitlines()) for v in sources.values()),
    'unreachable_from_main': [{'file': k, 'lines': len(v.splitlines())} for k, v in sources.items() if k not in seen and '/l10n/' not in k],
    'assets_without_literal_lib_reference': [
        {'file': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size}
        for p in sorted((root / 'assets').rglob('*')) if p.is_file()
        and p.relative_to(root).as_posix() not in all_text and p.name not in all_text
        and p.suffix.lower() in {'.png', '.wav', '.svg', '.webp', '.jpg'}
    ],
    'dependencies': {dep: [k for k, v in sources.items() if f'package:{dep}/' in v] for dep in [
        'cupertino_icons', 'flutter_svg', 'firebase_auth', 'firebase_analytics', 'cloud_firestore', 'firebase_remote_config', 'supabase_flutter'
    ]},
}
Path(__file__).with_name('inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
curated_names = [
    'assets/branding/ui/lives-room-v1.png',
    'assets/branding/ui/profile-player-cube-v1.png',
    'assets/branding/ui/lives-resting-sofa-v1.png',
    'assets/branding/account/fire-v1.png',
    'assets/branding/account/trophy-v1.png',
    'assets/branding/ui/hero-resting-v1.png',
    'assets/branding/ui/hero-focused-v1.png',
    'assets/branding/ui/hero-delighted-v1.png',
    'assets/branding/ui/hero-finished-v1.png',
    'assets/branding/ui/reward-v1.png',
    'assets/sfx/wall_hit.wav',
    'assets/sfx/wall_tick.wav',
]
apk = root / 'build/app/outputs/flutter-apk/app-release.apk'
with zipfile.ZipFile(apk) as z:
    curated = [{'file': name, 'bytes': (root / name).stat().st_size,
                'packaged': 'assets/flutter_assets/' + name in z.namelist()}
               for name in curated_names]
    meta = {'note': 'Manually reviewed: no caller for these GameArt variants; earlier v1 images replaced by v2. Other lexical candidates include active dynamically built paths and MUST NOT be deleted from that list.',
            'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'assets': curated, 'uncompressed_bytes': sum(x['bytes'] for x in curated)}
Path(__file__).with_name('curated-unused-assets.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding='utf-8')
tracked = list((root / 'lib').rglob('*.dart')) + list((root / 'supabase/functions').rglob('*.mjs')) + list((root / 'supabase/functions').rglob('*.ts')) + list((root / 'supabase/migrations').glob('*.sql'))
tracked += list((root / 'android/app/src/main').rglob('*.kt')) + list((root / 'android').rglob('*.gradle.kts'))
tracked += [root / p for p in ['pubspec.yaml', 'pubspec.lock', 'android/app/src/main/AndroidManifest.xml', 'assets/config/android-firebase.json']]
manifest = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(tracked))}
Path(__file__).with_name('source-sha256.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'assets_without_literal_lib_reference'}, ensure_ascii=False, indent=2))
