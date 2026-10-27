import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/audience_policy.dart';
import 'game_ui.dart';
import 'neon_chrome.dart';

final _activeAdDataRequest = Expando<Future<bool>>();

Future<void> openAdDataPolicy(BuildContext context) async {
  try {
    await const MethodChannel(
      'untouch/adPrivacy',
    ).invokeMethod<void>('openPolicy');
  } catch (_) {
    if (!context.mounted) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ru ? 'Не удалось открыть браузер.' : 'Could not open browser.',
        ),
      ),
    );
  }
}

/// Eligible placements use a separate dialog unless E03's visible notice was
/// explicitly confirmed by its launch button. Startup and details cannot grant.
Future<bool> ensureAdDataConsent(
  BuildContext context, {
  bool confirmedInRewardedGuide = false,
}) async {
  final policy = context.read<AudiencePolicy?>();
  if (policy == null ||
      !AudiencePolicy.adsBuildEnabled ||
      !policy.isAdEligibleAge) {
    return false;
  }
  // Only E03's explicit launch button, beside the visible data notice, uses
  // this path. Opening the guide/details and automatic ads cannot grant consent.
  if (confirmedInRewardedGuide && policy.adDataConsent != true) {
    try {
      await policy.setAdDataConsent(true);
    } catch (_) {
      if (context.mounted) {
        final ru = Localizations.localeOf(context).languageCode == 'ru';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ru
                  ? 'Не удалось сохранить согласие. Повторите попытку.'
                  : 'Could not save your consent. Please try again.',
            ),
          ),
        );
      }
      return false;
    }
    return context.mounted && policy.adsEnabled;
  }
  if (policy.adDataConsent != null) return policy.adsEnabled;
  return _requestAdData(context, policy);
}

Future<bool> _requestAdData(
  BuildContext context,
  AudiencePolicy policy, {
  bool settings = false,
}) {
  final pending = _activeAdDataRequest[policy];
  if (pending != null) return pending;
  late final Future<bool> request;
  request = _showAdData(context, policy, settings: settings).whenComplete(() {
    if (identical(_activeAdDataRequest[policy], request)) {
      _activeAdDataRequest[policy] = null;
    }
  });
  _activeAdDataRequest[policy] = request;
  return request;
}

Future<bool> _showAdData(
  BuildContext context,
  AudiencePolicy policy, {
  required bool settings,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final revision = policy.adConsentRevision;
  final granted = policy.adDataConsent == true;
  final choice = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    animationStyle: GameUi.windowAnimationStyle,
    builder: (dialog) => Dialog(
      key: const ValueKey('ad-data-consent-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AccountGlass(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeonSheetHeader(
                title: ru ? 'Данные для рекламы' : 'Data for ads',
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    ru
                        ? 'Разрешить Яндексу обрабатывать технические данные для рекламы?\n\nРекламный SDK передаёт Яндексу IP-адрес, сведения о соединении и устройстве и доступные SDK идентификаторы. Они используются для показа и подбора рекламы, в том числе персонализированной, измерения её эффективности и защиты от накруток.\n\nГеолокация Android и рекламный ID отключены. Игра не передаёт рекламному SDK ваш ник, Google-аккаунт или результаты партий. Согласие на аналитику игры оформляется отдельно.\n\nВыбор сохранится на этом устройстве. Изменить его можно в аккаунте: «Помощь и конфиденциальность» → «Данные для рекламы». Отказ не ограничивает игру, покупки и обычные бонусы; SDK не запускается, поэтому реклама и награды за её просмотр будут недоступны. Отзыв останавливает новые запросы; чтобы завершить работу уже запущенного SDK, полностью закройте приложение.'
                        : 'Allow Yandex to process technical data for advertising?\n\nThe ads SDK sends Yandex your IP address, connection and device information, and identifiers available to the SDK. These are used to serve and select ads, including personalized ads, measure effectiveness and prevent fraud.\n\nAndroid location and the advertising ID are disabled. The game does not send your nickname, Google account or round results to the ads SDK. Game analytics consent is separate.\n\nYour choice is saved on this device. Change it in Account: Help and privacy → Data for ads. Declining does not limit gameplay, purchases or regular bonuses; the SDK does not start, so ads and rewards for watching them are unavailable. Withdrawal stops new requests; fully close the app to stop an already running SDK.',
                    style: const TextStyle(
                      color: GameUi.text,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => openAdDataPolicy(dialog),
                child: Text(ru ? 'Политика Яндекса' : 'Yandex privacy policy'),
              ),
              if (settings && granted) ...[
                FilledButton(
                  key: const ValueKey('ad-data-revoke'),
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(ru ? 'Отозвать согласие' : 'Withdraw consent'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: Text(ru ? 'Закрыть' : 'Close'),
                ),
              ] else ...[
                FilledButton(
                  key: const ValueKey('ad-data-allow'),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(
                    ru ? 'Разрешить обработку данных' : 'Allow data processing',
                  ),
                ),
                TextButton(
                  key: const ValueKey('ad-data-decline'),
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(ru ? 'Не разрешать' : 'Do not allow'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  if (!context.mounted ||
      !identical(context.read<AudiencePolicy?>(), policy) ||
      revision != policy.adConsentRevision ||
      !policy.isAdEligibleAge) {
    return false;
  }
  // Back/outside tap cannot grant consent; dismissed automatic requests do not repeat.
  if (choice == null && settings) return policy.adsEnabled;
  try {
    await policy.setAdDataConsent(choice == true);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ru
                ? 'Не удалось сохранить выбор. Новые запросы рекламы выключены.'
                : 'Could not save your choice. New ad requests are disabled.',
          ),
        ),
      );
    }
    return false;
  }
  return context.mounted && policy.adsEnabled;
}

/// A data control, with no global switch for ad impressions.
class AdPrivacySettings extends StatelessWidget {
  const AdPrivacySettings({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final policy = context.watch<AudiencePolicy?>();
    if (policy == null ||
        !policy.isAdEligibleAge ||
        !AudiencePolicy.adsBuildEnabled) {
      return const SizedBox.shrink();
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return TextButton(
      key: const ValueKey('ad-privacy-compact'),
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        foregroundColor: GameUi.text,
      ),
      onPressed: () => _requestAdData(context, policy, settings: true),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined, color: GameUi.cyan, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ru ? 'Данные для рекламы' : 'Data for ads',
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
                ),
                Text(
                  policy.adDataConsent == true
                      ? (ru ? 'Обработка разрешена' : 'Processing allowed')
                      : policy.adDataConsent == false
                      ? (ru ? 'Обработка не разрешена' : 'Processing declined')
                      : (ru
                            ? 'Выбор перед первой рекламой'
                            : 'Choose before the first ad'),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: GameUi.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: GameUi.cyan, size: 18),
        ],
      ),
    );
  }
}
