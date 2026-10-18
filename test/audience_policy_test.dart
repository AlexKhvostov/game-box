import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/yandex_ads_driver.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:game_box/ui/ad_privacy_settings.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/domain/gameplay_config.dart';

class _Driver implements AdsDriver {
  int calls = 0;
  final reward = Completer<AdOutcome>();
  final loaded = Completer<void>();
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) {
    calls++;
    return reward.future;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async {
    calls++;
    await loaded.future;
    return canShow();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final band in [
    AgeBand.age6to8,
    AgeBand.unknown,
    if (!AudiencePolicy.adsBuildEnabled) AgeBand.age21plus,
  ]) {
    testWidgets(
      '$band has no ad switch or reward button; daily rewards remain',
      (tester) async {
        final policy = AudiencePolicy();
        await policy.load();
        await policy.select(band);
        final economy = EconomyStore();
        await economy.load();
        final driver = _Driver();
        final ads = AdsService(driver, audience: policy);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: policy),
              ChangeNotifierProvider.value(value: economy),
              ChangeNotifierProvider.value(value: ads),
              Provider.value(value: GameplayConfig()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const AdPrivacySettings(),
                      TextButton(
                        onPressed: () => showCrystalsSheet(context),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(const ValueKey('ad-privacy-switch')), findsNothing);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('shop-header-watch-ad')),
          findsNothing,
        );
        expect(find.text('Daily'), findsWidgets);
        expect(driver.calls, 0);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        ads.dispose();
        economy.dispose();
        policy.dispose();
      },
    );
  }

  for (final band in [null, ...AgeBand.values]) {
    test('no SDK calls or credit before permission: $band', () async {
      final policy = AudiencePolicy();
      await policy.load();
      if (band != null) await policy.select(band);
      if (!policy.isAdEligibleAge) policy.allowAdsForSession();
      final driver = _Driver();
      final ads = AdsService(driver, audience: policy);
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      expect((await ads.watchAndClaim(economy)).reward, 0);
      expect(await ads.showInterstitial(canShow: () => true), false);
      expect(driver.calls, 0);
      expect(economy.tokens, before);
      expect(economy.lastWatchAdClaimAt, isNull);

      // Calling the concrete driver directly must also fail before any channel call.
      final nativeCalls = <MethodCall>[];
      const channel = MethodChannel('yandex_mobileads.mobileAds');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call);
            return null;
          });
      final native = YandexAdsDriver(audience: policy);
      expect(await native.showRewarded(), AdOutcome.unavailable);
      expect(await native.showInterstitial(canShow: () => true), false);
      expect(nativeCalls, isEmpty);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      ads.dispose();
      economy.dispose();
      policy.dispose();
    });
  }

  test('age persists, permission does not; game reset cannot up-age', () async {
    final policy = AudiencePolicy();
    await policy.load();
    await policy.select(AgeBand.age6to8);
    await policy.select(AgeBand.age21plus);
    final economy = EconomyStore();
    await economy.load();
    await economy.resetToFreshInstall();
    final reloaded = AudiencePolicy();
    await reloaded.load();
    expect(reloaded.band, AgeBand.age6to8);
    expect(reloaded.adsEnabled, false);
    expect(reloaded.needsSelection, false);
  });

  test(
    'unrecognized group remains local with ads off until declaration',
    () async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: 'invalid',
      });
      final policy = AudiencePolicy();
      await policy.load();
      expect(policy.band, AgeBand.unknown);
      expect(policy.canPlayLocally, true);
      policy.allowAdsForSession();
      expect(policy.adsEnabled, false);
      await policy.select(AgeBand.age21plus);
      expect(policy.isAdEligibleAge, true);
      expect(policy.adsEnabled, false);
    },
  );

  test(
    'adult consent is session-only and revocation stops late reward',
    () async {
      final policy = AudiencePolicy();
      await policy.load();
      await policy.select(AgeBand.age21plus);
      policy.allowAdsForSession();
      expect(policy.adsEnabled, true);
      final nextLaunch = AudiencePolicy();
      await nextLaunch.load();
      expect(nextLaunch.isAdEligibleAge, true);
      expect(nextLaunch.adsEnabled, false);
      final driver = _Driver();
      final ads = AdsService(driver, audience: policy);
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      final pending = ads.watchAndClaim(economy);
      policy.revokeAdsForSession();
      policy.allowAdsForSession();
      driver.reward.complete(AdOutcome.rewarded);
      expect((await pending).reward, 0);
      expect(economy.tokens, before);
      expect(economy.lastWatchAdClaimAt, null);
      expect(policy.adsEnabled, false);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );

  test(
    'revocation discards interstitial that finishes loading later',
    () async {
      final policy = AudiencePolicy();
      await policy.load();
      await policy.select(AgeBand.age21plus);
      policy.allowAdsForSession();
      final driver = _Driver();
      final ads = AdsService(driver, audience: policy);
      final pending = ads.showInterstitial(canShow: () => true);
      expect(driver.calls, 1);
      policy.revokeAdsForSession();
      driver.loaded.complete();
      expect(await pending, false);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );

  for (final language in ['ru', 'en']) {
    testWidgets('profile asks age without advertising hints ($language)', (
      tester,
    ) async {
      final policy = AudiencePolicy();
      await policy.load();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: policy,
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(
              body: Column(
                children: [AudienceProfileSetting(), AdPrivacySettings()],
              ),
            ),
          ),
        ),
      );
      final hints = find.textContaining(
        RegExp('advert|ads|реклам', caseSensitive: false),
      );
      expect(hints, findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-age-edit')));
      await tester.pumpAndSettle();
      expect(hints, findsNothing);
      final choice = find.byKey(const ValueKey('age-under18'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      final confirm = find.byKey(const ValueKey('age-continue'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(language == 'ru' ? 'До 18 лет' : 'Under 18'), findsOneWidget);
      expect(hints, findsNothing);
      expect(find.byKey(const ValueKey('ad-age-setting')), findsNothing);
      expect(policy.band, AgeBand.under18);
      expect(policy.adsEnabled, false);
      expect(tester.takeException(), null);
    });
  }

  testWidgets('neutral age question has no default or advertising hint', (
    tester,
  ) async {
    final policy = AudiencePolicy();
    await policy.load();
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: policy,
        child: MaterialApp(
          home: AudienceGate(
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const Text('Game'),
                    TextButton(
                      onPressed: () => showAudienceSelection(context),
                      child: const Text('Reward'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Game'), findsOneWidget);
    expect(find.byKey(const ValueKey('age-continue')), findsNothing);
    await tester.tap(find.text('Reward'));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('age-continue'));
    await tester.scrollUntilVisible(next, 160);
    expect(tester.widget<FilledButton>(next).onPressed, null);
    expect(
      find.textContaining('advertising', findRichText: true),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('age-under18')));
    await tester.tap(find.byKey(const ValueKey('age-under18')));
    await tester.pump();
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Game'), findsOneWidget);
    expect(find.byKey(const ValueKey('age-access-blocked')), findsNothing);
    expect(policy.band, AgeBand.under18);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'adult permission requires separate disclosure; minors have no switch',
    (tester) async {
      final policy = AudiencePolicy();
      await policy.load();
      await policy.select(AgeBand.age21plus);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: policy,
          child: const MaterialApp(home: Scaffold(body: AdPrivacySettings())),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await tester.pumpAndSettle();
      expect(policy.adsEnabled, false);
      await tester.tap(find.text('No ads'));
      await tester.pumpAndSettle();
      expect(policy.adsEnabled, false);
      await tester.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(policy.adsEnabled, true);
      await tester.tap(find.byKey(const ValueKey('ad-privacy-switch')));
      await tester.pumpAndSettle();
      expect(policy.adsEnabled, false);
      expect(policy.revokedThisSession, true);
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );
}
