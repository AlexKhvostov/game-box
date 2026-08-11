import 'dart:math';

/// Наполнение комнаты: независимые рычаги → суммарная сложность (стоимость).
class RoomLoadout {
  const RoomLoadout({
    required this.enemyCount,
    required this.speedMult,
    required this.accelMult,
    this.enemiesCollide = false,
    this.spinDegPerSec = 0,
    this.wallCount = 0,
    this.exitMoveSpeed = 0,
    this.bonusDrops = false,
    this.debuffDrops = false,
    this.exitOpenDelaySec = 0,
  });

  final int enemyCount;
  final double speedMult;
  final double accelMult;
  final bool enemiesCollide;
  final double spinDegPerSec;
  final int wallCount;
  /// 0 = статичный проём; >0 = скорость езды вдоль стены.
  final double exitMoveSpeed;
  final bool bonusDrops;
  final bool debuffDrops;
  final int exitOpenDelaySec;

  bool get hasWalls => wallCount > 0;
  bool get hasSpin => spinDegPerSec > 0;
  bool get exitsMove => exitMoveSpeed > 0;

  int get totalCost => RoomDifficultyCosts.total(this);

  int get difficultyPercent => RoomDifficultyCosts.toPercent(totalCost);

  String summarize() {
    final parts = <String>[
      'мобов: $enemyCount',
      '×${speedMult.toStringAsFixed(2)}',
      if (enemiesCollide && enemyCount >= 2) 'столкновения',
      if (!enemiesCollide && enemyCount >= 2) 'проход сквозь',
      if (hasSpin) 'вращение',
      if (wallCount == 1) '1 стенка',
      if (wallCount >= 2) '$wallCount стенки',
      if (exitsMove) 'дыры ×${exitMoveSpeed.toStringAsFixed(0)}',
      if (!exitsMove) 'дыры стоят',
    ];
    return '${parts.join(' · ')}  (~$difficultyPercent%)';
  }
}

class RoomDifficultyCosts {
  RoomDifficultyCosts._();

  static int enemies(int n) => switch (n.clamp(0, 4)) {
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 22,
        _ => 42,
      };

  static int speed(double m) {
    if (m <= 0.72) return 0;
    if (m <= 0.95) return 8;
    if (m <= 1.22) return 18;
    if (m <= 1.5) return 30;
    return 42;
  }

  static int collide(bool on, int enemyCount) =>
      (on && enemyCount >= 2) ? 18 : 0;

  static int spin(double degPerSec) {
    if (degPerSec <= 0) return 0;
    if (degPerSec <= 30) return 22;
    return 32;
  }

  static int walls(int count) => switch (count.clamp(0, 2)) {
        0 => 0,
        1 => 20,
        _ => 35,
      };

  static int exitMove(double speed) {
    if (speed <= 0) return 0;
    if (speed <= 40) return 14;
    if (speed <= 70) return 24;
    return 36;
  }

  static int drops({required bool bonus, required bool debuff}) {
    var c = 0;
    if (bonus) c += 12;
    if (debuff) c += 14;
    return c;
  }

  static int exitDelay(int sec) => sec <= 0 ? 0 : 8 + sec * 2;

  static int total(RoomLoadout L) =>
      enemies(L.enemyCount) +
      speed(L.speedMult) +
      collide(L.enemiesCollide, L.enemyCount) +
      spin(L.spinDegPerSec) +
      walls(L.wallCount) +
      exitMove(L.exitMoveSpeed) +
      drops(bonus: L.bonusDrops, debuff: L.debuffDrops) +
      exitDelay(L.exitOpenDelaySec);

  static int toPercent(int cost) {
    final max = RoomLoadoutCatalog.maxCost;
    if (max <= 0) return 0;
    return ((cost / max) * 100).round().clamp(0, 100);
  }

  static int costFromDifficultyPercent(int difficultyPercent) {
    final p = difficultyPercent.clamp(0, 100) / 100.0;
    return (p * RoomLoadoutCatalog.maxCost).round();
  }
}

class RoomLoadoutCatalog {
  RoomLoadoutCatalog._();

  static const easiest = RoomLoadout(
    enemyCount: 2,
    speedMult: 0.65,
    accelMult: 0.55,
  );

  static const hardest = RoomLoadout(
    enemyCount: 4,
    speedMult: 1.75,
    accelMult: 1.6,
    enemiesCollide: true,
    spinDegPerSec: 40,
    wallCount: 2,
    exitMoveSpeed: 80,
  );

  static int get maxCost => hardest.totalCost;

