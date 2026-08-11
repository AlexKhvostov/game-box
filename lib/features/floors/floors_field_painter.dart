import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_field_painter.dart';
import '../game/impact_burst.dart';
import 'floors_config.dart';
import 'floors_world.dart';

/// Поле: своя рамка + чужая соседа, свет в проёме, Г-края.
class FloorsFieldPainter extends CustomPainter {
  FloorsFieldPainter({
    required this.floors,
    required this.accent,
    required this.danger,
    required this.fieldColor,
    required this.borderColor,
    this.borderWidth = 3,
    this.cornerRadius = 18,
    this.frame = 0,
    this.decorSec = 0,
    this.playerPreview = false,
    this.invulnerable = false,
    this.invulnerableFactor,
    this.impacts = const [],
    this.shadowBrightness = 1.0,
    this.eyeLook = Offset.zero,
    this.showFace = false,
  });

  final FloorsWorld floors;
  final Color accent;
  final Color danger;
  final Color fieldColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final int frame;
  /// Плавные часы декора (не frame) — без дёрганья при движении героя.
  final double decorSec;
  final bool playerPreview;
  final bool invulnerable;
  final double? invulnerableFactor;
  final List<ImpactBurst> impacts;
  final double shadowBrightness;
  final Offset eyeLook;
  final bool showFace;

  static const _stairsColor = Color(0xFF7EE0FF);

  @override
  void paint(Canvas canvas, Size size) {
    GameFieldPainter(
      world: floors.game,
      accent: accent,
      danger: danger,
      fieldColor: fieldColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: cornerRadius,
      frame: frame,
      playerPreview: playerPreview,
      invulnerable: invulnerable,
      invulnerableFactor: invulnerableFactor,
      impacts: impacts,
      shadowBrightness: shadowBrightness,
      drawBorder: false,
      eyeLook: eyeLook,
      showFace: showFace,
    ).paint(canvas, size);

    _drawCrystals(canvas);
    _drawKey(canvas);
    _drawObstacles(canvas);
    // Сначала чужая (снаружи), потом своя — своя читается поверх.
    _drawFrameLayer(canvas, size, own: false);
    _drawFrameLayer(canvas, size, own: true);
    _drawHoleGlows(canvas, size);
    if (floors.showStairs) _drawStairs(canvas);
  }

