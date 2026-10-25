import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';
import 'package:game_box/data/shared_config_loader.dart';
import 'package:game_box/domain/arcade_rules.dart';
import 'package:game_box/domain/replay_random.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/game/game_world.dart';

void main() {
  test(
    'real Dart physics emits completed proofs for server cross-runtime verification',
    () {
      final snapshot =
          jsonDecode(
                File('assets/config/android-firebase.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      // Version-one fixtures preserve the policy of old, already accepted rounds.
      (snapshot['config']['game'] as Map).remove('helmetCooldownSec');
      final config = MobileGameplayTuning.apply(
        SharedConfigs.fromSnapshot(snapshot, 'fixture').gameplay,
      );
      final fixtures = <Map<String, dynamic>>[];
      for (var seed = 1; seed <= 64; seed++) {
        for (var loadout = 0; loadout < 4; loadout++) {
          final key = (seed * 4 + loadout).toRadixString(16).padLeft(64, '0');
          final world = GameWorld(
            config: config,
            field: const Size(380, 380),
            rng: ReplayRandom(key),
            wallInset: ArcadeRules.wallInset(config.borderWidth),
          )..resetLayout();
          // Mix old transcripts and real visible poses after waiting on home.
          List<List<double>>? startPose;
          if (seed.isEven) {
            for (var idle = 0; idle < seed * 3 + 8; idle++) {
              world.tickIdle(.016);
            }
            world.startFromIdle();
            startPose = world.startPose;
          }
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

          for (var frame = 0; frame < 2000 && !dead; frame++) {
            final ms = [6.944, 16.666, 33.333, 49.999][seed % 4];
            events.add([0, ms]);
            elapsed += ms;
            world.tickJump(ms / 1000);
            world.tickPlay(
              ms / 1000,
              elapsed / 1000,
              checkPlayerHits: !invulnerable(),
            );
            startLeft = max(0, startLeft - ms / 1000);
            helmetLeft = max(0, helmetLeft - ms / 1000);
            if (!world.wallsKillPlayer && world.playerHitsBorder()) {
              world.clampPlayerToField();
            }
            collision();
            if (dead) break;
            if (jump && frame % 160 == 0 && world.tryJump(nowMs: elapsed)) {
              events.add([2]);
            }
            if (frame % 13 == 0) {
              final delta = Offset(
                frame % 26 == 0 ? 110 : -100,
                seed % 2 == 0 ? 5 : -5,
              );
              events.add([1, delta.dx, delta.dy]);
              world.movePlayerBy(delta, checkEnemies: !invulnerable());
              if (!world.wallsKillPlayer && world.playerHitsBorder()) {
                world.clampPlayerToField();
              }
              collision();
            }
          }
          expect(dead, isTrue, reason: 'seed $seed loadout $loadout');
          fixtures.add({
            'config': snapshot['config'],
            'requestId': key,
            'hadJump': jump,
            'hadHelmet': loadout & 1 != 0,
            'proof': {'version': 1, 'events': events, 'startPose': ?startPose},
            'timeMs': elapsed.floor(),
            'runDistance': ArcadeRules.runSteps(
              world.playerDistance,
              world.playerSize,
            ),
            'riskCount': world.nearMissCount,
          });
        }
      }
      expect(fixtures.length, 256);
      const target = String.fromEnvironment('REPLAY_FIXTURE_PATH');
      if (target.isNotEmpty) {
        File(target).writeAsStringSync(jsonEncode(fixtures));
      } else {
        expect(
          fixtures,
          jsonDecode(
            File(
              'supabase/test/fixtures/android-replay.json',
            ).readAsStringSync(),
          ),
          reason:
              'Physics changed: regenerate fixtures and compiled server verifier together.',
        );
      }
    },
  );
  test(
    'pending proof survives storage, ACK drops bulky proof but retains metrics',
    () {
      final attempt = LocalAttempt(
        id: 'run',
        timeMs: 500,
        createdAt: DateTime(2026),
        replayProof: {
          'version': 1,
          'events': [
            [0, 20],
          ],
        },
      );
      final recovered = LocalAttempt.fromJson(
        jsonDecode(jsonEncode(attempt.toJson())),
      );
      expect(recovered.replayProof, attempt.replayProof);
      final shared = recovered.copyWith(shared: true, clearReplayProof: true);
      expect(shared.replayProof, isNull);
      expect(shared.timeMs, 500);
    },
  );
}
