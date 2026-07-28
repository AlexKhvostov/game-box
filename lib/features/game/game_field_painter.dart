import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_world.dart';
import 'impact_burst.dart';

/// Отрисовка поля без MaskFilter.blur — blur на каждом кадре
/// часто роняет Android-эмулятор (GPU / EGL).
class GameFieldPainter extends CustomPainter {
  GameFieldPainter({
    required this.world,
    required this.accent,
    required this.danger,
    required this.fieldColor,
    required this.borderColor,
    this.borderWidth = 3,
    this.cornerRadius = 18,
    this.frame = 0,
    this.playerPreview = false,
    this.impacts = const [],
    this.hasHelmet = false,
    this.invulnerable = false,
    this.shadowBrightness = 1.0,
  });

  final GameWorld world;
  final Color accent;
  final Color danger;
  final Color fieldColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  /// Меняется каждый тик — иначе CustomPaint не перерисует mutable world.
  final int frame;
  /// До первого касания: игрок полупрозрачный.
  final bool playerPreview;
  final List<ImpactBurst> impacts;
  /// Активный шлем (1 заряд) — обводка на кубе.
  final bool hasHelmet;
  /// Мигание после разрушения шлема — неуязвимость.
  final bool invulnerable;
  /// >1 — тень светлее; <1 — темнее. Из RC `field.shadowBrightness`.
  final double shadowBrightness;

  double _shadowAlpha(double base) {
    final b = shadowBrightness.clamp(0.4, 2.5);
    return (base / b).clamp(0.02, 0.85);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return;
    }

