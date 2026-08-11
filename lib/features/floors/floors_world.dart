import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/gameplay_config.dart';
import '../game/game_world.dart';
import 'floors_config.dart';
import 'floors_data.dart';
import 'floors_loadout.dart';

enum FloorsBorderHit { none, exit, deadlyWall }

class RoomCrystal {
  RoomCrystal(this.center);

  Offset center;
  bool taken = false;

  Rect get hitbox {
    const s = 14.0;
    return Rect.fromCenter(center: center, width: s, height: s);
  }
}

class RoomKeyPickup {
  RoomKeyPickup(this.center);

  Offset center;
  bool taken = false;

  Rect get hitbox {
    const s = 22.0;
    return Rect.fromCenter(center: center, width: s, height: s);
  }
}

/// Комната этажа: своя рамка + видимая рамка соседа, внутренние стенки.
class FloorsWorld {
  FloorsWorld({
    required GameplayConfig arcadeConfig,
    required this.field,
    required this.floor,
    required this.row,
    required this.col,
    required this.loadout,
    required this.cell,
    this.floorsConfig = const FloorsConfig(),
    this.enterFrom,
    this.enterAlong,
    this.showStairs = false,
    this.exitClockSec = 0,
    this.crystalCount = 0,
    this.spawnKey = false,
    this.stairsLocked = false,
    Random? rng,
  })  : _rng = rng ?? Random(),
        borderWidth = arcadeConfig.borderWidth,
        game = GameWorld(
          config: FloorsConfig.roomGameplay(
            base: arcadeConfig,
            loadout: loadout.enemyCount == 0
                ? RoomLoadoutCatalog.easiest
                : loadout,
          ),
          field: field,
          rng: rng,
          wallInset: FloorsConfig.playableInset(
            FloorsConfig.frameBand(arcadeConfig.borderWidth),
          ),
        ) {
    portals = _buildPortals();
    syncExits(exitClockSec);
    obstacles = loadout.hasWalls ? _buildObstacles() : const [];
    // Центр — спавн героя; объекты ближе к краям.
    stairsCenter = showStairs ? _edgeAnchor(0.82, 0.20) : _edgeAnchor(0.5, 0.5);
    crystals = _spawnCrystals(crystalCount);
    keyPickup = spawnKey ? RoomKeyPickup(_edgeAnchor(0.18, 0.80)) : null;
    game.resetLayout();
    if (loadout.enemyCount == 0) {
      game.enemies.clear();
    } else {
      _pushEnemiesAwayFromEntry();
    }
    if (enterFrom != null) {
      _placePlayerNearSide(enterFrom!, along: enterAlong);
    }
    constrainPlayerToDeadlyWalls();
  }

  final Size field;
  final FloorDefinition floor;
  final int row;
  final int col;
  final FloorsConfig floorsConfig;
  final RoomLoadout loadout;
  final FloorCell cell;
  final GameWorld game;
  final WallSide? enterFrom;
  final double? enterAlong;
  final bool showStairs;
  final double exitClockSec;
  final double borderWidth;
  final Random _rng;
  late List<SidePortal> portals;
  late List<Rect> obstacles;
  late List<RoomCrystal> crystals;
  final int crystalCount;
  final bool spawnKey;
  /// Меняется при подборе ключа в этой же комнате (без пересборки мира).
  bool stairsLocked;
  RoomKeyPickup? keyPickup;
  late final Offset stairsCenter;

  double get band => FloorsConfig.frameBand(borderWidth);
  double get ownInset => FloorsConfig.ownInset(band);
  double get neighborInset => FloorsConfig.neighborInset(band);
  double get playableInset => FloorsConfig.playableInset(band);
  double get playerSize => game.playerSize;

  Rect get stairsRect {
    final s = playerSize * 1.55;
    return Rect.fromCenter(
      center: stairsCenter,
      width: s * 1.15,
      height: s * 1.35,
    );
  }

  /// u,v ∈ 0…1 внутри playable-зоны (не центр спавна).
  Offset _edgeAnchor(double u, double v) {
    final inset = playableInset + playerSize * 0.75;
    final x = inset + (field.width - 2 * inset) * u.clamp(0.0, 1.0);
    final y = inset + (field.height - 2 * inset) * v.clamp(0.0, 1.0);
    return Offset(x, y);
  }

