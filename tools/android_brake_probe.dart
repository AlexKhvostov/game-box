// Isolated physical-device acceptance. No production account/API or real payments.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';

late Map<String, dynamic> raw;
late EconomyStore economy;
late ScoresStore scores;
late PlayerPreferences preferences;
final probeKey = GlobalKey<_BrakeProbeState>();
final failures = <String>[];
final timings = <Map<String, int>>[];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('ANDROID_BRAKE_PROBE'))
    throw StateError('isolated_probe_only');
  FlutterError.onError = (details) {
    failures.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  raw =
      jsonDecode(
            await rootBundle.loadString('assets/config/android-firebase.json'),
          )
          as Map<String, dynamic>;
  if (const bool.fromEnvironment('ANDROID_BRAKE_AUTOMATION')) {
    raw['config']['game']['startInvulnSec'] = 30.0;
  }
  final shared = SharedConfigs.fromSnapshot(raw, 'isolated-brake-probe');
  economy = EconomyStore(config: shared.economy);
  await economy.load();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  await economy.applyServerWallet(
    {
      'energyVersion': 2,
      'energy': 50,
      'energyConfig': shared.economy.androidEnergyV2.toJson(),
      'simpleBonus': {
        'contract': 3,
        'nextAt': stamp + 28800000,
        'durationMs': 28800000,
        'reward': 30,
        'tier': 1,
        'policy': {'periodSec': 28800, 'tier2Reward': 60, 'tier5Reward': 150},
      },
      'bestTimeMs': 0,
    },
    owner: 'android-brake-isolated-probe',
    serverNow: stamp,
  );
  preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  scores = ScoresStore();
  await scores.loadLocal();
  SchedulerBinding.instance.addTimingsCallback((frames) {
    for (final f in frames) {
      if (timings.length < 2000)
        timings.add({
          'buildUs': f.buildDuration.inMicroseconds,
          'rasterUs': f.rasterDuration.inMicroseconds,
          'totalUs': f.totalSpan.inMicroseconds,
        });
    }
  });
  runApp(_BrakeProbe(key: probeKey));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8879);
  await for (final req in server) {
    try {
      if (req.uri.path == '/case') {
        probeKey.currentState!.choose(
          req.uri.queryParameters['brake'] != '0',
          req.uri.queryParameters['meter'] != '0',
        );
        timings.clear();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(probeState()));
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': e.toString()}));
    }
    await req.response.close();
  }
}

Map<String, dynamic> probeState() {
  GameFieldPainter? field;
  Rect? rect;
  var meter = false;
  void visit(Element e) {
    final w = e.widget;
    if (w is CustomPaint && w.painter is GameFieldPainter) {
      field = w.painter as GameFieldPainter;
      final box = e.renderObject;
      if (box is RenderBox && box.hasSize)
        rect = box.localToGlobal(Offset.zero) & box.size;
    }
    if (w.key == const ValueKey('enemy-speed-meter')) meter = true;
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final f = field;
  return {
    'isolated': true,
    'errors': failures,
    'playing': f?.roundPlaying?.call() ?? false,
    'brake': f?.enemyPace?.snapshot,
    'meterPresent': meter,
    'field': rect == null
        ? null
        : {
            'x': rect!.left,
            'y': rect!.top,
            'w': rect!.width,
            'h': rect!.height,
          },
    'dpr':
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
    'player': f == null
        ? null
        : {
            'x': f.world.player.dx,
            'y': f.world.player.dy,
            'size': f.world.playerSize,
          },
    'frames': timings,
  };
}

class _BrakeProbe extends StatefulWidget {
  const _BrakeProbe({super.key});
  @override
  State<_BrakeProbe> createState() => _BrakeProbeState();
}

class _BrakeProbeState extends State<_BrakeProbe> {
  var brake = true, meter = true, generation = 0;
  void choose(bool b, bool m) {
    setState(() {
      brake = b;
      meter = m;
      generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    copy['config']['enemyPace'] = {
      'brakeEnabled': brake,
      'speedBarEnabled': meter,
    };
    final config = MobileGameplayTuning.apply(
      SharedConfigs.fromSnapshot(copy, 'isolated-brake-probe').gameplay,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: preferences),
        Provider<GameplayConfig>.value(value: config),
      ],
      child: GameBoxApp(key: ValueKey(generation), forceLocale: 'ru'),
    );
  }
}
