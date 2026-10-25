import 'dart:convert';
import 'dart:js_interop';
import 'session.dart';

@JS('globalThis.untouchHelmetReplay')
external set verifier(JSFunction function);

void main() {
  verifier = ((JSString raw) {
    try {
      final input = jsonDecode(raw.toDart) as Map<String, dynamic>;
      final proof = input['proof'];
      if (proof is! Map || proof['version'] != 3 ||
          proof['events'] is! List || (proof['events'] as List).length > 600000 ||
          proof['startPose'] is! List) throw const FormatException('proof');
      final replay = HelmetReplaySession({...input, 'startPose': proof['startPose']});
      replay.start();
      for (final e in proof['events']) {
        if (e is! List || e.isEmpty) throw const FormatException('event');
        if (e[0] == 2) {
          if (e.length != 1) throw const FormatException('jump');
          final before = replay.jumpCount;
          replay.jump();
          if (replay.jumpCount != before + 1) throw const FormatException('jump');
        } else {
          if ((e[0] == 0 && e.length != 2) || (e[0] == 1 && e.length != 3)) {
            throw const FormatException('event');
          }
          replay.event(e);
        }
      }
      if (!replay.dead) throw const FormatException('unfinished');
      final s = replay.snapshot;
      return jsonEncode({'ok':true,'timeMs':s['timeMs'],
        'runDistance':s['runDistance'],'riskCount':s['riskCount']}).toJS;
    } catch (_) {
      return '{"ok":false}'.toJS;
    }
  }).toJS;
}