  void syncExits(double clockSec) {
    for (final p in portals) {
      p.sync(clockSec);
    }
  }

  SidePortal? portalOn(WallSide side) {
    for (final p in portals) {
      if (p.side == side) return p;
    }
    return null;
  }

  bool playerOnStairs() {
    if (!showStairs || stairsLocked) return false;
    final pr = Rect.fromLTWH(
      game.player.dx,
      game.player.dy,
      playerSize,
      playerSize,
    );
    return pr.overlaps(stairsRect);
  }

  /// Стоит на лестнице, но ключа нет.
  bool playerOnLockedStairs() {
    if (!showStairs || !stairsLocked) return false;
    final pr = Rect.fromLTWH(
      game.player.dx,
      game.player.dy,
      playerSize,
      playerSize,
    );
    return pr.overlaps(stairsRect);
  }

  bool playerHitsObstacle() {
    final pr = Rect.fromLTWH(
      game.player.dx,
      game.player.dy,
      playerSize,
      playerSize,
    );
    for (final o in obstacles) {
      if (pr.overlaps(o)) return true;
    }
    return false;
  }

  /// Вытолкнуть героя из препятствия (когда стены не убивают).
  void pushPlayerFromObstacles() {
    var x = game.player.dx;
    var y = game.player.dy;
    final s = playerSize;
    for (var iter = 0; iter < 4; iter++) {
      final pr = Rect.fromLTWH(x, y, s, s);
      var moved = false;
      for (final o in obstacles) {
        if (!pr.overlaps(o)) continue;
        final dxL = pr.right - o.left;
        final dxR = o.right - pr.left;
        final dyT = pr.bottom - o.top;
        final dyB = o.bottom - pr.top;
        final m = [dxL, dxR, dyT, dyB].reduce(min);
        if (m == dxL) {
          x = o.left - s;
        } else if (m == dxR) {
          x = o.right;
        } else if (m == dyT) {
          y = o.top - s;
        } else {
          y = o.bottom;
        }
        moved = true;
        break;
      }
      if (!moved) break;
    }
    final inset = playableInset;
    game.player = Offset(
      x.clamp(inset, field.width - s - inset),
      y.clamp(inset, field.height - s - inset),
    );
  }

  List<RoomCrystal> _spawnCrystals(int count) {
    if (count <= 0) return [];
    final out = <RoomCrystal>[];
    // Слоты у краёв — не центр (спавн) и не угол выхода/ключа.
    final slots = <Offset>[
      _edgeAnchor(0.20, 0.28),
      _edgeAnchor(0.78, 0.72),
      _edgeAnchor(0.72, 0.38),
      _edgeAnchor(0.30, 0.62),
      _edgeAnchor(0.55, 0.22),
    ];
    for (var i = 0; i < count; i++) {
      final base = slots[i % slots.length];
      final jitter = Offset(
        (_rng.nextDouble() - 0.5) * playerSize * 0.35,
        (_rng.nextDouble() - 0.5) * playerSize * 0.35,
      );
      out.add(RoomCrystal(base + jitter));
    }
    return out;
  }

  /// Касание кристаллов → список центров только что собранных.
  List<Offset> tryCollectCrystals() {
    final pr = Rect.fromLTWH(
      game.player.dx,
      game.player.dy,
      playerSize,
      playerSize,
    );
    final hits = <Offset>[];
    for (final c in crystals) {
      if (c.taken) continue;
      if (!pr.overlaps(c.hitbox)) continue;
      c.taken = true;
      hits.add(c.center);
    }
    return hits;
  }

  bool tryCollectKey() {
    final k = keyPickup;
    if (k == null || k.taken) return false;
    final pr = Rect.fromLTWH(
      game.player.dx,
      game.player.dy,
      playerSize,
      playerSize,
    );
    if (!pr.overlaps(k.hitbox)) return false;
    k.taken = true;
    return true;
  }

