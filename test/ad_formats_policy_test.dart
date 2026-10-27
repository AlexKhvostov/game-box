import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/app_installation.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/domain/ad_formats_config.dart';
import 'package:game_box/domain/economy_config.dart';

class PendingAutomaticAd implements AdsDriver {
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async =>
      AdOutcome.unavailable;
  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    calls++;
    await release.future;
    return canShow();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'legacy snapshots preserve format defaults; malformed policy is rejected',
    () {
      final legacy = AdFormatsConfig.fromJson(null);
      expect(legacy.banner.enabled, false);
      expect(legacy.automatic.enabled, true);
      expect(legacy.rewardedEnabled, true);
      for (final raw in [
        [],
        {
          'banner': {'enabled': 1},
        },
        {
          'automatic': {'resumeGraceSec': -1},
        },
        {
          'banner': {'unitId': 'demo-banner-yandex'},
        },
      ]) {
        expect(() => AdFormatsConfig.fromJson(raw), throwsFormatException);
      }
    },
  );
  test(
    'banner clock uses OS installation time and survives a process restart',
    () async {
      final now = DateTime.utc(2026, 10, 27, 12);
      final install = now.subtract(const Duration(hours: 23));
      const channel = MethodChannel('untouch/support');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {'firstInstallTime': install.millisecondsSinceEpoch},
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final first = EconomyStore(
        now: () => now,
        storagePrefix: 'install_test_',
        installedAt: await readAppInstallation(now: now),
      );
      await first.load();
      expect(first.bannerDelayLeft(86400), const Duration(hours: 1));
      first.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      final reopened = EconomyStore(
        now: () => now.add(const Duration(hours: 1)),
        storagePrefix: 'install_test_',
      );
      await reopened.load();
      expect(reopened.bannerDelayLeft(86400), Duration.zero);
      reopened.dispose();
    },
  );
  test('long absence blocks automatic ads for its own quiet period', () async {
    var now = DateTime.utc(2026, 10, 27);
    final store = EconomyStore(now: () => now, storagePrefix: 'resume_test_');
    await store.load();
    await store.enableEnergyPreview(balance: 50);
    for (var i = 0; i < 11; i++) {
      store.recordCompletedRound();
    }
    now = now.add(const Duration(hours: 1));
    expect(store.canShowResultInterstitial, true);
    store.advertisingBackgrounded();
    expect(store.canShowResultInterstitial, false);
    now = now.add(const Duration(minutes: 5));
    store.advertisingResumed();
    expect(store.canShowResultInterstitial, false);
    now = now.add(const Duration(seconds: 179));
    expect(store.canShowResultInterstitial, false);
    now = now.add(const Duration(seconds: 1));
    expect(store.canShowResultInterstitial, true);
    store.dispose();
  });
  test(
    'format switches do not alter each other or the automatic timing values',
    () async {
      var now = DateTime.utc(2026, 10, 27);
      final store = EconomyStore(
        now: () => now,
        storagePrefix: 'switch_test_',
        config: const EconomyConfig(interstitialCooldownSec: 220),
      );
      await store.load();
      await store.enableEnergyPreview(balance: 50);
      for (var i = 0; i < 11; i++) {
        store.recordCompletedRound();
      }
      now = now.add(const Duration(hours: 1));
      store.applyAdvertising(
        const AdFormatsConfig(
          banner: BannerFormatConfig(enabled: true),
          automatic: AutomaticFormatConfig(enabled: false),
        ),
      );
      expect(store.canShowResultInterstitial, false);
      expect(store.advertising.rewardedEnabled, true);
      expect(store.advertising.banner.enabled, true);
      store.applyAdvertising(const AdFormatsConfig(rewardedEnabled: false));
      expect(store.canShowResultInterstitial, true);
      expect(store.config.interstitialCooldownSec, 220);
      expect(store.advertising.banner.enabled, false);
      store.dispose();
    },
  );
  test(
    'RC automatic OFF blocks new loads and a load already waiting to show',
    () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: AgeBand.adult18plus.name,
        AudiencePolicy.adDataConsentKey: true,
      });
      final store = EconomyStore(storagePrefix: 'rc_automatic_off_');
      await store.load();
      final audience = AudiencePolicy();
      await audience.load();
      final driver = PendingAutomaticAd();
      final ads = AdsService(driver, audience: audience, economy: store);
      addTearDown(() {
        ads.dispose();
        audience.dispose();
        store.dispose();
      });
      final off = AdFormatsConfig.fromJson({
        'banner': {'enabled': true},
        'automatic': {'enabled': false},
        'rewarded': {'enabled': true},
      });
      store.applyAdvertising(off);
      expect(await ads.showInterstitial(canShow: () => true), false);
      expect(driver.calls, 0);
      expect(ads.busy, false);
      store.applyAdvertising(
        AdFormatsConfig.fromJson({
          ...off.toJson(),
          'automatic': {'enabled': true},
        }),
      );
      final waiting = ads.showInterstitial(canShow: () => true);
      expect(driver.calls, 1);
      store.applyAdvertising(off);
      driver.release.complete();
      expect(await waiting, false);
      expect(store.advertising.banner.enabled, true);
      expect(store.advertising.rewardedEnabled, true);
      expect(ads.busy, false);
    },
    skip: !AudiencePolicy.demoAds,
  );
  test(
    'a pending automatic load stays cancelled after even a short background visit',
    () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: AgeBand.adult18plus.name,
        AudiencePolicy.adDataConsentKey: true,
      });
      var now = DateTime.utc(2026, 10, 27);
      final store = EconomyStore(
        now: () => now,
        storagePrefix: 'pending_test_',
      );
      await store.load();
      final audience = AudiencePolicy();
      await audience.load();
      final driver = PendingAutomaticAd();
      final ads = AdsService(driver, audience: audience, economy: store);
      final pending = ads.showInterstitial(canShow: () => true);
      expect(ads.busy, true);
      store.advertisingBackgrounded();
      now = now.add(const Duration(seconds: 1));
      store.advertisingResumed();
      driver.release.complete();
      expect(await pending, false);
      ads.dispose();
      audience.dispose();
      store.dispose();
    },
    skip: !AudiencePolicy.demoAds,
  );
  test(
    'short return has its own pause; long absence also respects opening pause',
    () async {
      var now = DateTime.utc(2026, 10, 27);
      final store = EconomyStore(
        now: () => now,
        storagePrefix: 'short_return_',
        advertising: const AdFormatsConfig(
          automatic: AutomaticFormatConfig(
            resumeGraceSec: 10,
            longAbsenceSec: 300,
          ),
        ),
      );
      await store.load();
      await store.enableEnergyPreview(balance: 50);
      for (var i = 0; i < 11; i++) {
        store.recordCompletedRound();
      }
      now = now.add(const Duration(hours: 1));
      store.advertisingBackgrounded();
      now = now.add(const Duration(seconds: 1));
      store.advertisingResumed();
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(seconds: 9));
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(seconds: 1));
      expect(store.canShowResultInterstitial, true);
      store.advertisingBackgrounded();
      now = now.add(const Duration(seconds: 300));
      store.advertisingResumed();
      now = now.add(const Duration(seconds: 179));
      expect(store.canShowResultInterstitial, false);
      now = now.add(const Duration(seconds: 1));
      expect(store.canShowResultInterstitial, true);
      store.dispose();
    },
  );
}
