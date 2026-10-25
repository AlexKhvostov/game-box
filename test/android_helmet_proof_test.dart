import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/enemy_pace.dart';
import 'package:game_box/domain/helmet_charge.dart';
import 'package:game_box/domain/replay_random.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test(
    'native v3 proofs: zero, fractional, 30/60 seconds, repeated shield, jumps and exact physics',
    () {
      final base = jsonDecode(
        File('assets/config/android-firebase.json').readAsStringSync(),
      );
      final fixtures = <Map<String, dynamic>>[];
      for (final seconds in [0.0, .5, 30.0, 60.0]) {
        for (var seed = 1; seed <= 3; seed++) {
          for (final jump in [false, true]) {
            final raw = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
            raw['config']['game']['helmetCooldownSec'] = seconds;
            raw['config']['game']['startInvulnSec'] = 0;
            raw['config']['game']['helmetInvulnSec'] = .1;
            raw['config']['game']['wallsKillPlayer'] = true;
            // Synthetic safe arena: stationary enemies; wall contacts use real physics.
            raw['config']['enemyPace'] = {
              'initialSpeed': 0,
              'growthMultiplier': 0,
              'brakeEnabled': false,
            };
            if (seconds == 0 && seed == 1 && !jump) { raw['config'].remove('enemyPace'); }
          final config = MobileGameplayTuning.apply(
              SharedConfigs.fromSnapshot(raw, 'helmet-proof').gameplay,
            );
            final key = (fixtures.length + 5000)
                .toRadixString(16)
                .padLeft(64, '0');
            final world = GameWorld(
              config: config,
              field: const Size(380, 380),
              rng: ReplayRandom(key),
              wallInset: ArcadeRules.wallInset(config.borderWidth),
            )..resetLayout();
            world.startFromIdle();
            final pose = world.startPose, center = world.player;
            final shield = HelmetCharge(equipped: true, cooldownSec: seconds),
                pace = EnemyPace(config.enemyPace);
            final events = <List<num>>[];
            double elapsed = 0, grace = 0;
            var dead = false, restores = 0, hits = 0;
            void collide() {
              if (grace > 0) return;
              final wall = world.wallsKillPlayer && world.playerHitsBorder();
              if (!wall && !world.playerHitsEnemy()) return;
              if (shield.consume()) {
                hits++;
                grace = config.helmetInvulnSec;
                if (!wall) world.repelEnemiesFromPlayer();
              } else {
                dead = true;
              }
            }

            void tick(double ms) {
              events.add([0, ms]);
              elapsed += ms;
              final dt = ms / 1000;
              if (shield.advanceTo(elapsed)) restores++;
              pace.advance(dt);
              world.tickJump(dt);
              world.tickPlay(
                dt,
                elapsed / 1000,
                enemySpeedOverride: pace.speed * world.playerSize * .1,
                checkPlayerHits: grace <= 0,
              );
              grace = max(0, grace - dt);
              collide();
            }

            void move(Offset d) {
              events.add([1, d.dx, d.dy]);
              world.movePlayerBy(d, checkEnemies: grace <= 0);
              collide();
            }

            void waitMs(double duration) {
              final end = elapsed + duration;
              while (elapsed < end && !dead) {
                tick(min([16.0, 33.0, 50.0][seed - 1], end - elapsed));
              }
            }

            tick(1);
            for (
              var cycle = 0;
              cycle < (seconds > 0 ? 3 : 1) && !dead;
              cycle++
            ) {
              move(const Offset(-1000, 0));
              if (dead) break;
              move(center - world.player);
              if (jump && world.tryJump(nowMs: elapsed)) events.add([2]);
              if (cycle < 2 && seconds > 0) waitMs(seconds * 1000 + 200);
            }
            waitMs(200);
            if (!dead) move(const Offset(-1000, 0));
            expect(dead, true, reason: 'seconds=$seconds seed=$seed');
            expect(hits, seconds > 0 ? 3 : 1);
            expect(restores, seconds > 0 ? 2 : 0);
            fixtures.add({
              'requestId': key,
              'config': raw['config'],
              'hadHelmet': true,
              'hadJump': jump,
              'proof': {'version': 3, 'startPose': pose, 'events': events},
              'timeMs': elapsed.floor(),
              'runDistance': ArcadeRules.runSteps(
                world.playerDistance,
                world.playerSize,
              ),
              'riskCount': world.nearMissCount,
              'shieldHits': hits,
              'restores': restores,
            });
          }
        }
      }
      final target = const String.fromEnvironment(
        'HELMET_FIXTURES',
        defaultValue: 'supabase/test/fixtures/android-helmet-v3.json',
      );
      File(target).writeAsStringSync(jsonEncode(fixtures));
      expect(fixtures.length, 24);
    },
  );
}
