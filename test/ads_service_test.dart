import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/economy_config.dart';

class FakeAdsDriver implements AdsDriver {
  final pending = Completer<AdOutcome>();
  int loads = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) {
    loads++;
    return pending.future;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

class DelayedInterstitialDriver implements AdsDriver {
  final loaded = Completer<void>();
  int loads = 0;
  int presentations = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async =>
      AdOutcome.unavailable;
  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    loads++;
    await loaded.future;
    if (!canShow()) return false;
    presentations++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!AudiencePolicy.adsBuildEnabled) {
    test(
      'off build never loads or credits ads after adult permission',
      () async {
        SharedPreferences.setMockInitialValues({});
        final policy = AudiencePolicy();
        await policy.load();
        await policy.select(AgeBand.age21plus);
        await policy.setAdDataConsent(true);
        final driver = FakeAdsDriver();
        final ads = AdsService(driver, audience: policy);
        final economy = EconomyStore();
        await economy.load();
        final before = economy.tokens;
        expect((await ads.watchAndClaim(economy)).reward, 0);
        expect(await ads.showInterstitial(canShow: () => true), false);
        expect(driver.loads, 0);
        expect(policy.adsEnabled, false);
        expect(economy.tokens, before);
      },
    );
    return;
  }
  late AudiencePolicy audience;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    audience = AudiencePolicy();
    await audience.load();
    await audience.select(AgeBand.age21plus);
    await audience.setAdDataConsent(true);
  });
  test(
    'rewarded request from a closed route does not load or credit',
    () async {
      final driver = FakeAdsDriver();
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      final result = await AdsService(
        driver,
        audience: audience,
      ).watchAndClaim(economy, canShow: () => false);
      expect(result.reward, 0);
      expect(driver.loads, 0);
      expect(economy.tokens, before);
    },
  );
  test('interstitial cannot load outside results', () async {
    final driver = DelayedInterstitialDriver();
    final ads = AdsService(driver, audience: audience);
    expect(await ads.showInterstitial(canShow: () => false), false);
    expect(driver.loads, 0);
    expect(ads.busy, false);
  });
  test('late ad is discarded after replay or a different result', () async {
    var resultSession = 1;
    const requestedSession = 1;
    final driver = DelayedInterstitialDriver();
    final ads = AdsService(driver, audience: audience);
    final pending = ads.showInterstitial(
      canShow: () => resultSession == requestedSession,
    );
    expect(driver.loads, 1);
    resultSession = 2;
    driver.loaded.complete();
    expect(await pending, false);
    expect(driver.presentations, 0);
    expect(ads.busy, false);
  });
  test('ad can present while the same result remains visible', () async {
    final driver = DelayedInterstitialDriver();
    final ads = AdsService(driver, audience: audience);
    final pending = ads.showInterstitial(canShow: () => true);
    driver.loaded.complete();
    expect(await pending, true);
    expect(driver.presentations, 1);
    expect(ads.busy, false);
  });
  for (final outcome in [
    AdOutcome.rewarded,
    AdOutcome.dismissed,
    AdOutcome.unavailable,
  ]) {
    test('SDK $outcome grants only on completed reward', () async {
      final economy = EconomyStore(
        config: const EconomyConfig(
          earnActions: [
            EarnAction(id: 'watch_ad', title: 'Ad', subtitle: '', reward: 9),
          ],
        ),
      );
      await economy.load();
      final before = economy.tokens;
      final driver = FakeAdsDriver();
      final ads = AdsService(driver, audience: audience);
      final pending = ads.watchAndClaim(economy);
      expect(ads.busy, isTrue);
      final duplicate = await ads.watchAndClaim(economy);
      expect(duplicate.outcome, AdOutcome.busy);
      expect(driver.loads, 1);
      driver.pending.complete(outcome);
      final result = await pending;
      final expected = outcome == AdOutcome.rewarded ? 9 : 0;
      expect(result.reward, expected);
      expect(economy.tokens, before + expected);
      expect(ads.busy, isFalse);
      expect(economy.lastWatchAdClaimAt != null, outcome == AdOutcome.rewarded);
      if (outcome == AdOutcome.rewarded) {
        expect((await ads.watchAndClaim(economy)).reward, 0);
        expect(driver.loads, 1);
      }
    });
  }
  test('loader failure preserves balance and allows a later retry', () async {
    final economy = EconomyStore();
    await economy.load();
    final before = economy.tokens;
    final driver = FakeAdsDriver();
    final ads = AdsService(driver, audience: audience);
    final pending = ads.watchAndClaim(economy);
    driver.pending.completeError(StateError('no fill'));
    expect((await pending).outcome, AdOutcome.unavailable);
    expect(ads.busy, isFalse);
    expect(economy.tokens, before);
    expect(economy.canClaimWatchAd, isTrue);
  });
  test(
    'old social and rewarded preview buttons cannot grant credits',
    () async {
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      expect(economy.claimEarnAction('watch_ad'), isNull);
      expect(economy.claimEarnAction('telegram'), isNull);
      expect(economy.tokens, before);
    },
  );
}
