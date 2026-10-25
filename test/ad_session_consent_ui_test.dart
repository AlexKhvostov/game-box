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
  if (consent) await policy.setAdDataConsent(true);
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
                      ensureAdDataConsent(c),
                      ensureAdDataConsent(c),
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
  for (final accepted in [true, false]) {
    testWidgets(
      'first video waits for explicit data choice: $accepted',
      (t) async {
        final (policy, driver, _) = await _mount(t, settings: true);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.text('Реклама в этом сеансе'), findsNothing);
        expect(driver.rewardedCalls, 0);
        await t.tap(find.text('video'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ad-data-consent-dialog')),
          findsOneWidget,
        );
        expect(driver.rewardedCalls, 0);
        await t.tap(
          find.byKey(ValueKey(accepted ? 'ad-data-allow' : 'ad-data-decline')),
        );
        await t.pumpAndSettle();
        expect(policy.adDataConsent, accepted);
        expect(driver.rewardedCalls, accepted ? 1 : 0);
        expect(driver.interstitialCalls, 0);
        final reload = AudiencePolicy();
        await reload.load();
        expect(reload.adDataConsent, accepted);
        await t.tap(find.text('video'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ad-data-consent-dialog')),
          findsNothing,
        );
        expect(driver.rewardedCalls, accepted ? 2 : 0);
        expect(t.takeException(), null);
      },
      skip: !AudiencePolicy.adsBuildEnabled,
    );
  }
  testWidgets(
    'Back rejects; repeated requests coalesce into one dialog',
    (t) async {
      final (policy, driver, _) = await _mount(t);
      await t.tap(find.text('two prompts'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ad-data-consent-dialog')),
        findsOneWidget,
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(policy.adDataConsent, false);
      expect(driver.rewardedCalls, 0);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
  testWidgets(
    'data settings revoke and allow again without a session lock',
    (t) async {
      final (policy, driver, _) = await _mount(
        t,
        settings: true,
        consent: true,
      );
      await t.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.tap(find.byKey(const ValueKey('ad-privacy-compact')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ad-data-revoke')));
      await t.pumpAndSettle();
      expect(policy.adDataConsent, false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AudiencePolicy.adDataConsentKey,
        ),
        false,
      );
      await t.tap(find.byKey(const ValueKey('ad-privacy-compact')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ad-data-allow')));
      await t.pumpAndSettle();
      expect(policy.adsEnabled, true);
      expect(driver.rewardedCalls + driver.interstitialCalls, 0);
      expect(t.takeException(), null);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
  for (final age in [null, AgeBand.under18]) {
    testWidgets('ineligible age never asks data or loads SDK: $age', (t) async {
      final (policy, driver, _) = await _mount(t, age: age, settings: true);
      await t.tap(find.text('video'));
      await t.pumpAndSettle();
      expect(policy.adDataConsent, null);
      expect(
        find.byKey(const ValueKey('ad-data-consent-dialog')),
        findsNothing,
      );
      expect(driver.rewardedCalls + driver.interstitialCalls, 0);
    });
  }
  testWidgets(
    'disabled build cannot request ad data or initialize SDK',
    (t) async {
      final (_, driver, _) = await _mount(t);
      await t.tap(find.text('two prompts'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ad-data-consent-dialog')),
        findsNothing,
      );
      expect(driver.rewardedCalls + driver.interstitialCalls, 0);
    },
    skip: AudiencePolicy.adsBuildEnabled,
  );
}