  void _drawCrystals(Canvas canvas) {
    final bob = math.sin(decorSec * 2.1) * 1.8;
    final tilt = math.sin(decorSec * 1.35) * 0.05;
    for (final c in floors.crystals) {
      if (c.taken) continue;
      final p = c.center.translate(0, bob);
      canvas.drawCircle(
        p,
        13,
        Paint()
          ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(tilt);
      const r = 9.0;
      final top = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.86, -r * 0.32)
        ..lineTo(0, r * 0.18)
        ..lineTo(-r * 0.86, -r * 0.32)
        ..close();
      final left = Path()
        ..moveTo(-r * 0.86, -r * 0.32)
        ..lineTo(0, r * 0.18)
        ..lineTo(0, r)
        ..lineTo(-r * 0.86, r * 0.42)
        ..close();
      final right = Path()
        ..moveTo(r * 0.86, -r * 0.32)
        ..lineTo(0, r * 0.18)
        ..lineTo(0, r)
        ..lineTo(r * 0.86, r * 0.42)
        ..close();
      canvas.drawPath(
        top,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8FBFF), Color(0xFF7EE0FF)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.drawPath(left, Paint()..color = const Color(0xFF2A9BB8));
      canvas.drawPath(right, Paint()..color = const Color(0xFF3DDC97));
      canvas.drawPath(
        Path()
          ..addPath(top, Offset.zero)
          ..addPath(left, Offset.zero)
          ..addPath(right, Offset.zero),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.restore();
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (final o in floors.obstacles) {
      final rr = RRect.fromRectAndRadius(o, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFF2A3540));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFFF8A65).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawKey(Canvas canvas) {
    final k = floors.keyPickup;
    if (k == null || k.taken) return;
    final bob = math.sin(decorSec * 2.0) * 1.8;
    final p = k.center.translate(0, bob);
    final pulse = 0.5 + 0.5 * math.sin(decorSec * 1.6);
    canvas.drawCircle(
      p,
      16 + pulse * 2,
      Paint()
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.2 + pulse * 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Пьедестал
    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p.translate(0, 11), width: 18, height: 5),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      base,
      Paint()..color = const Color(0xFF3A2A10).withValues(alpha: 0.55),
    );
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF3C4), Color(0xFFFFC107), Color(0xFFE65100)],
      ).createShader(Rect.fromCircle(center: p, radius: 16));
    final stroke = Paint()
      ..color = const Color(0xFFFFE082)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Кольцо ключа
    canvas.drawCircle(p.translate(-5, -3), 6.5, gold);
    canvas.drawCircle(
      p.translate(-5, -3),
      3.2,
      Paint()..color = const Color(0xFF0E1419),
    );
    canvas.drawCircle(p.translate(-5, -3), 6.5, stroke);
    // Стержень + зубцы
    final shaft = Path()
      ..moveTo(p.dx + 1, p.dy - 3)
      ..lineTo(p.dx + 13, p.dy - 3)
      ..lineTo(p.dx + 13, p.dy + 1)
      ..lineTo(p.dx + 10, p.dy + 1)
      ..lineTo(p.dx + 10, p.dy + 5)
      ..lineTo(p.dx + 7, p.dy + 5)
      ..lineTo(p.dx + 7, p.dy + 1)
      ..lineTo(p.dx + 4, p.dy + 1)
      ..lineTo(p.dx + 4, p.dy + 4)
      ..lineTo(p.dx + 1, p.dy + 4)
      ..close();
    canvas.drawPath(shaft, gold);
    canvas.drawPath(shaft, stroke);
  }

  void _drawStairs(Canvas canvas) {
    final r = floors.stairsRect;
    final locked = floors.stairsLocked;
    final color = locked ? const Color(0xFF94A3B8) : _stairsColor;
    final pulse = 0.5 + 0.5 * math.sin(decorSec * 1.4);
    // Внешнее свечение портала
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.inflate(4), const Radius.circular(10)),
      Paint()
        ..color = color.withValues(alpha: locked ? 0.08 : 0.14 + pulse * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: locked
              ? const [Color(0xFF2A323C), Color(0xFF1A222C)]
              : [
                  Color.lerp(const Color(0xFF163028), _stairsColor, 0.35)!,
                  const Color(0xFF0E1A22),
                ],
        ).createShader(r),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    // Лестница-портал: ступени + арка
    final stepPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      final y = r.top + r.height * (0.28 + t * 0.5);
      final inset = 5.0 + i * 1.2;
      canvas.drawLine(
        Offset(r.left + inset, y),
        Offset(r.right - inset, y),
        stepPaint,
      );
    }
    final arch = Path()
      ..moveTo(r.left + 6, r.center.dy + 2)
      ..quadraticBezierTo(r.center.dx, r.top + 4, r.right - 6, r.center.dy + 2);
    canvas.drawPath(
      arch,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (locked) {
      _drawPadlock(canvas, r.center.translate(0, -2));
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Нужен ключ',
          style: TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width);
      tp.paint(
        canvas,
        Offset(r.center.dx - tp.width / 2, r.bottom - tp.height - 4),
      );
    } else {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'ВЫХОД',
          style: TextStyle(
            color: Color(0xFFE8FBFF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width);
      tp.paint(
        canvas,
        Offset(r.center.dx - tp.width / 2, r.bottom - tp.height - 5),
      );
    }
  }

  void _drawPadlock(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = const Color(0xFFFFC107).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 4), width: 18, height: 14),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFE65100)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final shackle = Path()
      ..addArc(
        Rect.fromCenter(center: center.translate(0, -4), width: 14, height: 14),
        math.pi * 1.05,
        math.pi * 0.9,
      );
    canvas.drawPath(
      shackle,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center.translate(0, 4),
      2.4,
      Paint()..color = const Color(0xFF1A222C),
    );
  }

  void _drawFrameLayer(Canvas canvas, Size size, {required bool own}) {
    final inset = own ? floors.ownInset : floors.neighborInset;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    if (right - left < 8 || bottom - top < 8) return;

    final stroke = floors.band;
    final alpha = own ? 1.0 : 0.72;
    final color = own
        ? borderColor
        : Color.lerp(borderColor, const Color(0xFF9AA8B5), 0.35)!;

    final soft = Paint()
      ..color = color.withValues(alpha: 0.22 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 2.5
      ..strokeCap = StrokeCap.round;
    final hard = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    void drawSeg(Offset a, Offset b) {
      if ((a - b).distance < 0.5) return;
      canvas.drawLine(a, b, soft);
      canvas.drawLine(a, b, hard);
    }

    for (final portal in floors.portals) {
      final hole = own ? portal.own : portal.neighbor;
      final holes = hole == null ? const <WallExit>[] : [hole];
      final fixed = switch (portal.side) {
        WallSide.top => top,
        WallSide.bottom => bottom,
        WallSide.left => left,
        WallSide.right => right,
      };
      final horizontal =
          portal.side == WallSide.top || portal.side == WallSide.bottom;
      _drawSideWithGaps(
        drawSeg,
        alongMin: horizontal ? left : top,
        alongMax: horizontal ? right : bottom,
        fixed: fixed,
        horizontal: horizontal,
        holes: holes,
      );
      if (hole != null) {
        _drawCornerLips(
          canvas,
          side: portal.side,
          hole: hole,
          fixed: fixed,
          stroke: stroke,
          color: color.withValues(alpha: alpha),
          own: own,
        );
      }
    }
  }

  /// «Г»-образный загиб стены к проёму (не «Т»).
  void _drawCornerLips(
    Canvas canvas, {
    required WallSide side,
    required WallExit hole,
    required double fixed,
    required double stroke,
    required Color color,
    required bool own,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final half = hole.length / 2;
    final a = hole.centerAlong - half;
    final b = hole.centerAlong + half;
    // Загиб внутрь комнаты для своей рамки, наружу — для чужой.
    final bend = own ? stroke * 1.6 : -stroke * 1.6;

    switch (side) {
      case WallSide.top:
        canvas.drawLine(Offset(a, fixed), Offset(a, fixed + bend), paint);
        canvas.drawLine(Offset(b, fixed), Offset(b, fixed + bend), paint);
      case WallSide.bottom:
        canvas.drawLine(Offset(a, fixed), Offset(a, fixed - bend), paint);
        canvas.drawLine(Offset(b, fixed), Offset(b, fixed - bend), paint);
      case WallSide.left:
        canvas.drawLine(Offset(fixed, a), Offset(fixed + bend, a), paint);
        canvas.drawLine(Offset(fixed, b), Offset(fixed + bend, b), paint);
      case WallSide.right:
        canvas.drawLine(Offset(fixed, a), Offset(fixed - bend, a), paint);
        canvas.drawLine(Offset(fixed, b), Offset(fixed - bend, b), paint);
    }
  }

  void _drawHoleGlows(Canvas canvas, Size size) {
    for (final portal in floors.portals) {
      final own = portal.own;
      final light = portal.neighborLight;
      if (own == null || light == null) continue;
      final half = own.length / 2;
      final a = own.centerAlong - half;
      final band = floors.band;
      // Свет между своей и чужой рамкой в зоне проёма.
      final outer = floors.neighborInset;
      final inner = floors.ownInset;
      final rect = switch (portal.side) {
        WallSide.top => Rect.fromLTRB(a, outer, a + own.length, inner),
        WallSide.bottom => Rect.fromLTRB(
            a,
            size.height - inner,
            a + own.length,
            size.height - outer,
          ),
        WallSide.left => Rect.fromLTRB(outer, a, inner, a + own.length),
        WallSide.right => Rect.fromLTRB(
            size.width - inner,
            a,
            size.width - outer,
            a + own.length,
          ),
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(band * 0.4)),
        Paint()..color = light.withValues(alpha: 0.22),
      );
    }
  }

  void _drawSideWithGaps(
    void Function(Offset a, Offset b) drawSeg, {
    required double alongMin,
    required double alongMax,
    required double fixed,
    required bool horizontal,
    required List<WallExit> holes,
  }) {
    final gaps = <({double a, double b})>[
      for (final e in holes)
        (a: e.centerAlong - e.length / 2, b: e.centerAlong + e.length / 2),
    ]..sort((x, y) => x.a.compareTo(y.a));

    var cursor = alongMin;
    for (final g in gaps) {
      final ga = g.a.clamp(alongMin, alongMax);
      final gb = g.b.clamp(alongMin, alongMax);
      if (ga > cursor) {
        if (horizontal) {
          drawSeg(Offset(cursor, fixed), Offset(ga, fixed));
        } else {
          drawSeg(Offset(fixed, cursor), Offset(fixed, ga));
        }
      }
      cursor = math.max(cursor, gb);
    }
    if (cursor < alongMax) {
      if (horizontal) {
        drawSeg(Offset(cursor, fixed), Offset(alongMax, fixed));
      } else {
        drawSeg(Offset(fixed, cursor), Offset(fixed, alongMax));
      }
    }
  }

  @override
  bool shouldRepaint(covariant FloorsFieldPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.decorSec != decorSec ||
        oldDelegate.playerPreview != playerPreview ||
        oldDelegate.invulnerable != invulnerable ||
        oldDelegate.invulnerableFactor != invulnerableFactor ||
        oldDelegate.impacts != impacts ||
        oldDelegate.fieldColor != fieldColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.floors.showStairs != floors.showStairs ||
        oldDelegate.floors.stairsLocked != floors.stairsLocked ||
        oldDelegate.floors.loadout.exitMoveSpeed !=
            floors.loadout.exitMoveSpeed ||
        oldDelegate.eyeLook != eyeLook ||
        oldDelegate.showFace != showFace ||
        oldDelegate.floors.crystals != floors.crystals ||
        oldDelegate.floors.keyPickup?.taken != floors.keyPickup?.taken;
  }
}
