import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/ads_service.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_sheet.dart';

class _NoAd implements AdsDriver {
  int calls = 0;
  @override
  Future<AdOutcome> showRewarded({bool Function()? canShow}) async {
    calls++;
    return AdOutcome.unavailable;
  }

  @override
  Future<bool> showInterstitial({required bool Function() canShow}) async =>
      false;
}

void main() {
  for (final locale in ['en', 'ru']) {
    for (final width in [320.0, 390.0]) {
      testWidgets('shop matches Telegram structure at $width ($locale)', (
        tester,
      ) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        SharedPreferences.setMockInitialValues({});
        final economy = EconomyStore(
          config: const EconomyConfig(initialTokens: 100),
        );
        await economy.load();
        final driver = _NoAd();
        final audience = AudiencePolicy();
        await audience.load();
        await audience.select(AgeBand.age21plus);
        audience.allowAdsForSession();
        final ads = AdsService(driver, audience: audience);
        await tester.binding.setSurfaceSize(Size(width, 560));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: economy),
              ChangeNotifierProvider.value(value: ads),
              Provider.value(value: GameplayConfig()),
            ],
            child: MaterialApp(
              theme: buildGameTheme(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      TextButton(
                        onPressed: () => showCrystalsSheet(context),
                        child: const Text('Open shop'),
                      ),
                      TextButton(
                        onPressed: () => showLivesSheet(context),
                        child: const Text('Open lives'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open shop'));
        await tester.pumpAndSettle();
        final ad = find.byKey(const ValueKey('shop-header-watch-ad'));
        final plus = find.byKey(const ValueKey('daily-plus-card'));
        expect(
          ad,
          AudiencePolicy.adsBuildEnabled ? findsOneWidget : findsNothing,
        );
        expect(plus, findsOneWidget);
        final menu = find.byKey(const ValueKey('shop-tab-menu'));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('shop-gift-material')))
              .height,
          closeTo(
            tester
                .getSize(find.byKey(const ValueKey('shop-crystal-balance')))
                .height,
            .01,
          ),
        );
        final firstDay = find.byKey(const ValueKey('daily-row-1'));
        expect(
          tester.getRect(menu).width,
          greaterThan(tester.getRect(firstDay).width + 20),
        );
        expect(
          find.textContaining(
            locale == 'ru' ? 'Ежедневные награды ×2' : 'Daily rewards ×2',
          ),
          findsOneWidget,
        );
        final fixedPlus = tester.getRect(plus);
        final fixedMenu = tester.getRect(menu);
        await tester.drag(
          find.byKey(const ValueKey('daily-days-scroll')),
          const Offset(0, -220),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(plus), fixedPlus);
        expect(tester.getRect(menu), fixedMenu);
        await tester.drag(
          find.byKey(const ValueKey('daily-days-scroll')),
          const Offset(0, 600),
        );
        await tester.pumpAndSettle();
        if (AudiencePolicy.adsBuildEnabled) {
          expect(
            tester.getRect(plus).top,
            greaterThan(tester.getRect(ad).bottom),
          );
          await tester.tap(ad);
          await tester.pumpAndSettle();
          expect(driver.calls, 1);
        }
        expect(economy.tokens, 100);
        await tester.tap(find.text(locale == 'ru' ? 'Покупки' : 'Shop'));
        await tester.pumpAndSettle();
        expect(
          ad,
          AudiencePolicy.adsBuildEnabled ? findsOneWidget : findsNothing,
        );
        expect(plus, findsNothing);
        expect(find.text('Watch an ad'), findsNothing);
        await tester.tap(find.text(locale == 'ru' ? 'Аренда' : 'Rent'));
        await tester.pumpAndSettle();
        expect(
          ad,
          AudiencePolicy.adsBuildEnabled ? findsOneWidget : findsNothing,
        );
        expect(find.text(locale == 'ru' ? 'Шлем' : 'Helmet'), findsWidgets);
        expect(find.text(locale == 'ru' ? 'Прыжок' : 'Jump'), findsWidgets);
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open lives'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('life-packs-list')), findsOneWidget);
        final floating = tester.getRect(
          find.descendant(
            of: find.byKey(const ValueKey('lives-floating-window')),
            matching: find.byType(GameSheetChrome),
          ),
        );
        expect(floating.top, greaterThanOrEqualTo(24));
        expect(floating.bottom, lessThanOrEqualTo(560 - 24));
        expect(floating.left, greaterThanOrEqualTo(16));
        final packs = economy.config.resolvedLifePacks;
        final first = find.byKey(
          ValueKey('life-pack-${packs[0].lives}-${packs[0].costTokens}'),
        );
        final second = find.byKey(
          ValueKey('life-pack-${packs[1].lives}-${packs[1].costTokens}'),
        );
        final inventory = tester.getRect(
          find.byKey(const ValueKey('lives-inventory')),
        );
        final lifeStatus = find.byKey(const ValueKey('lives-inventory'));
        final currency = find.byKey(const ValueKey('lives-exchange-currency'));
        expect(
          find.descendant(
            of: lifeStatus,
            matching: find.text(locale == 'ru' ? 'Ваши жизни' : 'Your lives'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: lifeStatus, matching: currency),
          findsNothing,
        );
        expect(
          find.descendant(of: currency, matching: find.text('100')),
          findsOneWidget,
        );
        expect(tester.getRect(currency).top, greaterThan(inventory.bottom));
        expect(
          tester.getRect(first).top - inventory.bottom,
          greaterThanOrEqualTo(16),
        );
        expect(tester.getRect(second).top, tester.getRect(first).top);
        expect(
          tester.getRect(second).left,
          greaterThan(tester.getRect(first).right),
        );
        expect(tester.getRect(first).width, lessThan(width * .55));
        expect(tester.getRect(first).height, lessThanOrEqualTo(132));
        final action = find.byKey(
          ValueKey('life-exchange-${packs[0].lives}-${packs[0].costTokens}'),
        );
        expect(tester.getRect(action).height, greaterThanOrEqualTo(48));
        final lives = economy.lives;
        // Reading the balance never starts an exchange.
        await tester.tap(find.byKey(const ValueKey('lives-inventory')));
        await tester.pumpAndSettle();
        expect(economy.lives, lives);
        expect(economy.tokens, 100);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        // A quick repeat cannot debit the same offer twice while it closes.
        await tester.tap(action);
        await tester.tap(action, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(economy.lives, lives + packs[0].lives);
        expect(economy.tokens, 100 - packs[0].costTokens);
        expect(tester.takeException(), isNull);
        // Make the last offer unaffordable with the approved cheaper catalogue.
        economy.tokens = packs.last.costTokens - 1;
        final afterExchange = economy.tokens;
        final afterLives = economy.lives;
        expect(packs.last.costTokens, greaterThan(afterExchange));
        await tester.tap(find.text('Open lives'));
        await tester.pumpAndSettle();
        final unavailable = find.byKey(
          ValueKey(
            'life-exchange-${packs.last.lives}-${packs.last.costTokens}',
          ),
        );
        await tester.ensureVisible(unavailable);
        await tester.pumpAndSettle();
        await tester.tap(unavailable);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('shop-tab-1')), findsOneWidget);
        expect(economy.tokens, afterExchange);
        expect(economy.lives, afterLives);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        economy.dispose();
        ads.dispose();
      });
    }
  }
}
