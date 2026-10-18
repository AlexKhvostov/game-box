import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/ui/rewarded_ad_disclosure.dart';
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
        final text = t.widget<Text>(disclosure).data!;
        expect(text, contains('Яндекс'));
        expect(text, contains('идентификаторы устройства'));
        expect(text, contains('сеанс'));
        expect(find.textContaining('После видео нажмите ▶|'), findsOneWidget);
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
        find.textContaining('connection data and device identifiers'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
    },
  );
}
