class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.displayName,
    required this.timeMs,
    required this.createdAt,
    this.countryCode = '--',
    this.uid,
    this.riskCount = 0,
    this.runDistance = 0,
    this.hadJump = false,
    this.hadHelmet = false,
  });

  final String id;
  final String displayName;
  final int timeMs;
  final DateTime createdAt;

  /// ISO 3166-1 alpha-2, например US / RU.
  final String countryCode;

  /// Firebase Auth uid автора (если есть) — для подсветки «с этого устройства».
  final String? uid;

  /// Near-miss / прыжки через врага.
  final int riskCount;

  /// Пробег за партию (px), округлённый.
  final int runDistance;

  /// В партии была активна аренда прыжка.
  final bool hadJump;

  /// В партии был активен шлем (на старте раунда).
  final bool hadHelmet;

  double get timeSec => timeMs / 1000.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'timeMs': timeMs,
        'createdAt': createdAt.toIso8601String(),
        'countryCode': countryCode,
        if (uid != null) 'uid': uid,
        'riskCount': riskCount,
        'runDistance': runDistance,
        'hadJump': hadJump,
        'hadHelmet': hadHelmet,
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      timeMs: json['timeMs'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      countryCode: (json['countryCode'] as String?)?.toUpperCase() ?? '--',
      uid: json['uid'] as String?,
      riskCount: (json['riskCount'] as num?)?.toInt() ??
          (json['nearMissCount'] as num?)?.toInt() ??
          0,
      runDistance: (json['runDistance'] as num?)?.toInt() ??
          (json['playerDistance'] as num?)?.toInt() ??
          0,
      hadJump: json['hadJump'] as bool? ?? false,
      hadHelmet: json['hadHelmet'] as bool? ?? false,
    );
  }
}

/// Локальная попытка игрока (даже без Share).
class LocalAttempt {
  const LocalAttempt({
    required this.id,
    required this.timeMs,
    required this.createdAt,
    this.shared = false,
    this.displayName,
    this.riskCount = 0,
    this.runDistance = 0,
    this.hadJump = false,
    this.hadHelmet = false,
  });

  final String id;
  final int timeMs;
  final DateTime createdAt;
  final bool shared;

  /// Имя, под которым результат сохранён в рейтинг (если shared).
  final String? displayName;
  final int riskCount;
  final int runDistance;
  final bool hadJump;
  final bool hadHelmet;

  double get timeSec => timeMs / 1000.0;

  LocalAttempt copyWith({
    bool? shared,
    String? displayName,
    int? riskCount,
    int? runDistance,
    bool? hadJump,
    bool? hadHelmet,
  }) {
    return LocalAttempt(
      id: id,
      timeMs: timeMs,
      createdAt: createdAt,
      shared: shared ?? this.shared,
      displayName: displayName ?? this.displayName,
      riskCount: riskCount ?? this.riskCount,
      runDistance: runDistance ?? this.runDistance,
      hadJump: hadJump ?? this.hadJump,
      hadHelmet: hadHelmet ?? this.hadHelmet,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeMs': timeMs,
        'createdAt': createdAt.toIso8601String(),
        'shared': shared,
        if (displayName != null) 'displayName': displayName,
        'riskCount': riskCount,
        'runDistance': runDistance,
        'hadJump': hadJump,
        'hadHelmet': hadHelmet,
      };

  factory LocalAttempt.fromJson(Map<String, dynamic> json) {
    return LocalAttempt(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      shared: json['shared'] as bool? ?? false,
      displayName: json['displayName'] as String?,
      riskCount: (json['riskCount'] as num?)?.toInt() ??
          (json['nearMissCount'] as num?)?.toInt() ??
          0,
      runDistance: (json['runDistance'] as num?)?.toInt() ??
          (json['playerDistance'] as num?)?.toInt() ??
          0,
      hadJump: json['hadJump'] as bool? ?? false,
      hadHelmet: json['hadHelmet'] as bool? ?? false,
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
