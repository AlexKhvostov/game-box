import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Scoped translation of live-kit/updates-components.css. Other sheets keep
/// their established materials. All surfaces, symbols and text stay native.
class UpdateNeonSurface extends StatelessWidget {
  const UpdateNeonSurface({super.key, required this.child, this.radius = 17});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _UpdateSurfacePainter(radius),
    child: Padding(padding: const EdgeInsets.all(6), child: child),
  );
}

class _UpdateSurfacePainter extends CustomPainter {
  const _UpdateSurfacePainter(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(.5),
      Radius.circular(radius + 6),
    );
    final innerRect = rect.deflate(6);
    final inner = RRect.fromRectAndRadius(innerRect, Radius.circular(radius));
    canvas.drawRRect(outer, Paint()..color = const Color(0xFF03223B));
    canvas.drawRRect(
      outer,
      Paint()
        ..color = const Color(0x66009EFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..color = const Color(0xFF00DFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03213A), Color(0xFF00172A), Color(0xFF001E32)],
          stops: [0, .48, 1],
        ).createShader(innerRect),
    );
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawOval(
      innerRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.2, -.52),
          radius: .9,
          colors: [Color(0x3306405F), Color(0x0006405F)],
        ).createShader(innerRect),
    );
    final stars = Paint()..color = const Color(0x704BDFFF);
    for (var y = 24; y < size.height; y += 41) {
      for (var x = 12; x < size.width; x += 53) {
        final dx = ((x * 17 + y * 3) % 37).toDouble();
        final dy = ((x * 7 + y * 11) % 29).toDouble();
        canvas.drawCircle(Offset(x + dx, y + dy), .55, stars);
      }
    }
    canvas.drawRRect(
      inner,
      Paint()
        ..color = const Color(0x3000B9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..color = const Color(0xFF46ECFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_UpdateSurfacePainter oldDelegate) =>
      radius != oldDelegate.radius;
}

class UpdateNeonSeal extends StatelessWidget {
  const UpdateNeonSeal({
    super.key,
    required this.ready,
    required this.failed,
    this.size = 98,
  });
  final bool ready, failed;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = ready
        ? const Color(0xFFFFF36D)
        : failed
        ? const Color(0xFFFFD67C)
        : const Color(0xFFA6F8FF);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _UpdateSealPainter(ready, failed),
          child: Center(
            child: Text(
              ready
                  ? '✓'
                  : failed
                  ? '!'
                  : '↓',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: size * .59,
                height: 1,
                fontWeight: FontWeight.w400,
                color: color,
                shadows: [
                  Shadow(color: color.withValues(alpha: .7), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateSealPainter extends CustomPainter {
  const _UpdateSealPainter(this.ready, this.failed);
  final bool ready, failed;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        r = math.min(size.width, size.height) / 2;
    final edge = ready
        ? const Color(0xFFFFF278)
        : failed
        ? const Color(0xFFFFCE79)
        : const Color(0xFF75F2FF);
    final dark = ready
        ? const Color(0xFF60531C)
        : failed
        ? const Color(0xFF533D29)
        : const Color(0xFF033A4C);
    canvas.drawCircle(
      center,
      r + 1,
      Paint()
        ..color = edge.withValues(alpha: .4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      center,
      r + 5,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      r + 2,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: ready
              ? const [Color(0xFF46421B), Color(0xFF242700)]
              : failed
              ? const [Color(0xFF493525), Color(0xFF2A2632)]
              : const [Color(0xFF0B4259), Color(0xFF012337)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (!failed) {
      canvas.drawCircle(Offset(size.width - 1, 20), 2.5, Paint()..color = edge);
    }
  }

  @override
  bool shouldRepaint(_UpdateSealPainter oldDelegate) =>
      ready != oldDelegate.ready || failed != oldDelegate.failed;
}

class UpdateNeonButton extends StatelessWidget {
  const UpdateNeonButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF6EF5FF)),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF00C5F5),
          Color(0xFF008AD2),
          Color(0xFF0060A5),
          Color(0xFF003E74),
        ],
        stops: [0, .12, .7, 1],
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x6000BFFF), blurRadius: 12),
        BoxShadow(color: Color(0x5000CAFF), blurRadius: 3),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: 1,
          left: 5,
          right: 5,
          child: IgnorePointer(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x9CC8FFFF), Color(0x00C8FFFF)],
                ),
              ),
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('update-primary'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(53),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Color(0xFF003358),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}
