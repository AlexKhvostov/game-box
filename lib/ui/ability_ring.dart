import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_ui.dart';

class AbilityRingPainter extends CustomPainter {
  AbilityRingPainter({
    required this.active,
    this.broken = false,
    this.hideReady = false,
    this.progress,
    super.repaint,
  });
  final bool active;
  final bool broken;
  final bool hideReady;
  final double Function()? progress;
  Color get color => !active
      ? const Color(0xFF81949F)
      : broken
      ? GameUi.yellow
      : value < 1
      ? GameUi.cyan
      : GameUi.mint;
  double get value => progress?.call().clamp(0.0, 1.0) ?? 1.0;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 6) return;
    if (hideReady && !broken && (!active || value >= 1)) return;
    final circle = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 3,
    );
    final track = Paint()
      ..color = active ? const Color(0xFF426077) : color.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2, false, track);
    if (broken) {
      for (var segment = 0; segment < 5; segment++) {
        canvas.drawArc(
          circle,
          -math.pi / 2 + segment * math.pi * 2 / 5,
          math.pi * 2 / 5 - .22,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }
    if (value <= 0) return;
    if (active) {
      canvas.drawArc(
        circle,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..color = color.withValues(alpha: .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawArc(
      circle,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color.withValues(alpha: active ? .95 : .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    if (active && value < 1) {
      final angle = -math.pi / 2 + math.pi * 2 * value;
      canvas.drawCircle(
        circle.center +
            Offset(math.cos(angle), math.sin(angle)) * circle.width / 2,
        2.1,
        Paint()..color = GameUi.text,
      );
    }
  }

  @override
  bool shouldRepaint(AbilityRingPainter old) =>
      old.hideReady != hideReady ||
      old.progress != progress ||
      old.active != active ||
      old.broken != broken;
}
