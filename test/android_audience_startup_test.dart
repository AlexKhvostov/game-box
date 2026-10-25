import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/android_audience_startup.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/ui/audience_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stored in [
    null,
    ...AgeBand.values.map((b) => b.name),
    'invalid',
    18,
  ]) {
    testWidgets('startup service isolation for saved age $stored', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        AudiencePolicy.storageKey: ?stored,
      });
      final policy = AudiencePolicy();
      await policy.load();
      var starts = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: policy,
          child: AndroidAudienceStartup(
            startGame: () async {
              starts++;
              return const Scaffold(body: Text('Started game'));
            },
          ),
        ),
      );
      await tester.pump();
      final adult =
          stored == 'age18to20' ||
          stored == 'age21plus' ||
          stored == 'adult18plus';
      expect(policy.canPlayLocally, true);
      expect(policy.isAdEligibleAge, adult);
      expect(starts, 1);
      expect(find.text('Started game'), findsOneWidget);
      expect(find.byKey(const ValueKey('age-continue')), findsNothing);
      expect(policy.adsEnabled, false);
      await policy.setAdDataConsent(true);
      expect(policy.adsEnabled, adult && AudiencePolicy.adsBuildEnabled);
      await tester.pump();
      expect(starts, 1);
      expect(tester.takeException(), null);
    });
  }

  for (final chosen in [AgeBand.under18, AgeBand.adult18plus]) {
    testWidgets(
      'choosing $chosen only changes advertising, not the game session',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final policy = AudiencePolicy();
        await policy.load();
        var starts = 0;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: policy,
            child: AndroidAudienceStartup(
              startGame: () async {
                starts++;
                return Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        const Text('Started game'),
                        TextButton(
                          onPressed: () => showAudienceSelection(context),
                          child: const Text('Age setting'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(starts, 1);
        await tester.tap(find.text('Age setting'));
        await tester.pumpAndSettle();
        final choice = find.byKey(ValueKey('age-${chosen.name}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
        final next = find.byKey(const ValueKey('age-continue'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        final adult = chosen == AgeBand.adult18plus;
        expect(starts, 1);
        expect(find.text('Started game'), findsOneWidget);
        expect(policy.band, chosen);
        expect(policy.canPlayLocally, true);
        expect(policy.isAdEligibleAge, adult);
        expect(policy.adsEnabled, false);
        expect(tester.takeException(), null);
      },
    );
  }
}
