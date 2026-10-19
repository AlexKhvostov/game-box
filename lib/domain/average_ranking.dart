/// Server-confirmed weighted average. Never sent as a client-authored score.
class AverageRanking {
  const AverageRanking({
    this.windowSize = 50,
    this.previousWeightPercent = 92,
    this.minAttempts = 1,
    this.minDurationMs = 0,
    this.rows = const [],
    this.mine = const AverageRankEntry(),
  });
  final int windowSize, minAttempts, minDurationMs;
  final double previousWeightPercent;
  final List<AverageRankEntry> rows;
  final AverageRankEntry mine;

  factory AverageRanking.fromJson(Map<String, dynamic> json) {
    final rules = json['rules'] as Map;
    return AverageRanking(
      windowSize: (rules['windowSize'] as num).toInt(),
      previousWeightPercent: (rules['previousWeightPercent'] as num).toDouble(),
      minAttempts: (rules['minAttempts'] as num).toInt(),
      minDurationMs: (rules['minDurationMs'] as num).toInt(),
      rows: (json['rows'] as List)
          .map(
            (v) =>
                AverageRankEntry.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      mine: AverageRankEntry.fromJson(
        Map<String, dynamic>.from(json['mine'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'rules': {
      'windowSize': windowSize,
      'previousWeightPercent': previousWeightPercent,
      'minAttempts': minAttempts,
      'minDurationMs': minDurationMs,
    },
    'rows': rows.map((r) => r.toJson()).toList(),
    'mine': mine.toJson(),
  };
}

class AverageRankEntry {
  const AverageRankEntry({
    this.userId,
    this.playerName = '',
    this.averageMs,
    this.usedCount = 0,
    this.eligibleCount = 0,
    this.totalAttempts,
    this.place,
  });
  final String? userId;
  final String playerName;
  final double? averageMs;
  final int usedCount, eligibleCount;

  /// All confirmed attempts, including those too short for the average.
  /// Null means an older server/cache did not supply this counter.
  final int? totalAttempts;
  final int? place;

  factory AverageRankEntry.fromJson(Map<String, dynamic> json) =>
      AverageRankEntry(
        userId: json['userId'] as String?,
        playerName: json['playerName'] as String? ?? '',
        averageMs: (json['averageMs'] as num?)?.toDouble(),
        usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
        eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
        totalAttempts: (json['totalAttempts'] as num?)?.toInt(),
        place: (json['place'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'playerName': playerName,
    'averageMs': averageMs,
    'usedCount': usedCount,
    'eligibleCount': eligibleCount,
    'totalAttempts': totalAttempts,
    'place': place,
  };
}
