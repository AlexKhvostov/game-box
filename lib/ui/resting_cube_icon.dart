import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Отдыхающий кубик-игрок для кнопки «нет жизней».
class RestingCubeIcon extends StatelessWidget {
  const RestingCubeIcon({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RestingCubePainter()),
    );
  }
}

class _RestingCubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2 + s * 0.06;

    // Тень под кубом
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.32),
        width: s * 0.55,
        height: s * 0.12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.18);

    final half = s * 0.28;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      Radius.circular(half * 0.22),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5CE1A8), Color(0xFF2FB87A)],
        ).createShader(rect.outerRect),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.035)
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Закрытые глаза
    final eyePaint = Paint()
      ..color = const Color(0xFF0E1419)
      ..strokeWidth = math.max(1.8, s * 0.04)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-half * 0.35, -half * 0.05), Offset(-half * 0.12, -half * 0.05), eyePaint);
    canvas.drawLine(Offset(half * 0.12, -half * 0.05), Offset(half * 0.35, -half * 0.05), eyePaint);

    // Улыбка
    final smile = Path()
      ..moveTo(-half * 0.22, half * 0.22)
      ..quadraticBezierTo(0, half * 0.38, half * 0.22, half * 0.22);
    canvas.drawPath(smile, eyePaint);

    canvas.restore();

    // Zzz
    final zStyle = TextStyle(
      color: const Color(0xFF7EE0FF).withValues(alpha: 0.9),
      fontWeight: FontWeight.w900,
      fontSize: s * 0.16,
      height: 1,
    );
    final tp1 = TextPainter(
      text: TextSpan(text: 'z', style: zStyle.copyWith(fontSize: s * 0.14)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tp2 = TextPainter(
      text: TextSpan(text: 'z', style: zStyle.copyWith(fontSize: s * 0.18)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tp3 = TextPainter(
      text: TextSpan(text: 'Z', style: zStyle.copyWith(fontSize: s * 0.22)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(cx + s * 0.18, cy - s * 0.38));
    tp2.paint(canvas, Offset(cx + s * 0.28, cy - s * 0.52));
    tp3.paint(canvas, Offset(cx + s * 0.38, cy - s * 0.68));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
