import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/rewarded_ad_guide.dart';
import 'simple_energy_test.dart' as fixture;

class _Driver implements AdsDriver {
  int calls = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    calls++;
    return AdOutcome.dismissed;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

class _FailConsentStore extends InMemorySharedPreferencesStore {
  _FailConsentStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(AudiencePolicy.adDataConsentKey)) return false;
    return super.setValue(valueType, key, value);
  }
}

final captureKey = GlobalKey();
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('D001_CAPTURE')) return;
  await t.pump(const Duration(milliseconds: 1700));
  final boundary =
      captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('docs/release-evidence/d001-android-ad-age-20261025');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<(AudiencePolicy, EconomyStore, _Driver, List<String>)> mount(
  WidgetTester t, {
  AgeBand? age,
  bool claimed = false,
  bool fail = false,
  String language = 'ru',
  double scale = 1,
  EnergyPage page = EnergyPage.video,
  Completer<void>? pending,
}) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  SharedPreferences.setMockInitialValues({
    if (age != null) AudiencePolicy.storageKey: age.name,
  });
  final policy = AudiencePolicy();
  await policy.load();
  final e = EconomyStore(storagePrefix: 'd001_test_');
  await e.load();
  var wallet = fixture.simpleWallet();
  if (claimed) wallet['claimed'] = ['energy_ad_unavailable_bonus'];
  await e.applyServerWallet(
    wallet,
    owner: 'android:1',
    serverNow: fixture.stamp,
  );
  final ops = <String>[];
  e.sendEnergyOperation = (kind, args) async {
    ops.add(kind);
    if (kind == 'energy_ad_unavailable_bonus') {
      expect(args, isEmpty);
      if (fail) throw StateError('offline');
      if (pending != null) await pending.future;
      if (!(wallet['claimed'] as List).contains(kind)) {
        wallet = {
          ...wallet,
          'energy': (wallet['energy'] as int) + 20,
          'claimed': [...(wallet['claimed'] as List), kind],
        };
      }
      await e.applyServerWallet(
        wallet,
        owner: 'android:1',
        serverNow: fixture.stamp,
      );
    }
  };
  final driver = _Driver(), ads = AdsService(driver, audience: policy);
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AudiencePolicy>.value(value: policy),
        ChangeNotifierProvider<EconomyStore>.value(value: e),
        ChangeNotifierProvider<AdsService>.value(value: ads),
      ],
      child: RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: buildGameTheme(),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showSimpleEnergyWindow(c, page: page),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    ads.dispose();
    policy.dispose();
    e.dispose();
  });
  await t.tap(find.text('open'));
  if (pending == null) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  return (policy, e, driver, ops);
}

