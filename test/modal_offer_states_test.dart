import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/crystal_cost_badge.dart';

void main() {
  for (final language in ['ru', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'crystal costs stay upper-right; poor rentals cannot debit $language $scale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final economy = EconomyStore();
          await economy.load();
          economy.tokens = 999;
          await tester.binding.setSurfaceSize(const Size(320, 560));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          late BuildContext home;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: economy),
                Provider.value(value: const GameplayConfig()),
              ],
              child: MaterialApp(
                theme: buildGameTheme(),
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (c) {
                    home = c;
                    return const Scaffold();
                  },
                ),
              ),
            ),
          );
          showCrystalsSheet(home, initialTab: 2);
          await tester.pumpAndSettle();
          final badges = find.byType(CrystalCostBadge);
          expect(badges, findsNWidgets(4));
          final costs = tester
              .widgetList<CrystalCostBadge>(badges)
              .map((b) => b.amount)
              .toSet();
          expect(costs, {
            economy.config.jumpRentalCost,
            economy.config.jumpRentalHourCost,
            economy.config.helmetRentalCost,
            economy.config.helmetRentalHourCost,
          });
          for (final element in badges.evaluate()) {
            expect((element.widget as CrystalCostBadge).available, isTrue);
            final badge = tester.getRect(find.byWidget(element.widget));
            final offer = find.ancestor(
              of: find.byWidget(element.widget),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is InkWell &&
                    w.key is ValueKey &&
                    (w.key as ValueKey).value.toString().startsWith(
                      'rental-offer-',
                    ),
              ),
            );
            expect(offer, findsOneWidget);
            final rect = tester.getRect(offer);
            expect(badge.top - rect.top, inInclusiveRange(8.0, 11.0));
            expect(rect.right - badge.right, inInclusiveRange(8.0, 11.0));
          }
          economy.tokens = 0;
          economy.applyConfig(economy.config);
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<CrystalCostBadge>(badges)
                .every((b) => !b.available),
            isTrue,
          );
          final poor = tester.widgetList<InkWell>(
            find.byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.key is ValueKey &&
                  (w.key as ValueKey).value.toString().startsWith(
                    'rental-offer-',
                  ),
            ),
          );
          expect(poor.every((button) => button.onTap == null), isTrue);
          expect(economy.tokens, 0);
          expect(economy.hasHelmetRental || economy.hasJumpRental, isFalse);
          Navigator.of(home).pop();
          await tester.pumpAndSettle();
          showLivesSheet(home);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('life-packs-list')),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(
            badges,
            findsNWidgets(economy.config.resolvedLifePacks.length),
          );
          for (final element in badges.evaluate()) {
            final cost = (element.widget as CrystalCostBadge).amount;
            final pack = economy.config.resolvedLifePacks.firstWhere(
              (p) => p.costTokens == cost,
            );
            final card = tester.getRect(
              find.byKey(ValueKey('life-pack-${pack.lives}-$cost')),
            );
            final badge = tester.getRect(find.byWidget(element.widget));
            expect(badge.top - card.top, inInclusiveRange(8.0, 11.0));
            expect(card.right - badge.right, inInclusiveRange(8.0, 11.0));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          economy.dispose();
        },
      );
    }
  }
}
