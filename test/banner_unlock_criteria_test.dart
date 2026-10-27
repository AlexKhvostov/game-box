import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/ad_formats_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'first of one day or 100 completed games unlocks, inclusive boundary',
    () async {
      var now = DateTime.utc(2026, 10, 27, 12);
      final store = EconomyStore(
        now: () => now,
        installedAt: now.subtract(const Duration(hours: 1)),
      );
      await store.load();
      addTearDown(store.dispose);
      for (var i = 0; i < 99; i++) {
        store.recordCompletedRound();
      }
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 100),
        const Duration(hours: 23),
      );
      store.recordCompletedRound();
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 100),
        Duration.zero,
      );
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 101),
        const Duration(hours: 23),
      );
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 0),
        const Duration(hours: 23),
      );
      now = now.add(const Duration(hours: 23));
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 101),
        Duration.zero,
      );
    },
  );
  test(
    'completed games survive restart, accumulate while OFF, stay installation-local',
    () async {
      final now = DateTime.utc(2026, 10, 27, 12);
      final first = EconomyStore(
        now: () => now,
        storagePrefix: 'phone_',
        installedAt: now,
      );
      await first.load();
      for (var i = 0; i < 100; i++) {
        first.completeRound(
          timeMs: 1,
          runDistance: 0,
          riskCount: 0,
          grantReward: false,
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(first.advertising.banner.enabled, false);
      expect(first.bannerCompletedGames, 100);
      first.dispose();
      final reopened = EconomyStore(now: () => now, storagePrefix: 'phone_');
      await reopened.load();
      addTearDown(reopened.dispose);
      expect(reopened.bannerCompletedGames, 100);
      expect(
        reopened.bannerDelayLeft(86400, unlockAfterGames: 100),
        Duration.zero,
      );
      final other = EconomyStore(
        now: () => now,
        storagePrefix: 'other_',
        installedAt: now,
      );
      await other.load();
      addTearDown(other.dispose);
      expect(other.bannerCompletedGames, 0);
      expect(
        other.bannerDelayLeft(86400, unlockAfterGames: 100),
        const Duration(days: 1),
      );
    },
  );
  test(
    'old installation unlocks by time with no games; zero seconds is immediate',
    () async {
      final now = DateTime.utc(2026, 10, 27, 12);
      final store = EconomyStore(
        now: () => now,
        installedAt: now.subtract(const Duration(days: 1)),
      );
      await store.load();
      addTearDown(store.dispose);
      expect(store.bannerCompletedGames, 0);
      expect(
        store.bannerDelayLeft(86400, unlockAfterGames: 100),
        Duration.zero,
      );
      expect(store.bannerDelayLeft(0, unlockAfterGames: 100), Duration.zero);
    },
  );
  test('RC count uses integer game units and rejects bad thresholds', () {
    expect(const AdFormatsConfig().banner.unlockAfterGames, 100);
    expect(
      AdFormatsConfig.fromJson({
        'banner': {'unlockAfterGames': 0},
      }).banner.unlockAfterGames,
      0,
    );
    for (final value in [-1, 1.5, '100', true, 1000001]) {
      expect(
        () => AdFormatsConfig.fromJson({
          'banner': {'unlockAfterGames': value},
        }),
        throwsFormatException,
      );
    }
  });
}
