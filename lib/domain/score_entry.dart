class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.displayName,
    required this.timeMs,
    required this.createdAt,
    this.countryCode = '--',
  });

  final String id;
  final String displayName;
  final int timeMs;
  final DateTime createdAt;

  /// ISO 3166-1 alpha-2, например US / RU.
  final String countryCode;

  double get timeSec => timeMs / 1000.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'timeMs': timeMs,
        'createdAt': createdAt.toIso8601String(),
        'countryCode': countryCode,
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      timeMs: json['timeMs'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      countryCode: (json['countryCode'] as String?)?.toUpperCase() ?? '--',
    );
  }
}

class RankInfo {
  const RankInfo({
    required this.place,
    required this.percentile,
    required this.totalCount,
  });

  final int place;
  final int percentile;
  final int totalCount;
}

/// Места одного результата по временным срезам.
class PeriodRanks {
  const PeriodRanks({
    required this.day,
    required this.week,
    required this.month,
    required this.year,
    required this.all,
  });

  final RankInfo day;
  final RankInfo week;
  final RankInfo month;
  final RankInfo year;
  final RankInfo all;
}
