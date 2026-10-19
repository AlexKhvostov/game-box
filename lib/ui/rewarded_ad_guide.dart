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
      child: Icon(
        Icons.arrow_downward_rounded,
        size: 23,
        color: RewardedAdGuide.cyan,
      ),
    ),
  );
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
    canvas.drawCircle(clock, 26, Paint()..color = const Color(0x1800C9FF));
    canvas.drawCircle(clock, 26, ink);
    canvas.drawPath(
      Path()
        ..moveTo(67, 34)
        ..lineTo(67, 51)
        ..lineTo(79, 62),
      ink,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(100 + i * 8, 51), 2, Paint()..color = cyan);
    }
    canvas.drawPath(
      Path()
        ..moveTo(132, 52)
        ..lineTo(150, 52)
        ..moveTo(142, 44)
        ..lineTo(150, 52)
        ..lineTo(142, 60),
      ink..strokeWidth = 4,
    );

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
    canvas.drawPath(
      Path()
        ..moveTo(170, 7)
        ..lineTo(262, 7)
        ..quadraticBezierTo(287, 7, 287, 32)
        ..lineTo(287, 88),
      ink..strokeWidth = 2.6,
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
      ..moveTo(277, 91)
      ..lineTo(270, 84)
      ..lineTo(264, 72)
      ..quadraticBezierTo(262, 67, 265, 66)
      ..quadraticBezierTo(268, 65, 270, 69)
      ..lineTo(274, 77)
      ..lineTo(274, 73)
      ..quadraticBezierTo(277, 70, 280, 74)
      ..quadraticBezierTo(284, 71, 287, 76)
      ..quadraticBezierTo(292, 74, 294, 80)
      ..lineTo(298, 89)
      ..lineTo(291, 97)
      ..close();
    canvas.drawPath(hand, Paint()..color = const Color(0xFFF0FBFF));
    canvas.drawPath(hand, ink..strokeWidth = 1.5);
    canvas.drawCircle(const Offset(13, 15), 12, Paint()..color = cyan);
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
