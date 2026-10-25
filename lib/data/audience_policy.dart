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
  // Choose exactly one explicit ad mode. An ordinary build remains ads-off.
  static const demoAds = bool.fromEnvironment('YANDEX_DEMO_ADS');
  static const liveAds = bool.fromEnvironment('YANDEX_LIVE_ADS');
  static const adsBuildEnabled = demoAds != liveAds;
  static const storageKey = 'audience_age_band_v1';
  // A new key: old session permissions never count as informed data consent.
  static const adDataConsentKey = 'yandex_ad_data_consent_v1';
  SharedPreferences? _prefs;
  AgeBand? _band;
  bool? _adDataConsent;
  int _adConsentRevision = 0;

  AgeBand? get band => _band;
  bool get needsSelection => _band == null || _band == AgeBand.unknown;
  bool get canPlayLocally => true;
  bool get isAdEligibleAge =>
      _band == AgeBand.age18to20 ||
      _band == AgeBand.age21plus ||
      _band == AgeBand.adult18plus;
  bool get adsEnabled =>
      adsBuildEnabled && isAdEligibleAge && _adDataConsent == true;
  // Format selection belongs to the placement, never to a global ad switch.
  bool get rewardedAdsEnabled => adsEnabled;
  bool? get adDataConsent => _adDataConsent;
  int get adConsentRevision => _adConsentRevision;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final value = _prefs!.get(storageKey);
    _band = value == null
        ? null
        : AgeBand.values.where((b) => b.name == value).firstOrNull ??
              AgeBand.unknown;
    final choice = _prefs!.get(adDataConsentKey);
    _adDataConsent = choice is bool ? choice : null;
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
    // An age correction never silently restores a previous data consent.
    _adDataConsent = null;
    _adConsentRevision++;
    notifyListeners();
    if (!await prefs.remove(adDataConsentKey)) {
      throw StateError('Could not reset advertising data choice');
    }
    if (!await prefs.setString(storageKey, band.name)) {
      throw StateError('Could not save audience');
    }
    _band = band;
    notifyListeners();
  }

  Future<void> setAdDataConsent(bool granted) async {
    final prefs = _prefs;
    if (prefs == null) throw StateError('Load audience before data consent');
    if (granted && !isAdEligibleAge) return;
    final revision = ++_adConsentRevision;
    // Revoke immediately, even if saving fails. Grant only after durable save.
    _adDataConsent = false;
    notifyListeners();
    if (!await prefs.setBool(adDataConsentKey, granted)) {
      throw StateError('Could not save advertising data choice');
    }
    if (revision != _adConsentRevision) return;
    _adDataConsent = granted && isAdEligibleAge;
    notifyListeners();
  }
}
