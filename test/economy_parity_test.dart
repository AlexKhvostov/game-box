import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/economy_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('remote configuration cannot remove the session ad minimums', () async {
    var now = DateTime(2026, 10, 9);
    final store = EconomyStore(
      config: const EconomyConfig(
        interstitialGraceSec: 0,
        interstitialSessionGraceSec: 0,
        interstitialSessionFreeRounds: 0,
      ),
      now: () => now,
    );
    await store.load();
    store.interstitialArmedAt = now.subtract(const Duration(days: 1));
    store.lives = 30;
    for (var i = 0; i < 10; i++) {
      store.recordCompletedRound();
    }
    now = now.add(const Duration(minutes: 3));
    expect(store.canShowResultInterstitial, false);
    store.recordCompletedRound();
    expect(store.canShowResultInterstitial, true);
  });
  test(
    'fresh balance uses initial tokens, not install action reward',
    () async {
      final store = EconomyStore(
        config: const EconomyConfig(initialTokens: 15),
      );
      await store.load();
      expect(store.tokens, 15);
      expect(store.claimEarnAction('install_bonus'), isNull);
      await store.resetToFreshInstall();
      expect(store.tokens, 15);
    },
  );
  test(
    'daily sequence, same day, gap, future clock and capped display',
    () async {
      var now = DateTime(2026, 10, 6, 23, 59);
      final store = EconomyStore(
        config: const EconomyConfig(dailyRewardTokens: [2, 4, 9]),
        now: () => now,
      );
      await store.load();
      expect(store.claimDaily(), 2);
      expect(store.claimDaily(), isNull);
      expect(store.upcomingDailyTokens, 2);
      now = now.add(const Duration(minutes: 2));
      expect(store.upcomingDailyTokens, 4);
      expect(store.claimDaily(), 4);
      now = now.add(const Duration(days: 1));
      expect(store.claimDaily(), 9);
      now = now.add(const Duration(days: 1));
      expect(store.upcomingStreakDay, 3);
      expect(store.claimDaily(), 9);
      now = now.subtract(const Duration(days: 2));
      expect(store.canClaimDaily, false);
      expect(store.claimDaily(), isNull);
      now = now.add(const Duration(days: 4));
      expect(store.upcomingStreakDay, 1);
      expect(store.claimDaily(), 2);
    },
  );
  test(
    'timed bonus changes readiness exactly at configured boundary',
    () async {
      var now = DateTime(2026, 10, 6);
      final store = EconomyStore(
        config: const EconomyConfig(timedBonusHours: 1, timedBonusTokens: 22),
        now: () => now,
      );
      await store.load();
      expect(store.claimTimedBonus(), 22);
      now = now.add(const Duration(hours: 1) - const Duration(milliseconds: 1));
      expect(store.canClaimTimedBonus, false);
      expect(store.claimTimedBonus(), isNull);
      now = now.add(const Duration(milliseconds: 1));
      expect(store.canClaimTimedBonus, true);
      expect(store.claimTimedBonus(), 22);
    },
  );
  test(
    'rentals extend active expiry and restart expired rental without free purchase',
    () async {
      var now = DateTime(2026, 10, 6);
      final store = EconomyStore(
        config: const EconomyConfig(
          initialTokens: 40,
          jumpRentalCost: 20,
          jumpRentalMinutes: 10,
          helmetRentalCost: 20,
          helmetRentalMinutes: 10,
        ),
        now: () => now,
      );
      await store.load();
      expect(store.rentJump(), true);
      expect(store.rentJump(), true);
      expect(store.jumpRentalUntil, now.add(const Duration(minutes: 20)));
      expect(store.rentHelmet(), false);
      expect(store.tokens, 0);
      now = now.add(const Duration(minutes: 20));
      expect(store.hasJumpRental, false);
      expect(store.jumpRentalRemaining, isNull);
      store.grantCrystals(20);
      expect(store.rentJump(), true);
      expect(store.jumpRentalUntil, now.add(const Duration(minutes: 10)));
    },
  );
  test(
    'interstitial waits for daily grace/cooldown and expires Plus exactly',
    () async {
      var now = DateTime(2026, 10, 6);
      final store = EconomyStore(
        config: const EconomyConfig(
          interstitialGraceSec: 210,
          interstitialCooldownSec: 220,
          interstitialMinLives: 6,
        ),
        now: () => now,
      );
      await store.load();
      store.lives = 6;
      expect(store.canShowResultInterstitial, false);
      store.claimDaily();
      for (var i = 0; i < 11; i++) {
        store.recordCompletedRound();
      }
      now = now.add(
        const Duration(seconds: 210) - const Duration(milliseconds: 1),
      );
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(milliseconds: 1));
      expect(store.canShowResultInterstitial, true);
      store.markInterstitialShown();
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(seconds: 220));
      expect(store.canShowResultInterstitial, true);
      store.lives = 5;
      expect(store.canShowResultInterstitial, false);
      store.lives = 6;
      store.hasPremium = true;
      store.premiumNextChargeAt = now.add(const Duration(milliseconds: 1));
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(milliseconds: 1));
      expect(store.hasPremium, false);
      expect(store.canShowResultInterstitial, true);
    },
  );
  test(
    'every launch protects ten completed rounds and at least three minutes',
    () async {
      var now = DateTime(2026, 10, 6);
      final store = EconomyStore(
        config: const EconomyConfig(interstitialGraceSec: 0),
        now: () => now,
      );
      await store.load();
      store.interstitialArmedAt = now.subtract(const Duration(days: 1));
      store.lives = 30;
      for (var i = 0; i < 10; i++) {
        store.recordCompletedRound();
      }
      now = now.add(const Duration(minutes: 3));
      expect(store.canShowResultInterstitial, false);
      store.recordCompletedRound();
      expect(store.canShowResultInterstitial, true);
      store.markInterstitialShown();
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(minutes: 3));
      expect(store.canShowResultInterstitial, true);
      final reopened = EconomyStore(
        config: const EconomyConfig(interstitialGraceSec: 0),
        now: () => now,
      );
      await reopened.load();
      reopened.interstitialArmedAt = store.interstitialArmedAt;
      reopened.lives = 30;
      for (var i = 0; i < 11; i++) {
        reopened.recordCompletedRound();
      }
      now = now.add(
        const Duration(minutes: 3) - const Duration(milliseconds: 1),
      );
      expect(reopened.canShowResultInterstitial, false);
      now = now.add(const Duration(milliseconds: 1));
      expect(reopened.canShowResultInterstitial, true);
    },
  );
}