  List<SidePortal> _buildPortals() {
    return [
      for (final side in WallSide.values) _portalForSide(side),
    ];
  }

  SidePortal _portalForSide(WallSide side) {
    final n = _neighborCell(side);
    if (n == null) {
      // Край карты: глухая своя + глухая «чужая» (без проёмов).
      return SidePortal(side: side);
    }

    final alongSpan = (side == WallSide.top || side == WallSide.bottom)
        ? field.width
        : field.height;
    final frac = floorsConfig.exitLengthFraction;
    final length = EdgeExitMath.holeLength(alongSpan, frac);
    final pad = field.shortestSide * 0.08;
    final range = EdgeExitMath.alongRange(
      alongSpan: alongSpan,
      length: length,
      cornerPad: pad,
    );
    final seed = EdgeExitMath.edgeSeed(
      floorNumber: floor.floorNumber,
      r1: row,
      c1: col,
      r2: n.r,
      c2: n.c,
    );
    final base = EdgeExitMath.baseAlong(
      seed: seed,
      minA: range.minA,
      maxA: range.maxA,
    );
    final ph = EdgeExitMath.phase(seed);

    final neighLoad = floor.loadoutFor(n.r, n.c);
    final neighCell = floor.cellAt(n.r, n.c);

    WallExit makeHole(double speed) => WallExit(
          side: side,
          length: length,
          minAlong: range.minA,
          maxAlong: range.maxA,
          baseAlong: base,
          speed: speed,
          phase: ph,
        );

    final light = FloorDefinition.colorForCell(
      neighCell.isStart
          ? neighCell
          : FloorCell(
              difficulty: neighLoad.difficultyPercent,
              isFloorExit: neighCell.isFloorExit,
            ),
    );

    return SidePortal(
      side: side,
      own: makeHole(loadout.exitMoveSpeed),
      neighbor: makeHole(neighLoad.exitMoveSpeed),
      neighborLight: light,
    );
  }

  ({int r, int c})? _neighborCell(WallSide side) {
    final r = row +
        (side == WallSide.top
            ? -1
            : side == WallSide.bottom
                ? 1
                : 0);
    final c = col +
        (side == WallSide.left
            ? -1
            : side == WallSide.right
                ? 1
                : 0);
    if (!floor.inBounds(r, c)) return null;
    return (r: r, c: c);
  }

  List<Rect> _buildObstacles() {
    final w = field.width;
    final h = field.height;
    final s = playerSize;
    final margin = s * 1.5 + playableInset;
    final thickness = (s * 0.14).clamp(3.5, 6.0);
    final length = s * (3.2 + _rng.nextDouble() * 0.6);
    final horizontal = _rng.nextBool();

    Rect place(double cx, double cy, {required bool horiz}) {
      final rect = horiz
          ? Rect.fromCenter(
              center: Offset(cx, cy),
              width: length,
              height: thickness,
            )
          : Rect.fromCenter(
              center: Offset(cx, cy),
              width: thickness,
              height: length,
            );
      return Rect.fromLTRB(
        rect.left.clamp(margin, w - margin),
        rect.top.clamp(margin, h - margin),
        rect.right.clamp(margin, w - margin),
        rect.bottom.clamp(margin, h - margin),
      );
    }

    final a = place(w * 0.38, h * 0.36, horiz: horizontal);
    if (loadout.wallCount < 2) return [a];

    // Вторая стенка — не ближе 1.5× героя к первой.
    final minGap = s * 1.5;
    var b = place(w * 0.66, h * 0.64, horiz: !horizontal);
    if (_rectsTooClose(a, b, minGap)) {
      b = place(w * 0.70, h * 0.30, horiz: horizontal);
    }
    if (_rectsTooClose(a, b, minGap)) {
      return [a];
    }
    return [a, b];
  }

  bool _rectsTooClose(Rect a, Rect b, double minGap) {
    final dx = (a.center.dx - b.center.dx).abs() - (a.width + b.width) / 2;
    final dy = (a.center.dy - b.center.dy).abs() - (a.height + b.height) / 2;
    final gap = max(dx, dy);
    return gap < minGap;
  }

