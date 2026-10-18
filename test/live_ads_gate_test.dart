import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/yandex_ads_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('live flag alone cannot activate unreviewed production ads', () async {
    SharedPreferences.setMockInitialValues({});
    final policy = AudiencePolicy();
    await policy.load();
    await policy.select(AgeBand.age21plus);
    policy.allowAdsForSession();
    const live = bool.fromEnvironment('YANDEX_LIVE_ADS');
    const demo = bool.fromEnvironment('YANDEX_DEMO_ADS');
    expect(policy.adsEnabled, demo && !live);
    expect(YandexAdsDriver(audience: policy).allowed, demo && !live);
  });
}
