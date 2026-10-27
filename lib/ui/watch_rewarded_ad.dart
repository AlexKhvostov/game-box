import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ads_service.dart';
import '../data/audience_policy.dart';
import '../data/economy_store.dart';
import '../l10n/app_localizations.dart';
import 'game_toast.dart';
import 'audience_gate.dart';
import 'ad_privacy_settings.dart';
import 'test_service_preview.dart';

Future<void> watchRewardedAd(
  BuildContext context, {
  Future<void> Function(int reward)? onReward,
}) async {
  if (!context.read<EconomyStore>().advertising.rewardedEnabled) return;
  if (!context.read<EconomyStore>().canClaimWatchAd) return;
  final ads = context.read<AdsService?>();
  if (ads != null &&
      AudiencePolicy.adsBuildEnabled &&
      ads.audience.isAdEligibleAge) {
    if (!await ensureAdDataConsent(context) || !context.mounted) return;
  }
  if (ads == null || !ads.available) {
    if (testServicePreviewActive(context)) {
      await showTestServiceUnavailable(
        context,
        service: TestService.video,
        amount: context.read<EconomyStore>().energyConfig.reward('watch_ad'),
      );
    } else {
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      final policy = ads?.audience;
      final message = !AudiencePolicy.adsBuildEnabled || ads == null
          ? (ru
                ? 'Реклама отключена в этой сборке.'
                : 'Ads are disabled in this build.')
          : policy!.adDataConsent == false
          ? (ru
                ? 'Обработка рекламных данных не разрешена. Изменить выбор можно в аккаунте.'
                : 'Advertising data processing was declined. Change your choice in Account.')
          : policy.needsSelection
          ? (ru
                ? 'Укажите возраст в профиле, чтобы смотреть рекламу.'
                : 'Set your age in Profile to watch ads.')
          : (ru
                ? 'Реклама доступна пользователям 18+.'
                : 'Ads are available to adults 18+.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return;
  }
  return runResourceAction(
    context,
    context.read<EconomyStore>(),
    'watch-ad',
    () => _watchRewardedAd(context, onReward: onReward),
  );
}

Future<void> _watchRewardedAd(
  BuildContext context, {
  Future<void> Function(int reward)? onReward,
}) async {
  final ads = context.read<AdsService>();
  final economy = context.read<EconomyStore>();
  if (!economy.canClaimWatchAd) return;
  final route = ModalRoute.of(context);
  final result = await ads.watchAndClaim(
    economy,
    canShow: () =>
        context.mounted &&
        route?.isCurrent == true &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  );
  if (!context.mounted) return;
  if (result.reward > 0) {
    if (onReward != null) {
      await onReward(result.reward);
      return;
    }
    // The energy wallet's shared observer presents confirmed credits, also
    // when this legacy entry point is opened over the main game.
    if (economy.energyEnabled) return;
    showGameToast(
      context,
      message: economy.energyEnabled
          ? "+${result.reward} ⚡"
          : AppLocalizations.of(context).crystalsPlus(result.reward),
      flyTo: economy.energyEnabled
          ? ToastFlyTarget.energy
          : ToastFlyTarget.crystals,
    );
  } else if (result.outcome == AdOutcome.unavailable) {
    if (testServicePreviewActive(context)) {
      await showTestServiceUnavailable(
        context,
        service: TestService.video,
        amount: economy.energyConfig.reward('watch_ad'),
      );
      return;
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ads.lastFailure == AdFailure.confirmation
              ? (ru
                    ? 'Не удалось подтвердить награду. Проверьте подключение и синхронизацию.'
                    : 'Could not confirm the reward. Check your connection and sync.')
              : (ru
                    ? 'Сейчас нет доступной рекламы. Попробуйте позже.'
                    : 'No ad is available right now. Please try later.'),
        ),
      ),
    );
  }
}
