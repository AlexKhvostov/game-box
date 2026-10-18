import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test(
    'enlarged player and every enemy preserve shape, area ratio and collision bounds',
    () {
      const config = GameplayConfig(game: GameConfig(wallsKillPlayer: false));
      final world = GameWorld(
        config: config,
        field: const Size(380, 380),
        wallInset: 3,
      )..resetLayout();
      expect(world.playerSize, closeTo(43.2, 1e-9));
      for (final enemy in world.enemies) {
        expect(enemy.w / enemy.h, closeTo(enemy.aspect, 1e-9));
        expect(
          enemy.w * enemy.h / (world.playerSize * world.playerSize),
          closeTo(config.enemyAreaMultiplier, 1e-9),
        );
      }
      world.movePlayerBy(const Offset(10000, 10000));
      expect(world.player.dx, closeTo(333.8, 1e-9));
      expect(world.player.dy, closeTo(333.8, 1e-9));
      world.enemies.clear();
      world.enemies.add(
        EnemyBody(
          pos: const Offset(370, 340),
          vel: Offset.zero,
          w: 10,
          h: 10,
          aspect: 1,
          angleDeg: 0,
          quadrantN: 0,
          fieldQuadrant: 0,
          initialSpeed: 0,
          acceleration: 0,
        ),
      );
      expect(
        world.playerHitsEnemy(),
        true,
        reason: 'enlarged visible edge is also the collision edge',
      );
    },
  );

  test('drowsy enemies stay near home and start from original spawn', () {
    final world = GameWorld(
      config: const GameplayConfig(game: GameConfig(idleEnemiesMove: false)),
      field: const Size(300, 300),
    )..resetLayout();
    for (var i = 0; i < 1200; i++) {
      world.tickIdle(1 / 60);
    }
    world.snapEnemiesToHome();
    for (final enemy in world.enemies) {
      expect(enemy.pos, enemy.homePos);
      expect(enemy.vel.distance, closeTo(enemy.initialSpeed, 1e-9));
    }
    final before = world.enemies.map((e) => e.pos).toList();
    world.tickPlay(1 / 60, 0, speedMult: 0);
    for (var i = 0; i < before.length; i++) {
      expect((world.enemies[i].pos - before[i]).distance, closeTo(0, 1e-9));
    }
  });
  test('jump matches Mini App cooldown and resets between rounds', () {
    final world = GameWorld(
      config: const GameplayConfig(),
      field: const Size(300, 300),
    )..resetLayout();
    expect(world.tryJump(nowMs: 0), isTrue);
    expect(
      world.tryJump(nowMs: 2000),
      isFalse,
      reason: 'cannot jump again in the air',
    );
    world.tickJump(1);
    expect(world.tryJump(nowMs: 1999), isFalse);
    expect(world.tryJump(nowMs: 2000), isTrue);
    world.resetLayout();
    expect(world.tryJump(nowMs: 2001), isTrue);
  });

  test('distance counts only movement inside nonlethal walls', () {
    final world = GameWorld(
      config: const GameplayConfig(game: GameConfig(wallsKillPlayer: false)),
      field: const Size(300, 300),
    )..resetLayout();
    final before = world.player;
    world.movePlayerBy(const Offset(10000, 10000));
    expect(
      world.playerDistance,
      closeTo((world.player - before).distance, 1e-9),
    );
    final distance = world.playerDistance;
    final position = world.player;
    world.movePlayerBy(const Offset(100, 100));
    expect(world.playerDistance, distance);
    world.movePlayerBy(const Offset(double.nan, 0));
    world.movePlayerBy(const Offset(0, double.infinity));
    expect(world.player, position);
    expect(world.playerDistance, distance);
  });

  test('enemies move on idle tick', () {
    final world = GameWorld(
      config: const GameplayConfig(),
      field: const Size(300, 300),
    )..resetLayout();

    expect(world.enemies, isNotEmpty);
    final before = world.enemies.map((e) => e.pos).toList();

    for (var i = 0; i < 30; i++) {
      world.tickIdle(1 / 60);
    }

    var moved = false;
    for (var i = 0; i < world.enemies.length; i++) {
      if (world.enemies[i].pos != before[i]) {
        moved = true;
        break;
      }
    }
    expect(moved, isTrue, reason: 'enemies must move during idle');
  });

  test('enemies move on play tick', () {
    final world = GameWorld(
      config: const GameplayConfig(),
      field: const Size(300, 300),
    )..resetLayout();
    final before = world.enemies.map((e) => e.pos).toList();

    for (var i = 0; i < 30; i++) {
      world.tickPlay(1 / 60, i / 60, speedMult: 1);
    }

    var moved = false;
    for (var i = 0; i < world.enemies.length; i++) {
      if (world.enemies[i].pos != before[i]) {
        moved = true;
        break;
      }
    }
    expect(moved, isTrue);
  });
}
