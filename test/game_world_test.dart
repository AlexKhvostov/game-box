import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
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
