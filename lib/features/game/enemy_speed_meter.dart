import 'package:flutter/material.dart';
import '../../domain/enemy_pace.dart';

class EnemySpeedMeter extends StatelessWidget {
  const EnemySpeedMeter({super.key, required this.pace, required this.repaint});
  final EnemyPace? Function() pace;
  final Listenable repaint;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
      child: SizedBox(
        height: 9,
        width: 380,
        child: Semantics(
          label: ru ? 'Скорость врагов' : 'Enemy speed',
          child: CustomPaint(
            key: const ValueKey('enemy-speed-meter'),
            painter: EnemySpeedPainter(
              pace: pace,
              repaint: repaint,
              caption: ru ? 'скорость врагов' : 'enemy speed',
              reduced: MediaQuery.disableAnimationsOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class EnemySpeedPainter extends CustomPainter {
  EnemySpeedPainter({
    required this.pace,
    required Listenable repaint,
    required this.caption,
    this.reduced = false,
  }) : super(repaint: repaint);
  final EnemyPace? Function() pace;
  final String caption;
  final bool reduced;
  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    final p = pace();
    final bounds = Offset.zero & size,
        rim = RRect.fromRectAndRadius(bounds, const Radius.circular(5));
    c.save();
    c.clipRRect(rim);
    c.drawRect(bounds, Paint()..color = const Color(0xff071f31));
    final fraction = ((p?.target ?? 0) / 150).clamp(0.0, 1.0);
    c.drawRect(
      Rect.fromLTWH(0, 0, size.width * fraction, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffc1c0), Color(0xffff8c95)],
        ).createShader(bounds),
    );
    if (p != null && p.presses > 0) {
      final age = p.elapsed - p.lastPress,
          hold = reduced ? 0.1 : 0.11,
          fade = reduced ? 0.1 : 0.22;
      if (age >= 0 && age < hold + fade) {
        final t = age <= hold ? 1.0 : 1 - (age - hold) / fade,
            from = (p.after / 150).clamp(0.0, 1.0),
            to = (p.before / 150).clamp(0.0, 1.0);
        c.drawRect(
          Rect.fromLTWH(
            size.width * from,
            0,
            size.width * (to - from) * (reduced ? 1 : t),
            size.height,
          ),
          Paint()
            ..color = Color.lerp(
              const Color(0xffc5ffb3),
              const Color(0xff68e59d),
              .5,
            )!.withValues(alpha: t),
        );
      }
    }
    final text = TextPainter(
      text: TextSpan(
        text: caption,
        style: const TextStyle(
          fontSize: 7,
          height: 1,
          color: Color(0xfff0fbff),
          shadows: [
            Shadow(
              color: Color(0xff061b2d),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    text.paint(
      c,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
    c.restore();
    c.drawRRect(
      rim,
      Paint()
        ..color = const Color(0xff467785)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(EnemySpeedPainter old) =>
      old.pace != pace || old.caption != caption || old.reduced != reduced;
}
