import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';

GameWorld worldOf(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('arcade-game-field')),
                )
                .painter!
            as GameFieldPainter)
        .world;
AbilityRingPainter ring(WidgetTester tester, String ability) =>
    tester
            .widget<CustomPaint>(find.byKey(ValueKey('$ability-ability-ring')))
            .foregroundPainter!
        as AbilityRingPainter;

Future<EconomyStore> mount(
  WidgetTester tester,
  GameplayConfig config, {
  bool rentals = false,
  ScoresStore? scoresStore,
}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final economy = EconomyStore();
  await economy.load();
  if (rentals) {
    economy.jumpRentalUntil = DateTime.now().add(const Duration(hours: 1));
    economy.helmetRentalUntil = DateTime.now().add(const Duration(hours: 1));
  }
  final scores = scoresStore ?? ScoresStore();
  await scores.loadLocal();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: scores),
        Provider.value(value: config),
      ],
      child: const GameBoxApp(forceLocale: 'en'),
    ),
  );
  await tester.pump();
  return economy;
}

Future<void> start(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('arcade-game-field')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('jump cooldown progresses and blocked attempt flashes twice', (
    tester,
  ) async {
    await mount(
      tester,
      const GameplayConfig(
        game: GameConfig(startInvulnSec: 60),
        audio: AudioConfig(
          sfxMobWall: false,
          sfxMobCollide: false,
          sfxHeroMob: false,
          sfxHeroWall: false,
          sfxNearMiss: false,
          sfxHelmet: false,
          sfxJump: false,
          sfxStart: false,
          music: false,
        ),
      ),
      rentals: true,
    );
    await start(tester);
    final point = tester.getCenter(
      find.byKey(const ValueKey('arcade-game-field')),
    );
    final primary = await tester.startGesture(point, pointer: 1);
    final jump = await tester.startGesture(
      point + const Offset(8, 0),
      pointer: 2,
    );
    await tester.pump();
    await jump.up();
    expect(ring(tester, 'jump').value, lessThan(.5));
    final firstProgress = ring(tester, 'jump').value;
    await tester.pump(const Duration(milliseconds: 200));
    expect(ring(tester, 'jump').value, greaterThan(firstProgress));
    final blocked = await tester.startGesture(
      point + const Offset(8, 0),
      pointer: 3,
    );
    await tester.pump();
    bool lit() => tester.widget<ArcadeHud>(find.byType(ArcadeHud)).jumpWarnLit;
    expect(lit(), isTrue);
    for (final expected in [false, true, false, false]) {
      await tester.pump(const Duration(milliseconds: 110));
      expect(lit(), expected);
    }
    await blocked.up();
    await primary.up();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'actual screen gains speed uniformly from first tick through10s',
    (tester) async {
      final config = MobileGameplayTuning.apply(
        const GameplayConfig(
          game: GameConfig(idleEnemiesMove: false, startInvulnSec: 60),
        ),
      );
      await mount(tester, config);
      await start(tester);
      final world = worldOf(tester);
      final prior = <EnemyBody, double>{};
      var priorTime = 0.0;
      for (var frame = 0; frame < 625; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final t =
            tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs() / 1000;
        expect(t, greaterThan(priorTime));
        for (final enemy in world.enemies) {
          expect(
            enemy.vel.distance,
            closeTo(enemy.initialSpeed + enemy.acceleration * t, .0001),
          );
          if (prior.containsKey(enemy)) {
            expect(
              (enemy.vel.distance - prior[enemy]!) / (t - priorTime),
              closeTo(enemy.acceleration, .0001),
            );
          }
          prior[enemy] = enemy.vel.distance;
        }
        priorTime = t;
      }
      expect(priorTime, greaterThanOrEqualTo(10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ability rings are gray when off; helmet is full while jump recharges',
    (tester) async {
      final economy = await mount(tester, const GameplayConfig());
      expect(ring(tester, 'jump').active, isFalse);
      expect(ring(tester, 'helmet').active, isFalse);
      economy.jumpRentalUntil = DateTime.now().add(const Duration(hours: 1));
      economy.helmetRentalUntil = DateTime.now().add(const Duration(hours: 1));
      economy.applyConfig(economy.config);
      await tester.pump();
      expect(ring(tester, 'jump').active, isTrue);
      expect(ring(tester, 'helmet').active, isTrue);
      expect(ring(tester, 'helmet').value, 1);
      worldOf(tester).tryJump(nowMs: 0);
      // Actual clock still begins close to zero; the ring reads the world's cooldown.
      await tester.pump(const Duration(milliseconds: 16));
      expect(ring(tester, 'jump').value, lessThan(.5));
      expect(ring(tester, 'helmet').value, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'helmet hit reflects enemy, spends only current helmet, second hit kills',
    (tester) async {
      await mount(
        tester,
        const GameplayConfig(
          game: GameConfig(
            startInvulnSec: 0,
            speedRampSeconds: 0,
            helmetInvulnSec: .1,
          ),
        ),
        rentals: true,
      );
      await start(tester);
      final world = worldOf(tester);
      world.enemies.clear();
      final enemy = EnemyBody(
        pos: world.player + Offset(world.playerSize - 2, 10),
        vel: const Offset(-100, 0),
        w: 20,
        h: 20,
        aspect: 1,
        angleDeg: 0,
        quadrantN: 0,
        fieldQuadrant: 0,
        initialSpeed: 100,
        acceleration: 0,
      );
      world.enemies.add(enemy);
      await tester.pump(const Duration(milliseconds: 16));
      expect(enemy.vel.dx, greaterThan(0));
      expect(enemy.vel.distance, closeTo(100, .00001));
      expect(world.playerHitsEnemy(), isFalse);
      expect(ring(tester, 'helmet').active, isTrue);
      expect(ring(tester, 'helmet').broken, isTrue);
      expect(find.text('Broken'), findsOneWidget);
      expect(ring(tester, 'jump').active, isTrue);
      final alive = tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
        greaterThan(alive),
      );
      enemy.pos = world.player + Offset(world.playerSize - 2, 10);
      enemy.vel = const Offset(-100, 0);
      await tester.pump(const Duration(milliseconds: 16));
      final ended = tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), ended);
      expect(enemy.vel.dx, lessThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('helmet separates rotated enemies and preserves reflection speed', () {
    for (final angle in [0.0, 35.0, 90.0]) {
      final world = GameWorld(
        config: const GameplayConfig(),
        field: const Size(380, 380),
        rng: Random(4),
      )..resetLayout();
      world.player = const Offset(100, 100);
      world.enemies.clear();
      final enemy = EnemyBody(
        pos: const Offset(130, 110),
        vel: const Offset(-100, 12),
        w: 25,
        h: 40,
        aspect: 1,
        angleDeg: 0,
        orientDeg: angle,
        quadrantN: 0,
        fieldQuadrant: 0,
        initialSpeed: 100,
        acceleration: 0,
      );
      world.enemies.add(enemy);
      final before = enemy.vel.distance;
      expect(world.playerHitsEnemy(), isTrue);
      expect(world.repelEnemiesFromPlayer(), 1);
      expect(world.playerHitsEnemy(), isFalse);
      expect(enemy.vel.distance, closeTo(before, .00001));
      expect(world.repelEnemiesFromPlayer(), 0);
    }
  });
}
