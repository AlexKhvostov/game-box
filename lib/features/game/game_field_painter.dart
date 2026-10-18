import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/hero_face.dart';
import 'game_world.dart';
import 'impact_burst.dart';

abstract final class GameFieldColors {
  static const floor = Color(0xFF08253B);
  static const hero = Color(0xFF35F5C6);
  // Sampled from the enemies' front and lit faces in result-scene-v1.png.
  static const enemy = Color(0xFFF0363E);
  static const enemyHighlight = Color(0xFFFE837D);
  static const enemyShade = Color(0xFFDC2433);
  static const enemyEdge = Color(0xFFFFC8B9);
  static const wall = Color(0xFF58E2EC);
}

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
    this.invulnerableFactor,
    this.shadowBrightness = 1.0,
    this.drawBorder = true,
    this.drawGrid = false,
    this.eyeLook = Offset.zero,
    this.showFace = false,
    super.repaint,
    this.frameValue,
    this.invulnerableNow,
  });
  final int Function()? frameValue;
  final bool Function()? invulnerableNow;
  Size? _shaderSize;
  Shader? _backgroundShader;
  Path? _floorGrid;
  late final _gridPaint = Paint()
    ..color = borderColor.withValues(alpha: .1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .6;
  late final _heroFill = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(accent, Colors.white, .62)!,
        accent,
        Color.lerp(accent, const Color(0xFF007D74), .4)!,
      ],
      stops: const [0, .35, 1],
    ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
  final _enemyFills = <Size, Paint>{};

  final GameWorld world;
  final Color accent;
  final Color danger;
  final Color fieldColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;

  /// Меняется каждый тик — иначе CustomPaint не перерисует mutable world.
  final int frame;

  /// До первого касания: яркий герой с рамкой ожидания.
  final bool playerPreview;
  final List<ImpactBurst> impacts;

  /// Активный шлем (1 заряд) — обводка на кубе.
  final bool hasHelmet;

  /// Мигание после разрушения шлема — неуязвимость.
  final bool invulnerable;

  /// Если задан — множитель альфы при [invulnerable] (0…1), иначе sin(frame).
  final double? invulnerableFactor;

  /// >1 — тень светлее; <1 — темнее. Из RC `field.shadowBrightness`.
  final double shadowBrightness;

  /// false — рамку рисует вызывающий (дыры в стене этажей).
  final bool drawBorder;

  /// Mobile arena detail, independent of the configurable surface color.
  final bool drawGrid;

  /// Направление взгляда глаз (−1…1 по X/Y). Если почти ноль — лёгкий idle-взгляд.
  final Offset eyeLook;

  /// RC A/B: аниме-личико; false = просто квадрат без мордочки.
  final bool showFace;

  double _shadowAlpha(double base) {
    final b = shadowBrightness.clamp(0.4, 2.5);
    return (base / b).clamp(0.02, 0.85);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return;
    }

    // Paint bodies, effects, walls and shadows in the same world units.
    // Resizing the display never resizes or recreates the simulation.
    canvas.save();
    canvas.scale(
      size.width / world.field.width,
      size.height / world.field.height,
    );
    size = world.field;

    final r = math.min(cornerRadius, size.shortestSide / 2).clamp(0.0, 64.0);
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );

    // Фон
    if (_shaderSize != size) {
      _shaderSize = size;
      _backgroundShader = RadialGradient(
        center: const Alignment(0, -.2),
        radius: .85,
        colors: [
          Color.lerp(fieldColor, const Color(0xFF168899), .18)!,
          fieldColor,
        ],
      ).createShader(Offset.zero & size);
      // One cached path and one stroke for the entire arena grid.
      _floorGrid = Path();
      for (var i = 1; i < 12; i++) {
        final x = size.width * i / 12;
        final y = size.height * i / 12;
        _floorGrid!
          ..moveTo(x, 0)
          ..lineTo(x, size.height)
          ..moveTo(0, y)
          ..lineTo(size.width, y);
      }
    }
    canvas.drawRRect(outer, Paint()..shader = _backgroundShader);
    if (drawGrid || fieldColor == GameFieldColors.floor) {
      canvas.save();
      canvas.clipRRect(outer);
      canvas.drawPath(_floorGrid!, _gridPaint);
      canvas.restore();
    }

    // Лёгкая «глубина» без blur — полупрозрачный оверлей по краям через stroke
    canvas.drawRRect(
      outer,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.08,
    );

    // Слой «пола»: только тень по форме объекта (без овала).
    const light = Offset(5.5, 7.0);
    final enemyShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: _shadowAlpha(0.42));
    for (final e in world.enemies) {
      _paintEnemy(canvas, e, enemyShadowPaint, shift: light);
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
    if (_isFiniteRect(base) && !jumping && !playerPreview) {
      _paintPlayerShadow(canvas, base, lift: 0, preview: playerPreview);
    }

    // Тела мобов поверх всех напольных теней
    final enemyAura = Paint()..color = danger.withValues(alpha: 0.24);
    final collideFrame = world.config.enemiesCollide;
    final collideStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (final e in world.enemies) {
      _paintEnemy(canvas, e, enemyAura, inflate: 3);
      _paintEnemy(
        canvas,
        e,
        _enemyFills.putIfAbsent(
          Size(e.w, e.h),
          () => Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                danger == GameFieldColors.enemy
                    ? GameFieldColors.enemyHighlight
                    : Color.lerp(danger, Colors.white, .5)!,
                danger,
                danger,
                danger == GameFieldColors.enemy
                    ? GameFieldColors.enemyShade
                    : Color.lerp(danger, Colors.black, .28)!,
              ],
              stops: const [0, .22, .7, 1],
            ).createShader(Rect.fromLTWH(-e.w / 2, -e.h / 2, e.w, e.h)),
        ),
      );
      _paintEnemy(
        canvas,
        e,
        Paint()
          ..color = danger == GameFieldColors.enemy
              ? GameFieldColors.enemyEdge.withValues(alpha: .7)
              : const Color(0x99FFE6DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      // Рамочка = мобы сталкиваются; без рамки = проходят сквозь.
      if (collideFrame) {
        _paintEnemy(canvas, e, collideStroke, inflate: 1.2);
      }
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
      final blink = !(invulnerableNow?.call() ?? invulnerable)
          ? 1.0
          : (invulnerableFactor ??
                (0.22 +
                    0.78 *
                        ((math.sin((frameValue?.call() ?? frame) * 1.35) + 1) *
                            0.5)));
      final bodyAlpha = blink;

      canvas.drawRRect(
        pr.inflate(4),
        Paint()..color = accent.withValues(alpha: 0.2 * bodyAlpha),
      );
      // The shader is fixed in unit coordinates; only its transform and alpha
      // follow the hero. No gradient allocation on a moving game frame.
      _heroFill.color = Colors.white.withValues(alpha: bodyAlpha);
      canvas.save();
      canvas.translate(visualRect.left, visualRect.top);
      canvas.scale(vis, vis);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 1, 1),
          Radius.circular(4 / vis),
        ),
        _heroFill,
      );
      canvas.restore();
      if (hasHelmet) {
        canvas.drawRRect(
          pr.inflate(2.5),
          Paint()
            ..color = const Color(
              0xFF7EE0FF,
            ).withValues(alpha: 0.95 * bodyAlpha)
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
      canvas.drawRRect(
        pr.deflate(.7),
        Paint()
          ..color = const Color(0xFF8AFFCD).withValues(alpha: bodyAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(
        Offset(visualRect.left + vis * .17, visualRect.top + vis * .083),
        Offset(visualRect.right - vis * .17, visualRect.top + vis * .083),
        Paint()
          ..color = const Color(0xFFC4FFE3).withValues(alpha: .65 * bodyAlpha)
          ..strokeWidth = 1.2,
      );
      if (playerPreview) {
        canvas.drawRRect(
          pr.inflate(5),
          Paint()
            ..color = const Color(0x77B1FFD7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (showFace) {
        _paintPlayerFace(canvas, visualRect, bodyAlpha: bodyAlpha);
      }
    }

    if (drawBorder) {
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
    }

    for (final burst in impacts) {
      burst.paint(canvas);
    }
    for (final fx in world.nearMissFx) {
      fx.paint(canvas);
    }
    canvas.restore();
  }

  /// Милое аниме-личико в духе иконки приложения.
  void _paintPlayerFace(Canvas canvas, Rect body, {required double bodyAlpha}) {
    paintHeroFace(
      canvas,
      body,
      alpha: bodyAlpha,
      frame: (frameValue?.call() ?? frame).toDouble(),
      look: eyeLook == Offset.zero ? nearestEnemyLook(world) : eyeLook,
      startled: world.enemyAtRiskDistance,
    );
  }

  void _paintEnemy(
    Canvas canvas,
    EnemyBody e,
    Paint paint, {
    Offset shift = Offset.zero,
    double inflate = 0,
  }) {
    final body = Rect.fromCenter(center: Offset.zero, width: e.w, height: e.h);
    if (!_isFiniteRect(body)) return;
    final c = e.center + shift;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (e.orientDeg.abs() > 0.01) {
      canvas.rotate(e.orientDeg * math.pi / 180);
    }
    var r = RRect.fromRectAndRadius(body, const Radius.circular(3));
    if (inflate != 0) r = r.inflate(inflate);
    canvas.drawRRect(r, paint);
    canvas.restore();
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
        oldDelegate.invulnerableFactor != invulnerableFactor ||
        oldDelegate.drawBorder != drawBorder ||
        oldDelegate.drawGrid != drawGrid ||
        oldDelegate.shadowBrightness != shadowBrightness ||
        oldDelegate.fieldColor != fieldColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.eyeLook != eyeLook ||
        oldDelegate.showFace != showFace;
  }
}

Offset nearestEnemyLook(GameWorld world) {
  final center =
      world.player + Offset(world.playerSize / 2, world.playerSize / 2);
  Offset delta = Offset.zero;
  double nearest = double.infinity;
  for (final enemy in world.enemies) {
    final candidate = enemy.center - center;
    if (candidate.distanceSquared < nearest) {
      nearest = candidate.distanceSquared;
      delta = candidate;
    }
  }
  return delta.distance > .001 ? delta / delta.distance : Offset.zero;
}
