import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test('gaze follows the nearest enemy as it moves and changes targets', () {
    final world = GameWorld(
      config: GameplayConfig(),
      field: const Size(380, 380),
    );
    world.player = Offset(
      190 - world.playerSize / 2,
      190 - world.playerSize / 2,
    );
    EnemyBody enemy(Offset center) => EnemyBody(
      pos: center - const Offset(10, 10),
      vel: Offset.zero,
      w: 20,
      h: 20,
      aspect: 1,
      angleDeg: 0,
      quadrantN: 0,
      fieldQuadrant: 0,
      initialSpeed: 0,
      acceleration: 0,
    );
    world.enemies.clear();
    final right = enemy(const Offset(220, 190));
    final left = enemy(const Offset(90, 190));
    world.enemies.addAll([right, left]);
    expect(nearestEnemyLook(world), const Offset(1, 0));
    right.pos = const Offset(180, 150);
    expect(nearestEnemyLook(world), const Offset(0, -1));
    right.pos = const Offset(350, 180);
    expect(nearestEnemyLook(world), const Offset(-1, 0));
    world.enemies.clear();
    expect(nearestEnemyLook(world), Offset.zero);
  });
  test('surprise uses risk entry gap rather than enemy center distance', () {
    final world = GameWorld(
      config: GameplayConfig(),
      field: const Size(380, 380),
    );
    world.player = const Offset(100, 100);
    final enemy = EnemyBody(
      pos: Offset(100 + world.playerSize + 14, 100),
      vel: Offset.zero,
      w: 100,
      h: 20,
      aspect: 5,
      angleDeg: 0,
      quadrantN: 0,
      fieldQuadrant: 0,
      initialSpeed: 0,
      acceleration: 0,
    );
    world.enemies.clear();
    world.enemies.add(enemy);
    expect(
      world.enemyAtRiskDistance,
      isTrue,
    ); // Edge gap is exactly the risk threshold.
    enemy.pos = Offset(100 + world.playerSize + 14.01, 100);
    expect(world.enemyAtRiskDistance, isFalse);
    enemy.pos = Offset(100 + world.playerSize, 100);
    expect(world.enemyAtRiskDistance, isTrue);
    world.enemies.clear();
    expect(world.enemyAtRiskDistance, isFalse);
  });
}
