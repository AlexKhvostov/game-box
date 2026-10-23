"""Compile the actual reviewed Dart physics for the server; no handwritten JS port.

Only rendering and Flutter geometry are replaced. A source hash manifest makes
stale generated verifier builds detectable. Output is a self-contained ESM file.
"""
import argparse,hashlib,json,os,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--dart',default='C:/Users/alexe/develop/flutter/bin/cache/dart-sdk/bin/dart.exe');args=p.parse_args()
out=root/'.private/android-replay-build';out.mkdir(parents=True,exist_ok=True)
def omit_method(source,marker):
    start=source.index(marker);brace=source.index(') {',start)+2;depth=1;i=brace+1
    while depth:
        if source[i]=='{':depth+=1
        elif source[i]=='}':depth-=1
        i+=1
    return source[:start]+source[i:]
world=(root/'lib/features/game/game_world.dart').read_text(encoding='utf-8')
world=world.replace("import 'package:flutter/material.dart';","import 'geometry.dart';").replace("import '../../domain/gameplay_config.dart';","import 'config.dart';")
world=omit_method(world,'  void paint(Canvas canvas)')
(out/'world.dart').write_text(world,encoding='utf-8')
config=(root/'lib/domain/gameplay_config.dart').read_text(encoding='utf-8').replace("import 'package:flutter/material.dart';",'')
config=omit_method(config,'  Color resolveSurfaceColor(')
config=omit_method(config,'Color? parseHexColor(')
(out/'config.dart').write_text(config,encoding='utf-8')
shutil.copyfile(root/'lib/domain/enemy_pace.dart',out/'enemy_pace.dart')
for name in ['geometry','session','main']:
    shutil.copyfile(root/f'tools/replay/{name}.dart',out/f'{name}.dart')
shutil.copyfile(root/'lib/domain/replay_random.dart',out/'random.dart')
target=root/'supabase/functions/_shared/android-replay.generated.mjs'
subprocess.run([args.dart,'compile','js','-O2','--no-source-maps','-o',str(target),str(out/'main.dart')],check=True)
license_file=Path(args.dart).resolve().parents[1]/'LICENSE'
target.write_text('/* Dart SDK runtime license:\n'+license_file.read_text(encoding='utf-8')+'\n*/\n'+target.read_text(encoding='utf-8'),encoding='utf-8')
# Dart VM and JS Random intentionally differ; the explicit PRNG is shared.
files=['lib/domain/enemy_pace.dart','lib/features/game/game_world.dart','lib/domain/gameplay_config.dart','lib/domain/replay_random.dart','lib/app/mobile_gameplay_tuning.dart','lib/domain/arcade_rules.dart',*[f'tools/replay/{n}.dart'for n in ['geometry','session','main']]]
def source_hash(file):
    # Git may check text out as CRLF on Windows; code identity ignores EOLs.
    return hashlib.sha256(file.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
manifest={name:source_hash(root/name)for name in files}
manifest['generatedSha256']=source_hash(target)
(target.with_suffix('.json')).write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
