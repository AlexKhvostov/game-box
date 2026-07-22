import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Отдыхающий кубик-игрок: устал и дремлет (плашка «нет жизней»).
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
    final cy = size.height / 2 + s * 0.04;

    // Подушка / место отдыха
    final pillow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.30),
        width: s * 0.72,
        height: s * 0.22,
      ),
      Radius.circular(s * 0.10),
    );
    canvas.drawRRect(
      pillow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7EE0FF).withValues(alpha: 0.35),
            const Color(0xFF3A5A70).withValues(alpha: 0.55),
          ],
        ).createShader(pillow.outerRect),
    );
    canvas.drawRRect(
      pillow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.02)
        ..color = const Color(0xFFB8F4FF).withValues(alpha: 0.35),
    );

    // Тень
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.36),
        width: s * 0.48,
        height: s * 0.08,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.translate(cx - s * 0.02, cy - s * 0.02);
    canvas.rotate(-0.22);

    final half = s * 0.26;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      Radius.circular(half * 0.22),
    );

    // Кубик игрока (тот же зелёный акцент)
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
    // Блик
    canvas.drawCircle(
      Offset(-half * 0.35, -half * 0.35),
      half * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Закрытые глаза (усталость)
    final eyePaint = Paint()
      ..color = const Color(0xFF0E1419)
      ..strokeWidth = math.max(1.8, s * 0.045)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-half * 0.38, -half * 0.02),
      Offset(-half * 0.12, -half * 0.08),
      eyePaint,
    );
    canvas.drawLine(
      Offset(half * 0.12, -half * 0.08),
      Offset(half * 0.38, -half * 0.02),
      eyePaint,
    );

    // Спокойная улыбка
    final smile = Path()
      ..moveTo(-half * 0.18, half * 0.26)
      ..quadraticBezierTo(0, half * 0.36, half * 0.18, half * 0.26);
    canvas.drawPath(smile, eyePaint);

    canvas.restore();

    // Капелька усталости
    final drop = Path()
      ..moveTo(cx + s * 0.22, cy - s * 0.08)
      ..quadraticBezierTo(
        cx + s * 0.30,
        cy + s * 0.02,
        cx + s * 0.22,
        cy + s * 0.10,
      )
      ..quadraticBezierTo(
        cx + s * 0.14,
        cy + s * 0.02,
        cx + s * 0.22,
        cy - s * 0.08,
      );
    canvas.drawPath(
      drop,
      Paint()..color = const Color(0xFF7EE0FF).withValues(alpha: 0.75),
    );

    // Zzz
    final zStyle = TextStyle(
      color: const Color(0xFF7EE0FF).withValues(alpha: 0.92),
      fontWeight: FontWeight.w900,
      height: 1,
    );
    final tp1 = TextPainter(
      text: TextSpan(text: 'z', style: zStyle.copyWith(fontSize: s * 0.13)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tp2 = TextPainter(
      text: TextSpan(text: 'z', style: zStyle.copyWith(fontSize: s * 0.17)),
      textDirection: TextDirection.ltr,
    )..layout();
    final tp3 = TextPainter(
      text: TextSpan(text: 'Z', style: zStyle.copyWith(fontSize: s * 0.21)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(cx + s * 0.16, cy - s * 0.42));
    tp2.paint(canvas, Offset(cx + s * 0.26, cy - s * 0.56));
    tp3.paint(canvas, Offset(cx + s * 0.36, cy - s * 0.72));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
