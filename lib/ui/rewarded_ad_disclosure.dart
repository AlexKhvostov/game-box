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
        Text(
          ru
              ? 'После видео нажмите ▶| справа сверху, если он появился. На последней карточке дождитесь × и закройте рекламу — энергия поступит после возврата в игру.'
              : 'After the video, tap ▶| at the top right if shown. On the final card, wait for × and close the ad. Energy arrives when you return to the game.',
          key: const ValueKey('rewarded-ad-exit-hint'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFFD8F1FF),
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
