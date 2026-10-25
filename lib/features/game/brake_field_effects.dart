import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/enemy_pace.dart';
import 'game_world.dart';

// The same top-down snail and field palette as the approved UI-kit component.
final _body = Path()
  ..moveTo(23, 63)
  ..lineTo(44, 63)
  ..cubicTo(54, 63, 61, 59, 62, 49)
  ..lineTo(63, 39)
  ..cubicTo(63.4, 33, 72, 32, 74, 38)
  ..cubicTo(78, 51, 70, 67, 57, 70)
  ..lineTo(23, 70)
  ..cubicTo(15, 70, 15, 63, 23, 63)
  ..close();
final _spiral = Path()
  ..moveTo(39, 60)
  ..cubicTo(24, 60, 20, 43, 30, 36)
  ..cubicTo(39, 29, 51, 37, 48, 46)
  ..cubicTo(46, 53, 36, 54, 34, 48)
  ..cubicTo(33, 44, 38, 41, 41, 44);
final _antenna = Path()
  ..moveTo(65, 34)
  ..lineTo(62, 25)
  ..moveTo(71, 34)
  ..lineTo(76, 24);
final _rim = Path()
  ..moveTo(50, 8)
  ..lineTo(80, 8)
  ..quadraticBezierTo(92, 8, 92, 20)
  ..lineTo(92, 80)
  ..quadraticBezierTo(92, 92, 80, 92)
  ..lineTo(20, 92)
  ..quadraticBezierTo(8, 92, 8, 80)
  ..lineTo(8, 20)
  ..quadraticBezierTo(8, 8, 20, 8)
  ..close();
final _rimMetric = _rim.computeMetrics().first;
final _face = RRect.fromRectAndRadius(
  const Rect.fromLTWH(8, 8, 84, 84),
  const Radius.circular(12),
);
final _empty = const LinearGradient(
  colors: [Color(0xff0b293b), Color(0xff071f31)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
).createShader(const Rect.fromLTWH(8, 8, 84, 84));
final _charging = const LinearGradient(
  colors: [Color(0xff153b4d), Color(0xff0c2b3f)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
).createShader(const Rect.fromLTWH(8, 8, 84, 84));
final _charged = const LinearGradient(
  colors: [Color(0xff1c4857), Color(0xff0d2e40)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
).createShader(const Rect.fromLTWH(8, 8, 84, 84));

void paintBrakeField(
  Canvas c,
  EnemyPace? p,
  double size, {
  required bool playing,
  required bool reduced,
}) {
  if (p == null || !p.brakeEnabled) return;
  final age = p.presses == 0 ? -1.0 : (p.elapsed - p.lastPress) * 1000;
  final pressing = playing && age >= 0 && age < 120, ready = p.ready;
  final opacity = pressing ? 1 - age / 120 : p.charge,
      q = pressing ? 1.0 : p.charge;
  if (opacity > 0) {
    c.save();
    c.translate(190 - size / 2, 190 - size / 2);
    c.scale(size / 100);
    // A fully charged plate is opaque. Avoid an offscreen render pass every
    // frame while ready; preserve group opacity throughout charging/pressing.
    if (opacity < 1) {
      c.saveLayer(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    } else {
      c.save();
    }
    if (ready) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 16, 84, 80),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0x70000000),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 12, 84, 82),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xff092331),
      );
    }
    c.translate(
      0,
      pressing
          ? 2
          : ready
          ? -4
          : 0,
    );
    c.drawRRect(_face, Paint()..shader = _empty);
    if (q > 0) {
      c.save();
      c.clipRRect(_face);
      final sector = Path()
        ..moveTo(50, 50)
        ..arcTo(
          const Rect.fromLTWH(-22, -22, 144, 144),
          -math.pi / 2,
          math.pi * 2 * q,
          false,
        )
        ..close();
      c.drawPath(sector, Paint()..shader = ready ? _charged : _charging);
      c.restore();
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ready ? const Color(0xff9bc8ad) : const Color(0xff5e7985);
    c.drawPath(_rim, stroke);
    stroke.color = ready ? const Color(0xffbde9cb) : const Color(0xff8ea9b1);
    c.drawPath(_rimMetric.extractPath(0, _rimMetric.length * q), stroke);
    final readyAge = (p.elapsed - p.readyAt) * 1000;
    if (ready && readyAge < 320 && !reduced) {
      final alpha = math.sin(readyAge / 320 * math.pi) * .36;
      c.drawRRect(
        _face,
        Paint()
          ..color = const Color(
            0xffb9ffd5,
          ).withValues(alpha: alpha.clamp(0, 1)),
      );
    }
    final fill = Paint()
      ..color = ready || pressing
          ? const Color(0xffe7f5ef)
          : const Color(0xff96a1a6).withValues(alpha: .72);
    stroke
      ..color = ready
          ? const Color(0xff31515b)
          : const Color(0xff50616c).withValues(alpha: .72)
      ..strokeWidth = 3.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(_body, fill);
    c.drawPath(_body, stroke);
    c.drawCircle(const Offset(39, 47), 18, fill);
    c.drawCircle(const Offset(39, 47), 18, stroke);
    stroke.color = ready
        ? const Color(0xff234c59)
        : const Color(0xff50616c).withValues(alpha: .72);
    c.drawPath(_spiral, stroke);
    c.drawPath(_antenna, stroke);
    c.drawCircle(const Offset(62, 23), 1.5, fill);
    c.drawCircle(const Offset(77, 22), 1.5, fill);
    c.restore();
    c.restore();
  }
  if (!playing || age < 0 || age > 840) {
    return;
  }
  final wave = Paint()..style = PaintingStyle.stroke;
  for (var i = 0; i < (reduced ? 1 : 3); i++) {
    final t = (age - i * 80) / 680;
    if (t < 0 || t > 1) continue;
    wave
      ..color = const Color(0xffb0f6d1).withValues(alpha: (1 - t) * .5)
      ..strokeWidth = 2 * (1 - t) + .5;
    c.drawCircle(const Offset(190, 190), reduced ? 30 : 12 + 270 * t, wave);
  }
}

void paintBrakeEnemyHit(
  Canvas c,
  EnemyPace? p,
  EnemyBody e, {
  required bool playing,
  required bool reduced,
}) {
  if (p == null || !p.brakeEnabled || !playing || reduced || p.presses == 0) {
    return;
  }
  final age = (p.elapsed - p.lastPress) * 1000;
  if (age < 0 || age > 680) return;
  final radius = 12 + 270 * age / 680,
      d = (e.rect.center - const Offset(190, 190)).distance;
  if (radius < d || radius > d + 55) return;
  c.save();
  c.translate(e.rect.center.dx, e.rect.center.dy);
  c.rotate(e.orientDeg * math.pi / 180);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-e.w / 2 - 1, -e.h / 2 - 1, e.w + 2, e.h + 2),
      const Radius.circular(4),
    ),
    Paint()
      ..color = const Color(
        0xffc4ffe0,
      ).withValues(alpha: (1 - (radius - d) / 55) * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8,
  );
  c.restore();
}
