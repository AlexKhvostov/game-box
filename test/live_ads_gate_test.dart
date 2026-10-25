import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/yandex_ads_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'explicit ad build requires saved adult data consent for both formats',
    () async {
      SharedPreferences.setMockInitialValues({});
      final policy = AudiencePolicy();
      await policy.load();
      await policy.select(AgeBand.age21plus);
      const live = bool.fromEnvironment('YANDEX_LIVE_ADS');
      const demo = bool.fromEnvironment('YANDEX_DEMO_ADS');
      final driver = YandexAdsDriver(audience: policy);
      expect(policy.rewardedAdsEnabled, false);
      expect(driver.allowed, false);
      // A reward tap cannot manufacture data consent.
      expect(policy.adDataConsent, null);
      await policy.setAdDataConsent(true);
      expect(policy.rewardedAdsEnabled, demo != live);
      expect(policy.adsEnabled, demo != live);
      expect(driver.allowed, demo != live);
      expect(
        YandexAdUnits.rewarded,
        live ? 'R-M-20184253-1' : 'demo-rewarded-yandex',
      );
      expect(
        YandexAdUnits.interstitial,
        live ? 'R-M-20184253-2' : 'demo-interstitial-yandex',
      );
      await policy.setAdDataConsent(true);
      expect(policy.adsEnabled, demo != live);
      await policy.setAdDataConsent(false);
      expect(driver.allowed, false);
      expect(driver.allowed, false);
      await policy.correct(AgeBand.under18);
      expect(driver.allowed, false);
      policy.dispose();
    },
  );
}
