class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.displayName,
    required this.timeMs,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final int timeMs;
  final DateTime createdAt;

  double get timeSec => timeMs / 1000.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'timeMs': timeMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      timeMs: json['timeMs'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
