import 'game_ui.dart';
import 'neon_chrome.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../data/audience_policy.dart';
import '../data/economy_store.dart';
import 'audience_gate.dart';

final _activeAdsConsent = Expando<Future<bool>>();

Future<bool> _manageAdsForSession(BuildContext context, AudiencePolicy policy) {
  if (!AudiencePolicy.adsBuildEnabled ||
      !policy.isAdEligibleAge ||
      !identical(context.read<AudiencePolicy?>(), policy)) {
    return Future.value(false);
  }
  final pending = _activeAdsConsent[policy];
  if (pending != null) return pending;
  late final Future<bool> request;
  request = _requestAdsConsent(context, policy, settings: true).whenComplete(
    () {
      if (identical(_activeAdsConsent[policy], request)) {
        _activeAdsConsent[policy] = null;
      }
    },
  );
  _activeAdsConsent[policy] = request;
  return request;
}

/// Voluntary permission for this process only. Neither requesting permission nor
/// declining it starts an SDK; age/build/revocation are checked before and after.
Future<bool> ensureAdsForSession(BuildContext context) async {
  final policy = context.read<AudiencePolicy?>();
  if (policy == null || !AudiencePolicy.adsBuildEnabled) return false;
  if (!await ensureResourceAge(context) || !context.mounted) return false;
  if (!identical(context.read<AudiencePolicy?>(), policy)) return false;
  if (!policy.isAdEligibleAge || policy.revokedThisSession) return false;
  if (policy.adsEnabled) return true;
  final pending = _activeAdsConsent[policy];
  if (pending != null) return pending;
  late final Future<bool> consent;
  consent = _requestAdsConsent(context, policy).whenComplete(() {
    if (identical(_activeAdsConsent[policy], consent)) {
      _activeAdsConsent[policy] = null;
    }
  });
  _activeAdsConsent[policy] = consent;
  return consent;
}

Future<bool> _requestAdsConsent(
  BuildContext context,
  AudiencePolicy policy, {
  bool settings = false,
}) async {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final wasEnabled = policy.rewardedAdsEnabled;
  final accepted = await showDialog<bool>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    useRootNavigator: false,
    builder: (ctx) => _AdsConsentDialog(
      title: settings
          ? (ru ? 'Реклама в этом сеансе' : 'Ads for this session')
          : (ru ? 'Включить рекламу?' : 'Enable ads?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ru
                  ? 'Рекламу предоставляет Яндекс. Для её загрузки SDK связывается с Яндексом и обрабатывает технические данные соединения и доступные SDK идентификаторы устройства. Персонализация и передача местоположения выключены. Ник и результаты игры Яндексу не передаются.\n\nВы можете играть без рекламы. Разрешение действует до закрытия приложения; новые запросы можно выключить здесь. Чтобы остановить уже запущенный SDK, полностью закройте приложение.${AudiencePolicy.demoAds ? ' В этой тестовой сборке используются демонстрационные объявления.' : ''}'
                  : 'Yandex provides the ads. Its SDK connects to Yandex and processes technical connection data and device identifiers available to it. Personalization and location tracking are off. Your nickname and game results are not sent to Yandex.\n\nYou can play without ads. Permission lasts until the app closes; you can stop new requests here. Fully close the app to stop an already running SDK.${AudiencePolicy.demoAds ? ' This test build uses demo ads.' : ''}',
              style: const TextStyle(
                color: GameUi.text,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await const MethodChannel(
                    'untouch/adPrivacy',
                  ).invokeMethod<void>('openPolicy');
                } catch (_) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        ru
                            ? 'Не удалось открыть браузер.'
                            : 'Could not open the browser.',
                      ),
                    ),
                  );
                }
              },
              child: Text(ru ? 'Политика Яндекса' : 'Yandex privacy policy'),
            ),
            if (settings && policy.revokedThisSession)
              Text(
                ru
                    ? 'Новые рекламные запросы выключены. Полностью закройте приложение, чтобы остановить рекламный SDK.'
                    : 'New ad requests are off. Fully close the app to stop the ads SDK.',
                style: const TextStyle(
                  fontSize: 12,
                  color: GameUi.muted,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(ctx, settings && wasEnabled ? null : false),
          child: Text(
            settings && wasEnabled
                ? (ru ? 'Закрыть' : 'Close')
                : (ru ? 'Без рекламы' : 'No ads'),
          ),
        ),
        FilledButton(
          onPressed: policy.revokedThisSession
              ? null
              : () => Navigator.pop(ctx, !(settings && wasEnabled)),
          child: Text(
            settings && wasEnabled
                ? (ru ? 'Выключить запросы' : 'Stop requests')
                : policy.revokedThisSession
                ? (ru ? 'Выключено в сеансе' : 'Off for this session')
                : (ru ? 'Включить' : 'Enable'),
          ),
        ),
      ],
    ),
  );
  if (settings && wasEnabled && accepted == false) {
    if (context.mounted && identical(context.read<AudiencePolicy?>(), policy)) {
      policy.revokeAdsForSession();
    }
    return false;
  }
  if (accepted != true ||
      !context.mounted ||
      !identical(context.read<AudiencePolicy?>(), policy) ||
      !policy.isAdEligibleAge ||
      policy.revokedThisSession) {
    return false;
  }
  policy.allowAdsForSession();
  return policy.adsEnabled;
}

