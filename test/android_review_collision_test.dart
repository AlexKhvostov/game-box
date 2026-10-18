import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

EnemyBody enemy({double angle = 0, Offset velocity = Offset.zero}) => EnemyBody(
  pos: const Offset(170, 100),
  vel: velocity,
  w: 8,
  h: 100,
  aspect: .08,
  angleDeg: 0,
  quadrantN: 0,
  fieldQuadrant: 0,
  initialSpeed: velocity.distance,
  acceleration: 0,
  orientDeg: angle,
);

GameWorld world() =>
    GameWorld(
        config: const GameplayConfig(game: GameConfig(wallsKillPlayer: false)),
        field: const Size(380, 380),
      )
      ..resetLayout()
      ..enemies.clear()
      ..player = const Offset(50, 120);

void main() {
  test('fast drag stops at thin enemy and counts only distance travelled', () {
    final w = world()..enemies.add(enemy());
    w.movePlayerBy(const Offset(250, 0));
    expect(w.playerHitsEnemy(), isTrue);
    expect(w.player.dx, closeTo(170 - w.playerSize, .001));
    expect(w.playerDistance, closeTo(w.player.dx - 50, .001));
    expect(w.nearMissCount, 0);
  });

  test('rotated sweep agrees with dense independent overlap sampling', () {
    final random = Random(42);
    for (var run = 0; run < 40; run++) {
      final w = world()..enemies.add(enemy(angle: random.nextDouble() * 180));
      final start = Offset(25, random.nextDouble() * 250);
      final delta = Offset(300, random.nextDouble() * 80 - 40);
      var sampled = false;
      for (var step = 0; step <= 2000; step++) {
        final p = start + delta * (step / 2000);
        if (w.enemies.single.overlapsAabb(
          Rect.fromLTWH(p.dx, p.dy, w.playerSize, w.playerSize),
        )) {
          sampled = true;
          break;
        }
      }
      expect(
        w.enemies.single.sweptAabb(
              Rect.fromLTWH(start.dx, start.dy, w.playerSize, w.playerSize),
              delta,
            ) !=
            null,
        sampled,
      );
    }
  });

  test('jump crosses enemy and grants one risk per enemy per jump', () {
    final w = world()..enemies.add(enemy());
    expect(w.tryJump(nowMs: 0), isTrue);
    w.movePlayerBy(const Offset(250, 0));
    expect(w.player.dx, 300);
    expect(w.playerHitsEnemy(), isFalse);
    expect(w.nearMissCount, 1);
    w.movePlayerBy(const Offset(-250, 0));
    expect(w.nearMissCount, 1);
  });

  test('helmet can reflect at swept contact; invulnerability can cross', () {
    final w = world()..enemies.add(enemy(velocity: const Offset(-200, 0)));
    w.movePlayerBy(const Offset(250, 0));
    expect(w.repelEnemiesFromPlayer(), 1);
    expect(w.enemies.single.vel.dx, greaterThan(0));
    expect(w.playerHitsEnemy(), isFalse);
    w.movePlayerBy(const Offset(200, 0), checkEnemies: false);
    expect(w.player.dx, greaterThan(300));
  });

  test('fast enemy cannot cross stationary hero in one frame', () {
    final w = world()..player = const Offset(100, 120);
    w.enemies.add(enemy(velocity: const Offset(-4000, 0)));
    w.tickPlay(.05, 0);
    expect(w.playerHitsEnemy(), isTrue);
    expect(w.enemies.single.pos.dx, greaterThan(100));
  });

  test('parallel near pass and movement away are not collisions', () {
    final e = enemy();
    expect(
      e.sweptAabb(const Rect.fromLTWH(50, 50, 40, 40), const Offset(250, 0)),
      isNull,
    );
    expect(
      e.sweptAabb(const Rect.fromLTWH(130, 120, 40, 40), const Offset(-100, 0)),
      isNull,
    );
  });
}
