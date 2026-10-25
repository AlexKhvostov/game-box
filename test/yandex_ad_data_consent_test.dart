import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/yandex_ads_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SDK receives only explicit data consent, before init; revoke sends false',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      const channel = MethodChannel('yandex_mobileads.mobileAds');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'initialize') {
              throw PlatformException(code: 'qa_stop_before_ad_load');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final policy = AudiencePolicy();
      await policy.load();
      await policy.select(AgeBand.adult18plus);
      final driver = YandexAdsDriver(audience: policy);
      final ads = AdsService(driver, audience: policy);
      expect(await ads.showInterstitial(canShow: () => true), false);
      expect(calls, isEmpty);
      await policy.setAdDataConsent(true);
      expect(await ads.showInterstitial(canShow: () => true), false);
      expect(calls.map((c) => c.method), [
        'setUserConsent',
        'setLocationTracking',
        'setAgeRestricted',
        'initialize',
      ]);
      expect(calls.first.arguments, true);
      expect(calls[1].arguments, false);
      await policy.setAdDataConsent(false);
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'setUserConsent');
      expect(calls.last.arguments, false);
      ads.dispose();
      policy.dispose();
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
}
