import 'dart:math' as math;
import 'package:flutter/painting.dart';

abstract final class HelmetArtwork {
  static const dim = Color(0xFF4D879B);
  static const bright = Color(0xFFA4EFFF);
  static const flashDuration = .42;
  static const breakDuration = .4;

  static double flash(double remaining, {bool reducedMotion = false}) =>
      reducedMotion
      ? 0
      : math.sin(math.pi * (remaining / flashDuration).clamp(0.0, 1.0));

  static void paint(
    Canvas canvas,
    RRect body, {
    required double progress,
    required bool ready,
    double flash = 0,
    double opacity = 1,
  }) {
    final rim = body.inflate(2.5);
    final p = progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    if (ready) {
      paint
        ..color = Color.lerp(
          bright,
          const Color(0xFFEDFFFF),
          flash,
        )!.withValues(alpha: opacity)
        ..strokeWidth = 2.6 + .8 * flash;
      canvas.drawRRect(rim, paint);
      paint
        ..strokeWidth = 1.2
        ..color = bright.withValues(alpha: (.48 + .45 * flash) * opacity);
      canvas.drawRRect(body.inflate(5 + flash), paint);
      return;
    }
    // Dim unfinished track. It cannot be mistaken for the active double rim.
    paint
      ..strokeWidth = 1.2
      ..color = dim.withValues(alpha: .25 * opacity);
    canvas.drawRRect(rim, paint);
    if (p <= 0) return;
    final rect = rim.outerRect;
    final r = rim.tlRadiusX;
    final path = Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r))
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r))
      ..lineTo(rect.center.dx, rect.top);
    final metric = path.computeMetrics().first;
    paint
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = dim.withValues(alpha: opacity);
    canvas.drawPath(metric.extractPath(0, metric.length * p), paint);
  }
}

/// Only six short rim fragments; no full-field flash or particles/text glyphs.
class HelmetShatter {
  HelmetShatter(this.body);
  final Rect body;
  double age = 0;
  bool update(double dt) {
    age += dt;
    return age < HelmetArtwork.breakDuration;
  }

  void paint(Canvas canvas, {bool reducedMotion = false}) {
    final t = (age / HelmetArtwork.breakDuration).clamp(0.0, 1.0);
    if (t >= 1) return;
    final scale = body.width / 44;
    const pieces = [
      [-.48, -.48, -1.0, -1.0],
      [.48, -.48, 1.0, -1.0],
      [.48, .48, 1.0, 1.0],
      [-.48, .48, -1.0, 1.0],
      [-.55, 0.0, -1.0, 0.0],
      [.55, 0.0, 1.0, 0.0],
    ];
    final travel = (reducedMotion ? 1 : 2 + 7 * t) * scale;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = HelmetArtwork.bright.withValues(alpha: 1 - t);
    for (var i = 0; i < pieces.length; i++) {
      final q = pieces[i];
      canvas.save();
      canvas.translate(
        body.center.dx + q[0] * body.width + q[2] * travel,
        body.center.dy + q[1] * body.height + q[3] * travel,
      );
      canvas.rotate(
        (i < 4 ? i * math.pi / 2 : math.pi / 2) +
            (reducedMotion ? 0 : (i.isOdd ? 1 : -1) * t * .3),
      );
      final path = Path();
      if (i < 4) {
        path
          ..moveTo(0, 8 * scale)
          ..lineTo(0, 0)
          ..quadraticBezierTo(0, -2 * scale, 2 * scale, -2 * scale)
          ..lineTo(9 * scale, -2 * scale);
      } else {
        path
          ..moveTo(-4 * scale, 0)
          ..lineTo(4 * scale, 0);
      }
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
}
