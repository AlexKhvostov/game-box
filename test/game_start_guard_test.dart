import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/features/game/game_start_guard.dart';
import 'package:game_box/features/game/game_world.dart';
import 'uniform_pace_helmet_test.dart' as fixture;

class _Scores extends ScoresStore {
  _Scores({this.pending});
  final Completer<bool>? pending;
  int starts = 0;
  @override
  Future<bool> beginRound({
    bool helmet = false,
    bool jump = false,
    String? economyRevision,
  }) async {
    starts++;
    return pending == null ? true : await pending!.future;
  }

  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
}

GameWorld _world({
  Size field = const Size.square(380),
  GameplayConfig config = const GameplayConfig(),
}) => GameWorld(config: config, field: field, rng: Random(4))..resetLayout();

String? _check(
  GameWorld world, {
  Size painted = const Size.square(380),
  Rect display = const Rect.fromLTWH(16, 116, 380, 380),
  Rect screen = const Rect.fromLTWH(0, 0, 412, 900),
  double dpr = 1,
}) => GameStartGuard.check(
  world: world,
  paintedSize: painted,
  displayedField: display,
  visibleScreen: screen,
  devicePixelRatio: dpr,
);

EnemyBody _copy(EnemyBody e, {double? w, double? h, Offset? pos}) =>
    EnemyBody(
        pos: pos ?? e.pos,
        vel: e.vel,
        w: w ?? e.w,
        h: h ?? e.h,
        aspect: e.aspect,
        angleDeg: e.angleDeg,
        quadrantN: e.quadrantN,
        fieldQuadrant: e.fieldQuadrant,
        initialSpeed: e.initialSpeed,
        acceleration: e.acceleration,
      )
      ..homePos = pos ?? e.homePos
      ..homeVel = e.homeVel;

void main() {
  testWidgets('geometry is rechecked after waiting for start confirmation', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final scores = _Scores(pending: pending);
    final economy = await fixture.mount(
      tester,
      const GameplayConfig(),
      scoresStore: scores,
    );
    final lives = economy.lives;
    await fixture.start(tester);
    expect(scores.starts, 1);
    final world = fixture.worldOf(tester);
    world.enemies.clear();
    pending.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(economy.lives, lives);
    expect(tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
    expect(
      find.byKey(const ValueKey('game-start-technical-error')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    scores.dispose();
  });
  test('proportions pass across devices/densities/random layouts', () {
    for (final side in [150.0, 295.0, 332.0, 380.0, 700.0]) {
      for (final dpr in [1.0, 2.625, 3.0]) {
        for (var seed = 0; seed < 50; seed++) {
          final world = GameWorld(
            config: const GameplayConfig(),
            field: const Size.square(380),
            rng: Random(seed),
          )..resetLayout();
          expect(
            _check(
              world,
              display: Rect.fromLTWH(16, 116, side, side),
              screen: Rect.fromLTWH(0, 0, side + 32, side + 160),
              dpr: dpr,
            ),
            isNull,
          );
        }
      }
    }
  });
  test(
    '3 percent corridor blocks distortion; empty/tiny/offscreen enemies block',
    () {
      final world = _world();
      expect(_check(world, painted: const Size(380, 380 * 1.029)), isNull);
      expect(
        _check(world, painted: const Size(380, 380 * 1.031)),
        'field_distorted',
      );
      expect(
        _check(world, display: const Rect.fromLTWH(16, 700, 380, 380)),
        'field_clipped',
      );
      final original = world.enemies[0];
      world.enemies[0] = _copy(
        original,
        w: original.w * .971,
        h: original.h * .971,
      );
      expect(_check(world), isNull);
      world.enemies[0] = _copy(original, w: original.w * .969);
      expect(_check(world), 'enemy_scale');
      world.enemies[0] = _copy(original, w: 1, h: 1);
      expect(_check(world), 'enemy_scale');
      world.enemies[0] = _copy(original, pos: const Offset(-500, 0));
      expect(_check(world), 'enemy_invisible');
      world.enemies.clear();
      expect(_check(world), 'enemy_count');
    },
  );
  test(
    'wrong world/reference scale, tiny hero, nonfinite values fail closed',
    () {
      expect(_check(_world(field: const Size.square(412))), 'world_scale');
      expect(
        _check(
          _world(config: const GameplayConfig(player: PlayerConfig(size: 1))),
        ),
        'hero_scale',
      );
      expect(
        _check(_world(), painted: const Size(double.nan, 380)),
        'field_not_ready',
      );
      final world = _world()..player = const Offset(double.nan, 0);
      expect(_check(world), 'hero_invisible');
      expect(
        _check(_world(), display: const Rect.fromLTWH(0, 0, 20, 20)),
        'hero_invisible',
      );
    },
  );
  for (final fault in ['missing', 'tiny', 'offscreen']) {
    testWidgets(
      '$fault blocks before server, life debit and timer; repair allows retry',
      (tester) async {
        final scores = _Scores();
        final economy = await fixture.mount(
          tester,
          const GameplayConfig(game: GameConfig(idleEnemiesMove: false)),
          scoresStore: scores,
        );
        final lives = economy.lives;
        final world = fixture.worldOf(tester);
        if (fault == 'missing') {
          world.enemies.clear();
        }
        if (fault == 'tiny') {
          world.enemies[0] = _copy(world.enemies[0], w: 1, h: 1);
        }
        if (fault == 'offscreen') {
          world.enemies[0] = _copy(
            world.enemies[0],
            pos: const Offset(-500, -500),
          );
        }
        await fixture.start(tester);
        expect(scores.starts, 0);
        expect(economy.lives, lives);
        expect(tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(), 0);
        expect(
          find.byKey(const ValueKey('game-start-technical-error')),
          findsOneWidget,
        );
        world.resetLayout();
        await fixture.start(tester);
        expect(scores.starts, 1);
        expect(economy.lives, lives - 1);
        expect(
          tester.widget<ArcadeHud>(find.byType(ArcadeHud)).timeMs(),
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        scores.dispose();
      },
    );
  }
}
