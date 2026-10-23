// Independent reviewer assertions. All data and account state are local fixtures.
// Root runs Flutter sequentially; this file never accesses a real API/device.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/my_attempts.dart';
import 'package:game_box/domain/score_entry.dart';
import 'package:game_box/features/leaderboard/my_attempts_panel.dart';
import 'package:game_box/features/leaderboard/player_result_sheet.dart';
import 'package:game_box/l10n/app_localizations.dart';

final _epoch = DateTime.utc(2026, 10, 1);
LocalAttempt _a(
  String id,
  int ms, {
  int date = 0,
  bool shared = true,
  String? error,
}) => LocalAttempt(
  id: id,
  timeMs: ms,
  createdAt: _epoch.add(Duration(minutes: date)),
  shared: shared,
  deliveryError: error,
  runDistance: 73,
  riskCount: 4,
  hadHelmet: true,
  hadJump: true,
);
ScoreEntry _score(String id, int ms, {int date = 0}) => ScoreEntry(
  id: id,
  displayName: 'Actual name',
  uid: 'android:1',
  timeMs: ms,
  createdAt: _epoch.add(Duration(minutes: date)),
  runDistance: 73,
  riskCount: 4,
  hadHelmet: true,
  hadJump: true,
);
AverageRanking _board({
  String algorithm = AverageRanking.quadraticAlgorithm,
  int window = 50,
  double weight = 92,
  int threshold = 0,
  double? official,
  int? total,
  int used = 0,
  int minimum = 1,
}) => AverageRanking(
  algorithm: algorithm,
  windowSize: window,
  previousWeightPercent: weight,
  minDurationMs: threshold,
  minAttempts: minimum,
  mine: AverageRankEntry(
    averageMs: official,
    totalAttempts: total,
    usedCount: used,
    eligibleCount: used,
  ),
);
MyAttemptsData _data(
  List<LocalAttempt> rows, {
  AverageRanking? board,
  ScoreEntry? best,
  Set<String> pending = const {},
}) => MyAttemptsData(
  attempts: rows,
  ranking: board,
  officialBest: best,
  isPending: pending.contains,
);
double _oracle(List<int> durations, int count, double q, bool rms) {
  final values = durations.reversed.take(count).toList();
  var numerator = 0.0, denominator = 0.0;
  for (var i = 0; i < values.length; i++) {
    final w = math.pow(q, i).toDouble();
    numerator += (rms ? values[i] * values[i] : values[i]) * w;
    denominator += w;
  }
  return rms ? math.sqrt(numerator / denominator) : numerator / denominator;
}

class _ViewScores extends ScoresStore {
  _ViewScores(MobileAccount account) : super(account: account);
  List<LocalAttempt> rows = [];
  final waiting = <String>{};
  @override
  List<LocalAttempt> get myAttempts => rows.toList();
  @override
  bool isAttemptPending(String id) => waiting.contains(id);
  @override
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {}
  void change(List<LocalAttempt> value, {AverageRanking? ranking}) {
    rows = value;
    averageRanking = ranking;
    notifyListeners();
  }
}

class _ObservedWalletAccount extends MobileAccount {
  _ObservedWalletAccount() {
    id = 'android:1';
    wallet = {'bestTimeMs': 2000};
  }
  @override
  String? get walletOwner => id;
  void receiveBest(int value) {
    wallet = {'bestTimeMs': value};
    notifyListeners();
  }
}

