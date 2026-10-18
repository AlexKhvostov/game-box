import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'ads_service.dart';
import 'audience_policy.dart';

abstract final class YandexAdUnits {
  // Live activation requires store publication, moderation and AP4 wallet checks.
  static const live = bool.fromEnvironment('YANDEX_LIVE_ADS');
  static const rewarded = live ? 'R-M-20184253-1' : 'demo-rewarded-yandex';
  static const interstitial = live
      ? 'R-M-20184253-2'
      : 'demo-interstitial-yandex';
}

class YandexAdsDriver implements AdsDriver {
  YandexAdsDriver({required this.audience});
  final AudiencePolicy audience;
  // Live ads stay blocked until content filters, regions and privacy are reviewed.
  bool get allowed =>
      AudiencePolicy.adsBuildEnabled &&
      audience.rewardedAdsEnabled &&
      !YandexAdUnits.live;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void>? _initializing;

  Future<void> _initialize() async {
    if (!allowed) throw StateError('Ads disabled by audience policy');
    if (!supported) throw UnsupportedError('Android ads only');
    try {
      await (_initializing ??= _init());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _init() async {
    // Explicit reward tap starts contextual demo ads, never personalization.
    await YandexAds.setUserConsent(false);
    await YandexAds.setLocationTracking(false);
    await YandexAds.setAgeRestricted(false); // Only declared adults reach here.
    if (!allowed) throw StateError('Advertising permission withdrawn');
    await YandexAds.initialize();
  }

  void _trace(String event) {
    if (!YandexAdUnits.live) debugPrint('UNTOUCH_AD $event');
  }

  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    if (!allowed || (canShow != null && !canShow())) {
      return AdOutcome.unavailable;
    }
    await _initialize();
    if (!allowed || (canShow != null && !canShow())) return AdOutcome.dismissed;
    final loader = RewardedAdLoader();
    RewardedAd? ad;
    var abandoned = false;
    try {
      _trace('rewarded loading SDK8.6.0');
      final loading = loader.loadAd(
        adRequest: const AdRequest(adUnitId: YandexAdUnits.rewarded),
      );
      // An eventual late load must not leak an ad or trigger an unsolicited show.
      loading.then((lateAd) {
        if (abandoned) unawaited(lateAd.destroy());
      }, onError: (Object _) {});
      ad = await loading.timeout(const Duration(seconds: 20));
      _trace('rewarded loaded');
      final done = Completer<AdOutcome>();
      var rewarded = false;
      void finish(AdOutcome outcome) {
        if (!done.isCompleted) done.complete(outcome);
      }

      await ad.setAdEventListener(
        eventListener: RewardedAdEventListener(
          onAdShown: () => _trace('rewarded shown'),
          onRewarded: (_) {
            _trace('rewarded earned');
            rewarded = true;
          },
          onAdDismissed: () {
            _trace('rewarded dismissed earned=$rewarded');
            finish(rewarded ? AdOutcome.rewarded : AdOutcome.dismissed);
          },
          onAdFailedToShow: (error) {
            _trace('rewarded failed to show: $error');
            finish(AdOutcome.unavailable);
          },
        ),
      );
      // Listener is registered before show so fast SDK events cannot be missed.
      if (!allowed || (canShow != null && !canShow())) {
        return AdOutcome.dismissed;
      }
      await ad.show();
      return await done.future;
    } catch (error) {
      _trace('rewarded request failed: $error');
      rethrow;
    } finally {
      abandoned = true;
      if (ad != null) await ad.destroy();
      loader.destroy();
    }
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    if (!allowed || !audience.adsEnabled || !canShow()) return false;
    await _initialize();
    if (!allowed || !canShow()) return false;
    final loader = InterstitialAdLoader();
    InterstitialAd? ad;
    var abandoned = false;
    try {
      final loading = loader.loadAd(
        adRequest: const AdRequest(adUnitId: YandexAdUnits.interstitial),
      );
      loading.then((lateAd) {
        if (abandoned) unawaited(lateAd.destroy());
      }, onError: (Object _) {});
      ad = await loading.timeout(const Duration(seconds: 20));
      final done = Completer<bool>();
      var shown = false;
      void finish(bool result) {
        if (!done.isCompleted) done.complete(result);
      }

      await ad.setAdEventListener(
        eventListener: InterstitialAdEventListener(
          onAdShown: () {
            shown = true;
          },
          onAdDismissed: () => finish(shown),
          onAdFailedToShow: (_) => finish(false),
        ),
      );
      // Loading/listener setup may finish after the result was closed.
      // Recheck immediately before the native SDK presentation, without an await.
      if (!allowed || !audience.adsEnabled || !canShow()) return false;
      await ad.show();
      return await done.future;
    } finally {
      abandoned = true;
      if (ad != null) await ad.destroy();
      loader.destroy();
    }
  }
}
