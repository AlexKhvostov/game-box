import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/gameplay_config.dart';
import 'floors_loadout.dart';

/// Геометрия рамок: своя внутри, чужая снаружи, зазор = 2×толщины.
class FloorsConfig {
  const FloorsConfig({
    this.exitLengthFraction = 0.2,
    this.showExitMarkers = false,
  });

  final double exitLengthFraction;
  final bool showExitMarkers;

  /// Толщина рамки (визуал = физика).
  static double frameBand(double borderWidth) =>
      borderWidth.clamp(2.5, 5.0).toDouble();

  /// Центр чужой (наружной) рамки от края поля.
  static double neighborInset(double band) => band * 0.5;

  /// Центр своей (внутренней) рамки от края.
  /// Сосед → зазор 2×band → своя: центры на расстоянии 3×band.
  static double ownInset(double band) => neighborInset(band) + 3 * band;

  /// Внутренний край своей рамки — граница поля для героя/врагов.
  static double playableInset(double band) => ownInset(band) + band * 0.5;

  static GameplayConfig roomGameplay({
    required GameplayConfig base,
    required RoomLoadout loadout,
  }) {
    // 0 = пусто; 1 ок для туториала; иначе обычно 2…4.
    final count =
        loadout.enemyCount <= 0 ? 0 : loadout.enemyCount.clamp(1, 4);
    final pool = List<double>.from(base.enemies.aspects);
    if (pool.isEmpty) {
      pool.addAll(const [1.0, 0.25, 0.5, 3.0]);
    }
    const prefer = [0.25, 3.0, 0.5, 1.0];
    bool close(double a, double b) => (a - b).abs() < 0.05;
    final ordered = <double>[
      for (final a in prefer)
        if (pool.any((p) => close(p, a))) a,
      ...pool.where((p) => !prefer.any((a) => close(p, a))),
    ];
    final aspects = <double>[
      for (var i = 0; i < count; i++)
        ordered.isEmpty ? 1.0 : ordered[i % ordered.length],
    ];
    final speedMin =
        (base.enemies.speedMin * loadout.speedMult).clamp(40.0, 400.0);
    final speedMax =
        (base.enemies.speedMax * loadout.speedMult).clamp(speedMin, 500.0);
    final accelMin =
        (base.enemies.accelMin * loadout.accelMult).clamp(0.0, 80.0);
    final accelMax =
        (base.enemies.accelMax * loadout.accelMult).clamp(accelMin, 100.0);

    return GameplayConfig(
      enemies: EnemiesConfig(
        areaMultiplier: base.enemies.areaMultiplier,
        aspects: aspects,
        angleMinDeg: base.enemies.angleMinDeg,
        angleMaxDeg: base.enemies.angleMaxDeg,
        speedMin: speedMin,
        speedMax: speedMax,
        accelMin: accelMin,
        accelMax: accelMax,
        collideWithEachOther: loadout.enemiesCollide,
        spinDegPerSec: loadout.spinDegPerSec,
      ),
      player: base.player,
      field: base.field,
      game: base.game,
      audio: base.audio,
    );
  }
}

enum WallSide { top, right, bottom, left }

/// Проём на одной рамке. Позиция из часов + детерминированной фазы ребра.
class WallExit {
  WallExit({
    required this.side,
    required this.length,
    required this.minAlong,
    required this.maxAlong,
    required this.baseAlong,
    required this.speed,
    required this.phase,
  }) : centerAlong = baseAlong;

  final WallSide side;
  final double length;
  final double minAlong;
  final double maxAlong;
  /// Статичная позиция (и старт осцилляции).
  final double baseAlong;
  final double speed;
  final double phase;
  double centerAlong;

  bool get isMoving => speed > 0;

  bool allowsSegment(double alongMin, double alongMax) {
    if (alongMax < alongMin) return false;
    final half = length / 2;
    final holeMin = centerAlong - half;
    final holeMax = centerAlong + half;
    return alongMin >= holeMin && alongMax <= holeMax;
  }

  void sync(double clockSec) {
    if (!isMoving) {
      centerAlong = baseAlong.clamp(minAlong, maxAlong);
      return;
    }
    final span = maxAlong - minAlong;
    if (span <= 1e-6) {
      centerAlong = minAlong;
      return;
    }
    final dist = speed * clockSec + phase * 2 * span;
    final cycle = dist % (2 * span);
    centerAlong = cycle < span ? minAlong + cycle : maxAlong - (cycle - span);
  }
}

/// Сторона комнаты: своя рамка + видимая чужая.
class SidePortal {
  SidePortal({
    required this.side,
    this.own,
    this.neighbor,
    this.neighborLight,
  });

  final WallSide side;
  final WallExit? own;
  final WallExit? neighbor;
  final Color? neighborLight;

  bool get isMapEdge => own == null;
  bool get canExit => own != null && neighbor != null;

  bool allowsSegment(double a0, double a1) {
    final o = own;
    final n = neighbor;
    if (o == null || n == null) return false;
    return o.allowsSegment(a0, a1) && n.allowsSegment(a0, a1);
  }

  void sync(double clockSec) {
    own?.sync(clockSec);
    neighbor?.sync(clockSec);
  }
}

/// Детерминированная геометрия проёма на общем ребре двух клеток.
abstract final class EdgeExitMath {
  static double holeLength(double alongSpan, double fraction) =>
      alongSpan * fraction.clamp(0.12, 0.45);

  static ({double minA, double maxA}) alongRange({
    required double alongSpan,
    required double length,
    required double cornerPad,
  }) {
    final half = length / 2;
    final minA = cornerPad + half;
    final maxA = alongSpan - cornerPad - half;
    if (maxA < minA) {
      return (minA: alongSpan / 2, maxA: alongSpan / 2);
    }
    return (minA: minA, maxA: maxA);
  }

  /// Общий seed ребра (порядок клеток не важен).
  static int edgeSeed({
    required int floorNumber,
    required int r1,
    required int c1,
    required int r2,
    required int c2,
  }) {
    final ra = min(r1, r2);
    final ca = min(c1, c2);
    final rb = max(r1, r2);
    final cb = max(c1, c2);
    return Object.hash(floorNumber, ra, ca, rb, cb, 'edge');
  }

  static double baseAlong({
    required int seed,
    required double minA,
    required double maxA,
  }) {
    if (maxA <= minA) return minA;
    final rng = Random(seed);
    return minA + rng.nextDouble() * (maxA - minA);
  }

  static double phase(int seed) {
    final rng = Random(seed ^ 0xA5A5);
    return rng.nextDouble();
  }
}
