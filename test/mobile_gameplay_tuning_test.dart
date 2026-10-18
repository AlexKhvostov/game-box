import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test('small variations scale with admin steps and actual hero size', () {
    for (final size in [24.0, 36.0, 48.0]) {
      final tuned = MobileGameplayTuning.apply(
        GameplayConfig(
          player: PlayerConfig(size: size),
          mobileEnemies: const MobileEnemyPace(
            startSpeedSteps: 50,
            accelerationSteps: 6,
          ),
        ),
      );
      final step = size * 1.2 * 0.1;
      expect(tuned.speedMin / step, closeTo(47.5, 1e-9));
      expect(tuned.speedMax / step, closeTo(52.5, 1e-9));
      expect(tuned.accelMin / step, closeTo(5.52, 1e-9));
      expect(tuned.accelMax / step, closeTo(6.48, 1e-9));
    }
  });

  test('phone pace keeps loaded geometry and other round rules', () {
    const original = GameplayConfig(
      enemies: EnemiesConfig(
        areaMultiplier: 2.5,
        aspects: [1, .5, 2],
        angleMinDeg: 20,
        angleMaxDeg: 70,
        speedMin: 100,
        speedMax: 200,
        accelMin: 10,
        accelMax: 20,
        collideWithEachOther: true,
        spinDegPerSec: 3,
      ),
    );
    final tuned = MobileGameplayTuning.apply(original);
    expect(tuned.speedMin, closeTo(149.9904 * .95, 1e-9));
    expect(tuned.speedMax, closeTo(149.9904 * 1.05, 1e-9));
    expect(tuned.accelMin, closeTo(20.0016 * .92, 1e-9));
    expect(tuned.accelMax, closeTo(20.0016 * 1.08, 1e-9));
    expect(tuned.enemies.areaMultiplier, original.enemyAreaMultiplier);
    expect(tuned.enemies.aspects, same(original.enemies.aspects));
    expect(tuned.angleMinDeg, original.angleMinDeg);
    expect(tuned.angleMaxDeg, original.angleMaxDeg);
    expect(tuned.enemiesCollide, isTrue);
    expect(tuned.enemySpinDegPerSec, 3);
    expect(tuned.player, same(original.player));
    expect(tuned.field, same(original.field));
    final expectedGame = original.game.toJson()..['speedRampSeconds'] = 0.0;
    expect(tuned.game.toJson(), expectedGame);
    expect(original.speedRampSeconds, .5);
    expect(tuned.audio, same(original.audio));
    expect(original.speedMin, 100, reason: 'server snapshot stays immutable');
  });

  test('spawn and geometry stay the same while the speed curve increases', () {
    const original = GameplayConfig();
    final previous = GameWorld(
      config: original,
      field: const Size(380, 380),
      rng: Random(42),
    )..resetLayout();
    final updated = GameWorld(
      config: MobileGameplayTuning.apply(original),
      field: const Size(380, 380),
      rng: Random(42),
    )..resetLayout();
    expect(updated.enemies.length, previous.enemies.length);
    for (var i = 0; i < updated.enemies.length; i++) {
      final old = previous.enemies[i];
      final enemy = updated.enemies[i];
      expect(enemy.pos, old.pos);
      expect(enemy.w, old.w);
      expect(enemy.h, old.h);
      expect(enemy.angleDeg, old.angleDeg);
      expect(
        enemy.initialSpeed,
        inInclusiveRange(149.9904 * .95, 149.9904 * 1.05),
      );
      expect(
        enemy.acceleration,
        inInclusiveRange(20.0016 * .92, 20.0016 * 1.08),
      );
      expect(enemy.vel.distance, closeTo(enemy.initialSpeed, 1e-9));
      for (final seconds in [0.0, 10.0, 20.0]) {
        expect(
          enemy.speedAt(seconds),
          closeTo(enemy.initialSpeed + enemy.acceleration * seconds, 1e-9),
        );
        expect(enemy.speedAt(seconds), greaterThan(old.speedAt(seconds)));
      }
    }
    expect(updated.playerSize, previous.playerSize);
    expect(updated.enemies.map((e) => e.initialSpeed).toSet().length, 4);
    expect(updated.enemies.map((e) => e.acceleration).toSet().length, 4);
  });

  test('start is softer than76 and acceleration is stronger', () {
    const config = GameplayConfig(
      enemies: EnemiesConfig(
        speedMin: 90,
        speedMax: 90,
        accelMin: 12,
        accelMax: 12,
      ),
    );
    final world = GameWorld(
      config: MobileGameplayTuning.apply(config),
      field: const Size(380, 380),
      rng: Random(7),
    )..resetLayout();
    // Build76 started at176.4 and gained13.2 per second.
    for (final enemy in world.enemies) {
      expect(
        enemy.initialSpeed,
        inInclusiveRange(149.9904 * .95, 149.9904 * 1.05),
      );
      expect(enemy.initialSpeed, lessThan(176.4));
      expect(
        enemy.acceleration,
        inInclusiveRange(20.0016 * .92, 20.0016 * 1.08),
      );
      expect(enemy.acceleration, greaterThan(13.2));
    }
    for (var frame = 1; frame <= 120; frame++) {
      world.tickPlay(1 / 60, frame / 60);
    }
    for (final enemy in world.enemies) {
      expect(
        enemy.vel.distance,
        closeTo(enemy.initialSpeed + enemy.acceleration * 2, 1e-9),
      );
    }
  });
}
