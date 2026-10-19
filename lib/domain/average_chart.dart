import 'dart:math' as math;

import 'average_ranking.dart';
import 'score_entry.dart';

/// Read-only projection of this account's confirmed device history.
/// This never replaces or submits the official server aggregate.
class AverageChartPoint {
  const AverageChartPoint({
    required this.attempt,
    required this.included,
    required this.averageMs,
    required this.windowCount,
    this.inCurrentWindow = false,
  });
  final LocalAttempt attempt;
  final bool included;
  final double? averageMs;
  final int windowCount;
  final bool inCurrentWindow;
}

class AverageChartData {
  const AverageChartData({
    required this.points,
    required this.confirmedCount,
    required this.awaitingCount,
    required this.historyComplete,
    required this.matchesRanking,
    required this.ranking,
  });
  final List<AverageChartPoint> points;
  final int confirmedCount, awaitingCount;
  final bool historyComplete, matchesRanking;
  final AverageRanking ranking;
  double? get averageMs => points.lastOrNull?.averageMs;
  int get visibleEligibleCount => points.where((p) => p.included).length;
  int get currentWindowCount => points.lastOrNull?.windowCount ?? 0;

  factory AverageChartData.fromAttempts({
    required List<LocalAttempt> attempts,
    required AverageRanking ranking,
    bool Function(String id)? isPending,
    int visibleLimit = 100,
  }) {
    assert(visibleLimit > 0);
    final confirmed =
        attempts
            .where(
              (a) =>
                  a.shared &&
                  a.deliveryError == null &&
                  a.timeMs > 0 &&
                  !(isPending?.call(a.id) ?? false),
            )
            .toList()
          ..sort((a, b) {
            final date = a.createdAt.compareTo(b.createdAt);
            return date != 0 ? date : a.id.compareTo(b.id);
          });
    final waiting = attempts
        .where(
          (a) =>
              !a.shared &&
              a.deliveryError == null &&
              (isPending?.call(a.id) ?? false),
        )
        .length;
    final eligible = <int>[];
    final projected = <AverageChartPoint>[];
    final weight = ranking.previousWeightPercent / 100;
    for (final attempt in confirmed) {
      final included = attempt.timeMs > ranking.minDurationMs;
      if (included) {
        eligible.add(attempt.timeMs);
        if (eligible.length > ranking.windowSize) eligible.removeAt(0);
      }
      // Same normalized exponential weights as average-ranking.mjs:
      // newest=1, previous=.92, previous=.92², over the latest N eligible.
      var sum = 0.0, weights = 0.0, factor = 1.0;
      for (var i = eligible.length - 1; i >= 0; i--) {
        final value = eligible[i].toDouble();
        sum += (ranking.isQuadratic ? value * value : value) * factor;
        weights += factor;
        factor *= weight;
      }
      projected.add(
        AverageChartPoint(
          attempt: attempt,
          included: included,
          averageMs: weights > 0
              ? (ranking.isQuadratic ? math.sqrt(sum / weights) : sum / weights)
              : null,
          windowCount: eligible.length,
        ),
      );
    }
    final end = projected.lastOrNull?.averageMs;
    final official = ranking.mine.averageMs;
    final matches =
        end != null &&
        official != null &&
        (end - official).abs() < .01 &&
        projected.last.windowCount == ranking.mine.usedCount;
    final activeIds = projected.reversed
        .where((p) => p.included)
        .take(ranking.windowSize)
        .map((p) => p.attempt.id)
        .toSet();
    final visible = projected.length <= visibleLimit
        ? projected
        : projected.sublist(projected.length - visibleLimit);
    return AverageChartData(
      points: List.unmodifiable(
        visible.map(
          (p) => AverageChartPoint(
            attempt: p.attempt,
            included: p.included,
            averageMs: p.averageMs,
            windowCount: p.windowCount,
            inCurrentWindow: activeIds.contains(p.attempt.id),
          ),
        ),
      ),
      confirmedCount: confirmed.length,
      awaitingCount: waiting,
      historyComplete:
          ranking.mine.totalAttempts == confirmed.length && matches,
      matchesRanking: matches,
      ranking: ranking,
    );
  }
}
