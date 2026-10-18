import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:game_box/app/app.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'helmet is one charge and respects configured protection duration',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      economy.helmetRentalUntil = DateTime.now().add(const Duration(hours: 1));
      final scores = ScoresStore();
      await scores.load();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider.value(value: scores),
            Provider.value(
              value: const GameplayConfig(
                game: GameConfig(startInvulnSec: 0, helmetInvulnSec: 6),
                enemies: EnemiesConfig(
                  speedMin: 0,
                  speedMax: 0,
                  accelMin: 0,
                  accelMax: 0,
                ),
              ),
            ),
          ],
          child: const GameBoxApp(forceLocale: 'en'),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GameHomeScreen)));
      await tester.pump();
      GameFieldPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<GameFieldPainter>()
          .first;
      final world = painter().world;
      expect(painter().hasHelmet, isTrue);
      world.enemies.first.setCenter(
        world.player + Offset(world.playerSize / 2, world.playerSize / 2),
      );
      for (var i = 0; i < 110; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(painter().hasHelmet, isFalse);
      expect(painter().invulnerable, isTrue);
      expect(find.byType(ResultOverlay), findsNothing);
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ResultOverlay), findsOneWidget);
      expect(scores.myAttempts, hasLength(1));
      expect(scores.myAttempts.first.hadHelmet, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('background time does not count toward the active attempt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final scores = ScoresStore();
    await scores.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(
            value: const GameplayConfig(
              game: GameConfig(startInvulnSec: 30),
              enemies: EnemiesConfig(
                speedMin: 0,
                speedMax: 0,
                accelMin: 0,
                accelMax: 0,
              ),
            ),
          ),
        ],
        child: const GameBoxApp(forceLocale: 'en'),
      ),
    );
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(GameHomeScreen)));
    await tester.pump();
    String timer() => tester
        .widget<Text>(find.byKey(const ValueKey('arcade-top-timer')))
        .data!;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final before = timer();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(timer(), before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(timer(), before);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(timer().startsWith('00:01.'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('round credits before flights and closing does not pay again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final scores = ScoresStore();
    await scores.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(
            value: const GameplayConfig(
              game: GameConfig(startInvulnSec: 0),
              enemies: EnemiesConfig(
                speedMin: 0,
                speedMax: 0,
                accelMin: 0,
                accelMax: 0,
              ),
            ),
          ),
        ],
        child: const GameBoxApp(forceLocale: 'en'),
      ),
    );
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(GameHomeScreen)));
    await tester.pump();
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<GameFieldPainter>()
        .first;
    final world = painter.world;
    world.playerDistance = world.playerSize * 0.1 * 400;
    world.nearMissCount = 10;
    world.enemies.first.setCenter(
      world.player + Offset(world.playerSize / 2, world.playerSize / 2),
    );
    final before = economy.tokens;
    // Small frames are required: the game's 50ms frame cap is intentional.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ResultOverlay), findsOneWidget);
    expect(economy.tokens, before + 4);
    expect(scores.myAttempts.first.runDistance, 400);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tokens'), before + 4);
    await tester.pump(const Duration(seconds: 1));
    expect(economy.tokens, before + 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(economy.tokens, before + 4);
  });

  for (final fps in [1, 4, 10, 60, 90, 120, 144]) {
    testWidgets('arcade timer preserves elapsed time at $fps FPS', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore();
      await economy.load();
      final scores = ScoresStore();
      await scores.load();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider.value(value: scores),
            Provider.value(
              value: const GameplayConfig(
                enemies: EnemiesConfig(
                  speedMin: 0,
                  speedMax: 0,
                  accelMin: 0,
                  accelMax: 0,
                ),
                game: GameConfig(startInvulnSec: 10),
              ),
            ),
          ],
          child: const GameBoxApp(forceLocale: 'en'),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GameHomeScreen)));
      await tester.pump();
      final frame = Duration(microseconds: (1000000 / fps).round());
      for (var i = 0; i < fps; i++) {
        await tester.pump(frame);
      }
      if (fps == 1) {
        for (var catchUp = 0; catchUp < 4; catchUp++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
      final timer = tester.widget<Text>(
        find.byKey(const ValueKey('arcade-top-timer')),
      );
      final parts = timer.data!.split(RegExp(r'[:.]'));
      final millis =
          int.parse(parts[0]) * 60000 +
          int.parse(parts[1]) * 1000 +
          int.parse(parts[2]);
      // HUD refresh is throttled; game time must not lose ~14% at 144 Hz.
      expect(millis, inInclusiveRange(900, 1010));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('Hypercasual home shows field hint', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final scores = ScoresStore();
    await scores.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: scores),
          Provider.value(value: const GameplayConfig()),
        ],
        child: const GameBoxApp(forceLocale: 'en'),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GameHomeScreen), findsOneWidget);
    expect(find.text('Tap and dodge'), findsOneWidget);
    expect(find.text('Выберите режим'), findsNothing);
    expect(find.text('Игра'), findsNothing);
    expect(find.text('Баланс'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
