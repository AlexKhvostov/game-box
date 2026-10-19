import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'energy_widgets.dart';

/// Untouch UIKit E03: wait -> next screen -> wait -> close -> reward.
/// Illustrations are schematic, never controls over the advertising SDK.
class RewardedAdGuide extends StatelessWidget {
  const RewardedAdGuide({super.key, required this.reward});
  final int reward;
  static const cyan = Color(0xFF54E9FF);

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Column(
      key: const ValueKey('rewarded-ad-exit-hint'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            ru ? 'Досмотрите рекламу' : 'Watch the whole ad',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF0FBFF),
            ),
          ),
        ),
        _GuideStep(
          number: 1,
          wait: ru ? 'Подождите' : 'Wait',
          action: ru ? 'Перейдите' : 'Continue',
        ),
        const _FlowArrow(),
        _GuideStep(
          number: 2,
          wait: ru ? 'Ещё немного' : 'Wait a little',
          action: ru ? 'Закройте' : 'Close',
        ),
        const _FlowArrow(),
        Column(
          key: const ValueKey('rewarded-guide-reward'),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF092C43),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFFFEE73), width: 1.6),
                boxShadow: const [
                  BoxShadow(color: Color(0x33FFEE73), blurRadius: 13),
                ],
              ),
              child: EnergyText(reward, prefix: '+', size: 38),
            ),
            const SizedBox(height: 3),
            Text(
              ru ? 'Бонус ваш!' : 'Your bonus!',
              style: const TextStyle(
                color: Color(0xFFFFEE73),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.wait,
    required this.action,
  });
  final int number;
  final String wait, action;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$number. $wait. $action.',
    child: Container(
      key: ValueKey('rewarded-guide-step-$number'),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07364D), Color(0xFF002033)],
        ),
        border: Border.all(color: const Color(0xFF13708C), width: 1.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final height = (box.maxWidth * .32).clamp(72.0, 100.0);
          return Column(
            children: [
              ExcludeSemantics(
                child: RepaintBoundary(
                  child: SizedBox(
                    height: height,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _StepIllustration(
                        close: number == 2,
                        number: number,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wait,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0FBFF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 25),
                  Expanded(
                    child: Text(
                      action,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0FBFF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();
  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      height: 20,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 20,
          child: CustomPaint(painter: _FlowArrowPainter()),
        ),
      ),
    ),
  );
}

class _FlowArrowPainter extends CustomPainter {
  const _FlowArrowPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      _paintGuideArrow(canvas, Offset.zero & size, down: true);
  @override
  bool shouldRepaint(_FlowArrowPainter old) => false;
}

// The same rounded silhouette and three-tone fill are used by the UIKit SVG.
void _paintGuideArrow(Canvas canvas, Rect bounds, {bool down = false}) {
  canvas.save();
  if (down) {
    canvas.translate(bounds.right, bounds.top);
    canvas.rotate(math.pi / 2);
    canvas.scale(bounds.height / 48, bounds.width / 36);
  } else {
    canvas.translate(bounds.left, bounds.top);
    canvas.scale(bounds.width / 48, bounds.height / 36);
  }
  final shape = Path()
    ..moveTo(5, 14)
    ..lineTo(28, 14)
    ..lineTo(28, 7)
    ..quadraticBezierTo(28, 4, 30.5, 5.5)
    ..lineTo(43, 16)
    ..quadraticBezierTo(45, 18, 43, 20)
    ..lineTo(30.5, 30.5)
    ..quadraticBezierTo(28, 32, 28, 29)
    ..lineTo(28, 22)
    ..lineTo(5, 22)
    ..cubicTo(-.3, 22, -.3, 14, 5, 14)
    ..close();
  canvas.drawPath(
    shape,
    Paint()
      ..color = const Color(0x7054E9FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawPath(
    shape.shift(const Offset(0, 1.3)),
    Paint()..color = const Color(0xFF00668E),
  );
  canvas.drawPath(
    shape,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFAAFAFF), Color(0xFF54E9FF), Color(0xFF13B6E6)],
        stops: [0, .4, 1],
      ).createShader(const Rect.fromLTWH(0, 4, 48, 29)),
  );
  canvas.drawPath(
    shape,
    Paint()
      ..color = const Color(0x889DFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.restore();
}

class _StepIllustration extends CustomPainter {
  const _StepIllustration({required this.close, required this.number});
  final bool close;
  final int number;
  @override
  void paint(Canvas canvas, Size size) {
    // A normalized canvas keeps corner, clock and pointer proportions identical
    // across phone widths; text remains real accessible Flutter text below it.
    canvas.save();
    canvas.scale(size.width / 300, size.height / 100);
    const cyan = RewardedAdGuide.cyan;
    final ink = Paint()
      ..color = cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final clock = const Offset(67, 52);
    canvas.drawCircle(
      clock,
      26,
      Paint()
        ..color = const Color(0x5054E9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      clock,
      26,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF06455D), Color(0xFF002237)],
        ).createShader(Rect.fromCircle(center: clock, radius: 26)),
    );
    canvas.drawCircle(
      clock,
      26,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB5FDFF), cyan, Color(0xFF159AC5)],
        ).createShader(Rect.fromCircle(center: clock, radius: 26))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(67, 34)
        ..lineTo(67, 51)
        ..lineTo(79, 62),
      ink,
    );
    if (close) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(100 + i * 8, 51),
          1.9,
          Paint()..color = cyan.withValues(alpha: 1 - i * .18),
        );
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(100, 35)
          ..lineTo(104, 32)
          ..moveTo(103, 45)
          ..lineTo(109, 45)
          ..moveTo(100, 55)
          ..lineTo(104, 58),
        ink..strokeWidth = 2.7,
      );
    }
    _paintGuideArrow(canvas, const Rect.fromLTWH(125, 39, 34, 27));

    // Only the top-right corner is visible. No advertising copy or brand art.
    const phone = Rect.fromLTWH(164, 7, 123, 83);
    final screen = RRect.fromRectAndCorners(
      phone,
      topRight: const Radius.circular(23),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0013191F), Color(0xFF11161C)],
          stops: [0, .65],
        ).createShader(phone),
    );
    final phoneEdge = Path()
      ..moveTo(170, 7)
      ..lineTo(262, 7)
      ..quadraticBezierTo(287, 7, 287, 32)
      ..lineTo(287, 88);
    canvas.drawPath(
      phoneEdge,
      Paint()
        ..color = const Color(0x6054E9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      phoneEdge,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0054E9FF), Color(0xFFA5F8FF), cyan],
          stops: [0, .5, 1],
        ).createShader(phone)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final status = Paint()
      ..color = const Color(0xFF747B80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(253, 18, 19, 8),
        const Radius.circular(2),
      ),
      status,
    );
    canvas.drawRect(
      const Rect.fromLTWH(272, 20, 2, 4),
      Paint()..color = const Color(0xFF747B80),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(230 + i * 4, 26),
        Offset(230 + i * 4, 23 - i * 2),
        status..strokeWidth = 2,
      );
    }
    const control = Offset(255, 57);
    final buttonRect = Rect.fromCircle(center: control, radius: 20);
    canvas.drawCircle(
      control + const Offset(0, 1),
      22,
      Paint()..color = const Color(0xB3000000),
    );
    canvas.drawCircle(
      control,
      20,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF45484A), Color(0xFF191B1D)],
        ).createShader(buttonRect),
    );
    canvas.drawCircle(
      control,
      20,
      Paint()
        ..color = const Color(0xFF53585A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final symbol = Paint()
      ..color = const Color(0xFFE2E5E6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (close) {
      canvas.drawPath(
        Path()
          ..moveTo(248, 50)
          ..lineTo(262, 64)
          ..moveTo(262, 50)
          ..lineTo(248, 64),
        symbol,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(248, 48)
          ..lineTo(248, 66)
          ..lineTo(259, 57)
          ..close(),
        Paint()..color = const Color(0xFFE2E5E6),
      );
      canvas.drawLine(const Offset(263, 49), const Offset(263, 65), symbol);
    }
    canvas.drawPath(
      Path()
        ..moveTo(275, 36)
        ..lineTo(281, 30)
        ..moveTo(271, 30)
        ..lineTo(273, 23),
      ink..strokeWidth = 3,
    );
    // Small schematic hand: finger points at the lower-right edge of the button.
    final hand = Path()
      ..moveTo(279, 92)
      ..quadraticBezierTo(274, 92, 271, 86)
      ..lineTo(262, 69)
      ..cubicTo(260, 65, 261, 62, 264, 62)
      ..cubicTo(267, 62, 268, 64, 270, 68)
      ..lineTo(277, 80)
      ..lineTo(275, 76)
      ..cubicTo(274, 73, 278, 71, 281, 75)
      ..lineTo(284, 81)
      ..lineTo(282, 78)
      ..cubicTo(281, 75, 285, 74, 288, 78)
      ..lineTo(291, 84)
      ..lineTo(290, 82)
      ..cubicTo(289, 79, 293, 79, 295, 83)
      ..lineTo(298, 90)
      ..quadraticBezierTo(300, 94, 295, 96)
      ..lineTo(289, 98)
      ..quadraticBezierTo(284, 100, 279, 94)
      ..close();
    canvas.drawPath(
      hand,
      Paint()
        ..color = const Color(0x5054E9FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.3),
    );
    canvas.drawPath(
      hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFD4F4FF)],
        ).createShader(const Rect.fromLTWH(261, 64, 38, 35)),
    );
    canvas.drawPath(hand, ink..strokeWidth = 1.2);
    canvas.drawPath(
      Path()
        ..moveTo(274, 75)
        ..lineTo(278, 82)
        ..moveTo(282, 80)
        ..lineTo(285, 81)
        ..moveTo(289, 83)
        ..lineTo(292, 88),
      Paint()
        ..color = const Color(0x886CCDE3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(13, 15),
      12,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9AFBFF), cyan, Color(0xFF12BCDE)],
        ).createShader(const Rect.fromLTWH(1, 3, 24, 24)),
    );
    final numberText = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF002638),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numberText.paint(
      canvas,
      Offset(13 - numberText.width / 2, 15 - numberText.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StepIllustration old) =>
      old.close != close || old.number != number;
}