Future<(_ViewScores, MobileAccount)> _mount(
  WidgetTester t,
  List<LocalAttempt> rows, {
  AverageRanking? ranking,
  MobileAccount? sourceAccount,
}) async {
  final account = sourceAccount ?? (MobileAccount()..id = 'android:1');
  final store = _ViewScores(account)..change(rows, ranking: ranking);
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(() {
    store.dispose();
    account.dispose();
  });
  await t.pumpWidget(
    ChangeNotifierProvider<ScoresStore>.value(
      value: store,
      child: MaterialApp(
        theme: buildGameTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: MyAttemptsSheet())),
      ),
    ),
  );
  await t.pump();
  return (store, account);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('reviewer real-history model', () {
    test(
      'unknown rules retain history but invent neither formula nor mean',
      () {
        final data = _data([_a('one', 2000)]);
        expect(data.rows, hasLength(1));
        expect(data.chart, isNull);
        expect(data.averageMs, isNull);
        expect(data.averageIsOfficial, false);
        final unsupported = _data([
          _a('one', 2000),
        ], board: _board(algorithm: 'future_v9'));
        expect(unsupported.averageMs, isNull);
        expect(unsupported.averages.values.every((v) => v == null), true);
      },
    );

    test(
      'official aggregate overrides incomplete local sample including zero',
      () {
        for (final value in [0.0, 25000.0]) {
          final data = _data([
            _a('one', 1000),
          ], board: _board(official: value, total: 500, used: 50));
          expect(data.averageMs, value);
          expect(data.averageIsOfficial, true);
          expect(data.historyComplete, false);
        }
      },
    );

    test('null official is never replaced by local mean or zero', () {
      final data = _data([
        _a('one', 1000),
        _a('two', 2000, date: 1),
      ], board: _board(weight: 100));
      expect(data.averageIsOfficial, false);
      expect(data.averageMs, isNull);
      expect(data.averages, isEmpty);
      expect(data.historyComplete, false);
    });

    test('no qualifying attempts have null mean and may still be complete', () {
      final data = _data([
        _a('short', 1000),
        _a('equal', 10000, date: 1),
      ], board: _board(threshold: 10000, total: 2, used: 0));
      expect(data.confirmed, hasLength(2));
      expect(data.averageMs, isNull);
      expect(data.averages.values.every((v) => v == null), true);
      expect(data.historyComplete, true);
    });

    test(
      'pending rejected and practice never win best or enter the formula',
      () {
        final data = _data(
          [
            _a('ok', 1000),
            _a('inflight', 90000, date: 1),
            _a('refused', 120000, date: 2, error: 'result_invalid'),
            _a('practice', 150000, date: 3, shared: false),
          ],
          board: _board(official: 1000, total: 1, used: 1),
          pending: {'inflight'},
        );
        expect(data.rows, hasLength(4));
        expect(data.confirmed.map((a) => a.id), ['ok']);
        expect(data.best!.id, 'ok');
        expect(data.chart!.points.single.attempt.id, 'ok');
      },
    );

    test(
      'all prefixes use complete retained data before graph viewport slicing',
      () {
        final input = List.generate(
          175,
          (i) =>
              _a('id${i.toString().padLeft(3, '0')}', 500 + i * 151, date: i),
        );
        for (final quadratic in [true, false]) {
          final data = _data(
            input.reversed.toList(),
            board: _board(
              algorithm: quadratic
                  ? AverageRanking.quadraticAlgorithm
                  : AverageRanking.legacyAlgorithm,
              window: 73,
              weight: 80,
              official: _oracle(
                input.map((a) => a.timeMs).toList(),
                73,
                .8,
                quadratic,
              ),
              total: input.length,
              used: 73,
            ),
          );
          expect(data.averages, hasLength(175));
          for (var i = 0; i < input.length; i++) {
            final expected = _oracle(
              input.take(i + 1).map((a) => a.timeMs).toList(),
              73,
              .8,
              quadratic,
            );
            expect(data.averages[input[i].id], closeTo(expected, 1e-7));
          }
          final visible = data.visibleAround(input[4].id);
          expect(visible, hasLength(100));
          expect(visible.any((a) => a.id == input[4].id), true);
          expect(visible.last.id, input[99].id);
        }
      },
    );

    test(
      'old official record outside local rows retains ID date and metrics',
      () {
        final rows = List.generate(
          120,
          (i) => _a('recent$i', 2000, date: i + 10),
        );
        final old = _score('not-loaded-server-id', 120000, date: -100);
        final data = _data(rows, board: _board(total: 900), best: old);
        expect(data.best!.id, old.id);
        expect(data.best!.createdAt, old.createdAt);
        expect(data.best!.riskCount, 4);
        expect(data.best!.runDistance, 73);
        expect(data.bestIsOfficial, true);
        expect(data.rows.any((a) => a.id == old.id), false);
      },
    );

    test(
      'equal duration with different date never selects another attempt',
      () {
        final old = _score('server-missing', 5000, date: -10);
        final data = _data([_a('local-new', 5000, date: 10)], best: old);
        expect(data.best!.id, 'server-missing');
        expect(data.best!.createdAt, old.createdAt);
      },
    );

    test(
      'legacy IDs may match exact time and date without selecting a different date',
      () {
        final data = _data([
          _a('other-date', 5000, date: 0),
          _a('exact-date', 5000, date: 10),
        ], best: _score('server-legacy-id', 5000, date: 10));
        expect(data.best!.id, 'exact-date');
        expect(data.best!.createdAt, _epoch.add(const Duration(minutes: 10)));
      },
    );

    test(
      'newer confirmed best above stale official keeps local provenance',
      () {
        final data = _data(
          [_a('fresh', 9000, date: 2)],
          board: _board(total: 99),
          best: _score('stale', 5000),
        );
        expect(data.best!.id, 'fresh');
        expect(data.best!.timeMs, 9000);
        expect(data.bestIsOfficial, false);
        final complete = _data(
          [_a('fresh', 9000, date: 2)],
          board: _board(official: 9000, total: 1, used: 1),
          best: _score('stale', 5000),
        );
        expect(complete.historyComplete, true);
        expect(
          complete.bestIsOfficial,
          false,
          reason:
              'Complete arithmetic coverage is not the source of the record',
        );
      },
    );
  });

  testWidgets('whole mean opens popup without changing panel geometry', (
    t,
  ) async {
    await _mount(t, [
      _a('one', 1000),
    ], ranking: _board(official: 1000, total: 1, used: 1));
    final before = t.getRect(find.byKey(const ValueKey('my-attempts-sheet')));
    await t.tap(find.byKey(const ValueKey('my-attempts-mean')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('my-attempts-average-help')),
      findsOneWidget,
    );
    expect(t.getRect(find.byKey(const ValueKey('my-attempts-sheet'))), before);
    expect(
      t.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      true,
    );
    await t.binding.handlePopRoute();
    // A popped dialog remains mounted for its reverse transition. Prime the
    // first frame before advancing its duration, as for the opening transition.
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(
      t.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      false,
    );
    expect(
      find.byKey(const ValueKey('my-attempts-average-help')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('my-attempts-sheet')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('owner replacement resets selection and collapsed graph', (
    t,
  ) async {
    final (store, account) = await _mount(t, [
      _a('old', 1000),
    ], ranking: _board(official: 1000));
    await t.tap(find.byKey(const ValueKey('my-attempts-toggle')));
    await t.pump();
    account.id = 'android:2';
    store.change([_a('new', 4321)], ranking: _board(official: 4321));
    await t.pump();
    expect(find.byKey(const ValueKey('my-attempts-plot')), findsOneWidget);
    final selected = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<MyAttemptsChartPainter>()
        .single
        .selected;
    expect(selected, 'new');
    expect(find.byKey(const ValueKey('my-attempts-selection')), findsNothing);
    expect(find.byKey(const ValueKey('my-attempt-old')), findsNothing);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('same-owner wallet-only best update rebuilds the open summary', (
    t,
  ) async {
    final account = _ObservedWalletAccount();
    await _mount(t, [], sourceAccount: account);
    expect(find.text('2,000 с'), findsOneWidget);
    account.receiveBest(9000);
    await t.pump();
    expect(find.text('9,000 с'), findsOneWidget);
    expect(find.text('2,000 с'), findsNothing);
    expect(find.text('Дата недоступна'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'compacted selected row reselects remaining data and details survive',
    (t) async {
      final (store, _) = await _mount(t, [
        _a('old', 1000),
        _a('remove', 2000, date: 1),
      ], ranking: _board(official: 2000));
      store.change([
        _a('kept', 4321, date: 2),
      ], ranking: _board(official: 4321));
      await t.pump();
      final selected = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<MyAttemptsChartPainter>()
          .single
          .selected;
      expect(selected, 'kept');
      expect(find.byKey(const ValueKey('my-attempts-selection')), findsNothing);
      await t.tap(find.byKey(const ValueKey('my-attempt-detail-kept')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final detail = t.widget<PlayerResultSheet>(
        find.byType(PlayerResultSheet),
      );
      expect(detail.entry.id, 'kept');
      expect(detail.entry.runDistance, 73);
      expect(detail.entry.riskCount, 4);
      expect(detail.entry.hadJump, true);
      expect(detail.entry.hadHelmet, true);
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
}
