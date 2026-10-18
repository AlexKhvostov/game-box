import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/app/app.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/features/game/game_home_screen.dart';
import 'package:game_box/features/game/game_field_painter.dart';
import 'package:game_box/features/result/result_screen.dart';
import 'package:game_box/data/audience_policy.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/domain/gameplay_config.dart';
import 'package:game_box/features/balance/crystals_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/billing_unavailable.dart';

class _RetryPolicy extends AudiencePolicy {
  bool fail = true;
  @override
  Future<void> select(AgeBand band) async {
    if (fail) throw StateError('isolated storage failure');
    await super.select(band);
  }
}

Future<void> _host(
  WidgetTester tester,
  EconomyStore economy,
  AudiencePolicy age, {
  int tab = 0,
  bool billing = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: age),
        Provider.value(value: const GameplayConfig()),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => billing
                  ? buyGoogleProduct(c, 'pack_handful')
                  : showCrystalsSheet(c, initialTab: tab),
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

Future<void> _choose(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('age-under18')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('age-continue')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final action in ['gift', 'helmet', 'jump', 'earn']) {
    testWidgets(
      '$action cancels with no mutation and continues once for a child',
      (tester) async {
        final age = AudiencePolicy();
        await age.load();
        final economy = EconomyStore();
        await economy.load();
        economy.tokens = 100;
        economy.unlockedEarnIds.add('survive_10s');
        final operations = <String>[];
        economy.sendOperation = (kind, _) => operations.add(kind);
        await _host(
          tester,
          economy,
          age,
          tab: action == 'earn'
              ? 3
              : action == 'gift'
              ? 0
              : 2,
        );
        VoidCallback handler() {
          if (action == 'gift') {
            return tester
                .widget<FilledButton>(find.byKey(const ValueKey('shop-gift')))
                .onPressed!;
          }
          final label = action == 'earn'
              ? find.text('Survive 10 seconds')
              : find
                    .descendant(
                      of: find.byKey(ValueKey('rental-$action-card')),
                      matching: find.text('Rent'),
                    )
                    .first;
          return tester
              .widget<InkWell>(
                find.ancestor(of: label, matching: find.byType(InkWell)).first,
              )
              .onTap!;
        }

        final before = economy.tokens;
        handler()();
        handler()();
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('age-continue')))
              .onPressed,
          isNull,
        );
        expect(find.byKey(const ValueKey('age-unknown')), findsNothing);
        expect(economy.tokens, before);
        expect(operations, isEmpty);
        await tester.tap(find.byKey(const ValueKey('age-cancel')));
        await tester.pumpAndSettle();
        expect(economy.tokens, before);
        expect(operations, isEmpty);
        handler()();
        handler()();
        await tester.pumpAndSettle();
        await _choose(tester);
        expect(age.band, AgeBand.under18);
        expect(age.adsEnabled, isFalse);
        expect(operations, hasLength(1));
        final expected = switch (action) {
          'gift' => before + economy.config.timedBonusTokens,
          'helmet' => before - economy.config.helmetRentalCost,
          'jump' => before - economy.config.jumpRentalCost,
          _ =>
            before +
                economy.config.earnActions
                    .firstWhere((a) => a.id == 'survive_10s')
                    .reward,
        };
        expect(economy.tokens, expected);
        if (action == 'helmet') expect(economy.hasHelmetRental, isTrue);
        if (action == 'jump') expect(economy.hasJumpRental, isTrue);
        if (action == 'earn') {
          expect(economy.isEarnClaimed('survive_10s'), isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        age.dispose();
        economy.dispose();
      },
    );
  }
  testWidgets(
    'unknown-age local round saves freely; claim cancel and replay never pay twice',
    (tester) async {
      final age = AudiencePolicy();
      await age.load();
      final economy = EconomyStore();
      await economy.load();
      final scores = ScoresStore();
      await scores.loadLocal();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: economy),
            ChangeNotifierProvider.value(value: age),
            ChangeNotifierProvider.value(value: scores),
            Provider.value(
              value: const GameplayConfig(
                game: GameConfig(startInvulnSec: 0),
                enemies: EnemiesConfig(
                  speedMin: 0,
                  speedMax: 0,
                  accelMin: 0,
                  accelMax: 0,
                ),
              ),
            ),
          ],
          child: const GameBoxApp(forceLocale: 'en'),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GameHomeScreen)));
      await tester.pump();
      final world = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<GameFieldPainter>()
          .first
          .world;
      world.playerDistance = world.playerSize * .1 * 400;
      world.nearMissCount = 10;
      world.enemies.first.setCenter(
        world.player + Offset(world.playerSize / 2, world.playerSize / 2),
      );
      final before = economy.tokens;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ResultOverlay), findsOneWidget);
      expect(scores.myAttempts.single.runDistance, 400);
      expect(economy.tokens, before);
      await tester.tap(find.byKey(const ValueKey('result-claim-reward')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('age-cancel')));
      await tester.pumpAndSettle();
      expect(economy.tokens, before);
      expect(scores.myAttempts, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('result-claim-reward')));
      await tester.pumpAndSettle();
      await _choose(tester);
      expect(economy.tokens, before + 4);
      expect(find.byKey(const ValueKey('result-claim-reward')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('result-replay')));
      await tester.pump();
      expect(economy.tokens, before + 4);
      expect(scores.myAttempts, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      scores.dispose();
      age.dispose();
      economy.dispose();
    },
  );
  testWidgets(
    'billing cancellation never proceeds; storage error keeps gate retryable',
    (tester) async {
      final age = _RetryPolicy();
      await age.load();
      final economy = EconomyStore();
      await economy.load();
      final before = economy.tokens;
      await _host(tester, economy, age, billing: true);
      await tester.tap(find.byKey(const ValueKey('age-under18')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('age-continue')));
      await tester.pumpAndSettle();
      expect(age.band, isNull);
      expect(find.text('Could not save. Please try again.'), findsOneWidget);
      expect(find.text('PURCHASES UNAVAILABLE'), findsNothing);
      expect(economy.tokens, before);
      age.fail = false;
      await tester.tap(find.byKey(const ValueKey('age-continue')));
      await tester.pumpAndSettle();
      expect(find.text('PURCHASES UNAVAILABLE'), findsOneWidget);
      expect(economy.tokens, before);
      await tester.pumpWidget(const SizedBox());
      age.dispose();
      economy.dispose();
    },
  );
}
