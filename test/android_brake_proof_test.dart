import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/enemy_pace.dart';
import 'package:game_box/domain/replay_random.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test(
    'native Dart v2 fixtures cover curve/brake toggles, idle poses, variable frames, jumps and helmets',
    () {
      final snapshot =
          jsonDecode(
                File('assets/config/android-firebase.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final fixtures = <Map<String, dynamic>>[];
      var presses = 0;
      for (var seed = 1; seed <= 32; seed++) {
        for (var loadout = 0; loadout < 4; loadout++) {
          final raw = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
          raw['config']['game']['startInvulnSec'] = seed.isEven ? 8.0 : 0.0;
          raw['config']['enemyPace'] = {
            'brakeEnabled': seed % 3 != 0,
            'speedBarEnabled': seed % 2 == 0,
          };
          final config = MobileGameplayTuning.apply(
                SharedConfigs.fromSnapshot(
                  raw,
                  'native-brake-fixture',
                ).gameplay,
              ),
              pace = EnemyPace(config.enemyPace);
          final key = (10000 + seed * 4 + loadout)
              .toRadixString(16)
              .padLeft(64, '0');
          final world = GameWorld(
            config: config,
            field: const Size(380, 380),
            rng: ReplayRandom(key),
            wallInset: ArcadeRules.wallInset(config.borderWidth),
          )..resetLayout();
          for (var idle = 0; idle < seed * 2; idle++) {
            world.tickIdle(.016);
          }
          world.startFromIdle();
          final pose = world.startPose;
          var helmet = loadout & 1 != 0, dead = false;
          final jump = loadout & 2 != 0, events = <List<num>>[];
          double elapsed = 0, startLeft = config.startInvulnSec, helmetLeft = 0;
          bool invulnerable() => startLeft > 0 || helmetLeft > 0;
          void collision() {
            if (invulnerable()) return;
            final wall = world.wallsKillPlayer && world.playerHitsBorder();
            if (!wall && !world.playerHitsEnemy()) return;
            if (helmet) {
              helmet = false;
              helmetLeft = config.helmetInvulnSec;
              if (!wall) world.repelEnemiesFromPlayer();
            } else {
              dead = true;
            }
          }

          void brake(Offset from) {
            if (!dead) {
              pace.pressOnFloor(
                fromX: from.dx,
                fromY: from.dy,
                toX: world.player.dx,
                toY: world.player.dy,
                playerSize: world.playerSize,
                grounded: !world.isJumping,
              );
            }
          }

          for (var frame = 0; frame < 10000 && !dead; frame++) {
            final ms = [6.944, 16.666, 33.333, 49.999][seed % 4],
                dt = ms / 1000;
            events.add([0, ms]);
            elapsed += ms;
            pace.advance(dt);
            world.tickJump(dt);
            world.tickPlay(
              dt,
              elapsed / 1000,
              enemySpeedOverride: pace.speed * world.playerSize * .1,
              checkPlayerHits: !invulnerable(),
            );
            startLeft = max(0, startLeft - dt);
            helmetLeft = max(0, helmetLeft - dt);
            if (!world.wallsKillPlayer && world.playerHitsBorder()) {
              world.clampPlayerToField();
            }
            collision();
            brake(world.player);
            if (dead) break;
            if (jump && frame % 160 == 0 && world.tryJump(nowMs: elapsed)) {
              events.add([2]);
            }
            if (frame % 37 == 0) {
              final from = world.player,
                  delta = Offset(
                    frame % 74 == 0 ? 65 : -60,
                    seed.isEven ? 3 : -3,
                  );
              events.add([1, delta.dx, delta.dy]);
              world.movePlayerBy(delta, checkEnemies: !invulnerable());
              if (!world.wallsKillPlayer && world.playerHitsBorder()) {
                world.clampPlayerToField();
              }
              collision();
              brake(from);
            }
          }
          expect(dead, true, reason: 'seed$seed/loadout$loadout');
          presses += pace.presses;
          fixtures.add({
            'config': raw['config'],
            'requestId': key,
            'hadHelmet': loadout & 1 != 0,
            'hadJump': jump,
            'proof': {'version': 2, 'events': events, 'startPose': pose},
            'timeMs': elapsed.floor(),
            'runDistance': ArcadeRules.runSteps(
              world.playerDistance,
              world.playerSize,
            ),
            'riskCount': world.nearMissCount,
            'brakePresses': pace.presses,
          });
        }
      }
      expect(fixtures.length, 128);
      expect(presses, greaterThan(0));
      const target = String.fromEnvironment('ANDROID_BRAKE_FIXTURES');
      if (target.isNotEmpty) {
        File(target).writeAsStringSync(jsonEncode(fixtures));
      }
    },
  );
  test(
    'typed settings preserve every admin parameter and strict toggle validation',
    () {
      final settings = EnemyPaceSettings.fromJson({
        'initialSpeed': 8,
        'growthMultiplier': 60,
        'growthExponent': .25,
        'startSmoothingSec': 4,
        'initialCompensation': .8,
        'brakeCooldownSec': 7,
        'brakeFirstReadySec': 5,
        'brakeRewindSec': 4,
        'brakeEnabled': false,
        'speedBarEnabled': true,
      });
      final pace = EnemyPace(settings);
      expect(pace.target, closeTo(8 + 60 * (pow(4, .25) - .8), 1e-10));
      pace.advance(20);
      expect(pace.press(), false);
      expect(pace.effective, 20);
      expect(settings.toJson()['brakeCooldownSec'], 7);
      expect(settings.brakeEnabled, false);
      expect(settings.speedBarEnabled, true);
      for (final value in [0, 1, 'false', null, {}, []]) {
        expect(
          () => EnemyPaceSettings.fromJson({'brakeEnabled': value}),
          throwsFormatException,
        );
      }
    },
  );
}
