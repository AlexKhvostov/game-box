import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/gameplay_config.dart';

/// Отскоки за кадр — для раздельных SFX.
class BounceReport {
  const BounceReport({this.wall = 0, this.enemy = 0});

  final int wall;
  final int enemy;
}

/// Короткая вспышка «едва разминулись».
class NearMissFx {
  NearMissFx({required this.origin});

  final Offset origin;
  double age = 0;

  bool update(double dt) {
    age += dt;
    return age < 0.42;
  }

  void paint(Canvas canvas) {
    final t = (age / 0.42).clamp(0.0, 1.0);
    final a = (1.0 - t) * 0.9;
    final r = 6 + t * 26;
    canvas.drawCircle(
      origin,
      r,
      Paint()
        ..color = const Color(0xFFFFC107).withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1.0 - t * 0.5),
    );
    canvas.drawCircle(
      origin,
      r * 0.35,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: a * 0.55),
    );
  }
}

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

  /// Оставшееся время прыжка (сек). 0 = на земле.
  double jumpRemaining = 0;

  /// Накопленный пробег игрока за партию (px).
  double playerDistance = 0;

  /// Сколько раз едва разминулись с мобом (near-miss).
  int nearMissCount = 0;

  /// Короткие вспышки near-miss на поле.
  final List<NearMissFx> nearMissFx = [];

  /// Враги, с которыми сейчас «опасно близко» (по индексу).
  final Set<int> _nearArmed = {};

  /// Враги, через которых уже засчитали прыжок в текущем прыжке.
  final Set<int> _jumpOverCounted = {};

  static const _nearEnterPx = 14.0;
  static const _nearExitPx = 22.0;

  double get playerSize => config.playerSize;

  bool get isJumping => jumpRemaining > 0;

  /// 0 на земле → 1 в пике → 0 при приземлении.
  double get jumpLift {
    if (!isJumping) return 0;
    final dur = max(0.05, config.jumpDurationSec);
    final t = (1.0 - jumpRemaining / dur).clamp(0.0, 1.0);
    return sin(pi * t);
  }

  double get visualScale {
    if (!isJumping) return 1;
    final peak = config.jumpScale.clamp(1.05, 1.8);
    return 1.0 + (peak - 1.0) * jumpLift;
  }

  void resetLayout() {
    player = Offset(
      (field.width - playerSize) / 2,
      (field.height - playerSize) / 2,
    );
    jumpRemaining = 0;
    playerDistance = 0;
    nearMissCount = 0;
    nearMissFx.clear();
    _nearArmed.clear();
    _jumpOverCounted.clear();
    enemies
      ..clear()
      ..addAll(_spawnEnemies());
  }

  bool tryJump() {
    if (!config.jumpEnabled || isJumping) return false;
    jumpRemaining = max(0.12, config.jumpDurationSec);
    _jumpOverCounted.clear();
    _nearArmed.clear();
    _evaluateJumpOver();
    return true;
  }

  void tickJump(double dt) {
    if (jumpRemaining <= 0) return;
    jumpRemaining = max(0.0, jumpRemaining - dt);
    if (jumpRemaining > 0) {
      _evaluateJumpOver();
    } else {
      _jumpOverCounted.clear();
    }
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

  /// Idle: движение с отскоками на пониженной скорости.
  BounceReport tickIdle(double dt) {
    final safeDt = dt.clamp(0.0, 0.05);
    final mult = config.idleSpeedMultiplier.clamp(0.05, 1.0);
    var wall = 0;
    for (final e in enemies) {
      final speed = (e.initialSpeed * mult).clamp(0.0, 2000.0);
      final dist = e.vel.distance;
      final dir = dist < 1e-6
          ? const Offset(1, 1)
          : Offset(e.vel.dx / dist, e.vel.dy / dist);
      e.vel = dir * speed;
      e.pos += e.vel * safeDt;
      if (_bounce(e)) wall++;
    }
    final enemy = config.enemiesCollide ? _resolveEnemyCollisions() : 0;
    return BounceReport(wall: wall, enemy: enemy);
  }

  /// Партия: скорость × rampMult (1.0 = норма).
  BounceReport tickPlay(double dt, double secondsAlive, {double speedMult = 1.0}) {
    final safeDt = dt.clamp(0.0, 0.05);
    final mult = speedMult.clamp(0.05, 2.0);
    final t = secondsAlive.clamp(0.0, 3600.0);
    var wall = 0;
    for (final e in enemies) {
      final speed = (e.speedAt(t) * mult).clamp(0.0, 4000.0);
      final dist = e.vel.distance;
      final dir = dist < 1e-6
          ? const Offset(1, 1)
          : Offset(e.vel.dx / dist, e.vel.dy / dist);
      e.vel = dir * speed;
      e.pos += e.vel * safeDt;
      if (_bounce(e)) wall++;
    }
    final enemy = config.enemiesCollide ? _resolveEnemyCollisions() : 0;
    tickNearMiss(safeDt);
    return BounceReport(wall: wall, enemy: enemy);
  }

  /// Средняя текущая скорость врагов (px/s), с учётом ramp-множителя.
  double averageSpeed(double secondsAlive, {double speedMult = 1.0}) {
    if (enemies.isEmpty) return 0;
    final mult = speedMult.clamp(0.05, 2.0);
    final t = secondsAlive.clamp(0.0, 3600.0);
    var sum = 0.0;
    for (final e in enemies) {
      sum += (e.speedAt(t) * mult).clamp(0.0, 4000.0);
    }
    return sum / enemies.length;
  }

  void movePlayerBy(Offset delta) {
    if (delta.dx == 0 && delta.dy == 0) return;
    player += delta;
    playerDistance += delta.distance;
    if (isJumping) {
      _evaluateJumpOver();
    } else {
      _evaluateNearMiss();
    }
  }

  void tickNearMiss(double dt) {
    nearMissFx.removeWhere((fx) => !fx.update(dt));
    if (isJumping) {
      _evaluateJumpOver();
    } else {
      _evaluateNearMiss();
    }
  }

  /// Прыжок через врага (перекрытие хитбоксов в воздухе) = Risk.
  void _evaluateJumpOver() {
    if (!isJumping) return;
    final pr = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    for (var i = 0; i < enemies.length; i++) {
      if (_jumpOverCounted.contains(i)) continue;
      if (!pr.overlaps(enemies[i].rect)) continue;
      _jumpOverCounted.add(i);
      nearMissCount++;
      final mid = Offset(
        (pr.center.dx + enemies[i].rect.center.dx) / 2,
        (pr.center.dy + enemies[i].rect.center.dy) / 2,
      );
      nearMissFx.add(NearMissFx(origin: mid));
    }
  }

  void _evaluateNearMiss() {
    if (isJumping) return;
    final pr = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    final stillArmed = <int>{};
    for (var i = 0; i < enemies.length; i++) {
      final gap = _aabbGap(pr, enemies[i].rect);
      if (gap <= 0) {
        // Касание — не near-miss
        continue;
      }
      if (gap <= _nearEnterPx) {
        _nearArmed.add(i);
        stillArmed.add(i);
      } else if (gap >= _nearExitPx && _nearArmed.contains(i)) {
        nearMissCount++;
        final mid = Offset(
          (pr.center.dx + enemies[i].rect.center.dx) / 2,
          (pr.center.dy + enemies[i].rect.center.dy) / 2,
        );
        nearMissFx.add(NearMissFx(origin: mid));
      } else if (_nearArmed.contains(i)) {
        stillArmed.add(i);
      }
    }
    _nearArmed
      ..clear()
      ..addAll(stillArmed);
  }

  /// Зазор между AABB: 0 = пересечение / касание.
  static double _aabbGap(Rect a, Rect b) {
    if (a.overlaps(b)) return 0;
    final dx = max(0.0, max(a.left - b.right, b.left - a.right));
    final dy = max(0.0, max(a.top - b.bottom, b.top - a.bottom));
    if (dx > 0 && dy > 0) return sqrt(dx * dx + dy * dy);
    return max(dx, dy);
  }

  bool playerHitsBorder() {
    return player.dx <= 0 ||
        player.dy <= 0 ||
        player.dx + playerSize >= field.width ||
        player.dy + playerSize >= field.height;
  }

  bool playerHitsEnemy() {
    if (isJumping) return false;
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

  /// true, если враг отразился от стены в этом кадре.
  bool _bounce(EnemyBody e) {
    var x = e.pos.dx;
    var y = e.pos.dy;
    var vx = e.vel.dx;
    var vy = e.vel.dy;
    var hit = false;

    if (x <= 0) {
      x = 0;
      vx = vx.abs();
      hit = true;
    } else if (x + e.w >= field.width) {
      x = field.width - e.w;
      vx = -vx.abs();
      hit = true;
    }
    if (y <= 0) {
      y = 0;
      vy = vy.abs();
      hit = true;
    } else if (y + e.h >= field.height) {
      y = field.height - e.h;
      vy = -vy.abs();
      hit = true;
    }

    e.pos = Offset(x, y);
    e.vel = Offset(vx, vy);
    return hit;
  }

  /// Отскок мобов друг от друга (как от стены). Возвращает число столкновений.
  int _resolveEnemyCollisions() {
    var hits = 0;
    for (var i = 0; i < enemies.length; i++) {
      for (var j = i + 1; j < enemies.length; j++) {
        final a = enemies[i];
        final b = enemies[j];
        final ar = a.rect;
        final br = b.rect;
        if (!ar.overlaps(br)) continue;

        final overlapX =
            min(ar.right, br.right) - max(ar.left, br.left);
        final overlapY =
            min(ar.bottom, br.bottom) - max(ar.top, br.top);
        if (overlapX <= 0 || overlapY <= 0) continue;

        hits++;
        final acx = ar.center.dx;
        final acy = ar.center.dy;
        final bcx = br.center.dx;
        final bcy = br.center.dy;

        if (overlapX < overlapY) {
          final sep = overlapX / 2 + 0.5;
          if (acx <= bcx) {
            a.pos = Offset(a.pos.dx - sep, a.pos.dy);
            b.pos = Offset(b.pos.dx + sep, b.pos.dy);
            if (a.vel.dx > 0) a.vel = Offset(-a.vel.dx.abs(), a.vel.dy);
            if (b.vel.dx < 0) b.vel = Offset(b.vel.dx.abs(), b.vel.dy);
          } else {
            a.pos = Offset(a.pos.dx + sep, a.pos.dy);
            b.pos = Offset(b.pos.dx - sep, b.pos.dy);
            if (a.vel.dx < 0) a.vel = Offset(a.vel.dx.abs(), a.vel.dy);
            if (b.vel.dx > 0) b.vel = Offset(-b.vel.dx.abs(), b.vel.dy);
          }
        } else {
          final sep = overlapY / 2 + 0.5;
          if (acy <= bcy) {
            a.pos = Offset(a.pos.dx, a.pos.dy - sep);
            b.pos = Offset(b.pos.dx, b.pos.dy + sep);
            if (a.vel.dy > 0) a.vel = Offset(a.vel.dx, -a.vel.dy.abs());
            if (b.vel.dy < 0) b.vel = Offset(b.vel.dx, b.vel.dy.abs());
          } else {
            a.pos = Offset(a.pos.dx, a.pos.dy + sep);
            b.pos = Offset(b.pos.dx, b.pos.dy - sep);
            if (a.vel.dy < 0) a.vel = Offset(a.vel.dx, a.vel.dy.abs());
            if (b.vel.dy > 0) b.vel = Offset(b.vel.dx, -b.vel.dy.abs());
          }
        }
        _bounce(a);
        _bounce(b);
      }
    }
    return hits;
  }
}
