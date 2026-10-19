import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/balance/simple_energy_sheet.dart';
import 'package:game_box/ui/rewarded_ad_guide.dart';
import 'simple_energy_test.dart' as fixture;

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(360, 770),
    const Size(412, 850),
  ]) {
    testWidgets(
      'ad guide and launch fit $size without scrolling at normal text',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final e = await fixture.store();
        addTearDown(e.dispose);
        await t.pumpWidget(fixture.app(e, page: EnergyPage.video));
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final one = t.getRect(
          find.byKey(const ValueKey('rewarded-guide-step-1')),
        );
        final two = t.getRect(
          find.byKey(const ValueKey('rewarded-guide-step-2')),
        );
        final reward = t.getRect(
          find.byKey(const ValueKey('rewarded-guide-reward')),
        );
        final launch = t.getRect(
          find.byKey(const ValueKey('simple-watch-video')),
        );
        expect(one.bottom, lessThan(two.top));
        expect(two.bottom, lessThan(reward.top));
        expect(reward.bottom, lessThan(launch.top));
        expect(launch.bottom, lessThan(size.height - 18));
        expect(find.byType(Image), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'guide reward comes from current policy and stays after the close step',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: RewardedAdGuide(reward: 75))),
      );
      expect(find.textContaining('75'), findsOneWidget);
      expect(find.textContaining('40'), findsNothing);
      expect(
        t.getTopLeft(find.byKey(const ValueKey('rewarded-guide-reward'))).dy,
        greaterThan(
          t
              .getBottomLeft(
                find.byKey(const ValueKey('rewarded-guide-step-2')),
              )
              .dy,
        ),
      );
      expect(t.takeException(), isNull);
    },
  );
}
