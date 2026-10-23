import 'average_ranking.dart';
import 'score_entry.dart';

/// A server-authored point retains context preceding its downloaded page.
class ServerAttempt {
  const ServerAttempt({
    required this.attempt,
    required this.number,
    required this.averageMs,
    required this.included,
    required this.windowCount,
  });
  final LocalAttempt attempt;
  final int number, windowCount;
  final double? averageMs;
  final bool included;

  factory ServerAttempt.fromJson(Map<String, dynamic> value) {
    int integer(String key, {int minimum = 0}) {
      final n = value[key];
      if (n is! num || !n.isFinite || n < minimum || n != n.toInt()) {
        throw const FormatException('Invalid attempt history number');
      }
      return n.toInt();
    }

    final id = value['id'];
    final average = value['averageMs'];
    if (id is! String ||
        id.isEmpty ||
        value['included'] is! bool ||
        average != null &&
            (average is! num || !average.isFinite || average < 0)) {
      throw const FormatException('Invalid attempt history point');
    }
    return ServerAttempt(
      attempt: LocalAttempt(
        id: id,
        timeMs: integer('timeMs'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          integer('createdAt'),
          isUtc: true,
        ),
        shared: true,
        runDistance: integer('runDistance'),
        riskCount: integer('riskCount'),
        hadJump: value['hadJump'] == true,
        hadHelmet: value['hadHelmet'] == true,
      ),
      number: integer('number', minimum: 1),
      averageMs: (average as num?)?.toDouble(),
      included: value['included'] as bool,
      windowCount: integer('windowCount'),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': attempt.id,
    'number': number,
    'timeMs': attempt.timeMs,
    'createdAt': attempt.createdAt.millisecondsSinceEpoch,
    'runDistance': attempt.runDistance,
    'riskCount': attempt.riskCount,
    'hadJump': attempt.hadJump,
    'hadHelmet': attempt.hadHelmet,
    'averageMs': averageMs,
    'included': included,
    'windowCount': windowCount,
  };
}

/// Separate from the durable result journal. Rows are newest first.
class ServerAttemptHistory {
  const ServerAttemptHistory({
    required this.userId,
    required this.snapshot,
    required this.totalCount,
    required this.rows,
    required this.nextCursor,
    required this.best,
    required this.average,
  });
  final String userId, snapshot;
  final int totalCount;
  final List<ServerAttempt> rows;
  final String? nextCursor;
  final ServerAttempt? best;
  final AverageRanking average;
  bool get complete => nextCursor == null && rows.length == totalCount;

  factory ServerAttemptHistory.fromJson(
    Map<String, dynamic> reply, {
    required String owner,
  }) {
    final history = Map<String, dynamic>.from(reply['history'] as Map);
    final ranking = AverageRanking.fromJson(
      Map<String, dynamic>.from(reply['average'] as Map),
    );
    final total = history['totalCount'];
    final snapshot = history['snapshot'];
    final next = history['nextCursor'];
    final currentAverage = ranking.mine.averageMs;
    final rows = (history['rows'] as List)
        .map((v) => ServerAttempt.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (history['userId'] != owner ||
        ranking.mine.userId != owner ||
        snapshot is! String ||
        snapshot.isEmpty ||
        total is! int ||
        total < 0 ||
        ranking.mine.totalAttempts != total ||
        currentAverage != null &&
            (!currentAverage.isFinite || currentAverage < 0) ||
        rows.length > total ||
        next != null && (next is! String || next.isEmpty) ||
        rows.map((r) => r.attempt.id).toSet().length != rows.length) {
      throw const FormatException('Invalid attempt history snapshot');
    }
    if (total > 0 && rows.isEmpty ||
        rows.isNotEmpty && ((rows.last.number == 1) != (next == null))) {
      throw const FormatException('Invalid attempt history continuation');
    }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].number > total ||
          i > 0 && rows[i - 1].number != rows[i].number + 1) {
        throw const FormatException('Invalid attempt history order');
      }
    }
    final best = history['best'] == null
        ? null
        : ServerAttempt.fromJson(
            Map<String, dynamic>.from(history['best'] as Map),
          );
    if (best != null && best.number > total || total == 0 && best != null) {
      throw const FormatException('Invalid attempt history record');
    }
    return ServerAttemptHistory(
      userId: owner,
      snapshot: snapshot,
      totalCount: total,
      rows: List.unmodifiable(rows),
      nextCursor: next as String?,
      best: best,
      average: ranking,
    );
  }

  ServerAttemptHistory append(ServerAttemptHistory older) {
    final loadedIds = rows.map((r) => r.attempt.id).toSet();
    if (older.userId != userId ||
        older.snapshot != snapshot ||
        older.totalCount != totalCount ||
        older.average.toJson().toString() != average.toJson().toString() ||
        older.rows.isEmpty ||
        rows.isNotEmpty && older.rows.first.number != rows.last.number - 1 ||
        older.rows.any((r) => loadedIds.contains(r.attempt.id))) {
      throw const FormatException('Attempt history snapshot changed');
    }
    return ServerAttemptHistory(
      userId: userId,
      snapshot: snapshot,
      totalCount: totalCount,
      rows: List.unmodifiable([...rows, ...older.rows]),
      nextCursor: older.nextCursor,
      best: best,
      average: average,
    );
  }

  Map<String, dynamic> toJson() => {
    'average': average.toJson(),
    'history': {
      'userId': userId,
      'snapshot': snapshot,
      'totalCount': totalCount,
      'rows': rows.map((r) => r.toJson()).toList(),
      'nextCursor': nextCursor,
      'best': best?.toJson(),
    },
  };
}
