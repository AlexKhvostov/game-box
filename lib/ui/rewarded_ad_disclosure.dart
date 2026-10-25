import 'package:flutter/material.dart';

/// The data summary stays visible before the single SDK launch action.
/// The complete explanation is available without starting an advertisement.
class RewardedAdDisclosure extends StatelessWidget {
  const RewardedAdDisclosure({super.key});
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Column(
      key: const ValueKey('rewarded-ad-disclosure'),
      children: [
        Text(
          ru
              ? 'Яндекс: данные соединения и устройства.'
              : 'Yandex: connection and device data.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFFA5CAE8)),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              ru ? '18+ · Добровольно · ' : '18+ · Optional · ',
              style: const TextStyle(fontSize: 10, color: Color(0xFFA5CAE8)),
            ),
            TextButton(
              key: const ValueKey('rewarded-ad-data-info'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: Text(ru ? 'О рекламе и данных' : 'Ads and data'),
                  content: SingleChildScrollView(
                    child: Text(
                      ru
                          ? '18+. Нажатие «Смотреть рекламу» выбирает одно видео за указанную награду. Согласие на обработку данных Яндексом запрашивается отдельно перед первым обращением к рекламному SDK. Выбор можно изменить в аккаунте. Геолокация Android и рекламный ID отключены.\n\nДосмотрите видео. Кнопки перехода и закрытия появляются не сразу. Вид рекламы может отличаться; иногда сразу появляется крестик. После завершения просмотра и закрытия вернитесь в игру за наградой.'
                          : '18+. Tapping “Watch ad” requests one video for the stated reward. Yandex data processing consent is requested separately before the first ads SDK request. Change it in Account. Android location and the advertising ID are disabled.\n\nWatch the full video. Continue and close buttons take time to appear. Ads can look different; some show the close button directly. Return to the game after completion and closing to receive your reward.',
                      key: const ValueKey('rewarded-ad-data-details'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(ru ? 'Понятно' : 'Got it'),
                    ),
                  ],
                ),
              ),
              child: Text(
                ru ? 'О рекламе и данных' : 'Ads and data',
                style: const TextStyle(
                  fontSize: 10,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
