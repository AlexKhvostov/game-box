import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/gameplay_config.dart';

class EnemyBody {
  EnemyBody({
    required this.pos,
    required this.vel,
    required this.w,
    required this.h,
    required this.aspect,
    required this.angleDeg,
    required this.quadrantN,
    required this.fieldQuadrant,
    required this.initialSpeed,
    required this.acceleration,
  });

  Offset pos;
  Offset vel;
  final double w;
  final double h;
  final double aspect;
  final double angleDeg;
  final int quadrantN;
  /// Квадрант поля: 0 TL, 1 TR, 2 BL, 3 BR.
  final int fieldQuadrant;
  final double initialSpeed;
  final double acceleration;

  Rect get rect => Rect.fromLTWH(pos.dx, pos.dy, w, h);

  double speedAt(double secondsAlive) =>
      initialSpeed + acceleration * secondsAlive;
}

class GameWorld {
  GameWorld({
    required this.config,
    required this.field,
    Random? rng,
  }) : _rng = rng ?? Random();

  final GameplayConfig config;
  final Size field;
  final Random _rng;

  late Offset player;
  final List<EnemyBody> enemies = [];

  double get playerSize => config.playerSize;

  void resetLayout() {
    player = Offset(
      (field.width - playerSize) / 2,
      (field.height - playerSize) / 2,
    );
    enemies
      ..clear()
      ..addAll(_spawnEnemies());
  }

  List<EnemyBody> _spawnEnemies() {
    final aspects = List<double>.from(config.enemyAspects)
        .where((a) => a.isFinite && a > 0.05 && a < 50)
        .toList();
    if (aspects.isEmpty) {
      aspects.addAll(const [1.0, 0.25, 0.5, 3.0]);
    }

    final count = aspects.length;
    // Уникальные направления n ∈ [0..3]
    final ns = List<int>.generate(max(count, 4), (i) => i % 4)..shuffle(_rng);
    final assignedN = ns.take(count).toList();

    // Квадранты поля: по одному врагу в каждый (циклически если врагов ≠ 4)
    final fieldQs = List<int>.generate(max(count, 4), (i) => i % 4)
      ..shuffle(_rng);
    final assignedFieldQ = fieldQs.take(count).toList();

    final result = <EnemyBody>[];
    for (var i = 0; i < count; i++) {
      result.add(
        _createEnemy(
          aspect: aspects[i],
          quadrantN: assignedN[i],
          fieldQuadrant: assignedFieldQ[i],
        ),
      );
    }
    return result;
  }

  /// Idle: полноценное движение с отскоками, но на пониженной скорости.
  void tickIdle(double dt) {
    final safeDt = dt.clamp(0.0, 0.05);
    final mult = config.idleSpeedMultiplier.clamp(0.05, 1.0);
    for (final e in enemies) {
      final speed = (e.initialSpeed * mult).clamp(0.0, 2000.0);
      final dist = e.vel.distance;
      final dir = dist < 1e-6
          ? const Offset(1, 1)
          : Offset(e.vel.dx / dist, e.vel.dy / dist);
      e.vel = dir * speed;
      e.pos += e.vel * safeDt;
      _bounce(e);
    }
  }

  /// Партия: скорость × rampMult (1.0 = норма).
  void tickPlay(double dt, double secondsAlive, {double speedMult = 1.0}) {
    final safeDt = dt.clamp(0.0, 0.05);
    final mult = speedMult.clamp(0.05, 2.0);
    final t = secondsAlive.clamp(0.0, 3600.0);
    for (final e in enemies) {
      final speed = (e.speedAt(t) * mult).clamp(0.0, 4000.0);
      final dist = e.vel.distance;
      final dir = dist < 1e-6
          ? const Offset(1, 1)
          : Offset(e.vel.dx / dist, e.vel.dy / dist);
      e.vel = dir * speed;
      e.pos += e.vel * safeDt;
      _bounce(e);
    }
  }

  void movePlayerBy(Offset delta) {
    player += delta;
  }

  bool playerHitsBorder() {
    return player.dx <= 0 ||
        player.dy <= 0 ||
        player.dx + playerSize >= field.width ||
        player.dy + playerSize >= field.height;
  }

  bool playerHitsEnemy() {
    final pr = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    for (final e in enemies) {
      if (pr.overlaps(e.rect)) return true;
    }
    return false;
  }

