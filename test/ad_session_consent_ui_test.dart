import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/play_billing_service.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/ad_privacy_settings.dart';
import 'package:game_box/ui/watch_rewarded_ad.dart';

class _Driver implements AdsDriver {
  int rewardedCalls = 0, interstitialCalls = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    rewardedCalls++;
    return AdOutcome.dismissed;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    interstitialCalls++;
    return false;
  }
}

Future<(AudiencePolicy, _Driver, AdsService)> _mount(
  WidgetTester t, {
  AgeBand? age = AgeBand.adult18plus,
  bool preview = false,
  bool consent = false,
  bool settings = false,
  bool compact = false,
}) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  SharedPreferences.setMockInitialValues({
    if (age != null) AudiencePolicy.storageKey: age.name,
  });
  final policy = AudiencePolicy();
  await policy.load();
  if (consent) policy.allowAdsForSession();
  final driver = _Driver();
  final ads = AdsService(driver, audience: policy);
  final e = EconomyStore(storagePrefix: 'session_ads_ui_');
  await e.load();
  await e.enableEnergyPreview();
  // This UI fixture dismisses every SDK presentation. Only the server's
  // pre-view authorization is needed; no wallet credit is simulated.
  e.sendEnergyOperation = (kind, args) async {
    expect(kind, 'rewarded_ad_start');
    expect(args['sessionId'], matches(RegExp(r'^[a-f0-9]{64}$')));
  };
  final account = MobileAccount();
  final billing = PlayBillingService(account, testServicePreview: preview);
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AudiencePolicy>.value(value: policy),
        ChangeNotifierProvider<AdsService>.value(value: ads),
        ChangeNotifierProvider<EconomyStore>.value(value: e),
        ChangeNotifierProvider<PlayBillingService>.value(value: billing),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) => Column(
              children: [
                TextButton(
                  onPressed: () => watchRewardedAd(c),
                  child: const Text('video'),
                ),
                TextButton(
                  onPressed: () async {
                    await Future.wait([
                      ensureAdsForSession(c),
                      ensureAdsForSession(c),
                    ]);
                  },
                  child: const Text('two prompts'),
                ),
                if (settings) AdPrivacySettings(compact: compact),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    policy.dispose();
    e.dispose();
    billing.dispose();
    account.dispose();
  });
  return (policy, driver, ads);
}

