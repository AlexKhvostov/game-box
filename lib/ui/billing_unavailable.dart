import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/play_billing_service.dart';
import '../data/mobile_account.dart';
import '../domain/shop_catalog.dart';
import 'audience_gate.dart';
import 'game_sheet.dart';
import 'game_ui.dart';
import 'test_service_preview.dart';

class GoogleBillingStatus extends StatelessWidget {
  const GoogleBillingStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<PlayBillingService?>();
    if (billing == null || (!billing.busy && billing.error == null)) {
      return const SizedBox.shrink();
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final pending = billing.error == 'verification_pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        billing.busy
            ? (ru
                  ? 'Ожидаем завершения покупки в Google Play.'
                  : 'Waiting for Google Play to complete your purchase.')
            : pending
            ? (ru
                  ? 'Проверка покупки ожидает соединения. Не покупайте повторно: нажмите «Восстановить покупки» после подключения.'
                  : 'Purchase verification is waiting for a connection. Do not buy again: use Restore purchases when connected.')
            : (ru
                  ? 'Покупка не завершена. Проверьте подключение и аккаунт Google Play; затем восстановите покупки.'
                  : 'Purchase not completed. Check your connection and Google Play account, then restore purchases.'),
        style: const TextStyle(color: GameUi.inkMuted, fontSize: 13),
      ),
    );
  }
}

void showBillingUnavailable(BuildContext context, {String? productId}) {
  if (testServicePreviewActive(context)) {
    showTestServiceUnavailable(context);
    return;
  }
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  showDialog<void>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 358),
        child: GameSheetChrome(
          modal: true,
          fitContent: true,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              shrinkWrap: true,
              children: [
                GameSheetHeader(
                  title: ru ? 'Покупки недоступны' : 'Purchases unavailable',
                ),
                const SizedBox(height: 8),
                const Center(child: GameArtwork(GameArt.crystals, size: 56)),
                const SizedBox(height: 8),
                Text(
                  ru
                      ? 'Покупки Google Play пока недоступны в этой тестовой версии.'
                      : 'Google Play purchases are not available in this test version yet.',
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(ru ? 'Понятно' : 'OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final _unavailableBillingOwner = Object();

Future<void> buyGoogleProduct(BuildContext context, String id) {
  if (testServicePreviewActive(context)) {
    return showTestServiceUnavailable(context);
  }
  return runResourceAction(
    context,
    context.read<PlayBillingService?>() ?? _unavailableBillingOwner,
    'billing',
    () => _buyGoogleProduct(context, id),
  );
}

Future<void> _buyGoogleProduct(BuildContext context, String id) async {
  final billing = context.read<PlayBillingService?>();
  if (billing == null || !billing.available || billing.price(id) == null) {
    showBillingUnavailable(context, productId: id);
    return;
  }
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  if (!billing.account.googleLinked) {
    await showDialog<void>(
      animationStyle: GameUi.windowAnimationStyle,
      context: context,
      builder: (dialogContext) => _StoreDialog(
        title: ru ? 'Google для покупок' : 'Google for purchases',
        content: Text(
          ru
              ? 'Перед покупкой привяжите Google в профиле игры. Это позволит восстановить покупки и кристаллы после переустановки.'
              : 'Link Google in your game profile before purchasing so you can recover purchases and crystals after reinstalling.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(ru ? 'Понятно' : 'OK'),
          ),
        ],
      ),
    );
    return;
  }
  final subscription = id == 'plus_weekly';
  final amount = ShopCatalog.packs
      .where((p) => p.id == id)
      .firstOrNull
      ?.crystals;
  final price = billing.price(id)!;
  final confirmed = await showDialog<bool>(
    animationStyle: GameUi.windowAnimationStyle,
    context: context,
    builder: (dialogContext) => _StoreDialog(
      title: ru ? 'Покупка за настоящие деньги' : 'Real-money purchase',
      content: Text(
        subscription
            ? (ru
                  ? 'Plus: $price за неделю. Подписка автоматически продлевается каждую неделю до отмены в Google Play. Отмена сохраняет доступ до конца оплаченного периода. Если вы ребёнок, попросите родителя подтвердить покупку.'
                  : 'Plus: $price per week. Renews automatically every week until canceled in Google Play. Canceling keeps access until the paid period ends. If you are a child, ask a parent to approve the purchase.')
            : (ru
                  ? '$amount кристаллов за $price. Разовая покупка без автопродления. Если вы ребёнок, попросите родителя подтвердить покупку.'
                  : '$amount crystals for $price. One-time purchase, no automatic renewal. If you are a child, ask a parent to approve the purchase.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(ru ? 'Перейти в Google Play' : 'Continue to Google Play'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await billing.buy(id);
  } on MobileApiError catch (_) {
    if (context.mounted) showBillingUnavailable(context);
  } catch (_) {
    if (context.mounted) showBillingUnavailable(context);
  }
}

Future<void> manageGoogleSubscription(BuildContext context) async {
  if (testServicePreviewActive(context)) {
    await showTestServiceUnavailable(context);
    return;
  }
  // Manage the owned subscription, not an offer the player may be viewing.
  // An energy wallet without a recognised active SKU opens Google's full list.
  final wallet = context.read<PlayBillingService?>()?.account.wallet;
  final subscription = wallet?['energySubscription'];
  final current = subscription is Map ? subscription['productId'] : null;
  final productId = wallet == null
      ? null
      : wallet['energyVersion'] == 2
      ? (current is String &&
                PlayBillingService.energySubscriptionIds.contains(current)
            ? current
            : null)
      : 'plus_weekly';
  try {
    await const MethodChannel(
      'untouch/store',
    ).invokeMethod<void>('manageSubscription', {'productId': ?productId});
  } catch (_) {
    if (context.mounted) showBillingUnavailable(context);
  }
}

Future<void> restoreGooglePurchases(BuildContext context) {
  if (testServicePreviewActive(context)) {
    return showTestServiceUnavailable(context, service: TestService.restore);
  }
  return runResourceAction(
    context,
    context.read<PlayBillingService?>() ?? _unavailableBillingOwner,
    'billing',
    () => _restoreGooglePurchases(context),
  );
}

Future<void> _restoreGooglePurchases(BuildContext context) async {
  final billing = context.read<PlayBillingService?>();
  if (billing == null || !billing.available || billing.busy) {
    showBillingUnavailable(context);
    return;
  }
  try {
    await billing.restore();
  } catch (_) {
    if (context.mounted) showBillingUnavailable(context);
  }
}

class _StoreDialog extends StatelessWidget {
  const _StoreDialog({
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
      constraints: const BoxConstraints(maxWidth: 358),
      child: GameSheetChrome(
        modal: true,
        fitContent: true,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameSheetHeader(title: title),
                const SizedBox(height: 8),
                content,
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
