import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

// The route is essential here: showModalBottomSheet normally removes top
// padding, so directly mounting MyAttemptsSheet would miss the regression.
void main() {
  for (final scenario in [
    (
      size: const Size(320, 480),
      insets: const FakeViewPadding(top: 32, bottom: 24),
    ),
    (
      size: const Size(390, 844),
      insets: const FakeViewPadding(top: 54, bottom: 34),
    ),
    (
      size: const Size(320, 480),
      insets: const FakeViewPadding(top: 24, bottom: 24, left: 24, right: 18),
    ),
  ]) {
    testWidgets(
      'attempts route respects system insets ${scenario.size} ${scenario.insets}',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = scenario.insets;
        tester.view.viewPadding = scenario.insets;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => GameViewport(child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => openMyAttemptsWindow(
                      context,
                      panel: const ColoredBox(
                        color: Colors.black,
                        child: SizedBox.expand(),
                      ),
                    ),
                    child: const Text('Open attempts'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open attempts'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final frame = tester.getRect(
          find.byKey(const ValueKey('my-attempts-sheet')),
        );
        final close = tester.getRect(
          find.byKey(const ValueKey('my-attempts-close')),
        );
        final margin = 12 * GameViewport.scaleFor(scenario.size.width);
        expect(
          frame.top,
          greaterThanOrEqualTo(scenario.insets.top + margin - .01),
        );
        expect(
          frame.bottom,
          lessThanOrEqualTo(
            scenario.size.height - scenario.insets.bottom - margin + .01,
          ),
        );
        expect(
          frame.left,
          greaterThanOrEqualTo(scenario.insets.left + margin - .01),
        );
        expect(
          frame.right,
          lessThanOrEqualTo(
            scenario.size.width - scenario.insets.right - margin + .01,
          ),
        );
        expect(frame.contains(close.center), isTrue);
        expect(frame.height, greaterThan(250));
        // Ensure the safe-area route did not create a second top/bottom inset.
        if (scenario.size.height == 480) {
          expect(frame.top, closeTo(scenario.insets.top + margin, .01));
          expect(
            frame.bottom,
            closeTo(
              scenario.size.height - scenario.insets.bottom - margin,
              .01,
            ),
          );
        }
        await tester.tap(find.byKey(const ValueKey('my-attempts-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('my-attempts-sheet')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
