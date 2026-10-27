import 'app_analytics.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'economy_store.dart';
import 'audience_policy.dart';

enum AdOutcome { rewarded, dismissed, unavailable, busy }

enum AdFailure { disabled, request, confirmation }

abstract interface class AdsDriver {
  Future<AdOutcome> showRewarded({bool Function()? canShow});
  Future<bool> showInterstitial({required bool Function() canShow});
}

abstract interface class AdsPrivacyDriver {
  void updatePrivacy();
  void dispose();
}

/// One fullscreen ad at a time. Yandex onRewarded consumes one server session.
class AdsService extends ChangeNotifier {
  AdsService(this.driver, {required this.audience, this.economy}) {
    audience.addListener(_policyChanged);
    economy?.addListener(_economyChanged);
    _lastSwitches = _switches;
  }
  final AdsDriver driver;
  final AudiencePolicy audience;
  final EconomyStore? economy;
  bool get available =>
      audience.rewardedAdsEnabled &&
      (economy?.advertising.rewardedEnabled ?? true);
  (bool, bool) get _switches =>
      (available, economy?.advertising.automatic.enabled ?? true);
  (bool, bool)? _lastSwitches;
  void _economyChanged() {
    final next = _switches;
    if (_lastSwitches == next) return;
    _lastSwitches = next;
    notifyListeners();
  }

  AdFailure? lastFailure;
  void _policyChanged() {
    final privacy = driver;
    if (privacy is AdsPrivacyDriver) {
      (privacy as AdsPrivacyDriver).updatePrivacy();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    audience.removeListener(_policyChanged);
    economy?.removeListener(_economyChanged);
    final privacy = driver;
    if (privacy is AdsPrivacyDriver) {
      (privacy as AdsPrivacyDriver).dispose();
    }
    super.dispose();
  }

  bool busy = false;

  Future<({AdOutcome outcome, int reward})> watchAndClaim(
    EconomyStore economy, {
    bool Function()? canShow,
  }) async {
    if (busy) return (outcome: AdOutcome.busy, reward: 0);
    lastFailure = null;
    final consentRevision = audience.adConsentRevision;
    bool allowed() =>
        available &&
        audience.adConsentRevision == consentRevision &&
        (canShow?.call() ?? true);
    if (!allowed() || !economy.canClaimWatchAd) {
      AppAnalytics.event('ad_result', {
        'format': 'rewarded',
        'status': 'unavailable',
      });
      lastFailure = AdFailure.disabled;
      return (outcome: AdOutcome.unavailable, reward: 0);
    }
    busy = true;
    notifyListeners();
    var confirming = false;
    var reportedOutcome = false;
    try {
      final rewardOwner = economy.energyOwner;
      String? sessionId;
      if (economy.energyEnabled) {
        // Persist/confirm authorization before loading an ad. A failed start
        // must never make a player watch a video that cannot be credited.
        final random = Random.secure();
        sessionId = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        confirming = true;
        await economy.performEnergyOperation('rewarded_ad_start', {
          'sessionId': sessionId,
        });
        confirming = false;
        if (!allowed() || economy.energyOwner != rewardOwner) {
          return (outcome: AdOutcome.dismissed, reward: 0);
        }
      }
      final outcome = await driver.showRewarded(canShow: allowed);
      AppAnalytics.event('ad_result', {
        'format': 'rewarded',
        'status': outcome.name,
      });
      reportedOutcome = true;
      if (outcome == AdOutcome.unavailable) lastFailure = AdFailure.request;
      var reward = 0;
      if (audience.rewardedAdsEnabled &&
          audience.adConsentRevision == consentRevision &&
          outcome == AdOutcome.rewarded) {
        if (economy.energyEnabled) {
          // A fullscreen SDK can outlive the old signed-in profile. Never
          // submit its reward using a different profile's current wallet.
          if (economy.energyOwner != rewardOwner) {
            return (outcome: AdOutcome.dismissed, reward: 0);
          }
          final beforeClaim = economy.confirmedEnergy;
          confirming = true;
          await economy.performEnergyOperation('watch_ad', {
            'sessionId': sessionId!,
          });
          if (economy.energyOwner == rewardOwner) {
            reward = (economy.confirmedEnergy - beforeClaim).clamp(
              0,
              1000000000,
            );
          }
        } else {
          reward = economy.claimWatchAd() ?? 0;
        }
      }
      return (outcome: outcome, reward: reward);
    } catch (_) {
      if (!reportedOutcome) {
        AppAnalytics.event('ad_result', {
          'format': 'rewarded',
          'status': confirming ? 'confirmation_failed' : 'error',
        });
      }
      lastFailure = confirming ? AdFailure.confirmation : AdFailure.request;
      return (outcome: AdOutcome.unavailable, reward: 0);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> showInterstitial({required bool Function() canShow}) async {
    final consentRevision = audience.adConsentRevision;
    final foregroundEpoch = economy?.adForegroundEpoch;
    bool allowed() =>
        audience.adsEnabled &&
        (economy?.advertising.automatic.enabled ?? true) &&
        foregroundEpoch == economy?.adForegroundEpoch &&
        audience.adConsentRevision == consentRevision &&
        canShow();
    if (busy || !allowed()) return false;
    busy = true;
    notifyListeners();
    try {
      final shown = await driver.showInterstitial(canShow: allowed);
      AppAnalytics.event('ad_result', {
        'format': 'interstitial',
        'status': shown ? 'shown' : 'not_shown',
      });
      return shown;
    } catch (_) {
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