void main() {
  testWidgets(
    'Compact privacy opens consent and preserves cancel, revoke and session lock',
    (t) async {
      await t.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final (policy, driver, _) = await _mount(
        t,
        settings: true,
        compact: true,
      );
      final row = find.byKey(const ValueKey('ad-privacy-compact'));
      expect(find.byKey(const ValueKey('ad-privacy-switch')), findsNothing);
      expect(t.getSize(row).height, lessThanOrEqualTo(56));
      expect(find.text('Сейчас выключена'), findsOneWidget);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('Реклама в этом сеансе'), findsNWidgets(2));
      expect(policy.adsEnabled, isFalse);
      expect(driver.rewardedCalls, 0);
      await t.tap(find.text('Без рекламы'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isFalse);
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(find.text('Включить'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isTrue);
      expect(driver.rewardedCalls, 0);
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(find.text('Закрыть'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isTrue);
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(find.text('Выключить запросы'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isFalse);
      expect(policy.revokedThisSession, isTrue);
      await t.tap(row);
      await t.pumpAndSettle();
      final disabled = find.ancestor(
        of: find.text('Выключено в сеансе'),
        matching: find.byType(FilledButton),
      );
      expect(t.widget<FilledButton>(disabled).onPressed, isNull);
      expect(
        find.textContaining('Полностью закройте приложение'),
        findsWidgets,
      );
      expect(driver.rewardedCalls, 0);
      expect(driver.interstitialCalls, 0);
      expect(t.takeException(), isNull);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );

  testWidgets(
    'No demo build cannot prompt or invoke advertising SDK',
    (t) async {
      final (policy, driver, _) = await _mount(t);
      await t.tap(find.text('two prompts'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isFalse);
      expect(find.text('Включить рекламу?'), findsNothing);
      expect(driver.rewardedCalls, 0);
    },
    skip: AudiencePolicy.adsBuildEnabled,
  );

  for (final age in [
    AgeBand.under6,
    AgeBand.under18,
    AgeBand.age13to15,
    AgeBand.age16to17,
    AgeBand.unknown,
  ]) {
    testWidgets(
      'Ineligible $age never starts SDK or consents implicitly',
      (t) async {
        final (policy, driver, _) = await _mount(t, age: age, preview: true);
        await t.tap(find.text('video'));
        await t.pumpAndSettle();
        expect(policy.adsEnabled, isFalse);
        expect(driver.rewardedCalls, 0);
        expect(find.text('Включить рекламу?'), findsNothing);
        expect(
          find.byKey(const ValueKey('test-service-unavailable')),
          findsOneWidget,
        );
      },
      skip: !AudiencePolicy.adsBuildEnabled,
    );
  }
  testWidgets(
    'Reward button directly invokes SDK without a second dialog or interstitial opt-in',
    (t) async {
      final (policy, driver, ads) = await _mount(t, settings: true);
      await t.tap(find.text('video'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(policy.rewardedAdsEnabled, isTrue);
      expect(policy.adsEnabled, isFalse);
      expect(driver.rewardedCalls, 1);
      expect(await ads.showInterstitial(canShow: () => true), isFalse);
      expect(driver.interstitialCalls, 0);
      await t.tap(find.text('video'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(driver.rewardedCalls, 2);
      await t.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await t.pumpAndSettle();
      expect(policy.revokedThisSession, isTrue);
      expect(policy.rewardedAdsEnabled, isFalse);
      await t.tap(find.text('video'));
      await t.pumpAndSettle();
      expect(driver.rewardedCalls, 2);
      expect(find.byType(Dialog), findsNothing);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'Decline or cancel explicit settings consent never starts SDK: cancel=$cancel',
      (t) async {
        final (policy, driver, _) = await _mount(
          t,
          preview: true,
          settings: true,
        );
        await t.tap(find.byKey(const ValueKey('ad-privacy-switch')));
        await t.pumpAndSettle();
        if (cancel) {
          await t.binding.handlePopRoute();
        } else {
          await t.tap(find.text('Без рекламы'));
        }
        await t.pumpAndSettle();
        expect(policy.adsEnabled, isFalse);
        expect(driver.rewardedCalls, 0);
        expect(
          find.byKey(const ValueKey('test-service-unavailable')),
          findsNothing,
        );
      },
      skip: !AudiencePolicy.adsBuildEnabled,
    );
  }
  testWidgets(
    'Session revoke prevents a new request or new consent',
    (t) async {
      final (policy, driver, _) = await _mount(t, preview: true, consent: true);
      policy.revokeAdsForSession();
      await t.pump();
      await t.tap(find.text('video'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isFalse);
      expect(driver.rewardedCalls, 0);
      expect(find.text('Включить рекламу?'), findsNothing);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
  testWidgets(
    'Concurrent helpers share one voluntary dialog',
    (t) async {
      final (policy, driver, _) = await _mount(t);
      await t.tap(find.text('two prompts'));
      await t.pumpAndSettle();
      expect(find.text('Включить рекламу?'), findsOneWidget);
      await t.tap(find.text('Включить'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isTrue);
      expect(driver.rewardedCalls, 0);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
  testWidgets(
    'Account switch uses same consent and energy wording',
    (t) async {
      final (policy, driver, _) = await _mount(t, settings: true);
      expect(find.textContaining('за энергию'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await t.pumpAndSettle();
      expect(find.text('Включить рекламу?'), findsOneWidget);
      expect(policy.adsEnabled, isFalse);
      await t.tap(find.text('Включить'));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, isTrue);
      expect(driver.rewardedCalls, 0);
      await t.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await t.pumpAndSettle();
      expect(policy.revokedThisSession, isTrue);
      expect(policy.adsEnabled, isFalse);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
}
