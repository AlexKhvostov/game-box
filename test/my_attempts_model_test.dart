import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/domain/average_ranking.dart';
import 'package:game_box/domain/my_attempts.dart';
import 'package:game_box/domain/score_entry.dart';

LocalAttempt attempt(int n, int ms, {bool shared = true, String? error}) =>
    LocalAttempt(
      id: '$n',
      timeMs: ms,
      createdAt: DateTime.utc(2026, 10, 21).add(Duration(minutes: n)),
      shared: shared,
      deliveryError: error,
    );
MyAttemptsData data(
  List<LocalAttempt> rows, {
  AverageRanking? ranking,
  ScoreEntry? best,
  Set<String> pending = const {},
}) => MyAttemptsData(
  attempts: rows,
  ranking: ranking,
  isPending: pending.contains,
  officialBest: best,
);

void main() {
  test(
    'Partial local history keeps official value without inventing a flat curve',
    () {
      final model = data(
        [attempt(1, 4000), attempt(2, 16000)],
        ranking: const AverageRanking(
          algorithm: AverageRanking.quadraticAlgorithm,
          mine: AverageRankEntry(
            averageMs: 11716.093,
            usedCount: 32,
            totalAttempts: 32,
          ),
        ),
      );
      expect(model.averageMs, 11716.093);
      expect(model.referenceAverageMs, isNull);
      expect(model.showsHistoricalAverage, isFalse);
      expect(model.averages, isEmpty);
      expect(model.chart!.averageMs, isNot(model.averageMs));
    },
  );
  test(
    'Complete matching history ends at the exact official value; stale aggregate hides curve',
    () {
      final official = math.sqrt((3000 * 3000 * .92 + 9000 * 9000) / 1.92);
      for (final value in [official, 4000.0]) {
        final model = data(
          [attempt(1, 3000), attempt(2, 9000)],
          ranking: AverageRanking(
            algorithm: AverageRanking.quadraticAlgorithm,
            mine: AverageRankEntry(
              averageMs: value,
              usedCount: 2,
              totalAttempts: 2,
            ),
          ),
        );
        expect(model.showsHistoricalAverage, value == official);
        expect(model.averageMs, value);
        if (value == official) {
          expect(model.averages['2'], same(model.averageMs));
          expect(model.averages['1'], 3000);
          expect(model.referenceAverageMs, isNull);
        } else {
          expect(model.averages, isEmpty);
          expect(model.referenceAverageMs, isNull);
        }
      }
    },
  );
  test(
    'Invalid official values cannot be replaced with a plausible local mean',
    () {
      for (final value in [null, double.nan, double.infinity, -1.0]) {
        final model = data(
          [attempt(1, 9000)],
          ranking: AverageRanking(
            algorithm: AverageRanking.quadraticAlgorithm,
            mine: AverageRankEntry(
              averageMs: value,
              usedCount: 1,
              totalAttempts: 1,
            ),
          ),
        );
        expect(model.averageMs, isNull);
        expect(model.averages, isEmpty);
        expect(model.referenceAverageMs, isNull);
      }
    },
  );
  test(
    'Only a confirmed wallet owned by the current account supplies a record scalar',
    () {
      expect(
        MyAttemptsData.confirmedWalletBestTimeMs(
          wallet: {'bestTimeMs': 9000},
          walletOwner: 'owner',
          owner: 'owner',
        ),
        9000,
      );
      for (final walletOwner in [null, 'other']) {
        expect(
          MyAttemptsData.confirmedWalletBestTimeMs(
            wallet: {'bestTimeMs': 9000},
            walletOwner: walletOwner,
            owner: 'owner',
          ),
          isNull,
        );
      }
      for (final value in [0, -1, double.nan, double.infinity, '9000']) {
        expect(
          MyAttemptsData.confirmedWalletBestTimeMs(
            wallet: {'bestTimeMs': value},
            walletOwner: 'owner',
            owner: 'owner',
          ),
          isNull,
        );
      }
    },
  );
  test(
    'Wallet-only record has an authoritative value and no invented ID or date',
    () {
      final model = MyAttemptsData(
        attempts: [attempt(1, 4000)],
        ranking: null,
        isPending: (_) => false,
        officialBestTimeMs: 99000,
      );
      expect(model.bestTimeMs, 99000);
      expect(model.best, isNull);
      expect(model.bestIsOfficial, isTrue);
      expect(model.bestSource, 'server_wallet');
      expect(model.rows.single.timeMs, 4000);
    },
  );
  test(
    'A stale wallet scalar preserves the actual larger confirmed record and date',
    () {
      final row = attempt(1, 9000);
      final model = MyAttemptsData(
        attempts: [row],
        ranking: null,
        isPending: (_) => false,
        officialBestTimeMs: 5000,
      );
      expect(model.bestTimeMs, 9000);
      expect(model.best!.id, row.id);
      expect(model.best!.createdAt, row.createdAt);
      expect(model.bestIsOfficial, isFalse);
    },
  );
  test('Official RMS and true date agree with complete sorted history', () {
    final rms = math.sqrt((3000 * 3000 + 4000 * 4000) / 2);
    final model = data(
      [attempt(2, 4000), attempt(1, 3000)],
      ranking: AverageRanking(
        algorithm: AverageRanking.quadraticAlgorithm,
        previousWeightPercent: 100,
        mine: AverageRankEntry(averageMs: rms, usedCount: 2, totalAttempts: 2),
      ),
    );
    expect(model.averageMs, closeTo(rms, .00001));
    expect(model.historyComplete, isTrue);
    expect(model.averageIsOfficial, isTrue);
    expect(model.best!.createdAt, attempt(2, 4000).createdAt);
    expect(model.rows.map((a) => a.id), ['1', '2']);
  });
  test(
    'Transport pending, rejected and practice stay visible but never become best or average',
    () {
      final model = data(
        [
          attempt(1, 4000),
          attempt(2, 90000, shared: false),
          attempt(3, 80000, error: 'replay_invalid'),
          attempt(4, 70000, shared: false),
        ],
        ranking: const AverageRanking(),
        pending: {'2'},
      );
      expect(model.rows.length, 4);
      expect(model.confirmed.map((a) => a.id), ['1']);
      expect(model.best!.timeMs, 4000);
      expect(model.averages, isEmpty);
      expect(model.averages['2'], isNull);
    },
  );
  test(
    'Strict threshold and current legacy weighted arithmetic are reused',
    () {
      final model = data(
        [attempt(1, 1000), attempt(2, 2000), attempt(3, 3000)],
        ranking: const AverageRanking(
          windowSize: 2,
          previousWeightPercent: 70,
          minDurationMs: 1000,
        ),
      );
      expect(model.averages, isEmpty);
      expect(model.chart!.points.first.averageMs, isNull);
      expect(
        model.chart!.points.last.averageMs,
        closeTo((3000 + 2000 * .7) / 1.7, .00001),
      );
      expect(model.averageIsOfficial, isFalse);
    },
  );
  test(
    '100 displayed attempts preserve the independent 50-attempt RMS window',
    () {
      final model = data(
        List.generate(200, (i) => attempt(i, 1000 + i * 100)),
        ranking: const AverageRanking(
          algorithm: AverageRanking.quadraticAlgorithm,
        ),
      );
      expect(model.chart!.points.length, 200);
      expect(model.visibleAround('0').map((a) => a.id).first, '0');
      expect(model.visibleAround('199').map((a) => a.id).first, '100');
      expect(model.visibleAround('199').length, 100);
      var numerator = 0.0, denominator = 0.0, factor = 1.0;
      for (var i = 199; i >= 150; i--) {
        numerator += math.pow(1000 + i * 100, 2) * factor;
        denominator += factor;
        factor *= .92;
      }
      expect(
        model.chart!.points.last.averageMs,
        closeTo(math.sqrt(numerator / denominator), .00001),
      );
    },
  );
  test(
    'Official aggregate and missing official best outrank partial device sample',
    () {
      final record = ScoreEntry(
        id: 'server-best',
        uid: 'owner',
        displayName: 'Player',
        timeMs: 30000,
        createdAt: DateTime.utc(2025, 8, 9),
      );
      final model = data(
        [attempt(1, 4000)],
        best: record,
        ranking: const AverageRanking(
          mine: AverageRankEntry(averageMs: 20000, totalAttempts: 600),
        ),
      );
      expect(model.averageMs, 20000);
      expect(model.best!.id, record.id);
      expect(model.best!.createdAt, record.createdAt);
      expect(model.bestIsOfficial, isTrue);
      expect(model.historyComplete, isFalse);
      expect(model.rows.any((a) => a.id == record.id), isFalse);
    },
  );
  test(
    'A stale smaller official record does not make the chosen local best official',
    () {
      final model = data(
        [attempt(1, 9000)],
        best: ScoreEntry(
          id: 'old-best',
          displayName: 'Player',
          timeMs: 5000,
          createdAt: DateTime.utc(2025),
        ),
        ranking: const AverageRanking(
          mine: AverageRankEntry(totalAttempts: 600),
        ),
      );
      expect(model.best!.timeMs, 9000);
      expect(model.bestIsOfficial, isFalse);
    },
  );
  test(
    'Null official mean never falls back to an incomplete device projection',
    () {
      final model = data(
        [attempt(1, 5000)],
        ranking: const AverageRanking(
          mine: AverageRankEntry(averageMs: null, totalAttempts: 600),
        ),
      );
      expect(model.averageMs, isNull);
      expect(model.averages, isEmpty);
      expect(model.referenceAverageMs, isNull);
      expect(model.averageIsOfficial, isFalse);
      expect(model.historyComplete, isFalse);
    },
  );
  test('Absent rules do not invent 50/92 or calculate a mean', () {
    final model = data([attempt(1, 5000)]);
    expect(model.ranking, isNull);
    expect(model.averageMs, isNull);
    expect(model.bestIsOfficial, isFalse);
  });
  test('Matching official best keeps the actual stable local row identity', () {
    final row = attempt(1, 5000);
    final model = data(
      [row],
      best: ScoreEntry(
        id: 'remote-id',
        displayName: 'Player',
        timeMs: row.timeMs,
        createdAt: row.createdAt,
      ),
    );
    expect(model.best!.id, row.id);
    expect(model.bestIsOfficial, isTrue);
  });
  test('Empty full history and unknown selection are safe', () {
    final empty = data(
      [],
      ranking: const AverageRanking(mine: AverageRankEntry(totalAttempts: 0)),
    );
    expect(empty.historyComplete, isTrue);
    expect(empty.best, isNull);
    expect(empty.visibleAround('missing'), isEmpty);
    final many = data(List.generate(100, (i) => attempt(i, 1000)));
    expect(many.visibleAround('missing').first.id, '0');
  });
}
