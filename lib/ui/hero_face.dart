import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Artwork stays inside the body; movement and collision geometry are separate.
void paintHeroFace(
  Canvas canvas,
  Rect body, {
  double alpha = 1,
  double frame = 0,
  Offset look = Offset.zero,
  bool startled = false,
}) {
  final w = body.width;
  final h = body.height;
  if (alpha < .05 || w < 3) return;
  final ink = Paint()..color = const Color(0xFF122C38).withValues(alpha: alpha);
  final white = Paint()
    ..color = const Color(0xFFF4FFFF).withValues(alpha: alpha);
  final iris = Paint()
    ..color = const Color(0xFF179CB0).withValues(alpha: alpha);
  final stroke = Paint()
    ..color = ink.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * .035
    ..strokeCap = StrokeCap.round;
  final gaze = look.distance < .04
      ? Offset(math.sin(frame * .042) * .45, math.cos(frame * .031) * .25)
      : look;
  final blink = !startled && frame > 0 && frame % 230 < 5;
  for (final sign in [-1.0, 1.0]) {
    final center = Offset(body.center.dx + sign * w * .21, body.top + h * .39);
    if (blink) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: w * .2, height: h * .1),
        0,
        math.pi,
        false,
        stroke,
      );
      continue;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: w * .23,
        height: h * (startled ? .36 : .32),
      ),
      white,
    );
    final pupil =
        center +
        Offset(
          gaze.dx.clamp(-1.0, 1.0) * w * .035,
          gaze.dy.clamp(-1.0, 1.0) * h * .027,
        );
    canvas.drawOval(
      Rect.fromCenter(center: pupil, width: w * .15, height: h * .24),
      ink,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: pupil + Offset(0, h * .06),
        width: w * .125,
        height: h * .1,
      ),
      iris,
    );
    canvas.drawCircle(pupil + Offset(-w * .035, -h * .065), w * .038, white);
    canvas.drawCircle(pupil + Offset(w * .035, h * .04), w * .018, white);
  }
  final blush = Paint()
    ..color = const Color(0xFFFF89AD).withValues(alpha: alpha * .65);
  for (final sign in [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: body.center + Offset(sign * w * .29, h * .12),
        width: w * .13,
        height: h * .065,
      ),
      blush,
    );
  }
  if (startled) {
    for (final sign in [-1.0, 1.0]) {
      final x = body.center.dx + sign * w * .21;
      final eyebrow = Path()
        ..moveTo(x - w * .075, body.top + h * .17)
        ..quadraticBezierTo(
          x,
          body.top + h * .105,
          x + w * .075,
          body.top + h * .15,
        );
      canvas.drawPath(eyebrow, stroke);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(body.center.dx, body.top + h * .73),
        width: w * .13,
        height: h * .16,
      ),
      ink,
    );
  } else {
    final smile = Path()
      ..moveTo(body.center.dx - w * .1, body.top + h * .69)
      ..quadraticBezierTo(
        body.center.dx,
        body.top + h * .82,
        body.center.dx + w * .1,
        body.top + h * .69,
      );
    canvas.drawPath(smile, stroke);
  }
}
