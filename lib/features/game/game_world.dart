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
    this.orientDeg = 0,
    this.spinDegPerSec = 0,
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
  /// Угол тела (°). Физика — OBB (повёрнутый прямоугольник).
  double orientDeg;
  final double spinDegPerSec;

  Offset get center => Offset(pos.dx + w * 0.5, pos.dy + h * 0.5);

  void setCenter(Offset c) {
    pos = Offset(c.dx - w * 0.5, c.dy - h * 0.5);
  }

  bool get isSpinning => spinDegPerSec.abs() > 0.01;

  Offset get axisX {
    final r = orientDeg * pi / 180;
    return Offset(cos(r), sin(r));
  }

  Offset get axisY {
    final r = orientDeg * pi / 180;
    return Offset(-sin(r), cos(r));
  }

  List<Offset> get corners {
    final c = center;
    final ax = axisX;
    final ay = axisY;
    final hx = w * 0.5;
    final hy = h * 0.5;
    Offset at(double lx, double ly) => Offset(
          c.dx + ax.dx * lx + ay.dx * ly,
          c.dy + ax.dy * lx + ay.dy * ly,
        );
    return [at(-hx, -hy), at(hx, -hy), at(hx, hy), at(-hx, hy)];
  }

  /// AABB оболочки (broadphase / near-miss).
  Rect get rect {
    final cs = corners;
    var minX = cs.first.dx;
    var maxX = cs.first.dx;
    var minY = cs.first.dy;
    var maxY = cs.first.dy;
    for (final p in cs) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  (double min, double max) project(Offset axis) {
    final c = center;
    final ax = axisX;
    final ay = axisY;
    final cen = c.dx * axis.dx + c.dy * axis.dy;
    final ext = (w * 0.5) * (axis.dx * ax.dx + axis.dy * ax.dy).abs() +
        (h * 0.5) * (axis.dx * ay.dx + axis.dy * ay.dy).abs();
    return (cen - ext, cen + ext);
  }

  double speedAt(double secondsAlive) =>
      initialSpeed + acceleration * secondsAlive;

  /// Пересечение с осью-выровненным прямоугольником (игрок / препятствие).
  bool overlapsAabb(Rect other) => mtvOutOfAabb(other) != null;

  /// MTV: сдвиг центра, чтобы выйти из [other] (null = нет пересечения).
  Offset? mtvOutOfAabb(Rect other) {
    final axes = <Offset>[
      const Offset(1, 0),
      const Offset(0, 1),
      axisX,
      axisY,
    ];
    var minOverlap = double.infinity;
    Offset? best;
    final oc = other.center;
    final ohx = other.width * 0.5;
    final ohy = other.height * 0.5;

    for (final axis in axes) {
      final len2 = axis.dx * axis.dx + axis.dy * axis.dy;
      if (len2 < 1e-12) continue;
      final inv = 1.0 / sqrt(len2);
      final n = Offset(axis.dx * inv, axis.dy * inv);
      final (minA, maxA) = project(n);
      final cenB = oc.dx * n.dx + oc.dy * n.dy;
      final extB = ohx * n.dx.abs() + ohy * n.dy.abs();
      final minB = cenB - extB;
      final maxB = cenB + extB;
      final overlap = min(maxA, maxB) - max(minA, minB);
      if (overlap <= 0) return null;
      if (overlap < minOverlap) {
        minOverlap = overlap;
        final side = (center.dx - oc.dx) * n.dx + (center.dy - oc.dy) * n.dy;
        best = side >= 0 ? n : Offset(-n.dx, -n.dy);
      }
    }
    if (best == null) return null;
    return best * (minOverlap + 0.5);
  }

  /// MTV, чтобы развести this и [other] (сдвиг для this).
  Offset? mtvOutOfObb(EnemyBody other) {
    final axes = <Offset>[axisX, axisY, other.axisX, other.axisY];
    var minOverlap = double.infinity;
    Offset? best;
    for (final axis in axes) {
      final len2 = axis.dx * axis.dx + axis.dy * axis.dy;
      if (len2 < 1e-12) continue;
      final inv = 1.0 / sqrt(len2);
      final n = Offset(axis.dx * inv, axis.dy * inv);
      final (minA, maxA) = project(n);
      final (minB, maxB) = other.project(n);
      final overlap = min(maxA, maxB) - max(minA, minB);
      if (overlap <= 0) return null;
      if (overlap < minOverlap) {
        minOverlap = overlap;
        final side = (center.dx - other.center.dx) * n.dx +
            (center.dy - other.center.dy) * n.dy;
        best = side >= 0 ? n : Offset(-n.dx, -n.dy);
      }
    }
    if (best == null) return null;
    return best * (minOverlap + 0.5);
  }

  /// Отражение скорости от плоскости с нормалью [n] (наружу).
  void reflectVelocity(Offset n) {
    final len2 = n.dx * n.dx + n.dy * n.dy;
    if (len2 < 1e-12) return;
    final inv = 1.0 / sqrt(len2);
    final nx = n.dx * inv;
    final ny = n.dy * inv;
    final vn = vel.dx * nx + vel.dy * ny;
    if (vn >= 0) return; // уже уходит
    vel = Offset(vel.dx - 2 * vn * nx, vel.dy - 2 * vn * ny);
  }
}

