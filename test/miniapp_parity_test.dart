import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  final snapshot = SharedConfigs.fromSnapshot(
    jsonDecode(
      File('assets/config/published-gameplay.json').readAsStringSync(),
    ),
    'bundled',
  );
  final fixture =
      jsonDecode(File('test/fixtures/miniapp-rules.json').readAsStringSync())
          as Map;
  test('fixture uses the bundled rules revision', () {
    expect(fixture['revision'], snapshot.revision);
  });
  for (final c in fixture['cases'] as List) {
    test('Mini App: ${c['name']}', () {
      // This recorded Telegram fixture uses the original character geometry.
      // Keep its coordinate basis while testing the shared simulation rules;
      // Android's enlarged geometry is covered by viewport/world tests.
      final reference = snapshot.gameplay;
      final config = GameplayConfig(
        enemies: reference.enemies,
        player: PlayerConfig(
          size: reference.playerSize / GameWorld.characterSizeScale,
        ),
        field: reference.field,
        game: reference.game,
        audio: reference.audio,
      );
      final world = GameWorld(
        config: config,
        field: const Size(300, 300),
        wallInset: ArcadeRules.wallInset(config.borderWidth),
      );
      final p = c['player'] as List;
      world.player = Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
      for (final e in c['enemies'] as List) {
        double n(String key) => (e[key] as num).toDouble();
        Offset v(String key) => Offset(
          (e[key]['dx'] as num).toDouble(),
          (e[key]['dy'] as num).toDouble(),
        );
        world.enemies.add(
          EnemyBody(
            pos: v('pos'),
            vel: v('vel'),
            w: n('w'),
            h: n('h'),
            aspect: n('aspect'),
            angleDeg: n('angleDeg'),
            quadrantN: e['quadrantN'],
            fieldQuadrant: e['fieldQuadrant'],
            initialSpeed: n('initialSpeed'),
            acceleration: n('acceleration'),
            orientDeg: n('orientDeg'),
            spinDegPerSec: n('spinDegPerSec'),
          ),
        );
      }
      for (var i = 0; i < (c['actions'] as List).length; i++) {
        final a = c['actions'][i] as List;
        double n(int index) => (a[index] as num).toDouble();
        bool? result;
        switch (a[0]) {
          case 'move':
            world.movePlayerBy(Offset(n(1), n(2)));
          case 'jump':
            result = world.tryJump(nowMs: n(1));
          case 'jumpTick':
            world.tickJump(n(1));
          case 'play':
            world.tickPlay(n(1), n(2), speedMult: n(3));
        }
        final e = c['expected'][i];
        void near(num actual, num expected) =>
            expect(actual, closeTo(expected, 1e-9), reason: 'action $i: $a');
        near(world.player.dx, e['player'][0]);
        near(world.player.dy, e['player'][1]);
        near(world.playerDistance, e['distance']);
        expect(world.nearMissCount, e['risks']);
        expect(world.isJumping, e['jumping']);
        expect(world.playerHitsEnemy(), e['hit']);
        expect(result, e['result']);
        for (var j = 0; j < world.enemies.length; j++) {
          final body = world.enemies[j];
          final actual = [
            body.pos.dx,
            body.pos.dy,
            body.vel.dx,
            body.vel.dy,
            body.orientDeg,
          ];
          for (var k = 0; k < actual.length; k++) {
            near(actual[k], e['enemies'][j][k]);
          }
        }
      }
    });
  }
  test('steps and additional score match actual Mini App utility', () {
    for (final e in fixture['scores'] as List) {
      final steps = ArcadeRules.runSteps(
        (e['px'] as num).toDouble(),
        (e['size'] as num).toDouble(),
      );
      expect(steps, e['steps']);
      expect(ArcadeRules.score(e['ms'], steps, e['risk']), e['score']);
    }
  });
  test('round rewards at threshold and without old arbitrary caps', () {
    const config = EconomyConfig();
    expect(ArcadeRules.roundReward(config, 199, 4), 0);
    expect(ArcadeRules.roundReward(config, 200, 5), 2);
    expect(ArcadeRules.roundReward(config, 400, 10), 4);
    expect(
      ArcadeRules.roundReward(
        const EconomyConfig(
          riskRewardEvery: 1000,
          riskRewardTokens: 1000,
          runRewardEvery: 1000000,
          runRewardTokens: 1000,
        ),
        1000000,
        1000,
      ),
      2000,
    );
  });
}
