import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AgeBand {
  under6,
  age6to8,
  age9to12,
  age13to15,
  age16to17,
  age18to20,
  age21plus,
  unknown,
  // Broad declarations from the two-answer UI; legacy named values stay intact.
  under18,
  adult18plus,
}

/// Device-only declaration, never included in account, score or ad requests.
/// No birthday is collected. The declaration admits client resource actions. Gameplay,
/// account recovery and automatic scores do not depend on this declaration.
class AudiencePolicy extends ChangeNotifier {
  // Demo ads require an intentional internal test build. Store candidates are off.
  static const adsBuildEnabled =
      bool.fromEnvironment('YANDEX_DEMO_ADS') &&
      !bool.fromEnvironment('YANDEX_LIVE_ADS');
  static const storageKey = 'audience_age_band_v1';
  SharedPreferences? _prefs;
  AgeBand? _band;
  bool _adsEnabled = false;
  bool _rewardedRequested = false;
  bool _revoked = false;

  AgeBand? get band => _band;
  bool get needsSelection => _band == null || _band == AgeBand.unknown;
  bool get canPlayLocally => true;
  bool get isAdEligibleAge =>
      _band == AgeBand.age18to20 ||
      _band == AgeBand.age21plus ||
      _band == AgeBand.adult18plus;
  bool get adsEnabled =>
      adsBuildEnabled && isAdEligibleAge && _adsEnabled && !_revoked;
  // A deliberate reward-button tap starts only rewarded ads. It does not
  // authorize automatic interstitials or personalized data processing.
  bool get rewardedAdsEnabled =>
      adsEnabled ||
      (adsBuildEnabled && isAdEligibleAge && _rewardedRequested && !_revoked);
  bool get revokedThisSession => _revoked;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final value = _prefs!.get(storageKey);
    _band = value == null
        ? null
        : AgeBand.values.where((b) => b.name == value).firstOrNull ??
              AgeBand.unknown;
    // Advertising permission is deliberately session-only and off at launch.
    notifyListeners();
  }

  Future<void> select(AgeBand band) async {
    if (_band != null && _band != AgeBand.unknown) {
      return; // Initial resource prompts never overwrite a saved declaration.
    }
    final prefs = _prefs;
    if (prefs == null) throw StateError('Load audience before selecting');
    if (!await prefs.setString(storageKey, band.name)) {
      throw StateError('Could not save audience');
    }
    _band = band;
    notifyListeners();
  }

  /// Explicit correction in Profile; never granted by a resource prompt/reset.
  Future<void> correct(AgeBand band) async {
    final prefs = _prefs;
    if (prefs == null) throw StateError('Load audience before correcting');
    if (!await prefs.setString(storageKey, band.name)) {
      throw StateError('Could not save audience');
    }
    _band = band;
    _adsEnabled = false;
    _rewardedRequested = false;
    notifyListeners();
  }

  void allowAdsForSession() {
    if (!isAdEligibleAge || _revoked) return;
    _adsEnabled = true;
    notifyListeners();
  }

  void requestRewardedAdsForSession() {
    if (!isAdEligibleAge || _revoked) return;
    _rewardedRequested = true;
    notifyListeners();
  }

  void revokeAdsForSession() {
    _adsEnabled = false;
    _rewardedRequested = false;
    _revoked = true;
    notifyListeners();
  }
}