    final r = math.min(cornerRadius, size.shortestSide / 2).clamp(0.0, 64.0);
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );

    // Фон
    canvas.drawRRect(outer, Paint()..color = fieldColor);

    // Лёгкая «глубина» без blur — полупрозрачный оверлей по краям через stroke
    canvas.drawRRect(
      outer,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.08,
    );

    // Тонкая сетка
    _drawSoftGrid(canvas, size, r);

    // Слой «пола»: только тень по форме объекта (без овала).
    const light = Offset(5.5, 7.0);
    final enemyShadowPaint =
        Paint()..color = Colors.black.withValues(alpha: _shadowAlpha(0.42));
    for (final e in world.enemies) {
      final rect = e.rect;
      if (!_isFiniteRect(rect)) continue;
      final er = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(er.shift(light), enemyShadowPaint);
    }

    // Тень игрока на полу — только вне прыжка (один уровень с мобами).
    // В прыжке тень рисуется позже, поверх мобов.
    final base = Rect.fromLTWH(
      world.player.dx,
      world.player.dy,
      world.playerSize,
      world.playerSize,
    );
    final lift = world.jumpLift;
    final jumping = lift > 0.02;
    if (_isFiniteRect(base) && !jumping) {
      _paintPlayerShadow(canvas, base, lift: 0, preview: playerPreview);
    }

    // Тела мобов поверх всех напольных теней
    final enemyPaint = Paint()..color = danger;
    final enemyAura = Paint()..color = danger.withValues(alpha: 0.18);
    for (final e in world.enemies) {
      final rect = e.rect;
      if (!_isFiniteRect(rect)) continue;
      final er = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(er.inflate(3), enemyAura);
      canvas.drawRRect(er, enemyPaint);
    }

    // В прыжке тень игрока падает на мобов
    if (_isFiniteRect(base) && jumping) {
      _paintPlayerShadow(canvas, base, lift: lift, preview: playerPreview);
    }

    // Игрок
    if (_isFiniteRect(base)) {
      final scale = world.visualScale;
      final cx = base.center.dx;
      final cy = base.center.dy;
      final vis = world.playerSize * scale;
      final visualRect = Rect.fromCenter(
        center: Offset(cx, cy - lift * 8),
        width: vis,
        height: vis,
      );
      final pr = RRect.fromRectAndRadius(visualRect, const Radius.circular(4));
      final blink = invulnerable
          ? (0.22 + 0.78 * ((math.sin(frame * 1.35) + 1) * 0.5))
          : 1.0;
      final bodyAlpha = (playerPreview ? 0.38 : 1.0) * blink;

      canvas.drawRRect(
        pr.inflate(4),
        Paint()..color = accent.withValues(alpha: 0.2 * bodyAlpha),
      );
      canvas.drawRRect(
        pr,
        Paint()..color = accent.withValues(alpha: bodyAlpha),
      );
      if (hasHelmet) {
        canvas.drawRRect(
          pr.inflate(2.5),
          Paint()
            ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.95 * bodyAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawRRect(
          pr.inflate(5),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35 * bodyAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      final shine = vis * 0.18;
      if (shine > 0 && shine * 2 < vis) {
        canvas.drawRRect(
          pr.deflate(shine),
          Paint()..color = Colors.white.withValues(alpha: 0.2 * bodyAlpha),
        );
      }
    }

    // Рамка inset — не обрезается клипом
    final inset = (borderWidth / 2 + 0.5).clamp(0.5, 12.0);
    final frameW = size.width - inset * 2;
    final frameH = size.height - inset * 2;
    if (frameW > 1 && frameH > 1) {
      final frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, frameW, frameH),
        Radius.circular(math.max(0, r - inset)),
      );

      canvas.drawRRect(
        frame,
        Paint()
          ..color = borderColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth + 4,
      );
      canvas.drawRRect(
        frame,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }

    _drawCornerMarks(canvas, size, r, borderColor);

    for (final burst in impacts) {
      burst.paint(canvas);
    }
    for (final fx in world.nearMissFx) {
      fx.paint(canvas);
    }
  }

  bool _isFiniteRect(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.width.isFinite &&
        rect.height.isFinite &&
        rect.width >= 0 &&
        rect.height >= 0;
  }

  void _paintPlayerShadow(
    Canvas canvas,
    Rect base, {
    required double lift,
    required bool preview,
  }) {
    final scale = world.visualScale;
    final cx = base.center.dx;
    final cy = base.center.dy;
    final vis = world.playerSize * scale;
    final visualRect = Rect.fromCenter(
      center: Offset(cx, cy - lift * 8),
      width: vis,
      height: vis,
    );
    final pr = RRect.fromRectAndRadius(visualRect, const Radius.circular(4));
    final baseAlpha = (preview ? 0.22 : 0.4) * (1.0 - lift * 0.25);
    final shadowAlpha = _shadowAlpha(baseAlpha);

    canvas.drawRRect(
      pr.shift(Offset(5 + lift * 10, 6 + lift * 12)),
      Paint()..color = Colors.black.withValues(alpha: shadowAlpha),
    );
  }

  void _drawSoftGrid(Canvas canvas, Size size, double r) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.restore();
  }

  void _drawCornerMarks(
    Canvas canvas,
    Size size,
    double r,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const len = 16.0;
    final m = borderWidth + 6;
    final arc = math.max(2.0, r * 0.35);

    // Простые L-уголки без arcToPoint (безопаснее на эмуляторе)
    void corner(Offset a, Offset b, Offset c) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy),
        paint,
      );
    }

    corner(
      Offset(m, m + len),
      Offset(m, m),
      Offset(m + len, m),
    );
    corner(
      Offset(size.width - m - len, m),
      Offset(size.width - m, m),
      Offset(size.width - m, m + len),
    );
    corner(
      Offset(m, size.height - m - len),
      Offset(m, size.height - m),
      Offset(m + len, size.height - m),
    );
    corner(
      Offset(size.width - m - len, size.height - m),
      Offset(size.width - m, size.height - m),
      Offset(size.width - m, size.height - m - len),
    );

    // Небольшой скруглённый акцент у угла (опционально, только если r ок)
    if (arc >= 4) {
      final soft = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawArc(
        Rect.fromLTWH(m, m, arc * 2, arc * 2),
        math.pi,
        math.pi / 2,
        false,
        soft,
      );
      canvas.drawArc(
        Rect.fromLTWH(size.width - m - arc * 2, m, arc * 2, arc * 2),
        -math.pi / 2,
        math.pi / 2,
        false,
        soft,
      );
      canvas.drawArc(
        Rect.fromLTWH(m, size.height - m - arc * 2, arc * 2, arc * 2),
        math.pi / 2,
        math.pi / 2,
        false,
        soft,
      );
      canvas.drawArc(
        Rect.fromLTWH(
          size.width - m - arc * 2,
          size.height - m - arc * 2,
          arc * 2,
          arc * 2,
        ),
        0,
        math.pi / 2,
        false,
        soft,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GameFieldPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.world != world ||
        oldDelegate.accent != accent ||
        oldDelegate.danger != danger ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.playerPreview != playerPreview ||
        oldDelegate.impacts != impacts ||
        oldDelegate.hasHelmet != hasHelmet ||
        oldDelegate.invulnerable != invulnerable ||
        oldDelegate.shadowBrightness != shadowBrightness ||
        oldDelegate.fieldColor != fieldColor;
  }
}
