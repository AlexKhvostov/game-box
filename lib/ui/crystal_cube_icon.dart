import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Иконка валюты: гранёный кристалл в форме куба.
class CrystalCubeIcon extends StatelessWidget {
  const CrystalCubeIcon({
    super.key,
    this.size = 28,
    this.glow = true,
  });

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrystalCubePainter(glow: glow),
      ),
    );
  }
}

class _CrystalCubePainter extends CustomPainter {
  _CrystalCubePainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = s * 0.38;

    if (glow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cx, cy), r * 1.15, glowPaint);
    }

    // Изометрический куб: top / left / right
    final top = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.86, cy - r * 0.35)
      ..lineTo(cx, cy + r * 0.15)
      ..lineTo(cx - r * 0.86, cy - r * 0.35)
      ..close();

    final left = Path()
      ..moveTo(cx - r * 0.86, cy - r * 0.35)
      ..lineTo(cx, cy + r * 0.15)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.86, cy + r * 0.45)
      ..close();

    final right = Path()
      ..moveTo(cx + r * 0.86, cy - r * 0.35)
      ..lineTo(cx, cy + r * 0.15)
      ..lineTo(cx, cy + r)
      ..lineTo(cx + r * 0.86, cy + r * 0.45)
      ..close();

    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FBFF), Color(0xFF7EE0FF)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
    canvas.drawPath(left, Paint()..color = const Color(0xFF2A9BB8));
    canvas.drawPath(right, Paint()..color = const Color(0xFF3DDC97));

    // Блик
    final shine = Path()
      ..moveTo(cx - r * 0.35, cy - r * 0.55)
      ..lineTo(cx - r * 0.05, cy - r * 0.75)
      ..lineTo(cx + r * 0.15, cy - r * 0.45)
      ..lineTo(cx - r * 0.15, cy - r * 0.35)
      ..close();
    canvas.drawPath(
      shine,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.04);
    canvas.drawPath(top, stroke);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
  }

  @override
  bool shouldRepaint(covariant _CrystalCubePainter oldDelegate) =>
      oldDelegate.glow != glow;
}
