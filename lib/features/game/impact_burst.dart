import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Короткий «аниме»-удар: цветные # / ※ / ✕ разлетаются из точки контакта.
class ImpactBurst {
  ImpactBurst._({
    required this.origin,
    required List<_ImpactGlyph> this._glyphs,
    required this.flashColor,
  });

  factory ImpactBurst.spawn({
    required Offset origin,
    required Color accent,
    required Color danger,
    required bool againstWall,
    math.Random? rng,
  }) {
    final r = rng ?? math.Random();
    final palette = againstWall
        ? <Color>[
            accent,
            const Color(0xFF5CE1FF),
            const Color(0xFFFFFFFF),
            const Color(0xFFFFE566),
            const Color(0xFFB8F2FF),
          ]
        : <Color>[
            danger,
            const Color(0xFFFF3D7F),
            const Color(0xFFFFE566),
            const Color(0xFFFFFFFF),
            accent,
            const Color(0xFFFF8A5B),
          ];
    const marks = <String>['#', '#', '#', '※', '✕', '✦'];
    final glyphs = <_ImpactGlyph>[];
    final count = 11 + r.nextInt(4);
    for (var i = 0; i < count; i++) {
      final ang = (i / count) * math.pi * 2 + r.nextDouble() * 0.35;
      final speed = 90 + r.nextDouble() * 160;
      glyphs.add(
        _ImpactGlyph(
          pos: origin,
          vel: Offset(math.cos(ang), math.sin(ang)) * speed,
          rot: r.nextDouble() * math.pi,
          rotVel: (r.nextDouble() - 0.5) * 10,
          life: 0.38 + r.nextDouble() * 0.22,
          size: 14 + r.nextDouble() * 18,
          color: palette[r.nextInt(palette.length)],
          mark: marks[r.nextInt(marks.length)],
        ),
      );
    }
    return ImpactBurst._(
      origin: origin,
      glyphs: glyphs,
      flashColor: againstWall ? accent : danger,
    );
  }

  final Offset origin;
  final List<_ImpactGlyph> _glyphs;
  final Color flashColor;
  double age = 0;

  bool get alive => age < 0.55 || _glyphs.any((g) => g.life > 0);

  /// Обновляет частицы. Возвращает true, пока эффект ещё виден.
  bool update(double dt) {
    age += dt;
    for (final g in _glyphs) {
      if (g.life <= 0) continue;
      g.life -= dt;
      g.pos += g.vel * dt;
      g.vel *= math.pow(0.08, dt).toDouble(); // быстрое торможение
      g.rot += g.rotVel * dt;
    }
    return alive;
  }

  void paint(Canvas canvas) {
    // Вспышка-кольцо
    final t = (age / 0.28).clamp(0.0, 1.0);
    final ringR = 8 + t * 42;
    final ringA = (1.0 - t) * 0.85;
    if (ringA > 0.02) {
      canvas.drawCircle(
        origin,
        ringR,
        Paint()
          ..color = flashColor.withValues(alpha: ringA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1.0 - t * 0.6),
      );
      canvas.drawCircle(
        origin,
        ringR * 0.45,
        Paint()..color = Colors.white.withValues(alpha: ringA * 0.55),
      );
    }

    // Лучи скорости
    if (age < 0.22) {
      final la = (1.0 - age / 0.22) * 0.55;
      final line = Paint()
        ..color = Colors.white.withValues(alpha: la)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = (i / 8) * math.pi * 2 + age * 2;
        final inner = 10.0 + age * 40;
        final outer = 28.0 + age * 90;
        canvas.drawLine(
          origin + Offset(math.cos(a), math.sin(a)) * inner,
          origin + Offset(math.cos(a), math.sin(a)) * outer,
          line,
        );
      }
    }

    for (final g in _glyphs) {
      if (g.life <= 0) continue;
      final fade = (g.life / 0.45).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: g.mark,
          style: TextStyle(
            color: g.color.withValues(alpha: fade),
            fontSize: g.size * (0.85 + (1 - fade) * 0.35),
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: [
              Shadow(
                color: g.color.withValues(alpha: fade * 0.7),
                blurRadius: 0,
                offset: const Offset(1.2, 1.2),
              ),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(g.pos.dx, g.pos.dy);
      canvas.rotate(g.rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

class _ImpactGlyph {
  _ImpactGlyph({
    required this.pos,
    required this.vel,
    required this.rot,
    required this.rotVel,
    required this.life,
    required this.size,
    required this.color,
    required this.mark,
  });

  Offset pos;
  Offset vel;
  double rot;
  double rotVel;
  double life;
  final double size;
  final Color color;
  final String mark;
}
