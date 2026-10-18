import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/android_firebase_config.dart';
import 'package:game_box/domain/android_energy.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'simple_energy_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'quota uses anchored server time; phone clock cannot reset a full day',
    () async {
      var wall = fixture.stamp, elapsed = 0;
      final e = EconomyStore(
        now: () => DateTime.fromMillisecondsSinceEpoch(wall),
        monotonicMilliseconds: () => elapsed,
      );
      await e.load();
      await e.applyServerWallet(
        {
          ...fixture.simpleWallet(),
          'adQuota': {
            'used': 20,
            'limit': 20,
            'resetAt': fixture.stamp + 10000,
          },
        },
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
      expect(e.watchAdsToday, 20);
      expect(e.canClaimWatchAd, false);
      wall += 86400000 * 10;
      expect(e.canClaimWatchAd, false);
      elapsed = 10000;
      expect(e.watchAdsToday, 0);
      expect(e.canClaimWatchAd, true);
      e.dispose();
    },
  );
  test(
    'canonical RC daily/cooldown fields reach typed model; missing field defaults20',
    () {
      final raw =
          jsonDecode(File(AndroidFirebaseConfig.assetPath).readAsStringSync())
              as Map<String, dynamic>;
      final bonus =
          raw['config']['economy']['androidEnergyV2']['simpleBonus'] as Map;
      bonus['videoDailyLimit'] = 7;
      bonus['videoCooldownSec'] = 180;
      raw['revision'] = sha256
          .convert(utf8.encode(jsonEncode(raw['config'])))
          .toString();
      final config = AndroidFirebaseConfig.parse(
        jsonEncode(raw),
        'quota-test',
      ).economy.androidEnergyV2;
      expect(config.watchAdDailyLimit, 7);
      expect(config.watchAdCooldownSec, 180);
      bonus.remove('videoDailyLimit');
      raw['revision'] = sha256
          .convert(utf8.encode(jsonEncode(raw['config'])))
          .toString();
      expect(
        AndroidFirebaseConfig.parse(
          jsonEncode(raw),
          'legacy',
        ).economy.androidEnergyV2.watchAdDailyLimit,
        20,
      );
      expect(
        AndroidEnergyConfig.fromJson(config.toJson()).watchAdDailyLimit,
        7,
      );
    },
  );
  testWidgets(
    'daily quota explains tomorrow and disables SDK entry before presentation',
    (t) async {
      final e = await fixture.store();
      await e.applyServerWallet(
        {
          ...fixture.simpleWallet(),
          'adQuota': {
            'used': 20,
            'limit': 20,
            'resetAt': fixture.stamp + 86400000,
          },
        },
        serverNow: fixture.stamp,
        owner: 'android:1',
      );
      await t.pumpWidget(fixture.app(e));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final button = t.widget<NeonAction>(
        find.byKey(const ValueKey('simple-energy-video')),
      );
      expect(button.onTap, isNull);
      expect(find.text('Сегодня: 20 из 20'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      e.dispose();
    },
  );
}
