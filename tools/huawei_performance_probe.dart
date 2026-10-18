// Isolated physical-device profiling: production GameHomeScreen and painter,
// fixture HTTP only. Build with UNTOUCH_UI_PROBE=true and --profile/--release.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';
import 'game_graphics_warm_up_experiment.dart';
import 'package:game_box/ui/game_ui.dart';

class _Vault implements AccountVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

final frames = <List<int>>[];
final ticks = <int>[];
final errors = <String>[];
late GameplayConfig baseConfig;
late EconomyStore economy;
late PlayerPreferences preferences;
late MobileAccount account;
late ScoresStore scores;
late AudiencePolicy audience;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Automated scenarios inject events through GestureBinding. Keep physical
  // touches from silently mixing idle, play and sheet measurements.
  PlatformDispatcher.instance.onPointerDataPacket = (_) {};
  WidgetsBinding.instance.addTimingsCallback((batch) {
    for (final f in batch) {
      frames.add([
        f.timestampInMicroseconds(FramePhase.vsyncStart),
        f.buildDuration.inMicroseconds,
        f.rasterDuration.inMicroseconds,
        f.totalSpan.inMicroseconds,
        f.vsyncOverhead.inMicroseconds,
      ]);
    }
  });
  SchedulerBinding.instance.addPersistentFrameCallback(
    (time) => ticks.add(time.inMicroseconds),
  );
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  final shared = await SharedConfigLoader.load(allowNetwork: false);
  baseConfig = MobileGameplayTuning.apply(shared.gameplay);
  economy = EconomyStore(config: shared.economy);
  await economy.load();
  economy.lives = 999;
  economy.tokens = 64;
  preferences = PlayerPreferences();
  await preferences.load();
  await preferences.setSound(false);
  await preferences.setMusic(false);
  audience = AudiencePolicy();
  await audience.load();
  await audience.select(AgeBand.age21plus);
  account = MobileAccount(
    vault: _Vault(),
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      return http.Response(
        jsonEncode(switch (body['action']) {
          'round_start' => {'ok': true, 'roundId': body['requestId']},
          'round_finish' => {'ok': true, 'scoreId': 'physical-probe-only'},
          _ => {
            'ok': true,
            'profile': {
              'id': 'android:90000000',
              'nickname': 'PhysicalProbe',
              'googleLinked': false,
            },
          },
        }),
        200,
      );
    }),
  );
  await account.load();
  scores = ScoresStore(
    account: account,
    client: MockClient(
      (_) async =>
          http.Response('{"ok":true,"source":"mysql","scores":[]}', 200),
    ),
  );
  await scores.load();
  runApp(const _Probe());
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final nav = GlobalKey<NavigatorState>();
  final gameKey = ValueNotifier<Key>(UniqueKey());
  GameplayConfig config = baseConfig;
  Timer? driver;
  Offset pointer = Offset.zero;
  bool down = false;
  int moves = 0;
  bool sustained = false;
  String label = 'startup';
  final controlSamples = <Map<String, Object>>[];
  Timer? controlObserver;
  Timer? paceObserver;
  final paceSamples = <Map<String, Object?>>[];

  Map<String, Object?> paceState(GameFieldPainter? painter) {
    int? aliveMs;
    bool? helmetActive;
    var debugVisible = false;
    void visit(Element e) {
      if (e.widget.key == const ValueKey('gameplay-debug-panel'))
        debugVisible = true;
      if (e.widget is ArcadeHud) {
        aliveMs = (e.widget as ArcadeHud).timeMs();
        helmetActive = (e.widget as ArcadeHud).helmetActive;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return {
      'gameTimeMs': aliveMs,
      'helmetActive': helmetActive,
      'debugPanelVisible': debugVisible,
      'enemies': painter?.world.enemies
          .map(
            (enemy) => {
              'initialSpeed': enemy.initialSpeed,
              'acceleration': enemy.acceleration,
              'actualSpeed': enemy.vel.distance,
              'vx': enemy.vel.dx,
              'vy': enemy.vel.dy,
              'x': enemy.pos.dx,
              'y': enemy.pos.dy,
            },
          )
          .toList(),
    };
  }

  Map<String, Object> controlState() {
    var warning = false, ready = false;
    void visit(Element e, bool inJump) {
      final w = e.widget;
      inJump = inJump || w.key == const ValueKey('hud-jump-button');
      if (inJump && w is Container && w.decoration is BoxDecoration) {
        final border = (w.decoration! as BoxDecoration).border;
        if (border is Border && border.top.color == GameUi.heart)
          warning = true;
      }
      if (w.key == const ValueKey('jump-ready-status')) ready = true;
      e.visitChildElements((child) => visit(child, inJump));
    }

    context.visitChildElements((child) => visit(child, false));
    return {
      'us': DateTime.now().microsecondsSinceEpoch,
      'warning': warning,
      'ready': ready,
    };
  }

  @override
  void initState() {
    super.initState();
    unawaited(_serve());
  }

  @override
  void dispose() {
    driver?.cancel();
    paceObserver?.cancel();
    controlObserver?.cancel();
    gameKey.dispose();
    super.dispose();
  }

  Element? field() {
    Element? found;
    void visit(Element e) {
      if (e.widget is CustomPaint &&
          (e.widget as CustomPaint).painter is GameFieldPainter) {
        found = e;
        return;
      }
      if (found == null) e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  void stopDrive() {
    driver?.cancel();
    driver = null;
    if (down)
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(pointer: 91, position: pointer),
      );
    down = false;
  }

  void startDrive(bool moving) {
    stopDrive();
    final element = field();
    if (element == null) throw StateError('No game field');
    final box = element.findRenderObject()! as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final scale =
        (box.localToGlobal(Offset(box.size.width, 0)) -
                box.localToGlobal(Offset.zero))
            .distance /
        380;
    pointer = center;
    down = true;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: 91, position: pointer),
    );
    moves = 0;
    if (moving) {
      final watch = Stopwatch()..start();
      driver = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final t = watch.elapsedMicroseconds / 1000000;
        final next =
            center +
            Offset(math.sin(t * 1.7) * 60, math.sin(t * 2.3) * 45) * scale;
        GestureBinding.instance.handlePointerEvent(
          PointerMoveEvent(pointer: 91, position: next, delta: next - pointer),
        );
        pointer = next;
        moves++;
      });
    }
  }

  Future<void> _serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8878);
    await for (final request in server) {
      try {
        final q = request.uri.queryParameters;
        if (request.uri.path == '/service') {
          final info = await developer.Service.getInfo();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'uri': info.serverUri?.toString()}),
          );
          await request.response.close();
          continue;
        }
        switch (request.uri.path) {
          case '/warmup':
            await const GameGraphicsWarmUp().execute();
          case '/observeControls':
            controlObserver?.cancel();
            controlSamples.clear();
            var remaining = 40;
            controlObserver = Timer.periodic(const Duration(milliseconds: 20), (
              timer,
            ) {
              if (!mounted || remaining-- <= 0) {
                timer.cancel();
                return;
              }
              controlSamples.add(controlState());
            });
          case '/reset':
            paceObserver?.cancel();
            paceSamples.clear();
            stopDrive();
            nav.currentState?.popUntil((route) => route.isFirst);
            sustained = q['sustained'] == 'true';
            await preferences.setSound(q['sound'] == 'true');
            await preferences.setMusic(q['music'] == 'true');
            economy.jumpRentalUntil = q['rent'] == 'true'
                ? DateTime.now().add(const Duration(hours: 1))
                : null;
            economy.helmetRentalUntil = q['helmet'] == 'true'
                ? DateTime.now().add(const Duration(hours: 1))
                : null;
            economy.applyConfig(economy.config);
            final gameJson = baseConfig.game.toJson();
            if (sustained) gameJson['startInvulnSec'] = 3600;
            if (q['helmet'] == 'true') gameJson['startInvulnSec'] = 0;
            setState(() {
              config = GameplayConfig(
                enemies: baseConfig.enemies,
                mobileEnemies: baseConfig.mobileEnemies,
                player: baseConfig.player,
                field: baseConfig.field,
                game: GameConfig.fromJson(gameJson),
                audio: baseConfig.audio,
              );
            });
            gameKey.value = UniqueKey();
            await Future<void>.delayed(const Duration(seconds: 2));
          case '/drive':
            startDrive(q['moving'] != 'false');
          case '/observePace':
            paceObserver?.cancel();
            paceSamples.clear();
            paceObserver = Timer.periodic(const Duration(milliseconds: 16), (
              timer,
            ) {
              if (!mounted || paceSamples.length >= 750) {
                timer.cancel();
                return;
              }
              final element = field();
              final painter = element == null
                  ? null
                  : (element.widget as CustomPaint).painter as GameFieldPainter;
              paceSamples.add(paceState(painter));
            });
          case '/toggleDebug':
            Element? timerElement;
            void findTimer(Element element) {
              if (element.widget.key == const ValueKey('hud-debug-toggle'))
                timerElement = element;
              element.visitChildElements(findTimer);
            }
            context.visitChildElements(findTimer);
            final timerBox = timerElement!.findRenderObject()! as RenderBox;
            final position = timerBox.localToGlobal(
              timerBox.size.center(Offset.zero),
            );
            for (var tap = 0; tap < 5; tap++) {
              GestureBinding.instance.handlePointerEvent(
                PointerDownEvent(pointer: 93, position: position),
              );
              GestureBinding.instance.handlePointerEvent(
                PointerUpEvent(pointer: 93, position: position),
              );
              await Future<void>.delayed(const Duration(milliseconds: 70));
            }
          case '/helmetHit':
            final element = field();
            final painter =
                (element!.widget as CustomPaint).painter as GameFieldPainter;
            final world = painter.world;
            final enemy = world.enemies.first;
            enemy.orientDeg = 0;
            enemy.pos = Offset(
              world.player.dx + world.playerSize - 1,
              world.player.dy + world.playerSize / 2 - enemy.h / 2,
            );
            enemy.vel = Offset(-enemy.vel.distance, 0);
          case '/stop':
            stopDrive();
          case '/jump':
            if (!down)
              throw StateError('Start the primary pointer before jumping');
            GestureBinding.instance.handlePointerEvent(
              PointerDownEvent(pointer: 92, position: pointer),
            );
            GestureBinding.instance.handlePointerEvent(
              PointerUpEvent(pointer: 92, position: pointer),
            );
          case '/clear':
            // Profile timing batches arrive after rendering; drain before reset.
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            label = q['label'] ?? 'measurement';
            frames.clear();
            ticks.clear();
            errors.clear();
          case '/window':
            stopDrive();
            if (!mounted) return;
            final c = nav.currentState!.overlay!.context;
            if (!c.mounted) return;
            if (q['name'] == 'profile') unawaited(showProfileSheet(c));
            if (q['name'] == 'share')
              unawaited(
                showShareSocialSheet(c, timeMs: 21349, betterPercent: 83),
              );
            if (q['name'] == 'lives') unawaited(showLivesSheet(c));
            if (q['name'] == 'crystals') unawaited(showCrystalsSheet(c));
            if (q['name'] == 'rent')
              unawaited(showCrystalsSheet(c, initialTab: 2));
            if (q['name'] == 'ranking') unawaited(showLeaderboardSheet(c));
          case '/back':
            nav.currentState?.popUntil((route) => route.isFirst);
        }
        final e = field();
        final painter = e == null
            ? null
            : (e.widget as CustomPaint).painter as GameFieldPainter;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'label': label,
            'sustainedInvulnerabilityFixture': sustained,
            'sound': preferences.sound,
            'moves': moves,
            'idle': painter?.playerPreview,
            'player': painter?.world.player.toString(),
            'enemyCount': painter?.world.enemies.length,
            'jumpRemainingMs': painter?.world.jumpCooldownRemaining(),
            'controls': controlState(),
            'pace': paceState(painter),
            'paceSamples': paceSamples,
            'controlSamples': controlSamples,
            'frames': frames,
            'ticksUs': ticks,
            'errors': errors,
          }),
        );
      } catch (error, stack) {
        request.response.statusCode = 500;
        request.response.write('$error\n$stack');
      }
      await request.response.close();
    }
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: economy),
      ChangeNotifierProvider.value(value: audience),
      ChangeNotifierProvider.value(value: preferences),
      ChangeNotifierProvider.value(value: account),
      ChangeNotifierProvider.value(value: scores),
      Provider.value(value: config),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          // Android can expose a zero-size view before its first metrics event.
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0)
            return const SizedBox.shrink();
          return GameViewport(child: child!);
        },
      ),
      home: ValueListenableBuilder<Key>(
        valueListenable: gameKey,
        builder: (context, key, child) => GameHomeScreen(key: key),
      ),
    ),
  );
}
