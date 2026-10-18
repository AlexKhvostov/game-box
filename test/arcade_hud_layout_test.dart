import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/arcade_hud.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_viewport.dart';

void main() {
  testWidgets(
    'Energy plus remains inside its card for an eight-digit balance',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore(storagePrefix: 'hud_energy_large_');
      await economy.load();
      await economy.enableEnergyPreview(balance: 47);
      final frame = ValueNotifier(0);
      await t.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            Provider.value(value: const GameplayConfig()),
          ],
          child: MaterialApp(
            theme: buildGameTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: ArcadeHud(
                  frame: frame,
                  timeMs: () => 0,
                  jumpProgress: () => 1,
                  onLivesTap: () {},
                  onCrystalsTap: () {},
                  onRecordTap: () {},
                  onProfileTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      final initialPlus = t.getRect(
        find.byKey(const ValueKey('hud-energy-plus')),
      );
      final initialRanking = t.getRect(
        find.byKey(const ValueKey('hud-ranking-card')),
      );
      await economy.enableEnergyPreview(balance: 99999999);
      await t.pump();
      final card = t.getRect(find.byKey(const ValueKey('hud-energy-card')));
      final plus = t.getRect(find.byKey(const ValueKey('hud-energy-plus')));
      final amount = t.getRect(find.byKey(const ValueKey('hud-energy-amount')));
      // The approved header centres the balance against the entire card,
      // independently of the fixed plus at its right edge.
      expect(amount.center.dx, closeTo(card.center.dx, .5));
      expect(plus, initialPlus);
      expect(card.contains(plus.topLeft), isTrue);
      expect(card.contains(plus.bottomRight), isTrue);
      expect(amount.right, lessThanOrEqualTo(plus.left + .01));
      expect(card.height, greaterThanOrEqualTo(48));
      expect(
        t.getRect(find.byKey(const ValueKey('hud-ranking-card'))),
        initialRanking,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      frame.dispose();
      economy.dispose();
    },
  );
  for (final language in ['ru', 'en']) {
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'four HUD cards / 999 / separate ranking $language $width $scale',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            final economy = EconomyStore();
            await economy.load();
            economy.lives = 999;
            economy.tokens = 999;
            final frame = ValueNotifier(0);
            var time = 0;
            final taps = [0, 0, 0, 0];
            await tester.binding.setSurfaceSize(Size(width, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: economy),
                  Provider.value(value: const GameplayConfig()),
                ],
                child: MaterialApp(
                  theme: buildGameTheme(),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: GameViewport(child: child!),
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ArcadeHud(
                        frame: frame,
                        timeMs: () => time,
                        jumpProgress: () => 1,
                        onLivesTap: () => taps[0]++,
                        onCrystalsTap: () => taps[1]++,
                        onRecordTap: () => taps[2]++,
                        onProfileTap: () => taps[3]++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final cards = [
              'lives',
              'crystals',
              'ranking',
              'account',
            ].map((name) => find.byKey(ValueKey('hud-$name-card'))).toList();
            final initial = cards.map(tester.getRect).toList();
            for (final rect in initial) {
              expect(rect.width, closeTo(initial.first.width, .01));
              expect(rect.height, closeTo(initial.first.height, .01));
            }
            expect(find.text('999'), findsNWidgets(2));
            expect(
              find.byKey(const ValueKey('hud-player-icon')),
              findsOneWidget,
            );
            final amounts = find
                .text('999')
                .evaluate()
                .map((e) => tester.getRect(find.byWidget(e.widget)))
                .toList();
            expect(amounts[0].width, closeTo(amounts[1].width, .01));
            expect(initial.first.contains(amounts.first.center), isTrue);
            expect(initial[1].contains(amounts[1].center), isTrue);
            expect(find.textContaining('Мой рекорд'), findsNothing);
            final clock = find.byKey(const ValueKey('arcade-top-timer'));
            expect(tester.getRect(clock).center.dx, closeTo(width / 2, .01));
            time = 5940123;
            frame.value++;
            await tester.pump();
            expect(tester.getRect(clock).center.dx, closeTo(width / 2, .01));
            expect(cards.map(tester.getRect).toList(), initial);
            for (var i = 0; i < cards.length; i++) {
              await tester.tap(cards[i]);
            }
            await tester.tap(clock);
            expect(taps, [1, 1, 1, 1]);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            economy.dispose();
            frame.dispose();
          },
        );
      }
    }
  }
}
