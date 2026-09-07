import 'package:flutter/material.dart';

/// Сводка геймплея: собирается из блоков Remote Config (enemies / player / field / game / audio).
class GameplayConfig {
  const GameplayConfig({
    this.enemies = const EnemiesConfig(),
    this.player = const PlayerConfig(),
    this.field = const FieldConfig(),
    this.game = const GameConfig(),
    this.audio = const AudioConfig(),
  });

  final EnemiesConfig enemies;
  final PlayerConfig player;
  final FieldConfig field;
  final GameConfig game;
  final AudioConfig audio;

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
  double get fieldBrightness => field.brightness;
  String? get fieldColorHex => field.colorHex;
  bool get enemiesCollide => enemies.collideWithEachOther;
  double get enemySpinDegPerSec => enemies.spinDegPerSec;
  double get idleSpeedMultiplier => game.idleSpeedMultiplier;
  double get speedRampSeconds => game.speedRampSeconds;
  bool get jumpEnabled => game.jumpEnabled;
  double get jumpDurationSec => game.jumpDurationSec;
  double get jumpScale => game.jumpScale;
  bool get helmetEnabled => game.helmetEnabled;
  /// Секунды неуязвимости (мигание) после разрушения шлема.
  double get helmetInvulnSec => game.helmetInvulnSec;
  /// Секунды неуязвимости в начале раунда.
  double get startInvulnSec => game.startInvulnSec;
  /// Верх шкалы скорости в HUD (полоска под полем).
  double get hudSpeedScaleMax => game.hudSpeedScaleMax;

  /// Этажи: касание стены/препятствия убивает героя.
  bool get wallsKillPlayer => game.wallsKillPlayer;

  factory GameplayConfig.fromBlocks({
    required EnemiesConfig enemies,
    required PlayerConfig player,
    required FieldConfig field,
    required GameConfig game,
    AudioConfig audio = const AudioConfig(),
  }) {
    return GameplayConfig(
      enemies: enemies,
      player: player,
      field: field,
      game: game,
      audio: audio,
    );
  }

  /// Старый единый JSON `gameplay` — для совместимости.
  factory GameplayConfig.fromLegacyJson(Map<String, dynamic> json) {
    return GameplayConfig(
      enemies: EnemiesConfig.fromJson(json),
      player: PlayerConfig.fromJson(json),
      field: FieldConfig.fromJson(json),
      game: GameConfig.fromJson(json),
      audio: AudioConfig.fromJson(json),
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
    this.collideWithEachOther = false,
    this.spinDegPerSec = 0,
  });

  final double areaMultiplier;
  final List<double> aspects;
  final double angleMinDeg;
  final double angleMaxDeg;
  final double speedMin;
  final double speedMax;
  final double accelMin;
  final double accelMax;
  /// Мобы отскакивают друг от друга как от стены.
  final bool collideWithEachOther;
  /// Медленное вращение тела (°/с). 0 = без вращения.
  final double spinDegPerSec;

