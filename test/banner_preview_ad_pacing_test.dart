import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/data/economy_store.dart';
import '../tools/android_automatic_ads_probe.dart' show probeEconomyConfig;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundled = AndroidFirebaseConfig.parse(
    File(AndroidFirebaseConfig.assetPath).readAsStringSync(),
    'pacing-test',
  ).economy;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('banner build consumes published economy without stress overrides', () {
    expect(
      identical(probeEconomyConfig(bundled, forBanner: true), bundled),
      true,
    );
    if (const bool.fromEnvironment('ANDROID_BANNER_PROBE')) {
      expect(identical(probeEconomyConfig(bundled), bundled), true);
    }
    expect(
      probeEconomyConfig(bundled, forBanner: false).interstitialCooldownSec,
      3,
    );
  });

  test(
    'banner preview protects first ten rounds and enforces normal cooldown',
    () async {
      var now = DateTime.utc(2026, 10, 27);
      final store = EconomyStore(
        config: probeEconomyConfig(bundled, forBanner: true),
        now: () => now,
        storagePrefix: 'banner_pacing_test_',
      );
      await store.load();
      await store.enableEnergyPreview(balance: 50);
      for (var round = 1; round <= 10; round++) {
        store.recordCompletedRound();
        now = now.add(const Duration(seconds: 3));
        expect(
          store.canShowResultInterstitial,
          false,
          reason: 'early round $round',
        );
      }
      now = now.add(const Duration(hours: 1));
      expect(store.canShowResultInterstitial, false, reason: 'ten free rounds');
      store.recordCompletedRound();
      expect(store.canShowResultInterstitial, true);
      store.markInterstitialShown();
      store.recordCompletedRound();
      now = now.add(const Duration(seconds: 3));
      expect(
        store.canShowResultInterstitial,
        false,
        reason: 'no stress 3s cooldown',
      );
      now = now.add(Duration(seconds: bundled.interstitialCooldownSec - 3));
      expect(store.canShowResultInterstitial, true);
      store.dispose();
    },
  );

  test('completing many short games does not bypass startup grace', () async {
    var now = DateTime.utc(2026, 10, 27);
    final store = EconomyStore(
      config: probeEconomyConfig(bundled, forBanner: true),
      now: () => now,
      storagePrefix: 'banner_startup_test_',
    );
    await store.load();
    await store.enableEnergyPreview(balance: 50);
    for (var i = 0; i < 20; i++) {
      store.recordCompletedRound();
    }
    expect(store.canShowResultInterstitial, false);
    now = now.add(const Duration(seconds: 209));
    expect(store.canShowResultInterstitial, false);
    now = now.add(const Duration(seconds: 1));
    expect(store.canShowResultInterstitial, true);
    store.dispose();
  });
}