  void constrainPlayerToDeadlyWalls() {
    final s = playerSize;
    final inner = playableInset;
    var x = game.player.dx;
    var y = game.player.dy;

    // Через оба проёма можно выйти за свою рамку; иначе — clamp к playable.
    if (!_portalAllows(WallSide.top, x, x + s) && y < inner) y = inner;
    if (!_portalAllows(WallSide.bottom, x, x + s) &&
        y + s > field.height - inner) {
      y = field.height - s - inner;
    }
    if (!_portalAllows(WallSide.left, y, y + s) && x < inner) x = inner;
    if (!_portalAllows(WallSide.right, y, y + s) &&
        x + s > field.width - inner) {
      x = field.width - s - inner;
    }
    game.player = Offset(x, y);
  }

  bool _portalAllows(WallSide side, double a0, double a1) {
    final p = portalOn(side);
    if (p == null) return false;
    return p.allowsSegment(a0, a1);
  }

  void _placePlayerNearSide(WallSide side, {double? along}) {
    final s = playerSize;
    final pad = playableInset + 4;
    final portal = portalOn(side);
    final fallback = portal?.own?.centerAlong ??
        ((side == WallSide.top || side == WallSide.bottom)
            ? field.width / 2
            : field.height / 2);
    final a = (along ?? fallback);

    game.player = switch (side) {
      WallSide.top => Offset(
          (a - s / 2).clamp(pad, field.width - s - pad),
          pad,
        ),
      WallSide.bottom => Offset(
          (a - s / 2).clamp(pad, field.width - s - pad),
          field.height - s - pad,
        ),
      WallSide.left => Offset(
          pad,
          (a - s / 2).clamp(pad, field.height - s - pad),
        ),
      WallSide.right => Offset(
          field.width - s - pad,
          (a - s / 2).clamp(pad, field.height - s - pad),
        ),
    };
  }

  /// Координата вдоль стены для спавна в соседней комнате.
  double playerAlongForSide(WallSide side) {
    final p = game.player;
    final s = playerSize;
    return switch (side) {
      WallSide.top || WallSide.bottom => p.dx + s / 2,
      WallSide.left || WallSide.right => p.dy + s / 2,
    };
  }

  void _pushEnemiesAwayFromEntry() {
    if (enterFrom == null) return;
    final safe = field.shortestSide * 0.38;
    final inset = playableInset + 8;
    for (final e in game.enemies) {
      final c = e.rect.center;
      final nearEntry = switch (enterFrom!) {
        WallSide.top => c.dy < safe,
        WallSide.bottom => c.dy > field.height - safe,
        WallSide.left => c.dx < safe,
        WallSide.right => c.dx > field.width - safe,
      };
      if (!nearEntry) continue;
      final nx = switch (enterFrom!) {
        WallSide.left => field.width * 0.65,
        WallSide.right => field.width * 0.2,
        _ => e.pos.dx,
      };
      final ny = switch (enterFrom!) {
        WallSide.top => field.height * 0.65,
        WallSide.bottom => field.height * 0.2,
        _ => e.pos.dy,
      };
      e.pos = Offset(
        nx.clamp(inset, field.width - e.w - inset),
        ny.clamp(inset, field.height - e.h - inset),
      );
    }
  }

  void resolveObstacleBounces() {
    for (final e in game.enemies) {
      for (final o in obstacles) {
        if (!e.rect.overlaps(o)) continue;
        final mtv = e.mtvOutOfAabb(o);
        if (mtv == null) continue;
        e.setCenter(e.center + mtv);
        e.reflectVelocity(mtv);
      }
    }
  }

