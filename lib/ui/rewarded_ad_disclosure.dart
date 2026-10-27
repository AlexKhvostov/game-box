import 'package:flutter/material.dart';
import 'ad_privacy_settings.dart';

/// Compact notice beside E03's launch action; details never grant consent.
class RewardedAdDisclosure extends StatelessWidget {
  const RewardedAdDisclosure({super.key});
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Text.rich(
      key: const ValueKey('rewarded-ad-disclosure'),
      TextSpan(
        text: ru
            ? 'Нажимая кнопку «Смотреть рекламу», вы соглашаетесь на обработку данных Яндексом для рекламы. '
            : 'By tapping “Watch ad”, you consent to Yandex processing data for ads. ',
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: TextButton(
              key: const ValueKey('rewarded-ad-data-info'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: Text(ru ? 'О рекламе и данных' : 'Ads and data'),
                  content: SingleChildScrollView(
                    child: Text(
                      ru
                          ? 'Реклама доступна с 18 лет. Просмотр добровольный: одно видео за указанную награду.\n\nНажатие «Смотреть рекламу» в инструкции разрешает Яндексу обрабатывать технические данные для рекламы. Рекламный SDK передаёт IP-адрес, сведения о соединении и устройстве и доступные SDK идентификаторы. Они используются для показа и подбора рекламы, в том числе персонализированной, измерения её эффективности и защиты от накруток.\n\nГеолокация Android и рекламный ID отключены. Игра не передаёт рекламному SDK ваш ник, Google-аккаунт или результаты партий. Аналитика игры требует отдельного согласия.\n\nСогласие сохраняется на этом устройстве и относится к рекламным данным для всех форматов рекламы. Отозвать его можно в аккаунте: «Помощь и конфиденциальность» → «Данные для рекламы». После отзыва новые запросы рекламы блокируются. Чтобы завершить работу уже запущенного SDK, полностью закройте приложение. Повторное нажатие «Смотреть рекламу» в инструкции сохраняет новое согласие. Отказ не ограничивает игру, покупки и обычные бонусы.\n\nДосмотрите видео. Кнопки перехода и закрытия появляются не сразу. После завершения просмотра и закрытия вернитесь в игру за наградой.'
                          : 'Ads are available to adults 18+. Viewing is optional: one video for the stated reward.\n\nTapping “Watch ad” in the guide allows Yandex to process technical data for advertising. The ads SDK sends your IP address, connection and device information, and identifiers available to the SDK. These are used to serve and select ads, including personalized ads, measure effectiveness and prevent fraud.\n\nAndroid location and the advertising ID are disabled. The game does not send your nickname, Google account or round results to the ads SDK. Game analytics requires separate consent.\n\nConsent is saved on this device and covers advertising data for all ad formats. Withdraw it in Account: Help and privacy → Data for ads. Withdrawal blocks new ad requests; fully close the app to stop an already running SDK. Tapping “Watch ad” in the guide again saves new consent. Declining does not limit gameplay, purchases or regular bonuses.\n\nWatch the full video. Continue and close buttons take time to appear. Return to the game after completion and closing to receive your reward.',
                      key: const ValueKey('rewarded-ad-data-details'),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => openAdDataPolicy(dialog),
                      child: Text(
                        ru ? 'Политика Яндекса' : 'Yandex privacy policy',
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(ru ? 'Понятно' : 'Got it'),
                    ),
                  ],
                ),
              ),
              child: Text(
                ru ? 'ссылка' : 'link',
                semanticsLabel: ru
                    ? 'ссылка: О рекламе и данных'
                    : 'link: Ads and data',
                style: const TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        height: 1.3,
        color: Color(0xFFA5CAE8),
      ),
    );
  }
}
