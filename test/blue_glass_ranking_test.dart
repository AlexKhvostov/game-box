import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/leaderboard_panel.dart';
import 'package:game_box/features/leaderboard/leaderboard_sheet.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/features/leaderboard/leaderboard_widgets.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/game_sheet.dart';

class QaScores extends ScoresStore {
  QaScores({super.account}) {
    online = true;
  }
  int refreshes = 0;
  int loads = 0;
  bool empty = false;
  int sampleCount = 15;
  int ghostPlace = 101;
  @override
  RankInfo rankFor(int timeMs, {String period = 'all'}) =>
      RankInfo(place: ghostPlace, percentile: 0, totalCount: 200);
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    refreshes++;
  }

  @override
  Future<void> load() async {
    loads++;
  }

  @override
  List<ScoreEntry> scoresForNamedPeriod(String period) => empty
      ? []
      : [
          for (var i = 0; i < sampleCount; i++)
            ScoreEntry(
              id: '$i',
              displayName: i == 0
                  ? 'A very long player name to fit in the left zone'
                  : 'Player $i',
              timeMs: 48392 - i * 1000,
              createdAt: DateTime(2026, 10, 10, 11, 14),
              countryCode: 'BY',
              riskCount: 5,
              runDistance: 286,
              hadJump: i.isEven,
              hadHelmet: i.isOdd,
            ),
        ];
  @override
  List<LocalAttempt> get myAttempts => empty
      ? []
      : [
          LocalAttempt(
            id: 'local',
            timeMs: 21349,
            createdAt: DateTime(2026, 10, 10, 11, 14),
            riskCount: 2,
            runDistance: 226,
            hadHelmet: true,
          ),
        ];
}

Future<void> mount(
  WidgetTester tester,
  QaScores store, {
  String language = 'ru',
  Size size = const Size(320, 560),
  double scale = 1,
  int? ghostTimeMs,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<ScoresStore>.value(
      value: store,
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ghostTimeMs == null
                  ? showLeaderboardSheet(context)
                  : showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => GameSheetChrome(
                        child: LeaderboardPanel(ghostTimeMs: ghostTimeMs),
                      ),
                    ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final lang in ['ru', 'en']) {
    for (final size in [
      const Size(320, 560),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('ranking $lang $size scale $scale layout and filters', (
          tester,
        ) async {
          final store = QaScores();
          await mount(tester, store, language: lang, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(store.refreshes, 1);
          final mine = tester.getRect(
            find.byKey(const ValueKey('leaderboard-filter-5')),
          );
          final periods = tester.getRect(
            find.byKey(const ValueKey('leaderboard-filter-0')),
          );
          expect(mine.bottom, lessThanOrEqualTo(periods.top));
          for (var i = 0; i < 5; i++) {
            final chip = find.byKey(ValueKey('leaderboard-filter-$i'));
            expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
            expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
            await tester.tap(chip);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester
                  .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
                  .filter,
              i,
            );
          }
          await tester.tap(find.byKey(const ValueKey('leaderboard-filter-5')));
          await tester.pumpAndSettle();
          expect(find.byType(MyAttemptsSheet), findsOneWidget);
          expect(
            find.byKey(const ValueKey('my-attempt-local')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('my-attempts-close')));
          await tester.pumpAndSettle();
          expect(
            tester
                .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
                .filter,
            4,
          );
          expect(find.byType(ScoreBoostIcons), findsWidgets);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(LeaderboardSheet), findsNothing);
          store.dispose();
        });
      }
    }
  }
  testWidgets('ranking loading, offline retry, online empty, mine empty', (
    tester,
  ) async {
    final store = QaScores()
      ..empty = true
      ..loading = true
      ..online = false;
    await mount(tester, store);
    expect(find.text('Загружаем рейтинг…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    store.loading = false;
    store.notifyListeners();
    await tester.pump();
    expect(
      find.text('Не удалось загрузить рейтинг. Проверьте сеть.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(store.loads, 1);
    store.online = true;
    store.notifyListeners();
    await tester.pump();
    expect(find.text('Повторить'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('leaderboard-filter-5')));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
  for (final lang in ['ru', 'en']) {
    for (final size in [const Size(320, 560), const Size(390, 844)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'player result $lang $size scale $scale actual entry, tips and Back',
          (tester) async {
            final store = QaScores();
            await mount(
              tester,
              store,
              language: lang,
              size: size,
              scale: scale,
            );
            final row = find.byType(LeaderboardRankRow).first;
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            await tester.tapAt(tester.getTopLeft(row) + const Offset(24, 12));
            await tester.pumpAndSettle();
            expect(find.byType(PlayerResultSheet), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(PlayerResultSheet),
                matching: find.text('48.392 ${lang == 'ru' ? 'с' : 's'}'),
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                '${lang == 'ru' ? 'Очки попытки' : 'Run points'}: ${store.scoresForNamedPeriod('day').first.score}',
              ),
              findsOneWidget,
            );
            for (final id in ['run', 'risk', 'jump', 'helmet']) {
              final action = find.byKey(ValueKey('player-$id'));
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('player-stat-tip')),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            }
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(PlayerResultSheet), findsNothing);
            expect(find.byType(LeaderboardSheet), findsOneWidget);
            store.dispose();
          },
        );
      }
    }
  }
  testWidgets(
    'own attempt inspection returns through history to the previous period',
    (tester) async {
      final account = MobileAccount()..id = 'android:qa';
      final store = QaScores(account: account);
      await mount(tester, store);
      await tester.tap(find.byKey(const ValueKey('leaderboard-filter-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-attempt-detail-local')));
      await tester.pumpAndSettle();
      expect(find.text('Это ваш личный результат'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PlayerResultSheet),
          matching: find.text('21.349 с'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('player-close')));
      await tester.tap(find.byKey(const ValueKey('player-close')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerResultSheet), findsNothing);
      expect(find.byType(MyAttemptsSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-attempts-close')));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<LeaderboardPanelState>(find.byType(LeaderboardPanel))
            .filter,
        4,
      );
      store.dispose();
      account.dispose();
    },
  );
  testWidgets('ghost after top50 retains actual rank101', (tester) async {
    final store = QaScores()..sampleCount = 50;
    await mount(tester, store, ghostTimeMs: 100);
    final ghost = find.byWidgetPredicate(
      (w) => w is LeaderboardRankRow && w.ghost,
    );
    await tester.scrollUntilVisible(
      ghost,
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<LeaderboardRankRow>(ghost).place, 101);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
}