  EnemyBody _createEnemy({
    required double aspect,
    required int quadrantN,
    required int fieldQuadrant,
  }) {
    final playerArea = max(1.0, playerSize * playerSize);
    final areaMult = config.enemyAreaMultiplier.clamp(0.2, 20.0);
    final area = playerArea * areaMult;
    final safeAspect = aspect.clamp(0.05, 50.0);
    final h = sqrt(area / safeAspect);
    final w = sqrt(area * safeAspect);

    final safePos = _randomPosInQuadrant(
      fieldQuadrant: fieldQuadrant,
      w: w,
      h: h,
    );

    final angleDeg = _angleForQuadrant(quadrantN);
    final rad = angleDeg * pi / 180;
    final initialSpeed = _lerpRandom(config.speedMin, config.speedMax);
    final acceleration = _lerpRandom(config.accelMin, config.accelMax);
    final vel = Offset(cos(rad), sin(rad)) * initialSpeed;

    return EnemyBody(
      pos: safePos,
      vel: vel,
      w: w,
      h: h,
      aspect: aspect,
      angleDeg: angleDeg,
      quadrantN: quadrantN,
      fieldQuadrant: fieldQuadrant,
      initialSpeed: initialSpeed,
      acceleration: acceleration,
    );
  }

  /// Случайная позиция внутри квадранта поля (0 TL, 1 TR, 2 BL, 3 BR).
  Offset _randomPosInQuadrant({
    required int fieldQuadrant,
    required double w,
    required double h,
  }) {
    const pad = 8.0;
    final midX = field.width / 2;
    final midY = field.height / 2;

    late double minX;
    late double maxX;
    late double minY;
    late double maxY;

    switch (fieldQuadrant % 4) {
      case 0: // TL
        minX = pad;
        maxX = midX - w - pad;
        minY = pad;
        maxY = midY - h - pad;
        break;
      case 1: // TR
        minX = midX + pad;
        maxX = field.width - w - pad;
        minY = pad;
        maxY = midY - h - pad;
        break;
      case 2: // BL
        minX = pad;
        maxX = midX - w - pad;
        minY = midY + pad;
        maxY = field.height - h - pad;
        break;
      default: // BR
        minX = midX + pad;
        maxX = field.width - w - pad;
        minY = midY + pad;
        maxY = field.height - h - pad;
    }

    if (maxX < minX) {
      minX = pad;
      maxX = max(pad, field.width - w - pad);
    }
    if (maxY < minY) {
      minY = pad;
      maxY = max(pad, field.height - h - pad);
    }

    final playerRect =
        Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize)
            .inflate(playerSize * 0.6);

    for (var attempt = 0; attempt < 12; attempt++) {
      final x = minX + _rng.nextDouble() * max(1.0, maxX - minX);
      final y = minY + _rng.nextDouble() * max(1.0, maxY - minY);
      final candidate = Offset(x, y);
      if (!Rect.fromLTWH(candidate.dx, candidate.dy, w, h)
          .overlaps(playerRect)) {
        return candidate;
      }
    }

    return Offset(
      minX.clamp(pad, field.width - w - pad),
      minY.clamp(pad, field.height - h - pad),
    );
  }

  double _angleForQuadrant(int n) {
    final minA = min(config.angleMinDeg, config.angleMaxDeg);
    final maxA = max(config.angleMinDeg, config.angleMaxDeg);
    final base = minA + _rng.nextDouble() * (maxA - minA);
    var a = base + 90.0 * n;
    if (a >= 360) a -= 360;
    return a;
  }

  double _lerpRandom(double a, double b) {
    final lo = min(a, b);
    final hi = max(a, b);
    return lo + _rng.nextDouble() * (hi - lo);
  }

  void _bounce(EnemyBody e) {
    var x = e.pos.dx;
    var y = e.pos.dy;
    var vx = e.vel.dx;
    var vy = e.vel.dy;

    if (x <= 0) {
      x = 0;
      vx = vx.abs();
    } else if (x + e.w >= field.width) {
      x = field.width - e.w;
      vx = -vx.abs();
    }
    if (y <= 0) {
      y = 0;
      vy = vy.abs();
    } else if (y + e.h >= field.height) {
      y = field.height - e.h;
      vy = -vy.abs();
    }

    e.pos = Offset(x, y);
    e.vel = Offset(vx, vy);
  }
}
