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
import 'package:game_box/l10n/app_localizations.dart';

Future<void> openDaily(WidgetTester tester, EconomyStore economy) async {
  final audience = AudiencePolicy();
  await audience.load();
  await audience.select(AgeBand.age21plus);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(audience.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: economy),
        ChangeNotifierProvider.value(value: audience),
        Provider.value(value: GameplayConfig()),
      ],
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCrystalsSheet(context),
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

Finder inDay(int day, String text) => find.descendant(
  of: find.byKey(ValueKey('daily-row-$day')),
  matching: find.text(text),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const config = EconomyConfig(
    initialTokens: 100,
    installBonusAutoClaim: false,
    dailyRewardTokens: [2, 3, 5, 7, 11, 17, 23],
  );
  testWidgets('countdown changes without rebuilding static days or Plus', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 12, 18);
    final economy = EconomyStore(config: config, now: () => now);
    await economy.load();
    economy.lastDailyClaimAt = now;
    economy.dailyStreak = 1;
    await openDaily(tester, economy);
    final day = find.byKey(const ValueKey('daily-row-1'));
    final plus = find.byKey(const ValueKey('daily-plus-card'));
    final dayWidget = tester.widget(day);
    final plusWidget = tester.widget(plus);
    final dayBounds = tester.getRect(day);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(inDay(2, '05:59:58'), findsOneWidget);
    expect(tester.widget(day), same(dayWidget));
    expect(tester.widget(plus), same(plusWidget));
    expect(tester.getRect(day), dayBounds);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    economy.dispose();
  });
  testWidgets(
    'rewards centered; locked day cannot claim; claim exposes next timer',
    (tester) async {
      final economy = EconomyStore(
        config: config,
        now: () => DateTime(2026, 10, 12, 18),
      );
      await economy.load();
      await openDaily(tester, economy);
      expect(inDay(1, '×2 с Plus'), findsOneWidget);
      expect(inDay(2, 'Закрыто'), findsOneWidget);
      final row = tester.getRect(find.byKey(const ValueKey('daily-row-1')));
      final amount = tester.getRect(
        find.byKey(const ValueKey('daily-reward-1')),
      );
      expect(amount.center.dx, closeTo(row.center.dx, .5));
      final before = economy.tokens;
      await tester.tap(find.byKey(const ValueKey('daily-status-2')));
      await tester.pump();
      expect(economy.tokens, before);
      expect(find.byKey(const ValueKey('daily-claim-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daily-claim-1')));
      await tester.pumpAndSettle();
      expect(economy.tokens, before + 2);
      expect(inDay(1, 'Получено'), findsOneWidget);
      expect(find.text('Завтра'), findsNothing);
      expect(find.text('Следующий бонус через'), findsNothing);
      expect(
        find.byKey(const ValueKey('daily-next-countdown-2')),
        findsOneWidget,
      );
      expect(find.text('06:00:00'), findsOneWidget);
      expect(inDay(2, '06:00:00'), findsOneWidget);
      final timer = tester.getRect(
        find.byKey(const ValueKey('daily-next-countdown-2')),
      );
      final nextRow = tester.getRect(find.byKey(const ValueKey('daily-row-2')));
      final status = tester.getRect(
        find.byKey(const ValueKey('daily-status-2')),
      );
      expect(nextRow.contains(timer.center), isTrue);
      expect(status.contains(timer.center), isTrue);
      final heights = [1, 2, 3].map(
        (day) => tester.getSize(find.byKey(ValueKey('daily-row-$day'))).height,
      );
      expect(heights.toSet(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
    },
  );
  testWidgets(
    'midnight switches waiting to claimable without resetting streak',
    (tester) async {
      var now = DateTime(2026, 10, 12, 23, 59, 58);
      final economy = EconomyStore(config: config, now: () => now);
      await economy.load();
      economy.lastDailyClaimAt = now;
      economy.dailyStreak = 3;
      await openDaily(tester, economy);
      expect(find.text('00:00:02'), findsOneWidget);
      expect(inDay(4, '00:00:02'), findsOneWidget);
      now = DateTime(2026, 10, 13, 0, 0, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('daily-next-countdown-4')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('daily-claim-4')), findsOneWidget);
      expect(economy.dailyStreak, 3);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
    },
  );
  testWidgets(
    'Plus hint uses configured multiplier and actual eligible amount',
    (tester) async {
      final economy = EconomyStore(
        config: config.copyWith(premiumDailyMultiplier: 3),
        now: () => DateTime(2026, 10, 12, 18),
      );
      await economy.load();
      economy.hasPremium = true;
      await openDaily(tester, economy);
      expect(inDay(1, '+6'), findsOneWidget);
      expect(inDay(1, '2 × 3'), findsOneWidget);
      expect(find.text('×2 с Plus'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
    },
  );
  testWidgets(
    'maximum streak still shows countdown for the next daily reward',
    (tester) async {
      final now = DateTime(2026, 10, 12, 18);
      final economy = EconomyStore(config: config, now: () => now);
      await economy.load();
      economy.lastDailyClaimAt = now;
      economy.dailyStreak = 7;
      await openDaily(tester, economy);
      expect(find.text('Следующий бонус через'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-next-countdown-7')),
        findsOneWidget,
      );
      expect(inDay(7, '06:00:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-claim-7')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      economy.dispose();
    },
  );
}
