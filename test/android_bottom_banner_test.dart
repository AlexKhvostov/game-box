import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/bottom_banner_config.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/ui/android_bottom_banner.dart';

class NoFullscreenAds implements AdsDriver {
  Completer<bool>? interstitial;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async =>
      AdOutcome.unavailable;
  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      interstitial?.future ?? false;
}

class FakeBanner extends BottomBannerSession {
  @override
  bool loaded = false;
  @override
  bool failed = false;
  bool closed = false;
  String? unit;
  @override
  Widget get view => SizedBox(
    key: const ValueKey('native-banner'),
    height: loaded ? 50 : 1,
    width: 360,
  );
  @override
  Future<void> load(String unit) async {
    this.unit = unit;
  }

  void complete({bool error = false}) {
    failed = error;
    loaded = !error;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    closed = true;
    dispose();
  }
}

void main() {
  test(
    'live placement requires both enabled flag and a separate valid unit',
    () {
      expect(const BottomBannerSettings().configured, false);
      expect(const BottomBannerSettings(enabled: true).configured, false);
      expect(
        const BottomBannerSettings(
          enabled: true,
          adUnitId: 'demo-banner-yandex',
        ).configured,
        false,
      );
      expect(
        const BottomBannerSettings(
          enabled: true,
          adUnitId: 'R-M-123-3',
        ).configured,
        true,
      );
      expect(
        const BottomBannerSettings(adUnitId: 'R-M-123-3').configured,
        false,
      );
    },
  );

  test(
    'RC fetches once concurrently, preserves state on failure, ignores late dispose',
    () async {
      var calls = 0;
      var pending = Completer<BottomBannerSettings>();
      final config = BottomBannerConfig(
        fetch: () {
          calls++;
          return pending.future;
        },
      );
      final first = config.refresh();
      final second = config.refresh();
      expect(calls, 1);
      pending.complete(const BottomBannerSettings(enabled: true));
      await Future.wait([first, second]);
      expect(config.settings.enabled, true);
      pending = Completer<BottomBannerSettings>();
      final failing = config.refresh();
      pending.completeError(StateError('offline'));
      await failing;
      expect(config.settings.enabled, true);
      pending = Completer<BottomBannerSettings>();
      final late = config.refresh();
      config.dispose();
      pending.complete(const BottomBannerSettings());
      await late;
    },
  );

  Future<
    ({
      BottomBannerConfig config,
      AudiencePolicy audience,
      AdsService ads,
      List<FakeBanner> sessions,
      ValueNotifier<bool> active,
      Future<void> Function(bool) configure,
    })
  >
  mount(
    WidgetTester tester, {
    bool enabled = true,
    bool consent = true,
    bool adult = true,
    int installDelaySec = 0,
    EconomyStore? economy,
    Future<void> Function()? initialize,
  }) async {
    SharedPreferences.setMockInitialValues({
      AudiencePolicy.storageKey:
          (adult ? AgeBand.adult18plus : AgeBand.under18).name,
      AudiencePolicy.adDataConsentKey: consent,
    });
    final audience = AudiencePolicy();
    await audience.load();
    final config = BottomBannerConfig(
      fetch: () async => BottomBannerSettings(
        enabled: enabled,
        installDelaySec: installDelaySec,
      ),
    );
    await config.refresh();
    final ads = AdsService(NoFullscreenAds(), audience: audience);
    final sessions = <FakeBanner>[];
    final active = ValueNotifier(true);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: config),
          ChangeNotifierProvider.value(value: audience),
          ChangeNotifierProvider.value(value: ads),
          if (economy != null) ChangeNotifierProvider.value(value: economy),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (_, value, _) => AndroidBottomBanner(
                    active: value,
                    initialize: initialize ?? () async {},
                    createSession: (_) {
                      final session = FakeBanner();
                      sessions.add(session);
                      return session;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      config.dispose();
      ads.dispose();
      audience.dispose();
      active.dispose();
    });
    return (
      config: config,
      audience: audience,
      ads: ads,
      sessions: sessions,
      active: active,
      configure: (value) async {
        enabled = value;
        await config.refresh();
      },
    );
  }

  testWidgets('disabled build or RC never requests an ad', (tester) async {
    final f = await mount(
      tester,
      enabled: AudiencePolicy.adsBuildEnabled ? false : true,
    );
    expect(f.sessions, isEmpty);
    expect(find.byKey(const ValueKey('android-bottom-banner')), findsNothing);
  });

  group(
    'demo-enabled privacy and lifecycle',
    skip: !AudiencePolicy.demoAds,
    () {
      testWidgets('no request for a minor', (tester) async {
        final f = await mount(tester, adult: false);
        expect(f.sessions, isEmpty);
      });
      testWidgets('no request without consent', (tester) async {
        final f = await mount(tester, consent: false);
        expect(f.sessions, isEmpty);
      });
      testWidgets(
        'banner waits for installation delay before any SDK session is created',
        (tester) async {
          var now = DateTime.utc(2026, 10, 27);
          final economy = EconomyStore(
            now: () => now,
            installedAt: now,
            storagePrefix: 'banner_delay_',
          );
          await economy.load();
          final f = await mount(tester, installDelaySec: 60, economy: economy);
          expect(f.sessions, isEmpty);
          now = now.add(const Duration(seconds: 59));
          await tester.pump(const Duration(seconds: 59));
          expect(f.sessions, isEmpty);
          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
          expect(f.sessions.length, 1);
          economy.dispose();
        },
      );
      testWidgets('loaded banner, then RC off closes ad and collapses space', (
        tester,
      ) async {
        final f = await mount(tester);
        final ad = f.sessions.single;
        expect(ad.unit, 'demo-banner-yandex');
        ad.complete();
        await tester.pump();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('android-bottom-banner')))
              .height,
          58,
        );
        await f.configure(false);
        await tester.pump();
        await tester.pump();
        expect(ad.closed, true);
        expect(
          find.byKey(const ValueKey('android-bottom-banner')),
          findsNothing,
        );
      });
      testWidgets('consent withdrawal closes native view immediately', (
        tester,
      ) async {
        final f = await mount(tester);
        final ad = f.sessions.single;
        ad.complete();
        await tester.pump();
        await f.audience.setAdDataConsent(false);
        await tester.pump();
        await tester.pump();
        expect(ad.closed, true);
        expect(find.byKey(const ValueKey('native-banner')), findsNothing);
      });
      testWidgets('failed load hides space; does not spin retry requests', (
        tester,
      ) async {
        final f = await mount(tester);
        f.sessions.single.complete(error: true);
        await tester.pump(const Duration(seconds: 20));
        expect(f.sessions.length, 1);
        expect(
          find.byKey(const ValueKey('android-bottom-banner')),
          findsNothing,
        );
      });
      testWidgets(
        'route deactivation closes, reactivation loads a fresh banner',
        (tester) async {
          final f = await mount(tester);
          final first = f.sessions.single;
          f.active.value = false;
          await tester.pump();
          await tester.pump();
          expect(first.closed, true);
          f.active.value = true;
          await tester.pump();
          await tester.pump();
          expect(f.sessions.length, 2);
        },
      );
      testWidgets('foreground return loads a fresh banner', (tester) async {
        final f = await mount(tester);
        final first = f.sessions.single;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump();
        expect(first.closed, true);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(f.sessions.length, 2);
        f.config.pause();
      });
      testWidgets('fullscreen ad suspends banner until dismissed', (
        tester,
      ) async {
        final f = await mount(tester);
        final first = f.sessions.single;
        final driver = f.ads.driver as NoFullscreenAds;
        driver.interstitial = Completer<bool>();
        final showing = f.ads.showInterstitial(canShow: () => true);
        await tester.pump();
        await tester.pump();
        expect(first.closed, true);
        driver.interstitial!.complete(true);
        await showing;
        await tester.pump();
        await tester.pump();
        expect(f.sessions.length, 2);
      });
      testWidgets('RC OFF during initialization prevents a late SDK request', (
        tester,
      ) async {
        final initializing = Completer<void>();
        final f = await mount(tester, initialize: () => initializing.future);
        await f.configure(false);
        await tester.pump();
        initializing.complete();
        await tester.pump();
        await tester.pump();
        expect(f.sessions, isEmpty);
        expect(
          find.byKey(const ValueKey('android-bottom-banner')),
          findsNothing,
        );
      });
      testWidgets('RC OFF ON OFF ON creates only fresh banner sessions', (
        tester,
      ) async {
        final f = await mount(tester, enabled: false);
        expect(f.sessions, isEmpty);
        await f.configure(true);
        await tester.pump();
        await tester.pump();
        final first = f.sessions.single;
        await f.configure(false);
        await tester.pump();
        await tester.pump();
        expect(first.closed, true);
        expect(find.byKey(const ValueKey('native-banner')), findsNothing);
        await f.configure(true);
        await tester.pump();
        await tester.pump();
        expect(f.sessions.length, 2);
        expect(identical(first, f.sessions.last), false);
      });
      testWidgets('late initialization cannot load after switch off', (
        tester,
      ) async {
        final initializing = Completer<void>();
        final f = await mount(tester, initialize: () => initializing.future);
        f.active.value = false;
        await tester.pump();
        initializing.complete();
        await tester.pump();
        await tester.pump();
        expect(f.sessions, isEmpty);
      });
    },
  );
}
