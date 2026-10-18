import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/economy_config.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/features/game/lives_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

const config = EconomyConfig(
  initialLives: 30,
  initialTokens: 0,
  installBonusAutoClaim: false,
);

Future<void> open(WidgetTester tester, EconomyStore economy, bool lives) async {
  final audience = AudiencePolicy();
  await audience.load();
  await audience.select(AgeBand.age21plus);
  addTearDown(audience.dispose);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: audience),
        Provider.value(value: const GameplayConfig()),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  lives ? showLivesSheet(context) : showCrystalsSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'isolated wallet storage remains separate without refill shortcuts',
    () async {
      SharedPreferences.setMockInitialValues({
        'lives': 0,
        'tokens': 19,
        'best_time_ms': 23280,
      });
      final local = EconomyStore(
        config: config,
        storagePrefix: 'test_wallet_v1_',
      );
      await local.load();
      local.grantCrystals(10);
      final ordinary = EconomyStore(config: config);
      await ordinary.load();
      expect(ordinary.tokens, 19);
      expect(ordinary.lives, 0);
      expect(ordinary.bestTimeMs, 23280);
      local.dispose();
      ordinary.dispose();
    },
  );
  testWidgets('former shop header shortcut is absent', (t) async {
    SharedPreferences.setMockInitialValues({});
    final e = EconomyStore(config: config);
    await e.load();
    await open(t, e, false);
    expect(
      find.byKey(const ValueKey('shop-crystal-test-credit')),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
    e.dispose();
  });
  testWidgets('holding the old lives card cannot refill resources', (t) async {
    SharedPreferences.setMockInitialValues({'lives': 0, 'tokens': 19});
    final e = EconomyStore(config: config);
    await e.load();
    await open(t, e, true);
    expect(find.byKey(const ValueKey('test-reset-lives')), findsNothing);
    await t.longPress(find.byKey(const ValueKey('lives-inventory')));
    await t.pumpAndSettle();
    expect(e.lives, 0);
    expect(e.tokens, 19);
    await t.pumpWidget(const SizedBox());
    e.dispose();
  });
}
