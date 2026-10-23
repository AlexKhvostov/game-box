import 'average_chart.dart';
import 'average_ranking.dart';
import 'score_entry.dart';
import 'server_attempt_history.dart';

class MyAttemptsData {
  static int? confirmedWalletBestTimeMs({
    required Map<String, dynamic>? wallet,
    required String? walletOwner,
    required String? owner,
  }) {
    if (owner == null || owner.isEmpty || walletOwner != owner) return null;
    final value = wallet?['bestTimeMs'];
    return value is num && value.isFinite && value > 0 ? value.toInt() : null;
  }

  MyAttemptsData({
    required List<LocalAttempt> attempts,
    required AverageRanking? ranking,
    required bool Function(String) isPending,
    String Function(String)? serverIdOf,
    this.serverHistory,
    this.officialBest,
    int? officialBestTimeMs,
  }) : ranking = serverHistory?.average ?? ranking {
    if (serverHistory != null) {
      final history = serverHistory!;
      final ids = history.rows.map((r) => r.attempt.id).toSet();
      final waiting =
          attempts
              .where(
                (a) =>
                    !ids.contains(serverIdOf?.call(a.id) ?? a.id) &&
                    (!a.shared || isPending(a.id)),
              )
              .toList()
            ..sort((a, b) {
              final date = a.createdAt.compareTo(b.createdAt);
              return date == 0 ? a.id.compareTo(b.id) : date;
            });
      // Server ordinals are authoritative even when dates/IDs tie.
      // Unconfirmed attempts are a separate tail, without invented ordinals.
      rows = List.unmodifiable([
        ...history.rows.reversed.map((r) => r.attempt),
        ...waiting,
      ]);
      confirmed = List.unmodifiable(history.rows.map((r) => r.attempt));
      best = history.best?.attempt;
      _bestTimeMs = best?.timeMs;
      _bestFromOfficial = true;
      averages = {
        for (final point in history.rows) point.attempt.id: point.averageMs,
      };
      _numbers = {
        for (final point in history.rows) point.attempt.id: point.number,
        if (history.best != null)
          history.best!.attempt.id: history.best!.number,
      };
      return;
    }
    rows = List.unmodifiable(
      [...attempts]..sort((a, b) {
        final date = a.createdAt.compareTo(b.createdAt);
        return date == 0 ? a.id.compareTo(b.id) : date;
      }),
    );
    if (rulesKnown) {
      chart = AverageChartData.fromAttempts(
        attempts: rows,
        ranking: this.ranking!,
        isPending: isPending,
        visibleLimit: rows.isEmpty ? 1 : rows.length,
      );
    }
    confirmed = List.unmodifiable(
      rows.where(
        (a) =>
            a.shared &&
            a.deliveryError == null &&
            !isPending(a.id) &&
            a.timeMs > 0,
      ),
    );
    for (final row in confirmed) {
      if (best == null || row.timeMs > best!.timeMs) best = row;
    }
    if (officialBest != null &&
        (best == null || officialBest!.timeMs >= best!.timeMs)) {
      _bestFromOfficial = true;
      final entry = officialBest!;
      // Keep the local identity when that exact confirmed attempt is loaded.
      best =
          confirmed
              .where(
                (a) =>
                    a.id == entry.id ||
                    (a.timeMs == entry.timeMs &&
                        a.createdAt.isAtSameMomentAs(entry.createdAt)),
              )
              .firstOrNull ??
          LocalAttempt(
            id: entry.id,
            timeMs: entry.timeMs,
            createdAt: entry.createdAt,
            shared: true,
            displayName: entry.displayName,
            runDistance: entry.runDistance,
            riskCount: entry.riskCount,
            hadJump: entry.hadJump,
            hadHelmet: entry.hadHelmet,
          );
    }
    _bestTimeMs = best?.timeMs;
    if (officialBestTimeMs != null &&
        officialBestTimeMs > 0 &&
        officialBestTimeMs > (_bestTimeMs ?? 0)) {
      _bestTimeMs = officialBestTimeMs;
      best = null; // The wallet confirms a value, never an ID or a date.
      _bestFromOfficial = true;
      _bestFromWallet = true;
    }
    averages = {
      if (showsHistoricalAverage)
        for (final point in chart!.points)
          point.attempt.id: identical(point, chart!.points.last)
              ? averageMs
              : point.averageMs,
    };
  }

  final AverageRanking? ranking;
  final ServerAttemptHistory? serverHistory;
  final ScoreEntry? officialBest;
  late final List<LocalAttempt> rows, confirmed;
  AverageChartData? chart;
  LocalAttempt? best;
  int? _bestTimeMs;
  int? get bestTimeMs => _bestTimeMs;
  bool _bestFromOfficial = false;
  bool _bestFromWallet = false;
  late final Map<String, double?> averages;
  Map<String, int> _numbers = const {};
  bool get rulesKnown =>
      ranking != null &&
      {
        AverageRanking.quadraticAlgorithm,
        AverageRanking.legacyAlgorithm,
      }.contains(ranking!.algorithm);
  bool get historyComplete =>
      serverHistory?.complete ??
      (chart?.historyComplete == true ||
          (ranking?.mine.totalAttempts == confirmed.length &&
              ranking?.mine.averageMs == null &&
              ranking?.mine.usedCount == 0 &&
              (chart?.currentWindowCount == 0 || confirmed.isEmpty)));
  bool get averageIsOfficial => averageMs != null;
  double? get averageMs {
    final value = ranking?.mine.averageMs;
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  // A partial device history cannot reconstruct the server's earlier means.
  bool get showsHistoricalAverage =>
      serverHistory != null ||
      (averageMs != null && rulesKnown && chart?.historyComplete == true);
  // An official scalar must never masquerade as a historical flat curve.
  double? get referenceAverageMs => null;
  int? numberOf(String id) => serverHistory != null
      ? _numbers[id]
      : rows.indexWhere((r) => r.id == id) + 1;
  bool get bestIsOfficial => _bestFromOfficial;
  String get bestSource => _bestFromWallet
      ? 'server_wallet'
      : _bestFromOfficial
      ? 'server'
      : historyComplete
      ? 'complete_confirmed_history'
      : 'available_history';

  // Display history length is independent of the ranking's calculation window.
  List<LocalAttempt> visibleAround(String? selected, {int limit = 100}) {
    final found = rows.indexWhere((a) => a.id == selected);
    final index = found < 0 ? rows.length - 1 : found;
    final start = (index - limit ~/ 2).clamp(
      0,
      (rows.length - limit).clamp(0, rows.length),
    );
    return rows.skip(start).take(limit).toList(growable: false);
  }
}