  FloorsBorderHit evaluateBorder() {
    final p = game.player;
    final s = playerSize;
    final w = field.width;
    final h = field.height;
    final pr = Rect.fromLTWH(p.dx, p.dy, s, s);

    if (_hitsSolidFrame(pr)) return FloorsBorderHit.deadlyWall;

    FloorsBorderHit sideHit({
      required WallSide side,
      required double a0,
      required double a1,
      required bool pastOuterEdge,
      required bool inExitCorridor,
    }) {
      if (!inExitCorridor && !pastOuterEdge) return FloorsBorderHit.none;
      final portal = portalOn(side);
      if (portal == null || portal.isMapEdge) {
        return inExitCorridor || pastOuterEdge
            ? FloorsBorderHit.deadlyWall
            : FloorsBorderHit.none;
      }
      if (portal.allowsSegment(a0, a1)) {
        return pastOuterEdge ? FloorsBorderHit.exit : FloorsBorderHit.none;
      }
      if (inExitCorridor || pastOuterEdge) return FloorsBorderHit.deadlyWall;
      return FloorsBorderHit.none;
    }

    final band = this.band;
    // Коридор выхода: от своей рамки наружу.
    final corridorLo = neighborInset - band / 2;

    final top = sideHit(
      side: WallSide.top,
      a0: p.dx,
      a1: p.dx + s,
      pastOuterEdge: p.dy <= 0,
      inExitCorridor: p.dy < playableInset && p.dy + s > corridorLo,
    );
    if (top != FloorsBorderHit.none) return top;

    final bottom = sideHit(
      side: WallSide.bottom,
      a0: p.dx,
      a1: p.dx + s,
      pastOuterEdge: p.dy + s >= h,
      inExitCorridor: p.dy + s > h - playableInset && p.dy < h - corridorLo,
    );
    if (bottom != FloorsBorderHit.none) return bottom;

    final left = sideHit(
      side: WallSide.left,
      a0: p.dy,
      a1: p.dy + s,
      pastOuterEdge: p.dx <= 0,
      inExitCorridor: p.dx < playableInset && p.dx + s > corridorLo,
    );
    if (left != FloorsBorderHit.none) return left;

    final right = sideHit(
      side: WallSide.right,
      a0: p.dy,
      a1: p.dy + s,
      pastOuterEdge: p.dx + s >= w,
      inExitCorridor: p.dx + s > w - playableInset && p.dx < w - corridorLo,
    );
    if (right != FloorsBorderHit.none) return right;

    return FloorsBorderHit.none;
  }

  bool _hitsSolidFrame(Rect pr) {
    for (final portal in portals) {
      for (final layer in [0, 1]) {
        final inset = layer == 0 ? ownInset : neighborInset;
        final hole = layer == 0 ? portal.own : portal.neighbor;
        final half = band / 2;
        final lo = (inset - half).clamp(0.0, field.shortestSide);
        final hi = inset + half;
        final strip = _frameStrip(portal.side, lo, hi).inflate(0.5);
        if (!pr.overlaps(strip)) continue;

        final a0 = (portal.side == WallSide.top ||
                portal.side == WallSide.bottom)
            ? pr.left
            : pr.top;
        final a1 = (portal.side == WallSide.top ||
                portal.side == WallSide.bottom)
            ? pr.right
            : pr.bottom;

        if (hole == null) return true;
        if (!hole.allowsSegment(a0, a1)) return true;
      }
    }
    return false;
  }

  Rect _frameStrip(WallSide side, double lo, double hi) {
    final w = field.width;
    final h = field.height;
    return switch (side) {
      WallSide.top => Rect.fromLTRB(0, lo, w, hi),
      WallSide.bottom => Rect.fromLTRB(0, h - hi, w, h - lo),
      WallSide.left => Rect.fromLTRB(lo, 0, hi, h),
      WallSide.right => Rect.fromLTRB(w - hi, 0, w - lo, h),
    };
  }

  WallSide? crossedExitSide() {
    if (evaluateBorder() != FloorsBorderHit.exit) return null;
    final p = game.player;
    final s = playerSize;
    final w = field.width;
    final h = field.height;
    if (p.dy <= 0 && _portalAllows(WallSide.top, p.dx, p.dx + s)) {
      return WallSide.top;
    }
    if (p.dy + s >= h && _portalAllows(WallSide.bottom, p.dx, p.dx + s)) {
      return WallSide.bottom;
    }
    if (p.dx <= 0 && _portalAllows(WallSide.left, p.dy, p.dy + s)) {
      return WallSide.left;
    }
    if (p.dx + s >= w && _portalAllows(WallSide.right, p.dy, p.dy + s)) {
      return WallSide.right;
    }
    return null;
  }
}
