"""Version-three Android verifier from current Dart physics and shield state.

Legacy v1/v2 generated verifiers and Telegram's browser kernel are never rebuilt.
Only Flutter painting/geometry dependencies are replaced.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--dart', default='C:/Users/alexe/develop/flutter/bin/cache/dart-sdk/bin/dart.exe')
args = parser.parse_args()
OUT = ROOT/'.private/helmet-replay-build'
OUT.mkdir(parents=True, exist_ok=True)
sources = []

def read(name):
    sources.append(name)
    return (ROOT/name).read_text(encoding='utf-8')

def omit(source, marker):
    start = source.index(marker)
    brace = source.index(') {', start) + 2
    depth, i = 1, brace + 1
    while depth:
        if source[i] == '{': depth += 1
        elif source[i] == '}': depth -= 1
        i += 1
    return source[:start] + source[i:]

world = read('lib/features/game/game_world.dart')
world = world.replace("import 'package:flutter/material.dart';", "import 'geometry.dart';")
world = world.replace("import '../../domain/gameplay_config.dart';", "import 'config.dart';")
(OUT/'world.dart').write_text(omit(world, '  void paint(Canvas canvas)'), encoding='utf-8')
config = read('lib/domain/gameplay_config.dart').replace("import 'package:flutter/material.dart';", '')
config = omit(omit(config, '  Color resolveSurfaceColor('), 'Color? parseHexColor(')
(OUT/'config.dart').write_text(config, encoding='utf-8')
for source, destination in [
    ('lib/domain/arcade_rules.dart', 'rules.dart'),
    ('lib/domain/economy_config.dart', 'economy_config.dart'),
    ('lib/domain/android_energy.dart', 'android_energy.dart'),
    ('lib/domain/enemy_pace.dart', 'enemy_pace.dart'),
    ('lib/domain/replay_random.dart', 'random.dart'),
    ('lib/domain/helmet_charge.dart', 'helmet_charge.dart'),
    ('tools/replay/geometry.dart', 'geometry.dart'),
    ('tools/replay_helmet/session.dart', 'session.dart'),
    ('tools/replay_helmet/main.dart', 'main.dart'),
]:
    (OUT/destination).write_text(read(source), encoding='utf-8')
tuning = read('lib/app/mobile_gameplay_tuning.dart')
tuning = tuning.replace("'../domain/gameplay_config.dart'", "'config.dart'")
tuning = tuning.replace("'../domain/arcade_rules.dart'", "'rules.dart'")
tuning = tuning.replace("'../features/game/game_world.dart'", "'world.dart'")
(OUT/'tuning.dart').write_text(tuning, encoding='utf-8')
target = ROOT/'supabase/functions/_shared/android-helmet-replay.generated.mjs'
compiled = OUT/'replay.js'
subprocess.run([args.dart, 'compile', 'js', '-O2', '--no-source-maps', '-o', str(compiled), str(OUT/'main.dart')], check=True)
license_text = (Path(args.dart).resolve().parents[1]/'LICENSE').read_text(encoding='utf-8')
target.write_text('/* Dart SDK runtime license:\n'+license_text+'\n*/\n'+compiled.read_text(encoding='utf-8'), encoding='utf-8')
digest = lambda p: hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
manifest = {'proofVersion':3, 'files':{s:digest(ROOT/s) for s in sources},
    'generatedSha256':digest(target)}
target.with_suffix('.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'ok':True,'proofVersion':3,'sources':len(sources),'sha256':manifest['generatedSha256']}))