  Map<String, dynamic> toJson() => {
        'areaMultiplier': areaMultiplier,
        'aspects': aspects,
        'angleMinDeg': angleMinDeg,
        'angleMaxDeg': angleMaxDeg,
        'speedMin': speedMin,
        'speedMax': speedMax,
        'accelMin': accelMin,
        'accelMax': accelMax,
        'collideWithEachOther': collideWithEachOther,
        'spinDegPerSec': spinDegPerSec,
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
      collideWithEachOther: json['collideWithEachOther'] as bool? ??
          json['enemiesCollide'] as bool? ??
          false,
      spinDegPerSec: (json['spinDegPerSec'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Блок Remote Config: `player`
class PlayerConfig {
  const PlayerConfig({
    this.size = 36,
    this.showFace = false,
  });

  final double size;

  /// A/B: милое аниме-личико на кубе (по умолчанию выкл — просто квадрат).
  final bool showFace;

  Map<String, dynamic> toJson() => {
        'size': size,
        'showFace': showFace,
      };

  factory PlayerConfig.fromJson(Map<String, dynamic> json) {
    return PlayerConfig(
      size: (json['size'] as num?)?.toDouble() ??
          (json['playerSize'] as num?)?.toDouble() ??
          36,
      showFace: json['showFace'] as bool? ??
          json['playerShowFace'] as bool? ??
          false,
    );
  }
}

/// Блок Remote Config: `field`
class FieldConfig {
  const FieldConfig({
    this.borderWidth = 3,
    this.brightness = 1.0,
    this.shadowBrightness = 1.0,
    this.colorHex,
  });

  final double borderWidth;

  /// Яркость заливки поля: 1.0 = тема как есть; >1 светлее; <1 темнее.
  final double brightness;

  /// Осветление теней объектов: 1.0 = как сейчас; >1 светлее/слабее; <1 темнее.
  /// Независимо от `brightness` поля.
  final double shadowBrightness;

  /// Опциональный цвет поля (#RRGGBB или #AARRGGBB). Пусто = цвет темы.
  final String? colorHex;

  Map<String, dynamic> toJson() => {
        'borderWidth': borderWidth,
        'brightness': brightness,
        'shadowBrightness': shadowBrightness,
        if (colorHex != null && colorHex!.isNotEmpty) 'color': colorHex,
      };

  factory FieldConfig.fromJson(Map<String, dynamic> json) {
    final rawColor = json['color'] ?? json['colorHex'] ?? json['surfaceColor'];
    String? colorHex;
    if (rawColor is String && rawColor.trim().isNotEmpty) {
      colorHex = rawColor.trim();
    }
    return FieldConfig(
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 3,
      brightness: (json['brightness'] as num?)?.toDouble() ??
          (json['fieldBrightness'] as num?)?.toDouble() ??
          1.0,
      shadowBrightness: (json['shadowBrightness'] as num?)?.toDouble() ?? 1.0,
      colorHex: colorHex,
    );
  }

  /// Цвет заливки поля с учётом RC.
  Color resolveSurfaceColor(Color themeSurface) {
    final base = parseHexColor(colorHex) ?? themeSurface;
    final b = brightness.clamp(0.4, 1.8);
    if (b == 1.0) return base;
    if (b > 1.0) {
      return Color.lerp(base, Colors.white, ((b - 1.0) / 0.8).clamp(0.0, 1.0))!;
    }
    return Color.lerp(base, Colors.black, ((1.0 - b) / 0.6).clamp(0.0, 1.0))!;
  }
}

/// Парсит `#RRGGBB` / `#AARRGGBB` (с # или без). Иначе null.
Color? parseHexColor(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// Блок Remote Config: `game`
class GameConfig {
  const GameConfig({
    this.startHintEnabled = true,
    this.idleSpeedMultiplier = 0.5,
    this.speedRampSeconds = 0.5,
    this.jumpEnabled = true,
    this.jumpDurationSec = 0.38,
    this.jumpScale = 1.32,
    this.helmetEnabled = true,
    this.helmetInvulnSec = 0.3,
    this.startInvulnSec = 1,
    this.heartbeatHaptic = true,
    this.timerHaptic = true,
    this.timerHapticStyle = 'warning',
    this.timerHapticStyle5 = 'warning',
    this.timerHapticStyle10 = 'warning',
    this.hudSpeedScaleMax = 400,
    this.wallsKillPlayer = true,
  });

  /// Показывать подсказку «коснитесь экрана».
  final bool startHintEnabled;

  /// Скорость врагов до первого касания (доля от стартовой).
  final double idleSpeedMultiplier;

  /// За сколько секунд скорость вырастает до нормальной после касания.
  final double speedRampSeconds;

  /// Прыжок: HUD / Shop / игра. Доступ игроку — через аренду в economy.
  final bool jumpEnabled;

  /// Длительность прыжка в секундах.
  final double jumpDurationSec;

  /// Визуальный масштаб в пике прыжка (хитбокс стены не растёт).
  final double jumpScale;

  /// Шлем: HUD / Shop / игра. Доступ игроку — через аренду в economy.
  final bool helmetEnabled;

  /// Неуязвимость после разрушения шлема (секунды). Герой мигает.
  final double helmetInvulnSec;

  /// Неуязвимость в начале раунда (секунды). 0 — сразу уязвим.
  final double startInvulnSec;

  /// Вибро-сердцебиение в Mini App: сильный удар на целую секунду, слабый следом.
  final bool heartbeatHaptic;

  /// Вибро на целые секунды секундомера.
  final bool timerHaptic;

  /// Сила удара: success (тише) | warning (обычно) | error (как проигрыш).
  final String timerHapticStyle;
  final String timerHapticStyle5;
  final String timerHapticStyle10;

  /// Максимум шкалы скорости в панели под полем (полоска 0…1).
  final double hudSpeedScaleMax;

  /// Этажи: `true` — касание стены/препятствия убивает; `false` — только блок.
  final bool wallsKillPlayer;

  Map<String, dynamic> toJson() => {
        'startHintEnabled': startHintEnabled,
        'idleSpeedMultiplier': idleSpeedMultiplier,
        'speedRampSeconds': speedRampSeconds,
        'jumpEnabled': jumpEnabled,
        'jumpDurationSec': jumpDurationSec,
        'jumpScale': jumpScale,
        'helmetEnabled': helmetEnabled,
        'helmetInvulnSec': helmetInvulnSec,
        'startInvulnSec': startInvulnSec,
        'heartbeatHaptic': heartbeatHaptic,
        'timerHaptic': timerHaptic,
        'timerHapticStyle': timerHapticStyle,
        'timerHapticStyle5': timerHapticStyle5,
        'timerHapticStyle10': timerHapticStyle10,
        'hudSpeedScaleMax': hudSpeedScaleMax,
        'wallsKillPlayer': wallsKillPlayer,
      };

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      startHintEnabled: json['startHintEnabled'] as bool? ?? true,
      idleSpeedMultiplier:
          (json['idleSpeedMultiplier'] as num?)?.toDouble() ?? 0.5,
      speedRampSeconds: (json['speedRampSeconds'] as num?)?.toDouble() ?? 0.5,
      jumpEnabled: json['jumpEnabled'] as bool? ??
          json['jumpsEnabled'] as bool? ??
          true,
      jumpDurationSec: (json['jumpDurationSec'] as num?)?.toDouble() ?? 0.38,
      jumpScale: (json['jumpScale'] as num?)?.toDouble() ?? 1.32,
      helmetEnabled: json['helmetEnabled'] as bool? ?? true,
      helmetInvulnSec: (json['helmetInvulnSec'] as num?)?.toDouble() ?? 0.3,
      startInvulnSec: (json['startInvulnSec'] as num?)?.toDouble() ?? 1,
      heartbeatHaptic: json['heartbeatHaptic'] as bool? ?? true,
      timerHaptic: json['timerHaptic'] as bool? ?? true,
      timerHapticStyle: json['timerHapticStyle'] as String? ?? 'warning',
      timerHapticStyle5: json['timerHapticStyle5'] as String? ?? 'warning',
      timerHapticStyle10: json['timerHapticStyle10'] as String? ?? 'warning',
      hudSpeedScaleMax: (json['hudSpeedScaleMax'] as num?)?.toDouble() ?? 400,
      wallsKillPlayer: json['wallsKillPlayer'] as bool? ?? true,
    );
  }
}

/// Блок Remote Config: `audio` — вкл/выкл звуков и музыки.
class AudioConfig {
  const AudioConfig({
    this.sfxMobWall = true,
    this.sfxMobCollide = true,
    this.sfxHeroMob = true,
    this.sfxHeroWall = true,
    this.sfxNearMiss = true,
    this.sfxHelmet = true,
    this.sfxJump = true,
    this.sfxStart = true,
    this.music = true,
    this.sfxVolume = 1.0,
    this.musicVolume = 0.08,
  });

  /// Моб ударяется о стену.
  final bool sfxMobWall;

  /// Мобы ударяются друг о друга (имеет смысл при collideWithEachOther).
  final bool sfxMobCollide;

  /// Герой касается моба (смерть).
  final bool sfxHeroMob;

  /// Герой касается стены (смерть).
  final bool sfxHeroWall;

  /// Опасный момент (risk / near-miss) — лёгкий свист / скольжение.
  final bool sfxNearMiss;

  /// Шлем разбился (короткое стекло).
  final bool sfxHelmet;

  /// Прыжок (второе касание).
  final bool sfxJump;

  /// Звук старта партии.
  final bool sfxStart;

  /// Тихая фоновая музыка (луп).
  final bool music;

  /// Общая громкость SFX (0..1). 1.0 = как сейчас в клиенте.
  final double sfxVolume;

  /// Громкость фоновой музыки (0..1). По умолчанию тихо: 0.08.
  final double musicVolume;

  Map<String, dynamic> toJson() => {
        'sfxMobWall': sfxMobWall,
        'sfxMobCollide': sfxMobCollide,
        'sfxHeroMob': sfxHeroMob,
        'sfxHeroWall': sfxHeroWall,
        'sfxNearMiss': sfxNearMiss,
        'sfxHelmet': sfxHelmet,
        'sfxJump': sfxJump,
        'sfxStart': sfxStart,
        'music': music,
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
      };

  factory AudioConfig.fromJson(Map<String, dynamic> json) {
    return AudioConfig(
      sfxMobWall: _asBool(json['sfxMobWall'], true),
      sfxMobCollide: _asBool(json['sfxMobCollide'], true),
      sfxHeroMob: _asBool(json['sfxHeroMob'], true),
      sfxHeroWall: _asBool(json['sfxHeroWall'], true),
      sfxNearMiss: _asBool(json['sfxNearMiss'], true),
      sfxHelmet: _asBool(json['sfxHelmet'], true),
      sfxJump: _asBool(json['sfxJump'], true),
      sfxStart: _asBool(json['sfxStart'], true),
      music: _asBool(json['music'], true),
      sfxVolume: _asVolume(json['sfxVolume'], 1.0),
      musicVolume: _asVolume(json['musicVolume'], 0.08),
    );
  }

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  static double _asVolume(Object? value, double fallback) {
    double? n;
    if (value is num) {
      n = value.toDouble();
    } else if (value is String) {
      n = double.tryParse(value.trim());
    }
    if (n == null || n.isNaN || n.isInfinite) return fallback;
    return n.clamp(0.0, 1.0);
  }
}
