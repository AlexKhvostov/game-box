import 'package:flutter/material.dart';

/// Equal squares on a ground plane, projected with depth rather than stretched
/// into a fixed number of screen rows. Near cells remain close to square.
class TouchpadGrid {
  TouchpadGrid(this.size);
  final Size size;
  double get top => size.height * .04;
  double get bottom => size.height - 9;
  double get nearWidth => size.width - 6;
  int get columns => (nearWidth / 56).round().clamp(6, 16);
  double get cell => nearWidth / columns;
  static const farScale = .22;
  double get perspective => cell * (1 - farScale) / (bottom - top);
  double get depth => (1 / farScale - 1) / perspective;
  double rowY(double row) => bottom - cell * row / (1 + perspective * row);
}

/// A quiet perspective surface explains the gesture without restricting it.
class GameTouchpad extends StatelessWidget {
  const GameTouchpad({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('game-touchpad'),
    painter: const _TouchpadPainter(),
    child: const SizedBox.expand(),
  );
}

class _TouchpadPainter extends CustomPainter {
  const _TouchpadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = TouchpadGrid(size);
    final top = geometry.top;
    final bottom = geometry.bottom;
    final backLeft = size.width * .39;
    final backRight = size.width * .61;
    final frontLeft = 3.0;
    final frontRight = size.width - 3;
    Path surface(double offset) => Path()
      ..moveTo(backLeft, top + offset)
      ..lineTo(backRight, top + offset)
      ..lineTo(frontRight, bottom + offset)
      ..quadraticBezierTo(
        size.width / 2,
        bottom + 8 + offset,
        frontLeft,
        bottom + offset,
      )
      ..close();
    canvas.drawPath(surface(5), Paint()..color = const Color(0xFF071827));
    final face = surface(0);
    canvas.drawPath(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D2C43), Color(0xFF16415B)],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(face);
    final grid = Paint()
      ..color = const Color(0x2378BBD7)
      ..strokeWidth = 1;
    for (var i = 1; i < geometry.columns; i++) {
      final f = i / geometry.columns;
      canvas.drawLine(
        Offset(backLeft + (backRight - backLeft) * f, top),
        Offset(frontLeft + (frontRight - frontLeft) * f, bottom),
        grid,
      );
    }
    for (var row = 1; row < geometry.depth; row++) {
      final y = geometry.rowY(row.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.restore();
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x6678BBD7),
    );
    // The near edge is slightly brighter, like a shallow physical touch surface.
    canvas.drawLine(
      Offset(size.width * .24, bottom + 2),
      Offset(size.width * .76, bottom + 2),
      Paint()
        ..color = const Color(0x8878BBD7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TouchpadPainter oldDelegate) => false;
}
