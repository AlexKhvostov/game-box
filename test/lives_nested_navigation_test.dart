import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'lives dialog uses game providers inside Android outer navigator',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final economy = EconomyStore(
        config: const EconomyConfig(initialTokens: 100),
      );
      await economy.load();
      final audience = AudiencePolicy();
      await audience.load();
      await audience.select(AgeBand.age21plus);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: economy),
              ChangeNotifierProvider.value(value: audience),
              Provider.value(value: const GameplayConfig()),
            ],
            child: MaterialApp(
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showLivesSheet(context),
                    child: const Text('Lives'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lives'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lives-inventory')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final pack = economy.config.resolvedLifePacks.first;
      final lives = economy.lives;
      final tokens = economy.tokens;
      final exchange = find.byKey(
        ValueKey('life-exchange-${pack.lives}-${pack.costTokens}'),
      );
      await tester.ensureVisible(exchange);
      await tester.pumpAndSettle();
      await tester.tap(exchange);
      await tester.pumpAndSettle();
      expect(economy.lives, lives + pack.lives);
      expect(economy.tokens, tokens - pack.costTokens);
      expect(find.byKey(const ValueKey('lives-floating-window')), findsNothing);
      await tester.tap(find.text('Lives'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lives-to-crystals-shop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-tab-1')), findsOneWidget);
      expect(economy.tokens, tokens - pack.costTokens);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
      audience.dispose();
    },
  );
}