  static const recipes = <RoomLoadout>[
    easiest,
    RoomLoadout(enemyCount: 2, speedMult: 0.9, accelMult: 0.85),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 0.9,
      accelMult: 0.85,
      exitMoveSpeed: 35,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 0.9,
      accelMult: 0.85,
      enemiesCollide: true,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.15,
      accelMult: 1.1,
      spinDegPerSec: 28,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 0.9,
      accelMult: 0.85,
      wallCount: 1,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.15,
      accelMult: 1.1,
      enemiesCollide: true,
      wallCount: 1,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.15,
      accelMult: 1.1,
      enemiesCollide: true,
      exitMoveSpeed: 55,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.15,
      accelMult: 1.1,
      exitMoveSpeed: 45,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.4,
      accelMult: 1.35,
      enemiesCollide: true,
      spinDegPerSec: 28,
      exitMoveSpeed: 55,
    ),
    RoomLoadout(
      enemyCount: 2,
      speedMult: 1.4,
      accelMult: 1.35,
      enemiesCollide: true,
      spinDegPerSec: 28,
      wallCount: 1,
      exitMoveSpeed: 60,
    ),
    RoomLoadout(
      enemyCount: 3,
      speedMult: 1.15,
      accelMult: 1.1,
      enemiesCollide: true,
    ),
    RoomLoadout(
      enemyCount: 3,
      speedMult: 1.15,
      accelMult: 1.1,
      enemiesCollide: true,
      wallCount: 2,
    ),
    RoomLoadout(
      enemyCount: 3,
      speedMult: 1.4,
      accelMult: 1.35,
      enemiesCollide: true,
      spinDegPerSec: 28,
      exitMoveSpeed: 50,
    ),
    RoomLoadout(
      enemyCount: 3,
      speedMult: 1.4,
      accelMult: 1.35,
      enemiesCollide: true,
      spinDegPerSec: 40,
      wallCount: 2,
      exitMoveSpeed: 65,
    ),
    RoomLoadout(
      enemyCount: 4,
      speedMult: 1.4,
      accelMult: 1.35,
      enemiesCollide: true,
      spinDegPerSec: 28,
      wallCount: 1,
      exitMoveSpeed: 55,
    ),
    RoomLoadout(
      enemyCount: 4,
      speedMult: 1.75,
      accelMult: 1.6,
      enemiesCollide: true,
      spinDegPerSec: 40,
      wallCount: 2,
      exitMoveSpeed: 70,
    ),
    hardest,
  ];

  static RoomLoadout compose({
    required int targetD,
    required int maxEnemies,
    required bool allowWalls,
    required bool allowMovingExits,
    required bool allowBonusDrops,
    required bool allowDebuffDrops,
    required Random rng,
  }) {
    final targetCost =
        RoomDifficultyCosts.costFromDifficultyPercent(targetD);
    final maxC = maxCost;

    if (targetD >= 92) {
      return _clampToFlags(
        hardest,
        maxEnemies: maxEnemies,
        allowWalls: allowWalls,
        allowMovingExits: allowMovingExits,
        allowBonusDrops: allowBonusDrops,
        allowDebuffDrops: allowDebuffDrops,
      );
    }

    final pool = <RoomLoadout>[];
    final minEnemies = maxEnemies >= 2 ? 2 : maxEnemies;
    for (final r in recipes) {
      if (r.enemyCount < minEnemies) continue;
      if (r.enemyCount > maxEnemies) continue;
      if (!allowWalls && r.wallCount > 0) continue;
      if (!allowMovingExits && r.exitsMove) continue;
      if (!allowBonusDrops && r.bonusDrops) continue;
      if (!allowDebuffDrops && r.debuffDrops) continue;
      pool.add(r);
    }
    if (pool.isEmpty) return easiest;

    pool.sort((a, b) {
      final da = (a.totalCost - targetCost).abs();
      final db = (b.totalCost - targetCost).abs();
      return da.compareTo(db);
    });

    final tol = max(12, (maxC * 0.06).round());
    final bestDelta = (pool.first.totalCost - targetCost).abs();
    final near = pool
        .where((r) => (r.totalCost - targetCost).abs() <= bestDelta + tol)
        .toList();
    return near[rng.nextInt(near.length)];
  }

  static RoomLoadout _clampToFlags(
    RoomLoadout base, {
    required int maxEnemies,
    required bool allowWalls,
    required bool allowMovingExits,
    required bool allowBonusDrops,
    required bool allowDebuffDrops,
  }) {
    return RoomLoadout(
      enemyCount: base.enemyCount.clamp(2, maxEnemies),
      speedMult: base.speedMult,
      accelMult: base.accelMult,
      enemiesCollide: base.enemiesCollide,
      spinDegPerSec: base.spinDegPerSec,
      wallCount: allowWalls ? base.wallCount : 0,
      exitMoveSpeed: allowMovingExits ? base.exitMoveSpeed : 0,
      bonusDrops: allowBonusDrops && base.bonusDrops,
      debuffDrops: allowDebuffDrops && base.debuffDrops,
      exitOpenDelaySec: base.exitOpenDelaySec,
    );
  }
}
