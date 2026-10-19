import 'package:flutter/material.dart';

/// Visible in the normal rewarded path before the SDK can be requested.
/// The adjacent video button remains the single affirmative action.
class RewardedAdDisclosure extends StatelessWidget {
  const RewardedAdDisclosure({super.key});
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: const ValueKey('rewarded-ad-exit-hint'),
          children: [
            _AdExitStep(
              number: 1,
              close: false,
              title: ru
                  ? 'Досмотрите видео → нажмите ▶|'
                  : 'Finish the video → tap ▶|',
              detail: ru
                  ? 'Кнопка справа сверху откроет последний экран. Дождитесь её появления.'
                  : 'The top-right button opens the final screen. Wait until it appears.',
            ),
            const SizedBox(height: 8),
            _AdExitStep(
              number: 2,
              close: true,
              title: ru
                  ? 'На новом экране → нажмите ×'
                  : 'On the next screen → tap ×',
              detail: ru
                  ? 'Дождитесь крестика справа сверху. Он вернёт вас в игру с наградой.'
                  : 'Wait for the top-right close button. It returns you to the game with your reward.',
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          ru
              ? 'Примеры кнопок. Вид рекламы может отличаться; иногда сразу появляется ×.'
              : 'Example buttons. Ads can look different; some show × directly.',
          style: const TextStyle(
            fontSize: 10,
            height: 1.3,
            color: Color(0xFFA5CAE8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ru
              ? '18+. Для видео Яндекс получает данные соединения и доступные SDK идентификаторы устройства. Без персонализации и геолокации. Нажатие разрешает видео на сеанс.'
              : '18+. For video ads, Yandex receives connection data and device identifiers available to its SDK. No personalization or location tracking. Tapping requests video for this session.',
          key: const ValueKey('rewarded-ad-disclosure'),
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Color(0xFFA5CAE8),
          ),
        ),
      ],
    );
  }
}

class _AdExitStep extends StatelessWidget {
  const _AdExitStep({
    required this.number,
    required this.close,
    required this.title,
    required this.detail,
  });
  final int number;
  final bool close;
  final String title, detail;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF092C43),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF276278)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF54E9FF),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF002638),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE7FAFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Color(0xFFD8F1FF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: SizedBox(
                  width: 120,
                  height: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          right: 0,
                          top: -50,
                          width: 648,
                          height: 1387.2,
                          child: Image.asset(
                            'assets/branding/ui/rewarded-${close ? 'close' : 'next'}-example.png',
                            fit: BoxFit.fill,
                            cacheWidth: 648,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const Positioned.fill(
                          child: CustomPaint(painter: _AdButtonArrow()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A real SDK screenshot is clipped in the widget; the arrow lives only in this
/// instruction screen. Nothing is overlaid on or injected into a running ad.
class _AdButtonArrow extends CustomPainter {
  const _AdButtonArrow();
  @override
  void paint(Canvas canvas, Size size) {
    final target = Offset(size.width - 44, 34);
    final paint = Paint()
      ..color = const Color(0xFF54E9FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(target, 19, paint..strokeWidth = 1.5);
    final end = target + const Offset(-19, 14);
    canvas.drawPath(
      Path()
        ..moveTo(15, 58)
        ..quadraticBezierTo(30, 43, end.dx, end.dy),
      paint..strokeWidth = 2.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(end.dx - 9, end.dy - 2)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx - 2, end.dy + 9),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AdButtonArrow old) => false;
}
