import 'dart:convert';
import 'dart:js_interop';
import 'session.dart';
import 'reward_motion.dart';

@JS('globalThis.untouchKernel')
external set kernel(JSFunction function);

void main() {
  BrowserSession? session;
  kernel = ((JSString raw) {
    try {
      final input = jsonDecode(raw.toDart) as Map<String, dynamic>;
      final op = input['op'];
      if(op=='verify') {
        final proof=input['proof'];
        if(proof is! Map || proof['version']!=2 || proof['events'] is! List || (proof['events'] as List).length>600000 || proof['startPose'] is! List) throw FormatException('proof');
        final replay=BrowserSession({...input,'proofVersion':2,'startPose':proof['startPose']});
        replay.start();
        for(final e in proof['events']) {
          if(e is! List || e.isEmpty) throw FormatException('event');
          if(e[0]==2) {
            if(e.length!=1) throw FormatException('jump');
            final count=replay.jumpCount;replay.jump();if(replay.jumpCount!=count+1) throw FormatException('jump');
          } else {
            if((e[0]==0 && e.length!=2)||(e[0]==1 && e.length!=3)) throw FormatException('event');
            replay.event(e);
          }
        }
        if(!replay.dead) throw FormatException('unfinished');
        final s=replay.snapshot;
        return jsonEncode({'ok':true,'timeMs':s['timeMs'],'runDistance':s['runDistance'],'riskCount':s['riskCount']}).toJS;
      }
      if (op == 'rewardFrame') {
        final f = EnergyRewardFrame((input['p'] as num).toDouble(),reduced:input['reduced']==true);
        return jsonEncode({'ok':true,'p':f.p,'appearance':f.appearance,'flight':f.flight,'fly':f.fly,'scale':f.scale,'opacity':f.opacity,'roll':f.roll,'hit':f.hit}).toJS;
      }
      if (op == 'create') {
        session = BrowserSession(input);
      } else {
        if (session == null) throw StateError('session_missing');
        switch (op) {
          case 'idle': session!.idle((input['ms'] as num).toDouble());
          case 'start': session!.start();
          case 'tick': session!.event([0, input['ms']]);
          case 'move': session!.move((input['dx'] as num).toDouble(), (input['dy'] as num).toDouble());
          case 'jump': session!.jump();
          case 'snapshot': break;
          case 'proof': return jsonEncode({'ok': true, 'proof': session!.proof}).toJS;
          case 'guard': return jsonEncode({'ok':true,'issue':session!.guard(input)}).toJS;
          default: throw FormatException('unknown_operation');
        }
      }
      return jsonEncode({'ok': true, ...session!.snapshot}).toJS;
    } catch (_) {
      return '{"ok":false,"error":"invalid_kernel_operation"}'.toJS;
    }
  }).toJS;
}
