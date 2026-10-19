import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/average_chart.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/score_entry.dart';

LocalAttempt attempt(int i, int ms, {bool shared = true, String? error}) =>
    LocalAttempt(
      id: '$i',
      timeMs: ms,
      createdAt: DateTime.utc(2026, 10, 19).add(Duration(seconds: i)),
      shared: shared,
      deliveryError: error,
    );

void main() {
  test(
    '100 visible attempts retain history while only last 50 qualify for current mean',
    () {
      final data = AverageChartData.fromAttempts(
        attempts: [for (var i = 1; i <= 200; i++) attempt(i, i * 100)],
        ranking: const AverageRanking(),
      );
      expect(data.points.length, 100);
      expect(data.points.first.attempt.id, '101');
      expect(data.currentWindowCount, 50);
      expect(data.points.where((p) => p.inCurrentWindow).length, 50);
      expect(data.points[49].inCurrentWindow, isFalse);
      expect(data.points[50].attempt.id, '151');
      expect(data.points[50].inCurrentWindow, isTrue);
      final filtered = AverageChartData.fromAttempts(
        attempts: [
          for (var i = 1; i <= 100; i++) attempt(i, i.isEven ? 700 : 7000),
        ],
        ranking: const AverageRanking(minDurationMs: 1000),
      );
      expect(filtered.points.where((p) => p.inCurrentWindow).length, 50);
      expect(filtered.points.first.inCurrentWindow, isTrue);
      expect(filtered.points.last.inCurrentWindow, isFalse);
    },
  );
  test('uses normalized server weights, not the unnormalized sketch EMA', () {
    final data = AverageChartData.fromAttempts(
      attempts: [attempt(2, 2000), attempt(1, 1000)],
      ranking: const AverageRanking(
        mine: AverageRankEntry(
          averageMs: 1520.8333333333333,
          usedCount: 2,
          totalAttempts: 2,
        ),
      ),
    );
    expect(data.points.first.averageMs, 1000);
    expect(data.averageMs, closeTo(1520.8333333333333, 1e-9));
    expect(data.matchesRanking, isTrue);
    expect(data.historyComplete, isTrue);
  });
  test(
    'strict RC threshold: gray short attempts count at zero, excluded ones hold line',
    () {
      final history = [
        attempt(1, 400),
        attempt(2, 1000),
        attempt(3, 2000),
        attempt(4, 700),
      ];
      final all = AverageChartData.fromAttempts(
        attempts: history,
        ranking: const AverageRanking(),
      );
      expect(all.visibleEligibleCount, 4);
      expect(all.points.last.averageMs, lessThan(all.points[2].averageMs!));
      final filtered = AverageChartData.fromAttempts(
        attempts: history,
        ranking: const AverageRanking(minDurationMs: 1000),
      );
      expect(filtered.visibleEligibleCount, 1);
      expect(filtered.points[1].averageMs, isNull);
      expect(filtered.points.last.averageMs, 2000);
      expect(filtered.points.last.included, isFalse);
    },
  );
  test(
    'filters confirmations/errors/pending, never mutates source history',
    () {
      final history = [
        attempt(1, 1000),
        attempt(2, 2000, shared: false),
        attempt(3, 3000, error: 'result_invalid'),
        attempt(4, 4000),
        attempt(5, 0),
      ];
      final data = AverageChartData.fromAttempts(
        attempts: history,
        ranking: const AverageRanking(),
        isPending: (id) => id == '2' || id == '4',
      );
      expect(data.points.map((p) => p.attempt.id), ['1']);
      expect(data.awaitingCount, 1);
      expect(history.map((a) => a.id), ['1', '2', '3', '4', '5']);
    },
  );
  test(
    'finite window drops oldest eligible value before normalizing, even when hidden',
    () {
      final data = AverageChartData.fromAttempts(
        attempts: [for (var i = 1; i <= 6; i++) attempt(i, i * 1000)],
        ranking: const AverageRanking(
          windowSize: 3,
          previousWeightPercent: 100,
        ),
        visibleLimit: 2,
      );
      expect(data.confirmedCount, 6);
      expect(data.points.map((p) => p.averageMs), [4000.0, 5000.0]);
      expect(data.points.last.windowCount, 3);
      expect(data.historyComplete, isFalse);
    },
  );
  test(
    'no confirmed history stays empty, unknown/mismatched server history is explicit',
    () {
      final empty = AverageChartData.fromAttempts(
        attempts: [],
        ranking: const AverageRanking(),
      );
      expect(empty.points, isEmpty);
      expect(empty.averageMs, isNull);
      final partial = AverageChartData.fromAttempts(
        attempts: [attempt(1, 1000)],
        ranking: const AverageRanking(
          mine: AverageRankEntry(
            averageMs: 1000,
            usedCount: 1,
            totalAttempts: 50,
          ),
        ),
      );
      expect(partial.matchesRanking, isTrue);
      expect(partial.historyComplete, isFalse);
    },
  );
}
