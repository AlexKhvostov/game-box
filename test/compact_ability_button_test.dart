import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/game/compact_ability_button.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('six states keep geometry and use the supplied game clock', (
    t,
  ) async {
    final frame = ValueNotifier(0);
    var remaining = 0.0, progress = 1.0;
    var taps = 0;
    for (final state in [
      (true, false, false, 'Выкл.'),
      (true, true, false, 'Вкл.'),
      (true, true, true, 'Разбит'),
      (false, false, false, 'Выкл.'),
      (false, true, false, 'Готов'),
      (false, true, false, '1,5 с'),
    ]) {
      remaining = state.$4 == '1,5 с' ? 1500 : 0;
      progress = remaining > 0 ? .25 : 1;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactAbilityButton(
                helmet: state.$1,
                active: state.$2,
                broken: state.$3,
                ru: true,
                progress: () => progress,
                remainingMs: () => remaining,
                frame: frame,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.text(state.$4), findsOneWidget);
      expect(t.getSize(find.byType(CompactAbilityButton)), const Size(72, 44));
      expect(
        t.getSize(
          find.byKey(
            ValueKey(state.$1 ? 'compact-helmet-face' : 'compact-jump-face'),
          ),
        ),
        const Size(72, 36),
      );
      expect(find.text('+1'), findsNothing);
      await t.tap(find.byType(CompactAbilityButton));
      expect(t.takeException(), isNull);
    }
    expect(taps, 6);
    remaining = 500;
    progress = .75;
    frame.value++;
    await t.pump();
    expect(find.text('0,5 с'), findsOneWidget);
    remaining = 0;
    progress = 1;
    frame.value++;
    await t.pump();
    expect(find.text('Готов'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    frame.dispose();
  });

  for (final band in AgeBand.values) {
    test(
      'saved ${band.name} survives loading and aggregate declarations remain distinct',
      () async {
        SharedPreferences.setMockInitialValues({
          AudiencePolicy.storageKey: band.name,
        });
        final policy = AudiencePolicy();
        await policy.load();
        expect(policy.band, band);
        expect(
          policy.isAdEligibleAge,
          [
            AgeBand.age18to20,
            AgeBand.age21plus,
            AgeBand.adult18plus,
          ].contains(band),
        );
        expect(policy.adsEnabled, false);
        policy.dispose();
      },
    );
  }
}