Future<void> selectAge(WidgetTester t, bool adult) async {
  await t.tap(find.byKey(ValueKey(adult ? 'age-adult18plus' : 'age-under18')));
  await t.pump();
  await t.tap(find.byKey(const ValueKey('age-continue')));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final folder = Platform.environment['RANKING_FONT_DIR'];
    if (folder == null) return;
    final font = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(await File('$folder/$name').readAsBytes()),
        ),
      );
    }
    await font.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                Platform.environment['RANKING_ICON_FONT'] ??
                    '$folder/materialicons-regular.otf',
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  testWidgets(
    'ordinary energy entry asks age before instructions and Back leaves age unknown',
    (t) async {
      final (policy, e, driver, ops) = await mount(t, page: EnergyPage.energy);
      await t.tap(find.byKey(const ValueKey('simple-energy-video')));
      await t.pumpAndSettle();
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(find.byKey(const ValueKey('age-under18')), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(policy.needsSelection, isTrue);
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(e.energy, 50);
      expect(driver.calls, 0);
      expect(ops, isEmpty);
    },
  );
  testWidgets(
    'closing while the bonus is pending does not reopen the window or repeat the claim',
    (t) async {
      final pending = Completer<void>();
      final (_, e, _, ops) = await mount(
        t,
        age: AgeBand.under18,
        pending: pending,
      );
      expect(e.energy, 50);
      expect(e.adUnavailableBonusClaimed, isFalse);
      await t.tap(find.byKey(const ValueKey('simple-energy-close')));
      await t.pumpAndSettle();
      pending.complete();
      await t.pumpAndSettle();
      expect(e.energy, 70);
      expect(ops.length, 1);
      expect(find.byKey(const ValueKey('simple-energy-window')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown age is asked before any instruction; cancel and retry do not grant or load ads',
    (t) async {
      final (_, e, driver, ops) = await mount(t);
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(find.byKey(const ValueKey('age-adult18plus')), findsOneWidget);
      await capture(t, 'unknown-age');
      await t.tap(find.byKey(const ValueKey('age-cancel')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('ad-select-age')), findsOneWidget);
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(ops, isEmpty);
      expect(e.energy, 50);
      expect(driver.calls, 0);
      await t.tap(find.byKey(const ValueKey('ad-select-age')));
      await t.pumpAndSettle();
      await selectAge(t, true);
      expect(find.byType(RewardedAdGuide), findsOneWidget);
      expect(find.byKey(const ValueKey('simple-watch-video')), findsOneWidget);
      expect(driver.calls, 0);
      expect(ops, isEmpty);
      await capture(t, 'adult-guide');
    },
  );
  for (final previousConsent in <bool?>[null, false, true]) {
    testWidgets(
      'only explicit guide launch saves consent, including after withdrawal: $previousConsent',
      (t) async {
        final (policy, _, driver, ops) = await mount(
          t,
          age: AgeBand.adult18plus,
        );
        if (previousConsent != null) {
          await policy.setAdDataConsent(previousConsent);
          await t.pumpAndSettle();
        }
        // Entering the guide and reading details cannot change the stored choice.
        expect(policy.adDataConsent, previousConsent);
        expect(driver.calls, 0);
        final details = find.byKey(const ValueKey('rewarded-ad-data-info'));
        await t.ensureVisible(details);
        await t.tap(details);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('rewarded-ad-data-details')),
          findsOneWidget,
        );
        expect(policy.adDataConsent, previousConsent);
        expect(ops, isEmpty);
        await t.tap(find.text('Понятно'));
        await t.pumpAndSettle();
        final video = find.byKey(const ValueKey('simple-watch-video'));
        await t.ensureVisible(video);
        await t.tap(video);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ad-data-consent-dialog')),
          findsNothing,
        );
        expect(policy.adDataConsent, true);
        expect(driver.calls, 1);
        expect(ops, ['rewarded_ad_start']);
        final reload = AudiencePolicy();
        await reload.load();
        expect(reload.adDataConsent, true);
        reload.dispose();
        expect(t.takeException(), null);
      },
      skip: !AudiencePolicy.adsBuildEnabled,
    );
    testWidgets('Not now preserves advertising choice: $previousConsent', (
      t,
    ) async {
      final (policy, _, driver, ops) = await mount(t, age: AgeBand.adult18plus);
      if (previousConsent != null) {
        await policy.setAdDataConsent(previousConsent);
      }
      await t.pumpAndSettle();
      final cancel = find.widgetWithText(TextButton, 'Не сейчас');
      await t.ensureVisible(cancel);
      await t.tap(cancel);
      await t.pumpAndSettle();
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(policy.adDataConsent, previousConsent);
      expect(driver.calls, 0);
      expect(ops, isEmpty);
    });
  }
  testWidgets(
    'failed consent save explains the error and never contacts ads',
    (t) async {
      final (policy, _, driver, ops) = await mount(t, age: AgeBand.adult18plus);
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailConsentStore();
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final video = find.byKey(const ValueKey('simple-watch-video'));
      await t.ensureVisible(video);
      await t.tap(video);
      await t.pumpAndSettle();
      expect(policy.adDataConsent, false);
      expect(driver.calls, 0);
      expect(ops, isEmpty);
      expect(
        find.text('Не удалось сохранить согласие. Повторите попытку.'),
        findsOneWidget,
      );
    },
    skip: !AudiencePolicy.adsBuildEnabled,
  );

  testWidgets(
    'disabled ad build cannot save guide consent',
    (t) async {
      final (policy, _, driver, ops) = await mount(t, age: AgeBand.adult18plus);
      final video = find.byKey(const ValueKey('simple-watch-video'));
      await t.ensureVisible(video);
      await t.tap(video);
      await t.pumpAndSettle();
      expect(policy.adDataConsent, null);
      expect(driver.calls, 0);
      expect(ops, isEmpty);
    },
    skip: AudiencePolicy.adsBuildEnabled,
  );

  testWidgets(
    'under18 gets explanation and one confirmed bonus; reopening and age correction cannot repeat',
    (t) async {
      final (policy, e, driver, ops) = await mount(t);
      await selectAge(t, false);
      expect(find.byType(RewardedAdGuide), findsNothing);
      expect(find.byKey(const ValueKey('simple-watch-video')), findsNothing);
      expect(e.energy, 70);
      expect(ops, ['energy_ad_unavailable_bonus']);
      expect(driver.calls, 0);
      await capture(t, 'under18-bonus');
      await policy.correct(AgeBand.adult18plus);
      await t.pumpAndSettle();
      expect(find.byType(RewardedAdGuide), findsOneWidget);
      await policy.correct(AgeBand.under18);
      await t.pumpAndSettle();
      expect(e.energy, 70);
      expect(ops.length, 1);
      await t.tap(find.byKey(const ValueKey('simple-energy-close')));
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(ops.length, 1);
      expect(e.energy, 70);
      await t.tap(find.byKey(const ValueKey('ad-energy-alternatives')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('simple-bonus-orb')), findsOneWidget);
    },
  );
  testWidgets('saved underage after restart never claims again', (t) async {
    final (_, _, driver, ops) = await mount(
      t,
      age: AgeBand.age16to17,
      claimed: true,
    );
    expect(find.byKey(const ValueKey('ad-age-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('age-under18')), findsNothing);
    expect(ops, isEmpty);
    expect(driver.calls, 0);
  });
  testWidgets('offline does not pretend a bonus is received and offers retry', (
    t,
  ) async {
    final (_, e, driver, ops) = await mount(
      t,
      age: AgeBand.under18,
      fail: true,
    );
    expect(e.energy, 50);
    expect(e.adUnavailableBonusClaimed, false);
    expect(
      find.byKey(const ValueKey('ad-unavailable-bonus-retry')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('ad-unavailable-bonus-retry')));
    await t.pumpAndSettle();
    expect(ops.length, 2);
    expect(e.energy, 50);
    expect(driver.calls, 0);
    await capture(t, 'under18-offline');
  });
  for (final language in ['ru', 'en']) {
    for (final scale in [1.0, 1.4]) {
      testWidgets(
        'underage explanation and alternatives fit 320px $language $scale',
        (t) async {
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await mount(
            t,
            age: AgeBand.under18,
            language: language,
            scale: scale,
          );
          await t.ensureVisible(
            find.byKey(const ValueKey('ad-energy-alternatives')),
          );
          expect(t.takeException(), isNull);
          await capture(t, 'under18-$language-$scale');
        },
      );
    }
  }
}
