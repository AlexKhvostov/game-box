import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/ui/rewarded_ad_disclosure.dart';
import 'package:game_box/ui/rewarded_ad_guide.dart';
import 'simple_energy_test.dart' as fixture;

void main() {
  for (final page in [EnergyPage.energy, EnergyPage.video]) {
    testWidgets(
      'SDK disclosure is in the normal reward path before any request: $page',
      (t) async {
        t.view.physicalSize = const Size(320, 780);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final e = await fixture.store();
        addTearDown(e.dispose);
        await t.pumpWidget(fixture.app(e, page: page, scale: 1.3));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final disclosure = find.byKey(const ValueKey('rewarded-ad-disclosure'));
        if (page == EnergyPage.energy) {
          expect(disclosure, findsNothing);
          expect(
            find.byKey(const ValueKey('rewarded-ad-exit-hint')),
            findsNothing,
          );
          await t.tap(find.byKey(const ValueKey('simple-energy-video')));
          await t.pumpAndSettle();
          expect(find.text('Энергия за рекламу'), findsOneWidget);
        }
        expect(disclosure, findsOneWidget);
        expect(find.textContaining('Яндекс: данные'), findsOneWidget);
        expect(find.text('Подождите'), findsOneWidget);
        expect(find.text('Закройте'), findsOneWidget);
        expect(find.byType(RewardedAdGuide), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        final details = find.byKey(const ValueKey('rewarded-ad-data-info'));
        await t.ensureVisible(details);
        await t.tap(details);
        await t.pumpAndSettle();
        final text = t
            .widget<Text>(
              find.byKey(const ValueKey('rewarded-ad-data-details')),
            )
            .data!;
        expect(text, contains('идентификаторы устройства'));
        expect(text, contains('сеанс'));
        expect(text, contains('Без персонализации и геолокации'));
        await t.tap(find.text('Понятно'));
        await t.pumpAndSettle();
        expect(find.text('Включить рекламу?'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'English explains connection/device data without an additional consent control',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          home: Scaffold(body: RewardedAdDisclosure()),
        ),
      );
      expect(
        find.textContaining('Yandex: connection and device data'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
    },
  );
  for (final width in [320.0, 430.0]) {
    testWidgets('two ad steps stay readable at width $width with large text', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      RewardedAdGuide(reward: 40),
                      RewardedAdDisclosure(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Your bonus!'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
