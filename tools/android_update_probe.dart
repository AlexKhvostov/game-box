// Isolated physical acceptance entry. Synthetic wallet/Play updates; no live API.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/android_updates.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/ui/android_update_host.dart';

class ProbeUpdates implements PlayUpdateSource {
  final stream = StreamController<PlayUpdateInfo>.broadcast(sync: true);
  PlayUpdateInfo current = const PlayUpdateInfo(supported: false);
  int starts = 0, completions = 0;
  @override
  Stream<PlayUpdateInfo> get events => stream.stream;
  void state(String value) {
    if (value == 'success') {
      updates.successNotice = true;
      current = const PlayUpdateInfo(supported: false);
      stream.add(current);
      return;
    }
    current = PlayUpdateInfo(
      installedVersion: 197,
      availableVersion: 198,
      available: true,
      flexibleAllowed: true,
      installStatus: switch (value) {
        'download' => 2,
        'ready' => 11,
        'error' => 5,
        _ => 0,
      },
      downloadedBytes: 8400000,
      totalBytes: 20000000,
    );
    stream.add(current);
  }

  @override
  Future<PlayUpdateInfo> check() async => current;
  @override
  Future<PlayUpdateInfo> startFlexible() async {
    starts++;
    state('download');
    return current;
  }

  @override
  Future<void> complete() async {
    completions++;
    throw StateError('QA never restarts or installs');
  }
}

final errors = <String>[];
final capture = GlobalKey();
late ProbeUpdates source;
late AndroidUpdates updates;
late ScoresStore scores;
late EconomyStore economy;
T? firstWidget<T extends Widget>() {
  T? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget is T) {
      found = element.widget as T;
      return;
    }
    element.visitChildren(visit);
  }

  capture.currentContext?.visitChildElements(visit);
  return found;
}

GameWorld? world() {
  GameWorld? found;
  void visit(Element element) {
    final w = element.widget;
    if (w is CustomPaint && w.painter is GameFieldPainter) {
      found = (w.painter! as GameFieldPainter).world;
    }
    element.visitChildren(visit);
  }

  capture.currentContext?.visitChildElements(visit);
  return found;
}

Map<String, Object?> snapshot() => {
  'phase': updates.phase.name,
  'prompt': updates.prompt?.name,
  'dialog': firstWidget<AndroidUpdateDialog>()?.prompt.name,
  'banner': firstWidget<AndroidUpdateBanner>() != null,
  'progress': firstWidget<LinearProgressIndicator>()?.value,
  'playing': firstWidget<ArcadeHud>()?.isPlaying,
  'timeMs': firstWidget<ArcadeHud>()?.timeMs(),
  'result': firstWidget<ResultOverlay>() != null,
  'attempt': scores.latestAttempt?.timeMs,
  'starts': source.starts,
  'completions': source.completions,
  'errors': errors,
};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    errors.add(d.exceptionAsString());
    FlutterError.presentError(d);
  };
  // Device QA deliberately uses in-memory storage, never the main game's data.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'device_music': false,
    'device_sound': false,
    'google_startup_seen_v1': true,
    'age_startup_seen_v1': true,
  });
  economy = EconomyStore();
  await economy.load();
  final prefs = PlayerPreferences();
  await prefs.load();
  scores = ScoresStore(
    client: MockClient((_) async => http.Response('{}', 503)),
  );
  await scores.loadLocal();
  source = ProbeUpdates();
  updates = AndroidUpdates(
    source: source,
    preferences: await SharedPreferences.getInstance(),
    prepareForRestart: () async {
      await scores.prepareForAppRestart();
      await economy.prepareForAppRestart();
    },
  );
  await updates.start();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: updates),
        Provider.value(
          value: const GameplayConfig(
            game: GameConfig(idleEnemiesMove: false, startInvulnSec: 0),
          ),
        ),
      ],
      child: RepaintBoundary(
        key: capture,
        child: const GameBoxApp(forceLocale: 'ru'),
      ),
    ),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8897);
  await for (final request in server) {
    try {
      switch (request.uri.path) {
        case '/state':
          source.state(request.uri.queryParameters['value'] ?? 'offer');
        case '/finish':
          world()?.player = const Offset(-1000, -1000);
        case '/result-close':
          firstWidget<ResultOverlay>()?.onOk();
        case '/native':
          final info = await const NativePlayUpdateSource().check();
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'supported': info.supported}));
          await request.response.close();
          continue;
      }
      await WidgetsBinding.instance.endOfFrame;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(snapshot()));
    } catch (error) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': '$error'}));
    }
    await request.response.close();
  }
}
