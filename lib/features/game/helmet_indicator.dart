import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'helmet_artwork.dart';

/// Transparent HUD hit area, circular artwork and ring. No rectangular face.
class HelmetIndicator extends StatelessWidget {
  const HelmetIndicator({
    super.key,
    required this.equipped,
    required this.ru,
    required this.frame,
    required this.ready,
    required this.progress,
    required this.remainingMs,
    required this.cooling,
    required this.flash,
    this.onTap,
  });
  final bool equipped, ru;
  final Listenable frame;
  final bool Function() ready, cooling;
  final double Function() progress, remainingMs, flash;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: frame,
    child: ClipOval(
      child: Image.asset(
        'assets/branding/ui/simple-energy-helmet.png',
        width: 26,
        height: 26,
        fit: BoxFit.cover,
        cacheHeight: 104,
        excludeFromSemantics: true,
      ),
    ),
    builder: (context, artwork) {
      final active = equipped && ready();
      final text = !equipped
          ? (ru ? 'Выкл.' : 'Off')
          : active
          ? (ru ? 'Готов' : 'Ready')
          : cooling()
          ? '${(remainingMs() / 1000).toStringAsFixed(1).replaceAll('.', ru ? ',' : '.')} ${ru ? 'с' : 's'}'
          : (ru ? 'Разбит' : 'Spent');
      final color = active ? HelmetArtwork.bright : const Color(0xFF86AEBD);
      return Semantics(
        label: '${ru ? 'Шлем' : 'Helmet'}: $text',
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 72,
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CustomPaint(
                    key: const ValueKey('helmet-charge-ring'),
                    foregroundPainter: HelmetRingPainter(
                      equipped: equipped,
                      ready: active,
                      progress: progress(),
                      flash: flash(),
                    ),
                    child: Center(
                      child: Opacity(opacity: active ? 1 : .4, child: artwork),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      key: const ValueKey('helmet-charge-status'),
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class HelmetRingPainter extends CustomPainter {
  HelmetRingPainter({
    required this.equipped,
    required this.ready,
    required this.progress,
    required this.flash,
  });
  final bool equipped, ready;
  final double progress, flash;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF253F50);
    canvas.drawOval(rect, paint);
    if (!equipped || (!ready && progress <= 0)) return;
    paint
      ..color = ready
          ? Color.lerp(HelmetArtwork.bright, const Color(0xFFEDFFFF), flash)!
          : HelmetArtwork.dim
      ..strokeWidth = ready ? 2.4 + flash : 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (ready ? 1 : progress.clamp(0.0, 1.0)),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(HelmetRingPainter old) =>
      old.equipped != equipped ||
      old.ready != ready ||
      old.progress != progress ||
      old.flash != flash;
}
