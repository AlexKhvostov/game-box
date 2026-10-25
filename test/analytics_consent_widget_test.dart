import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/analytics_consent.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/features/profile/analytics_consent_sheet.dart';
import 'package:game_box/features/profile/profile_screen.dart';
import 'package:game_box/l10n/app_localizations.dart';

const boundary = ValueKey('analytics-test-boundary');
Future<AnalyticsConsent> mount(
  WidgetTester tester, {
  String age = 'adult18plus',
  String language = 'ru',
  bool granted = false,
  Size size = const Size(390, 740),
  double scale = 1,
}) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({
    AudiencePolicy.storageKey: age,
    AnalyticsConsent.permissionKey: granted,
  });
  final audience = AudiencePolicy();
  await audience.load();
  final consent = AnalyticsConsent(audience, applyRuntime: (_) async {});
  await consent.load();
  final economy = EconomyStore();
  await economy.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: audience),
        ChangeNotifierProvider.value(value: consent),
        ChangeNotifierProvider.value(value: economy),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    key: const ValueKey('first'),
                    onPressed: () => showAnalyticsFirstQuestion(context),
                    child: const Text('First'),
                  ),
                  TextButton(
                    key: const ValueKey('state'),
                    onPressed: () => showAnalyticsSettings(context),
                    child: const Text('State'),
                  ),
                  TextButton(
                    key: const ValueKey('profile'),
                    onPressed: () => showProfileSheet(context),
                    child: const Text('Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return consent;
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> frame(WidgetTester tester, String name) async {
  final out = Platform.environment['ANALYTICS_EVIDENCE'];
  if (out == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['ANALYTICS_EVIDENCE'] == null) return;
    final font = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File(
              'C:/Users/alexe/develop/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes(),
          ),
        ),
      );
    await icons.load();
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  testWidgets('first question closes immediately on grant, no state screen', (
    tester,
  ) async {
    final c = await mount(tester);
    await tap(tester, 'first');
    expect(
      find.byKey(const ValueKey('analytics-first-question')),
      findsOneWidget,
    );
    await tap(tester, 'analytics-details-open');
    expect(find.byType(AnalyticsDataBlock), findsOneWidget);
    expect(c.enabled, false);
    await tap(tester, 'analytics-info-back');
    await tap(tester, 'analytics-consent-allow');
    expect(c.enabled, true);
    expect(find.byKey(const ValueKey('analytics-state-row')), findsNothing);
    expect(
      find.byKey(const ValueKey('analytics-first-question')),
      findsNothing,
    );
    await tap(tester, 'first');
    expect(
      find.byKey(const ValueKey('analytics-first-question')),
      findsNothing,
    );
  });
  testWidgets('decline and close do not grant and do not show state', (
    tester,
  ) async {
    final c = await mount(tester);
    await tap(tester, 'first');
    await tap(tester, 'analytics-consent-decline');
    expect(c.enabled, false);
    expect(c.promptSeen, true);
    final second = await mount(tester);
    await tap(tester, 'first');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(second.enabled, false);
    expect(second.promptSeen, true);
    expect(find.byKey(const ValueKey('analytics-state-row')), findsNothing);
  });
  for (final age in ['under18', 'unknown']) {
    testWidgets('$age: no initial prompt; settings cannot enable', (
      tester,
    ) async {
      final c = await mount(tester, age: age, granted: true);
      await tap(tester, 'first');
      expect(
        find.byKey(const ValueKey('analytics-first-question')),
        findsNothing,
      );
      await tap(tester, 'state');
      final s = tester.widget<Switch>(
        find.byKey(const ValueKey('analytics-consent-switch')),
      );
      expect(s.value, false);
      expect(s.onChanged, isNull);
      expect(c.enabled, false);
    });
  }
  testWidgets('X closes first question with no grant or follow-up', (
    tester,
  ) async {
    final c = await mount(tester);
    await tap(tester, 'first');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(c.enabled, false);
    expect(c.promptSeen, true);
    expect(
      find.byKey(const ValueKey('analytics-first-question')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('analytics-state-row')), findsNothing);
    await tap(tester, 'first');
    expect(
      find.byKey(const ValueKey('analytics-first-question')),
      findsNothing,
    );
  });
  testWidgets(
    'existing profile has one direct Analytics button; state updates in place',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'profile');
      expect(
        find.byKey(const ValueKey('profile-analytics-open')),
        findsOneWidget,
      );
      await tap(tester, 'profile-analytics-open');
      expect(find.byKey(const ValueKey('analytics-cube-off')), findsOneWidget);
      await tap(tester, 'analytics-consent-switch');
      expect(c.enabled, true);
      expect(find.byKey(const ValueKey('analytics-cube-on')), findsOneWidget);
      await tap(tester, 'analytics-details-open');
      expect(find.textContaining('IP-адрес.'), findsOneWidget);
      await tap(tester, 'analytics-info-back');
      expect(c.enabled, true);
      await tap(tester, 'analytics-consent-switch');
      expect(c.enabled, false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
    },
  );
  for (final lang in ['ru', 'en']) {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final small in [false, true]) {
        testWidgets('layout $lang width$width short$small with large text', (
          tester,
        ) async {
          await mount(
            tester,
            language: lang,
            size: Size(width, small ? 480 : 740),
            scale: small ? 1.4 : 1,
          );
          await tap(tester, 'first');
          expect(tester.takeException(), isNull);
          await frame(
            tester,
            'first-$lang-${width.toInt()}-${small ? 'short-large' : 'normal'}',
          );
          await tap(tester, 'analytics-details-open');
          expect(tester.takeException(), isNull);
          await frame(
            tester,
            'info-$lang-${width.toInt()}-${small ? 'short-large' : 'normal'}',
          );
          await tap(tester, 'analytics-info-back');
          await tap(tester, 'analytics-consent-decline');
          await tap(tester, 'state');
          expect(tester.takeException(), isNull);
          await frame(
            tester,
            'off-$lang-${width.toInt()}-${small ? 'short-large' : 'normal'}',
          );
          await tap(tester, 'analytics-consent-switch');
          expect(tester.takeException(), isNull);
          await frame(
            tester,
            'on-$lang-${width.toInt()}-${small ? 'short-large' : 'normal'}',
          );
        });
      }
    }
  }
}
