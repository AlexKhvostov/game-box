import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'simple_energy_test.dart' as fixture;
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/app/mobile_gameplay_tuning.dart';

void main() {
  testWidgets(
    'Remote Config color reaches the actual mobile painter instead of fixed design override',
    (t) async {
      final e = await fixture.store();
      final scores = ScoresStore();
      await scores.loadLocal();
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EconomyStore>.value(value: e),
            ChangeNotifierProvider.value(value: scores),
            Provider.value(
              value: const GameplayConfig(
                field: FieldConfig(colorHex: '#123456'),
              ),
            ),
          ],
          child: const GameBoxApp(forceLocale: 'ru'),
        ),
      );
      await t.pump();
      final scene = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.painter is GameFieldPainter)
          .single;
      expect(
        (scene.painter as GameFieldPainter).fieldColor,
        const Color(0xFF123456),
      );
      await t.pumpWidget(const SizedBox());
      scores.dispose();
      e.dispose();
    },
  );
  final cases =
      jsonDecode(
            File('test/fixtures/admin-config-cases.json').readAsStringSync(),
          )
          as List;
  for (final change in cases.where(
    (c) =>
        !c['path'].toString().contains('.simpleBonus.') &&
        !c['path'].toString().startsWith('ranking.'),
  )) {
    final path = change['path'] as String;
    test(
      'admin parameter $path reaches the typed Android startup snapshot',
      () {
        final raw =
            jsonDecode(File(AndroidFirebaseConfig.assetPath).readAsStringSync())
                as Map<String, dynamic>;
        final parts = path.split('.');
        dynamic target = raw['config'];
        for (final part in parts.take(parts.length - 1)) {
          target = target[part] ??= <String, dynamic>{};
        }
        target[parts.last] = change['value'];
        raw['revision'] = sha256
            .convert(utf8.encode(jsonEncode(raw['config'])))
            .toString();
        final parsed = AndroidFirebaseConfig.parse(
          jsonEncode(raw),
          'admin-contract',
        );
        final tuned = MobileGameplayTuning.apply(parsed.gameplay);
        final model = <String, dynamic>{
          'enemyPace': tuned.enemyPace?.toJson(),
          'mobileEnemies': {
            'startSpeedSteps': tuned.mobileEnemies.startSpeedSteps,
            'accelerationSteps': tuned.mobileEnemies.accelerationSteps,
            'speedVariation': tuned.mobileEnemies.speedVariation,
            'accelerationVariation': tuned.mobileEnemies.accelerationVariation,
          },
          'enemies': tuned.enemies.toJson(),
          'player': tuned.player.toJson(),
          'field': {...tuned.field.toJson(), 'colorHex': tuned.field.colorHex},
          'game': tuned.game.toJson(),
          'audio': tuned.audio.toJson(),
          'economy': {
            'androidEnergyV2': parsed.economy.androidEnergyV2.toJson(),
            'runRewardEvery': parsed.economy.runRewardEvery,
            'riskRewardEvery': parsed.economy.riskRewardEvery,
            'interstitialSessionGraceSec':
                parsed.economy.interstitialSessionGraceSec,
            'interstitialSessionFreeRounds':
                parsed.economy.interstitialSessionFreeRounds,
            'interstitialGraceSec': parsed.economy.interstitialGraceSec,
            'interstitialCooldownSec': parsed.economy.interstitialCooldownSec,
            'interstitialMinLives': parsed.economy.interstitialMinLives,
          },
        };
        dynamic actual = model;
        for (final part in parts) {
          actual = actual[part];
        }
        expect(actual, change['value']);
      },
    );
  }
}
