/// Сводка геймплея: собирается из блоков Remote Config (enemies / player / field / game).
class GameplayConfig {
  const GameplayConfig({
    this.enemies = const EnemiesConfig(),
    this.player = const PlayerConfig(),
    this.field = const FieldConfig(),
    this.game = const GameConfig(),
  });

  final EnemiesConfig enemies;
  final PlayerConfig player;
  final FieldConfig field;
  final GameConfig game;

  double get enemyAreaMultiplier => enemies.areaMultiplier;
  double get playerSize => player.size;
  List<double> get enemyAspects => enemies.aspects;
  double get angleMinDeg => enemies.angleMinDeg;
  double get angleMaxDeg => enemies.angleMaxDeg;
  double get speedMin => enemies.speedMin;
  double get speedMax => enemies.speedMax;
  double get accelMin => enemies.accelMin;
  double get accelMax => enemies.accelMax;
  int get enemyCount => enemies.aspects.length;
  double get borderWidth => field.borderWidth;
  double get idleSpeedMultiplier => game.idleSpeedMultiplier;
  double get speedRampSeconds => game.speedRampSeconds;

  factory GameplayConfig.fromBlocks({
    required EnemiesConfig enemies,
    required PlayerConfig player,
    required FieldConfig field,
    required GameConfig game,
  }) {
    return GameplayConfig(
      enemies: enemies,
      player: player,
      field: field,
      game: game,
    );
  }

  /// Старый единый JSON `gameplay` — для совместимости.
  factory GameplayConfig.fromLegacyJson(Map<String, dynamic> json) {
    return GameplayConfig(
      enemies: EnemiesConfig.fromJson(json),
      player: PlayerConfig.fromJson(json),
      field: FieldConfig.fromJson(json),
      game: GameConfig.fromJson(json),
    );
  }
}

/// Блок Remote Config: `enemies`
class EnemiesConfig {
  const EnemiesConfig({
    this.areaMultiplier = 2.0,
    this.aspects = const [1.0, 0.25, 0.5, 3.0],
    this.angleMinDeg = 30,
    this.angleMaxDeg = 60,
    this.speedMin = 75,
    this.speedMax = 105,
    this.accelMin = 9,
    this.accelMax = 15,
  });

  final double areaMultiplier;
  final List<double> aspects;
  final double angleMinDeg;
  final double angleMaxDeg;
  final double speedMin;
  final double speedMax;
  final double accelMin;
  final double accelMax;

  Map<String, dynamic> toJson() => {
        'areaMultiplier': areaMultiplier,
        'aspects': aspects,
        'angleMinDeg': angleMinDeg,
        'angleMaxDeg': angleMaxDeg,
        'speedMin': speedMin,
        'speedMax': speedMax,
        'accelMin': accelMin,
        'accelMax': accelMax,
      };

  factory EnemiesConfig.fromJson(Map<String, dynamic> json) {
    final aspectsRaw = json['aspects'] ?? json['enemyAspects'];
    List<double> aspects = const [1.0, 0.25, 0.5, 3.0];
    if (aspectsRaw is List && aspectsRaw.isNotEmpty) {
      aspects = aspectsRaw.map((e) => (e as num).toDouble()).toList();
    }
    return EnemiesConfig(
      areaMultiplier: (json['areaMultiplier'] as num?)?.toDouble() ??
          (json['enemyAreaMultiplier'] as num?)?.toDouble() ??
          2.0,
      aspects: aspects,
      angleMinDeg: (json['angleMinDeg'] as num?)?.toDouble() ?? 30,
      angleMaxDeg: (json['angleMaxDeg'] as num?)?.toDouble() ?? 60,
      speedMin: (json['speedMin'] as num?)?.toDouble() ?? 75,
      speedMax: (json['speedMax'] as num?)?.toDouble() ?? 105,
      accelMin: (json['accelMin'] as num?)?.toDouble() ?? 9,
      accelMax: (json['accelMax'] as num?)?.toDouble() ?? 15,
    );
  }
}

/// Блок Remote Config: `player`
class PlayerConfig {
  const PlayerConfig({this.size = 36});

  final double size;

  Map<String, dynamic> toJson() => {'size': size};

  factory PlayerConfig.fromJson(Map<String, dynamic> json) {
    return PlayerConfig(
      size: (json['size'] as num?)?.toDouble() ??
          (json['playerSize'] as num?)?.toDouble() ??
          36,
    );
  }
}

/// Блок Remote Config: `field`
class FieldConfig {
  const FieldConfig({this.borderWidth = 3});

  final double borderWidth;

  Map<String, dynamic> toJson() => {'borderWidth': borderWidth};

  factory FieldConfig.fromJson(Map<String, dynamic> json) {
    return FieldConfig(
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 3,
    );
  }
}

/// Блок Remote Config: `game`
class GameConfig {
  const GameConfig({
    this.startHintEnabled = true,
    this.idleSpeedMultiplier = 0.5,
    this.speedRampSeconds = 0.5,
  });

  /// Показывать подсказку «коснитесь экрана».
  final bool startHintEnabled;

  /// Скорость врагов до первого касания (доля от стартовой).
  final double idleSpeedMultiplier;

  /// За сколько секунд скорость вырастает до нормальной после касания.
  final double speedRampSeconds;

  Map<String, dynamic> toJson() => {
        'startHintEnabled': startHintEnabled,
        'idleSpeedMultiplier': idleSpeedMultiplier,
        'speedRampSeconds': speedRampSeconds,
      };

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      startHintEnabled: json['startHintEnabled'] as bool? ?? true,
      idleSpeedMultiplier:
          (json['idleSpeedMultiplier'] as num?)?.toDouble() ?? 0.5,
      speedRampSeconds: (json['speedRampSeconds'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
