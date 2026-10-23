"""Build browser simulation from the immutable Android baseline, never a JS reimplementation."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--dart', default='C:/Users/alexe/develop/flutter/bin/cache/dart-sdk/bin/dart.exe')
args = parser.parse_args()
baseline = json.loads((ROOT/'docs/release-evidence/telegram-port/P0/baseline.json').read_text(encoding='utf-8'))
SOURCE = ROOT/baseline['privateSnapshot']
OUT = ROOT/'.private/telegram-port/kernel-build'
OUT.mkdir(parents=True, exist_ok=True)

def omit(source, marker):
    start=source.index(marker); brace=source.index(') {',start)+2; depth=1; i=brace+1
    while depth:
        if source[i]=='{': depth+=1
        elif source[i]=='}': depth-=1
        i+=1
    return source[:start]+source[i:]

def read(name):
    raw=(SOURCE/name).read_bytes().replace(b'\r\n',b'\n')
    if hashlib.sha256(raw).hexdigest()!=baseline['files'][name]: raise SystemExit(f'Baseline changed: {name}')
    return raw.decode('utf-8')

override_file=ROOT/'telegram-app/tools/kernel/jump-cooldown-zero-v1.json'
override=json.loads(override_file.read_text(encoding='utf-8'))
world_source=read('lib/features/game/game_world.dart')
if override['file']!='lib/features/game/game_world.dart' or world_source.count(override['before'])!=1:
    raise SystemExit('Jump cooldown override does not match the frozen world')
world_source=world_source.replace(override['before'],override['after'])
reviewed_world_hash=hashlib.sha256(world_source.encode()).hexdigest()
pace_override_file=ROOT/'telegram-app/tools/kernel/enemy-pace-v2.json'
pace_override=json.loads(pace_override_file.read_text(encoding='utf-8'))
for patch in pace_override['patches']:
    if world_source.count(patch['before'])!=1: raise SystemExit('Pace override does not match reviewed world')
    world_source=world_source.replace(patch['before'],patch['after'])
if world_source!=(ROOT/override['file']).read_text(encoding='utf-8'):
    raise SystemExit('Current Android world differs from the frozen baseline plus reviewed jump/pace overrides')
shutil.copyfile(ROOT/'lib/domain/enemy_pace.dart',OUT/'enemy_pace.dart')
world=world_source.replace("import 'package:flutter/material.dart';","import 'geometry.dart';").replace("import '../../domain/gameplay_config.dart';","import 'config.dart';")
(OUT/'world.dart').write_text(omit(world,'  void paint(Canvas canvas)'),encoding='utf-8')
config=read('lib/domain/gameplay_config.dart').replace("import 'package:flutter/material.dart';",'')
config=omit(omit(config,'  Color resolveSurfaceColor('),'Color? parseHexColor(')
(OUT/'config.dart').write_text(config,encoding='utf-8')
# Keep actual mobile tuning and rules; remove only Flutter color helpers.
rules=read('lib/domain/arcade_rules.dart')
(OUT/'rules.dart').write_text(rules.replace("import 'economy_config.dart';","import 'economy.dart';"),encoding='utf-8')
economy=read('lib/domain/economy_config.dart')
(OUT/'economy.dart').write_text(economy,encoding='utf-8')
(OUT/'android_energy.dart').write_text(read('lib/domain/android_energy.dart'),encoding='utf-8')
tuning=read('lib/app/mobile_gameplay_tuning.dart')
tuning=tuning.replace("'../domain/gameplay_config.dart'","'config.dart'").replace("'../domain/arcade_rules.dart'","'rules.dart'").replace("'../features/game/game_world.dart'","'world.dart'")
(OUT/'tuning.dart').write_text(tuning,encoding='utf-8')
(OUT/'random.dart').write_text(read('lib/domain/replay_random.dart'),encoding='utf-8')
(OUT/'geometry.dart').write_text(read('tools/replay/geometry.dart'),encoding='utf-8')
# Compile the actual Android preflight too. Only Flutter geometry conveniences
# are replaced; the checks/tolerances remain the frozen implementation.
guard = read('lib/features/game/game_start_guard.dart').replace("import 'package:flutter/material.dart';", "import 'geometry.dart';").replace("import '../../ui/game_viewport.dart';", '').replace("import 'game_world.dart';", "import 'world.dart';").replace('GameViewport.referenceFieldSide', '380.0')
(OUT/'guard.dart').write_text(guard, encoding='utf-8')
motion = read('lib/ui/energy_reward_motion.dart')
motion = motion[motion.index('double _clamp'):motion.index('class _RewardEvent')]
(OUT/'reward_motion.dart').write_text("import 'dart:math' as math;\nimport 'geometry.dart';\n"+motion, encoding='utf-8')
with (OUT/'geometry.dart').open('a', encoding='utf-8') as f:
    f.write('''
extension GuardOffset on Offset { Rect operator &(Size s) => Rect.fromLTWH(dx,dy,s.width,s.height); }
extension GuardRect on Rect {
 Size get size => Size(width,height);
 Offset get topLeft => Offset(left,top);
 bool get isEmpty => width <= 0 || height <= 0;
 Rect intersect(Rect r) => Rect.fromLTRB(max(left,r.left),max(top,r.top),min(right,r.right),min(bottom,r.bottom));
}
''')
for name in ['main','session']:
    shutil.copyfile(ROOT/f'telegram-app/tools/kernel/{name}.dart',OUT/f'{name}.dart')
target=ROOT/'telegram-app/public/kernel/android-world.js'
target.parent.mkdir(parents=True,exist_ok=True)
compiled=OUT/'android-world.js'
subprocess.run([args.dart,'compile','js','-O2','--no-source-maps','-o',str(compiled),str(OUT/'main.dart')],check=True)
license_file=Path(args.dart).resolve().parents[1]/'LICENSE'
target.write_text('/* Dart SDK runtime license:\n'+license_file.read_text(encoding='utf-8')+'\n*/\n'+compiled.read_text(encoding='utf-8'),encoding='utf-8')
server_target=ROOT/'supabase/functions/_shared/telegram-replay.generated.mjs'
server_target.write_text(target.read_text(encoding='utf-8').replace('untouchKernel','untouchTelegramReplay'),encoding='utf-8')
report={'baselineId':baseline['id'],'generatedSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size,
        'method':'actual Dart GameWorld + MobileGameplayTuning, incremental browser adapter; rendering replaced',
        'adapterSha256':hashlib.sha256((OUT/'session.dart').read_bytes()).hexdigest(),
        'extendedWorldSha256':hashlib.sha256(world_source.encode()).hexdigest(),
        'paceOverrideSha256':hashlib.sha256(pace_override_file.read_bytes()).hexdigest(),
        'paceModelSha256':hashlib.sha256((ROOT/'lib/domain/enemy_pace.dart').read_bytes()).hexdigest(),
        'serverGeneratedSha256':hashlib.sha256(server_target.read_bytes()).hexdigest(),
        'gameplayOverrides':[{'id':override['id'],'file':override_file.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(override_file.read_bytes()).hexdigest(),'worldSha256':reviewed_world_hash}],
        'adapterInputs':{name:hashlib.sha256((ROOT/'telegram-app/tools'/name).read_bytes()).hexdigest() for name in ['build_kernel.py','kernel/main.dart','kernel/session.dart','kernel/jump-cooldown-zero-v1.json']}}
(ROOT/'telegram-app/public/kernel/manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
