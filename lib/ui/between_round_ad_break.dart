import 'dart:async';
import 'package:flutter/material.dart';
import '../data/ads_service.dart';
import '../data/economy_store.dart';
import 'ad_privacy_settings.dart';
import 'game_ui.dart';
import 'neon_chrome.dart';

/// A modal break after results/sharing and before the next start is available.
/// Failed or slow loading can be skipped and must never surface in a new round.
Future<void> showBetweenRoundAdBreak(
  BuildContext context, {
  required AdsService ads,
  required EconomyStore economy,
  required bool Function() canShow,
}) async {
  if (!ads.audience.isAdEligibleAge ||
      !economy.canShowResultInterstitial ||
      ads.busy ||
      ModalRoute.of(context)?.isCurrent != true ||
      !canShow()) {
    return;
  }
  if (!await ensureAdDataConsent(context) ||
      !context.mounted ||
      !canShow() ||
      ModalRoute.of(context)?.isCurrent != true ||
      !economy.canShowResultInterstitial) {
    return;
  }
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (_) => _AdBreak(ads: ads, economy: economy, canShow: canShow),
  );
}

class _AdBreak extends StatefulWidget {
  const _AdBreak({
    required this.ads,
    required this.economy,
    required this.canShow,
  });
  final AdsService ads;
  final EconomyStore economy;
  final bool Function() canShow;
  @override
  State<_AdBreak> createState() => _AdBreakState();
}

class _AdBreakState extends State<_AdBreak> with WidgetsBindingObserver {
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_show()));
  }

  @override
  void dispose() {
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Once interrupted, a loading ad may not reappear on return.
    if (state != AppLifecycleState.resumed) _active = false;
  }

  bool _canShow() =>
      mounted &&
      _active &&
      widget.canShow() &&
      widget.economy.canShowResultInterstitial &&
      ModalRoute.of(context)?.isCurrent == true &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  Future<void> _show() async {
    final shown = await widget.ads.showInterstitial(canShow: _canShow);
    if (shown) widget.economy.markInterstitialShown();
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.pop(context);
    } else {
      // A new screen may cover the loading break. Remove only this stale route.
      Navigator.of(context).removeRoute(route);
    }
  }

  void _skip() {
    _active = false;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Dialog(
      key: const ValueKey('between-round-ad-break'),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AccountGlass(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeonSheetHeader(
                title: ru ? 'Пауза между партиями' : 'Between rounds',
              ),
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: GameUi.cyan),
              const SizedBox(height: 14),
              Text(ru ? 'Загрузка рекламы…' : 'Loading an ad…'),
              const SizedBox(height: 10),
              TextButton(
                key: const ValueKey('ad-break-skip'),
                onPressed: _skip,
                child: Text(
                  ru ? 'Продолжить без ожидания' : 'Continue without waiting',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
