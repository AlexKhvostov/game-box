import 'app_analytics.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'ads_service.dart';
import 'ad_presentation_lease.dart';
import 'audience_policy.dart';

abstract final class YandexAdUnits {
  // The publisher's units also serve test ads until Yandex approves the app.
  static const live = AudiencePolicy.liveAds;
  static const rewarded = live ? 'R-M-20184253-1' : 'demo-rewarded-yandex';
  static const interstitial = live
      ? 'R-M-20184253-2'
      : 'demo-interstitial-yandex';
}

class YandexAdsDriver implements AdsDriver, AdsPrivacyDriver {
  YandexAdsDriver({required this.audience});
  final AudiencePolicy audience;
  bool get allowed =>
      AudiencePolicy.adsBuildEnabled && audience.rewardedAdsEnabled;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void>? _initializing;
  bool _privacyConfigured = false;
  @override
  void updatePrivacy() {
    if (_privacyConfigured && !allowed) {
      unawaited(
        YandexAds.setUserConsent(false).catchError((Object _) {
          _trace('privacy update incomplete; new requests remain blocked');
        }),
      );
    }
  }

  @override
  void dispose() {
    if (_privacyConfigured) {
      unawaited(YandexAds.setUserConsent(false).catchError((Object _) {}));
    }
  }

  AdPresentationLease<dynamic>? _nativeLease;
  void _hold(AdPresentationLease<dynamic> lease) {
    _nativeLease = lease;
    unawaited(
      lease.released.then((_) {
        if (identical(_nativeLease, lease)) _nativeLease = null;
      }),
    );
  }

  Future<void> _initialize() async {
    if (!allowed) throw StateError('Ads disabled by audience policy');
    if (!supported) throw UnsupportedError('Android ads only');
    _privacyConfigured = true;
    // Only the separate, saved data choice may be passed as SDK consent.
    await YandexAds.setUserConsent(true);
    if (!allowed) {
      await YandexAds.setUserConsent(false);
      throw StateError('Advertising data consent withdrawn');
    }
    try {
      await (_initializing ??= _init());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _init() async {
    // Location and advertising-ID access stay disabled independently of consent.
    await YandexAds.setLocationTracking(false);
    await YandexAds.setAgeRestricted(false); // Only declared adults reach here.
    if (!allowed) throw StateError('Advertising permission withdrawn');
    await YandexAds.initialize();
  }

  Future<void> _destroy(Future<void> Function() destroy) async {
    try {
      await destroy().timeout(const Duration(seconds: 5));
    } catch (_) {
      _trace('native cleanup incomplete');
    }
  }

  void _trace(String event) {
    if (!YandexAdUnits.live) debugPrint('UNTOUCH_AD $event');
  }

  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    if (_nativeLease?.safeToDispose == false ||
        !allowed ||
        (canShow != null && !canShow())) {
      return AdOutcome.unavailable;
    }
    await _initialize().timeout(const Duration(seconds: 20));
    if (!allowed || (canShow != null && !canShow())) return AdOutcome.dismissed;
    final loader = RewardedAdLoader();
    RewardedAd? ad;
    AdPresentationLease<AdOutcome>? presentation;
    var showRequested = false;
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
      final lease = AdPresentationLease<AdOutcome>(
        fallback: AdOutcome.unavailable,
      );
      presentation = lease;
      _hold(lease);
      var rewarded = false;
      void finish(AdOutcome outcome) {
        lease.finish(outcome);
      }

      await ad
          .setAdEventListener(
            eventListener: RewardedAdEventListener(
              onAdShown: () {
                AppAnalytics.event('ad_started', {
                  'format': 'rewarded',
                  'placement': 'energy',
                });
                _trace('rewarded shown');
              },
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
          )
          .timeout(const Duration(seconds: 10));
      // Listener is registered before show so fast SDK events cannot be missed.
      if (!allowed || (canShow != null && !canShow())) {
        return AdOutcome.dismissed;
      }
      if (lease.safeToDispose) return await lease.result;
      showRequested = true;
      unawaited(
        ad.show().then(
          (_) {},
          onError: (Object error) {
            finish(AdOutcome.unavailable);
          },
        ),
      );
      return await lease.result;
    } catch (error) {
      _trace('rewarded request failed: $error');
      rethrow;
    } finally {
      abandoned = true;
      final lease = presentation;
      if (!showRequested) lease?.finish(AdOutcome.unavailable);
      final retained = ad;
      if (retained != null) {
        if (lease != null && !lease.safeToDispose) {
          unawaited(
            lease.released
                .then((_) => _destroy(retained.destroy))
                .catchError((Object _) {}),
          );
        } else {
          await _destroy(retained.destroy);
        }
      }
      loader.destroy();
    }
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    if (_nativeLease?.safeToDispose == false ||
        !allowed ||
        !audience.adsEnabled ||
        !canShow()) {
      return false;
    }
    await _initialize().timeout(const Duration(seconds: 20));
    if (!allowed || !canShow()) return false;
    final loader = InterstitialAdLoader();
    InterstitialAd? ad;
    AdPresentationLease<bool>? presentation;
    var showRequested = false;
    var abandoned = false;
    try {
      final loading = loader.loadAd(
        adRequest: const AdRequest(adUnitId: YandexAdUnits.interstitial),
      );
      loading.then((lateAd) {
        if (abandoned) unawaited(lateAd.destroy());
      }, onError: (Object _) {});
      ad = await loading.timeout(const Duration(seconds: 20));
      final lease = AdPresentationLease<bool>(fallback: false);
      presentation = lease;
      _hold(lease);
      var shown = false;
      void finish(bool result) {
        lease.finish(result);
      }

      await ad
          .setAdEventListener(
            eventListener: InterstitialAdEventListener(
              onAdShown: () {
                shown = true;
                AppAnalytics.event('ad_started', {
                  'format': 'interstitial',
                  'placement': 'result',
                });
              },
              onAdDismissed: () => finish(shown),
              onAdFailedToShow: (_) => finish(false),
            ),
          )
          .timeout(const Duration(seconds: 10));
      // Loading/listener setup may finish after the between-round break ended.
      // Recheck immediately before the native SDK presentation, without an await.
      if (!allowed || !audience.adsEnabled || !canShow()) return false;
      if (lease.safeToDispose) return await lease.result;
      showRequested = true;
      unawaited(
        ad.show().then(
          (_) {},
          onError: (Object error) {
            finish(false);
          },
        ),
      );
      return await lease.result;
    } finally {
      abandoned = true;
      final lease = presentation;
      if (!showRequested) lease?.finish(false);
      final retained = ad;
      if (retained != null) {
        if (lease != null && !lease.safeToDispose) {
          unawaited(
            lease.released
                .then((_) => _destroy(retained.destroy))
                .catchError((Object _) {}),
          );
        } else {
          await _destroy(retained.destroy);
        }
      }
      loader.destroy();
    }
  }
}