/// Permission to start the non-personalized SDK is separate from age selection.
/// It is never granted on behalf of a child or remembered across app launches.
class AdPrivacySettings extends StatelessWidget {
  const AdPrivacySettings({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final policy = context.watch<AudiencePolicy?>();
    if (policy == null) return const SizedBox.shrink();
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final energy = context.watch<EconomyStore?>()?.energyEnabled ?? false;
    if (!policy.isAdEligibleAge || !AudiencePolicy.adsBuildEnabled) {
      return const SizedBox.shrink();
    }
    if (compact) {
      final status = policy.revokedThisSession
          ? (ru ? 'Новые запросы выключены' : 'New requests are off')
          : policy.adsEnabled
          ? (ru ? 'До закрытия приложения' : 'Until the app closes')
          : policy.rewardedAdsEnabled
          ? (ru ? 'Просмотр по кнопке' : 'Reward button only')
          : (ru ? 'Сейчас выключена' : 'Currently off');
      return TextButton(
        key: const ValueKey('ad-privacy-compact'),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          foregroundColor: GameUi.text,
        ),
        onPressed: () => _manageAdsForSession(context, policy),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: GameUi.cyan,
              size: 21,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ru ? 'Реклама в этом сеансе' : 'Ads for this session',
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
                  ),
                  Text(
                    status,
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
            const Icon(
              Icons.chevron_right_rounded,
              color: GameUi.cyan,
              size: 18,
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('ad-privacy-switch'),
          title: Text(ru ? 'Реклама в этом сеансе' : 'Ads for this session'),
          subtitle: Text(
            ru
                ? 'Добровольный просмотр за ${energy ? 'энергию' : 'кристаллы'} и объявления между играми. По умолчанию выключены.'
                : 'Optional videos for ${energy ? 'energy' : 'crystals'} and ads between games. Off by default.',
          ),
          value: policy.rewardedAdsEnabled,
          onChanged: policy.revokedThisSession
              ? null
              : (value) async {
                  if (!value) {
                    policy.revokeAdsForSession();
                    return;
                  }
                  await ensureAdsForSession(context);
                },
        ),
        if (policy.revokedThisSession)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ru
                  ? 'Новые рекламные запросы выключены. Полностью закройте приложение, чтобы остановить рекламный SDK.'
                  : 'New ad requests are off. Fully close the app to stop the ads SDK.',
            ),
          ),
      ],
    );
  }
}

class _AdsConsentDialog extends StatelessWidget {
  const _AdsConsentDialog({
    required this.title,
    required this.content,
    required this.actions,
  });
  final String title;
  final Widget content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
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
            NeonSheetHeader(title: title),
            Flexible(child: content),
            Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
          ],
        ),
      ),
    ),
  );
}