class GameWorld {
  GameWorld({
    required this.config,
    required this.field,
    Random? rng,
    this.wallInset = 0,
  }) : _rng = rng ?? Random();

  final GameplayConfig config;
  final Size field;
  final Random _rng;
  /// Отступ от края поля для отскока врагов (рамка этажей).
  final double wallInset;

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
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt;
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
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt;
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

  bool get wallsKillPlayer => config.wallsKillPlayer;

  void clampPlayerToField() {
    final s = playerSize;
    final lo = wallInset;
    final hiX = max(lo, field.width - wallInset - s);
    final hiY = max(lo, field.height - wallInset - s);
    player = Offset(player.dx.clamp(lo, hiX), player.dy.clamp(lo, hiY));
  }

  bool playerHitsBorder() {
    return player.dx <= wallInset ||
        player.dy <= wallInset ||
        player.dx + playerSize >= field.width - wallInset ||
        player.dy + playerSize >= field.height - wallInset;
  }

  bool playerHitsEnemy() {
    if (isJumping) return false;
    final pr = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    for (final e in enemies) {
      if (e.overlapsAabb(pr)) return true;
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
    final spin = config.enemySpinDegPerSec;

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
      spinDegPerSec: spin,
      orientDeg: spin.abs() > 0.01 ? _rng.nextDouble() * 360 : 0,
    );
  }

  /// Случайная позиция внутри квадранта поля (0 TL, 1 TR, 2 BL, 3 BR).
  Offset _randomPosInQuadrant({
    required int fieldQuadrant,
    required double w,
    required double h,
  }) {
    final pad = max(8.0, wallInset + 2);
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

  /// Отскок OBB от стен поля по реальным углам тела.
  bool _bounce(EnemyBody e) {
    var cen = e.center;
    var hit = false;

    for (var iter = 0; iter < 3; iter++) {
      e.setCenter(cen);
      final cs = e.corners;
      var minX = cs.first.dx;
      var maxX = cs.first.dx;
      var minY = cs.first.dy;
      var maxY = cs.first.dy;
      for (final p in cs) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      final lo = wallInset;
      final hiX = field.width - wallInset;
      final hiY = field.height - wallInset;
      var dx = 0.0;
      var dy = 0.0;
      if (minX < lo) {
        dx = lo - minX;
        e.reflectVelocity(const Offset(1, 0));
        hit = true;
      } else if (maxX > hiX) {
        dx = hiX - maxX;
        e.reflectVelocity(const Offset(-1, 0));
        hit = true;
      }
      if (minY < lo) {
        dy = lo - minY;
        e.reflectVelocity(const Offset(0, 1));
        hit = true;
      } else if (maxY > hiY) {
        dy = hiY - maxY;
        e.reflectVelocity(const Offset(0, -1));
        hit = true;
      }
      if (dx == 0 && dy == 0) break;
      cen = Offset(cen.dx + dx, cen.dy + dy);
    }

    e.setCenter(cen);
    return hit;
  }

  /// Отскок мобов друг от друга (OBB + SAT / MTV).
  int _resolveEnemyCollisions() {
    var hits = 0;
    for (var i = 0; i < enemies.length; i++) {
      for (var j = i + 1; j < enemies.length; j++) {
        final a = enemies[i];
        final b = enemies[j];
        // Broadphase
        if (!a.rect.overlaps(b.rect)) continue;
        final mtv = a.mtvOutOfObb(b);
        if (mtv == null) continue;
        hits++;
        final half = Offset(mtv.dx * 0.5, mtv.dy * 0.5);
        a.setCenter(a.center + half);
        b.setCenter(b.center - half);
        // Нормаль контакта: направление MTV (от b к a).
        a.reflectVelocity(mtv);
        b.reflectVelocity(Offset(-mtv.dx, -mtv.dy));
        _bounce(a);
        _bounce(b);
      }
    }
    return hits;
  }
}
