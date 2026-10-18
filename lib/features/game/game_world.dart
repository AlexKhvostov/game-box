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
  late Offset homePos;
  late Offset homeVel;
  double idleT = 0;
  double idleWx = 1.4;
  double idleWy = 1.1;
  double idlePhase = 0;
  double idlePhase2 = 1;
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
    Offset at(double lx, double ly) =>
        Offset(c.dx + ax.dx * lx + ay.dx * ly, c.dy + ax.dy * lx + ay.dy * ly);
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
    final ext =
        (w * 0.5) * (axis.dx * ax.dx + axis.dy * ax.dy).abs() +
        (h * 0.5) * (axis.dx * ay.dx + axis.dy * ay.dy).abs();
    return (cen - ext, cen + ext);
  }

  double speedAt(double secondsAlive) =>
      initialSpeed + acceleration * secondsAlive;

  /// Пересечение с осью-выровненным прямоугольником (игрок / препятствие).
  bool overlapsAabb(Rect other) => mtvOutOfAabb(other) != null;

  /// First overlap while [other] moves by [delta], using the four SAT axes.
  /// A clear endpoint alone cannot rule out crossing a thin/rotated enemy.
  double? sweptAabb(Rect other, Offset delta) {
    var enter = 0.0;
    var exit = 1.0;
    for (final axis in [const Offset(1, 0), const Offset(0, 1), axisX, axisY]) {
      final (lo, hi) = project(axis);
      final center = other.center.dx * axis.dx + other.center.dy * axis.dy;
      final extent =
          other.width / 2 * axis.dx.abs() + other.height / 2 * axis.dy.abs();
      final velocity = delta.dx * axis.dx + delta.dy * axis.dy;
      if (velocity.abs() < 1e-12) {
        if (center + extent <= lo || center - extent >= hi) return null;
        continue;
      }
      final a = (lo - center - extent) / velocity;
      final b = (hi - center + extent) / velocity;
      enter = max(enter, min(a, b));
      exit = min(exit, max(a, b));
      if (enter >= exit) return null;
    }
    return exit <= 0 ? null : enter;
  }

  /// MTV: сдвиг центра, чтобы выйти из [other] (null = нет пересечения).
  Offset? mtvOutOfAabb(Rect other) {
    final axes = <Offset>[const Offset(1, 0), const Offset(0, 1), axisX, axisY];
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
        final side =
            (center.dx - other.center.dx) * n.dx +
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
  final Stopwatch _jumpClock = Stopwatch()..start();
  double _jumpReadyAtMs = 0;

  double get jumpCooldownMs {
    final seconds = config.jumpCooldownSec;
    return max(2.0, seconds.isFinite ? seconds : 2.0) * 1000;
  }

  double jumpCooldownRemaining({double? nowMs}) => max(
    0,
    _jumpReadyAtMs - (nowMs ?? _jumpClock.elapsedMilliseconds.toDouble()),
  );

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

  bool get enemyAtRiskDistance {
    final body = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    return enemies.any((enemy) => _aabbGap(body, enemy.rect) <= _nearEnterPx);
  }

  // New run proportions: 54 reference units at a 36-unit published base.
  // Enemy dimensions derive from this area, so both axes grow by exactly 1.5.
  static const characterSizeScale = 1.2;
  double get playerSize => config.playerSize * characterSizeScale;

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
    _jumpReadyAtMs = 0;
    playerDistance = 0;
    nearMissCount = 0;
    nearMissFx.clear();
    _nearArmed.clear();
    _jumpOverCounted.clear();
    enemies
      ..clear()
      ..addAll(_spawnEnemies());
  }

  bool tryJump({double? nowMs}) {
    final now = nowMs ?? _jumpClock.elapsedMilliseconds.toDouble();
    if (!now.isFinite ||
        !config.jumpEnabled ||
        isJumping ||
        jumpCooldownRemaining(nowMs: now) > 0) {
      return false;
    }
    jumpRemaining = max(0.12, config.jumpDurationSec);
    _jumpReadyAtMs = now + jumpCooldownMs;
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
    final aspects = List<double>.from(
      config.enemyAspects,
    ).where((a) => a.isFinite && a > 0.05 && a < 50).toList();
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
    if (!config.idleEnemiesMove) return _tickIdleDrowsy(safeDt);
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

  void snapEnemiesToHome() {
    for (final e in enemies) {
      e.pos = e.homePos;
      final length = e.homeVel.distance;
      final direction = length < 1e-6 ? const Offset(1, 1) : e.homeVel / length;
      e.vel = direction * e.initialSpeed;
    }
  }

  BounceReport _tickIdleDrowsy(double dt) {
    for (final e in enemies) {
      e.idleT += dt;
      final amplitude = min(e.w, e.h) * 0.5;
      final length = e.homeVel.distance;
      final direction = length < 1e-6 ? const Offset(1, 0) : e.homeVel / length;
      final perpendicular = Offset(-direction.dy, direction.dx);
      final along = cos(e.idleT * e.idleWx + e.idlePhase) * amplitude;
      final side = sin(e.idleT * e.idleWy + e.idlePhase2) * amplitude * 0.35;
      var delta = direction * along + perpendicular * side;
      if (delta.distance > amplitude && delta.distance > 1e-6) {
        delta = delta * (amplitude / delta.distance);
      }
      e.pos = e.homePos + delta;
      if (e.isSpinning) e.orientDeg += e.spinDegPerSec * dt * 0.35;
      _nudgeInside(e);
    }
    return const BounceReport();
  }

  void _nudgeInside(EnemyBody e) {
    for (var i = 0; i < 3; i++) {
      final corners = e.corners;
      final minX = corners.map((p) => p.dx).reduce(min);
      final maxX = corners.map((p) => p.dx).reduce(max);
      final minY = corners.map((p) => p.dy).reduce(min);
      final maxY = corners.map((p) => p.dy).reduce(max);
      final hiX = field.width - wallInset;
      final hiY = field.height - wallInset;
      final dx = minX < wallInset
          ? wallInset - minX
          : (maxX > hiX ? hiX - maxX : 0.0);
      final dy = minY < wallInset
          ? wallInset - minY
          : (maxY > hiY ? hiY - maxY : 0.0);
      if (dx == 0 && dy == 0) break;
      e.pos += Offset(dx, dy);
    }
  }

  /// Партия: скорость × rampMult (1.0 = норма).
  BounceReport tickPlay(
    double dt,
    double secondsAlive, {
    double speedMult = 1.0,
    bool checkPlayerHits = true,
  }) {
    final safeDt = dt.clamp(0.0, 0.05);
    final mult = speedMult.clamp(0.0, 2.0);
    final t = secondsAlive.clamp(0.0, 3600.0);
    var wall = 0;
    for (final e in enemies) {
      final speed = (e.speedAt(t) * mult).clamp(0.0, 4000.0);
      final dist = e.vel.distance;
      final dir = dist < 1e-6
          ? const Offset(1, 1)
          : Offset(e.vel.dx / dist, e.vel.dy / dist);
      e.vel = dir * speed;
      // Translation uses a continuous test; rotating bodies also need samples
      // of their orientation. Ordinary frames still take only one step.
      final parts = max(1, (e.spinDegPerSec.abs() * safeDt / 5).ceil());
      for (var part = 0; part < parts; part++) {
        final delta = e.vel * (safeDt / parts);
        if (e.isSpinning) e.orientDeg += e.spinDegPerSec * safeDt / parts;
        final hit = checkPlayerHits && !isJumping
            ? e.sweptAabb(
                Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize),
                -delta,
              )
            : null;
        e.pos +=
            delta *
            (hit == null
                ? 1
                : hit == 0
                ? 0
                : min(1.0, hit + 1e-7));
        if (_bounce(e)) wall++;
        if (hit != null) break;
      }
    }
    final enemy = config.enemiesCollide ? _resolveEnemyCollisions() : 0;
    tickNearMiss(safeDt);
    return BounceReport(wall: wall, enemy: enemy);
  }

  /// Средняя текущая скорость врагов (px/s), с учётом ramp-множителя.
  double averageSpeed(double secondsAlive, {double speedMult = 1.0}) {
    if (enemies.isEmpty) return 0;
    final mult = speedMult.clamp(0.0, 2.0);
    final t = secondsAlive.clamp(0.0, 3600.0);
    var sum = 0.0;
    for (final e in enemies) {
      sum += (e.speedAt(t) * mult).clamp(0.0, 4000.0);
    }
    return sum / enemies.length;
  }

  void movePlayerBy(Offset delta, {bool checkEnemies = true}) {
    if (!delta.dx.isFinite ||
        !delta.dy.isFinite ||
        (delta.dx == 0 && delta.dy == 0)) {
      return;
    }
    final previous = player;
    var target = player + delta;
    if (!wallsKillPlayer) {
      target = Offset(
        target.dx.clamp(
          wallInset,
          max(wallInset, field.width - wallInset - playerSize),
        ),
        target.dy.clamp(
          wallInset,
          max(wallInset, field.height - wallInset - playerSize),
        ),
      );
    }
    final movement = target - previous;
    final pr = Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize);
    var fraction = 1.0;
    if (checkEnemies && !isJumping) {
      for (final enemy in enemies) {
        final hit = enemy.sweptAabb(pr, movement);
        if (hit != null) fraction = min(fraction, hit == 0 ? 0 : hit + 1e-7);
      }
    }
    player = previous + movement * min(1.0, fraction);
    final moved = (player - previous).distance;
    if (moved == 0) return;
    playerDistance += moved;
    if (isJumping) {
      for (var i = 0; i < enemies.length; i++) {
        if (enemies[i].sweptAabb(pr, movement) != null) _countJumpOver(i);
      }
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
      _countJumpOver(i);
    }
  }

  void _countJumpOver(int i) {
    if (!_jumpOverCounted.add(i)) return;
    nearMissCount++;
    final center = player + Offset(playerSize / 2, playerSize / 2);
    nearMissFx.add(NearMissFx(origin: (center + enemies[i].rect.center) / 2));
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

  /// The helmet reflects every enemy touching the hero, just like a wall.
  /// Separate the bodies first so the reflected enemy cannot cross the hero.
  int repelEnemiesFromPlayer() {
    final playerRect = Rect.fromLTWH(
      player.dx,
      player.dy,
      playerSize,
      playerSize,
    );
    var reflected = 0;
    for (final enemy in enemies) {
      final separation = enemy.mtvOutOfAabb(playerRect);
      if (separation == null) continue;
      enemy.pos += separation;
      enemy.reflectVelocity(separation);
      reflected++;
    }
    return reflected;
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

    final body = EnemyBody(
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
    // A rotated spawn uses a larger envelope than its unrotated dimensions.
    // Resolve it before recording home so preflight sees the actual visible body.
    if (body.isSpinning) _nudgeInside(body);
    body.homePos = body.pos;
    body.homeVel = body.vel;
    body.idlePhase = _rng.nextDouble() * pi * 2;
    body.idlePhase2 = _rng.nextDouble() * pi * 2;
    body.idleWx = 1.15 + _rng.nextDouble() * 0.85;
    body.idleWy = 0.85 + _rng.nextDouble() * 0.85;
    return body;
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

    final playerRect = Rect.fromLTWH(
      player.dx,
      player.dy,
      playerSize,
      playerSize,
    ).inflate(playerSize * 0.6);

    for (var attempt = 0; attempt < 12; attempt++) {
      final x = minX + _rng.nextDouble() * max(1.0, maxX - minX);
      final y = minY + _rng.nextDouble() * max(1.0, maxY - minY);
      final candidate = Offset(x, y);
      if (!Rect.fromLTWH(
        candidate.dx,
        candidate.dy,
        w,
        h,
      ).overlaps(playerRect)) {
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
