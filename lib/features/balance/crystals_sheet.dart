import 'energy_sheet.dart';
import '../../ui/crystal_package_card.dart';
import '../../ui/crystal_cost_badge.dart';
import '../../ui/game_ui.dart';
import '../../app/app_target.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_analytics.dart';
import '../../data/economy_store.dart';
import '../../domain/gameplay_config.dart';
import '../../domain/shop_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_catalog.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';
import '../../ui/watch_rewarded_ad.dart';
import '../../ui/rewarded_ad_disclosure.dart';
import '../../ui/billing_unavailable.dart';
import '../../ui/audience_gate.dart';
import '../../data/ads_service.dart';
import '../../data/play_billing_service.dart';
import '../invites/invite_action_card.dart';

Future<void> showCrystalsSheet(BuildContext context, {int initialTab = 0}) {
  if (context.read<EconomyStore>().energyEnabled) {
    return showEnergySheet(context, initialTab: initialTab == 3 ? 1 : 0);
  }
  return showModalBottomSheet<void>(
    sheetAnimationStyle: GameUi.windowAnimationStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CrystalsSheet(initialTab: initialTab),
  );
}

class _CrystalsSheet extends StatefulWidget {
  const _CrystalsSheet({this.initialTab = 0});

  /// 0 Daily · 1 Shop · 2 Rent · 3 Earn
  final int initialTab;

  @override
  State<_CrystalsSheet> createState() => _CrystalsSheetState();
}

class _CrystalsSheetState extends State<_CrystalsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final ValueNotifier<int> _visibleTab;
  Object? _dailySnapshot;
  Widget? _dailyContent;

  Widget _dailyPane(EconomyStore economy) {
    final snapshot = (
      economy.canClaimDaily,
      economy.dailyStreak,
      economy.upcomingStreakDay,
      economy.hasPremium,
      economy.config,
    );
    if (_dailySnapshot != snapshot) {
      _dailySnapshot = snapshot;
      _dailyContent = _DailyPane(economy: economy, format: _fmt);
    }
    // Keep the exact subtree between seconds. Only a day/state change needs
    // to rebuild cards; the countdown has its own small clock below.
    return _dailyContent!;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _visibleTab = ValueNotifier(_tabs.index);
    AppAnalytics.openCrystalsTab(_tabs.index);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (_visibleTab.value != _tabs.index) {
        _visibleTab.value = _tabs.index;
        AppAnalytics.openCrystalsTab(_tabs.index);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _visibleTab.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  int _giftAmount(EconomyStore economy) {
    return economy.config.timedBonusTokens;
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final l10n = AppLocalizations.of(context);

    return GameSheetChrome(
      glass: GameGlass.none,
      softShadow: false,
      backgroundGradient: const LinearGradient(
        colors: [Color(0xFF0D3047), Color(0xFF0D3047)],
      ),
      heightFactor: 0.90,
      heightLimit:
          GameUi.shopWindowHeight *
          (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 1.5),
      child: Column(
        children: [
          DecoratedBox(
            decoration: const GameGlassDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF174761), Color(0xFF0D3047)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: SizedBox(
                height:
                    (MediaQuery.textScalerOf(context).scale(28) * 1.1 +
                            MediaQuery.textScalerOf(context).scale(11) * 1.2 +
                            14)
                        .clamp(62.0, 110.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _ShopBalance(
                        value: economy.tokens,
                        label: l10n.crystals,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: GameClockBuilder(
                        running: () => economy.timedBonusRemaining != null,
                        builder: (_) => _GiftButton(
                          fillHeader: true,
                          canClaim: economy.canClaimTimedBonus,
                          amount: _giftAmount(economy),
                          remaining: economy.timedBonusRemaining,
                          unlockProgress: economy.timedBonusUnlockProgress,
                          format: _fmt,
                          readyLabel: l10n.giftReady,
                          onClaim: () async {
                            if (!await ensureResourceAge(context) ||
                                !context.mounted) {
                              return;
                            }
                            final n = economy.claimTimedBonus();
                            if (n != null) {
                              AppAnalytics.claimGift(tokens: n);
                              showGameToast(
                                context,
                                message: l10n.giftToast(n),
                                flyTo: ToastFlyTarget.crystals,
                                festive: true,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    if (context.watch<AdsService?>()?.available == true) ...[
                      const SizedBox(width: 6),
                      GameClockBuilder(
                        running: () => economy.watchAdCooldownRemaining != null,
                        builder: (_) => SizedBox(
                          width: 48,
                          child: _RewardedHeaderButton(economy: economy),
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: GameUi.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            if (context.watch<AdsService?>()?.available == true)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: RewardedAdDisclosure(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: DecoratedBox(
              key: const ValueKey('shop-tab-menu'),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF245D78), Color(0xFF123E58)],
                ),
                border: Border.all(color: const Color(0xFF80DFFF), width: 1.5),
              ),
              child: RepaintBoundary(
                child: TabBar(
                  controller: _tabs,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: GameGlassDecoration(
                    glass: GameGlass.selected,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                      bottom: Radius.circular(4),
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF348AAB), Color(0xFF225E7D)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFACF3FF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x3342D9FF),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorPadding: const EdgeInsets.all(3),
                  labelColor: GameUi.text,
                  unselectedLabelColor: const Color(0xFFABD2E4),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(
                      key: const ValueKey('shop-tab-0'),
                      height: GameUi.touchTarget(context),
                      child: _CrystalsTabLabel(
                        icon: Icons.calendar_month_rounded,
                        text: l10n.tabDaily,
                      ),
                    ),
                    Tab(
                      key: const ValueKey('shop-tab-1'),
                      height: GameUi.touchTarget(context),
                      child: _CrystalsTabLabel(
                        icon: Icons.storefront_rounded,
                        text: l10n.tabShop,
                      ),
                    ),
                    Tab(
                      key: const ValueKey('shop-tab-2'),
                      height: GameUi.touchTarget(context),
                      child: _CrystalsTabLabel(
                        icon: Icons.timer_outlined,
                        text: l10n.tabRent,
                      ),
                    ),
                    Tab(
                      key: const ValueKey('shop-tab-3'),
                      height: GameUi.touchTarget(context),
                      child: _CrystalsTabLabel(
                        icon: Icons.stars_rounded,
                        text: l10n.tabEarn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              key: const ValueKey('shop-tab-content'),
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3047),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border.all(color: const Color(0xFF5C8AA3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _retainedPane(
                    0,
                    GameClockBuilder(
                      running: () => _tabs.index == 0 && !economy.canClaimDaily,
                      builder: (_) => _dailyPane(economy),
                    ),
                  ),
                  _retainedPane(1, _ShopPane(economy: economy)),
                  _retainedPane(2, _RentPane(economy: economy)),
                  _retainedPane(3, _EarnPane(economy: economy)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retainedPane(int index, Widget child) => _RetainedShopPane(
    key: ValueKey('shop-pane-$index'),
    child: ValueListenableBuilder<int>(
      valueListenable: _visibleTab,
      child: child,
      builder: (_, visible, child) =>
          TickerMode(enabled: visible == index, child: child!),
    ),
  );
}

/// Retain visited pages and their scroll positions. Switching tabs must not
/// rebuild the entire shop or lay out its static cards from scratch each time.
class _RetainedShopPane extends StatefulWidget {
  const _RetainedShopPane({super.key, required this.child});
  final Widget child;
  @override
  State<_RetainedShopPane> createState() => _RetainedShopPaneState();
}

class _RetainedShopPaneState extends State<_RetainedShopPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ShopBalance extends StatelessWidget {
  const _ShopBalance({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('shop-crystal-balance'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF226B90), Color(0xFF124564)],
      ),
      border: Border.all(color: const Color(0xFF75D3E9)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const CrystalCubeIcon(size: 30, glow: true),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GameUi.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: GameUi.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CrystalsTabLabel extends StatelessWidget {
  const _CrystalsTabLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final label = scale > 1.2 && ru
        ? switch (icon) {
            Icons.calendar_month_rounded => 'Ежедневно',
            Icons.storefront_rounded => 'Покупки',
            Icons.timer_outlined => scale > 1.5 ? 'Бусты' : 'Аренда',
            _ => 'Действия',
          }
        : text;
    return Tooltip(
      message: text,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({
    super.key,
    this.advertisement = false,
    this.fillHeader = false,
    required this.canClaim,
    required this.amount,
    required this.remaining,
    required this.unlockProgress,
    required this.format,
    required this.readyLabel,
    required this.onClaim,
  });
  final bool advertisement, canClaim, fillHeader;
  final int amount;
  final Duration? remaining;
  final double unlockProgress;
  final String Function(Duration) format;
  final String readyLabel;
  final Future<void> Function() onClaim;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SizedBox(
      height: fillHeader ? null : GameUi.touchTarget(context),
      child: FilledButton(
        key: ValueKey(advertisement ? 'shop-ad-gift' : 'shop-gift'),
        onPressed: canClaim
            ? advertisement
                  ? onClaim
                  : () => runResourceAction(
                      context,
                      context.read<EconomyStore>(),
                      'gift',
                      () async => await onClaim(),
                    )
            : null,
        style:
            FilledButton.styleFrom(
              foregroundColor: GameUi.text,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(48, 48),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? GameUi.muted
                    : advertisement
                    ? GameUi.text
                    : GameUi.background,
              ),
              backgroundBuilder: (context, states, child) => Container(
                key: ValueKey(
                  advertisement
                      ? 'shop-ad-gift-material'
                      : 'shop-gift-material',
                ),
                decoration: GameGlassDecoration(
                  glass: states.contains(WidgetState.disabled)
                      ? GameGlass.none
                      : GameGlass.none,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: canClaim && !advertisement
                        ? const Color(0xFFFFEAB1)
                        : canClaim
                        ? GameUi.cyan
                        : const Color(0xFFBDA36D),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: states.contains(WidgetState.disabled)
                        ? const [Color(0xFF245572), Color(0xFF12364F)]
                        : !advertisement
                        ? const [
                            Color(0xFFFFE6A1),
                            Color(0xFFFFC957),
                            Color(0xFFFFB847),
                          ]
                        : const [
                            Color(0xFF398FAB),
                            Color(0xFF276E8E),
                            Color(0xFF164962),
                          ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF04192B), offset: Offset(0, 3)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!advertisement) ...[
                      Positioned(
                        right: 6,
                        top: 4,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: canClaim
                              ? const Color(0xFFFFF7DB)
                              : const Color(0xFFBDA36D),
                        ),
                      ),
                      Positioned(
                        left: 5,
                        bottom: 5,
                        child: Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: canClaim
                              ? const Color(0xFFAE6D22)
                              : const Color(0xFFBDA36D),
                        ),
                      ),
                    ],
                    Center(child: child),
                  ],
                ),
              ),
            ),
        child: fillHeader
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        size: 21,
                        color: canClaim
                            ? const Color(0xFF87520C)
                            : const Color(0xFFEAD398),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ru ? 'БОНУС' : 'BONUS',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        canClaim
                            ? '+$amount'
                            : remaining == null
                            ? '—'
                            : format(remaining!),
                        style: TextStyle(
                          fontSize: canClaim ? 24 : 15,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : advertisement
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ondemand_video, size: 18),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        canClaim
                            ? '+$amount'
                            : remaining == null
                            ? '—'
                            : format(remaining!),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    advertisement
                        ? Icons.ondemand_video
                        : Icons.card_giftcard_rounded,
                    size: 16,
                    color: canClaim ? GameUi.yellow : GameUi.muted,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        canClaim
                            ? '+$amount · ${ru ? 'Бонус' : 'Bonus'}'
                            : remaining == null
                            ? '—'
                            : format(remaining!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RewardedHeaderButton extends StatelessWidget {
  const _RewardedHeaderButton({required this.economy});
  final EconomyStore economy;
  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdsService>();
    final remaining = economy.watchAdCooldownRemaining;
    final total = economy.config.watchAdCooldownSec;
    final reward =
        economy.config.earnActions
            .where((a) => a.id == 'watch_ad')
            .firstOrNull
            ?.reward ??
        5;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return _GiftButton(
      key: const ValueKey('shop-header-watch-ad'),
      advertisement: true,
      canClaim: economy.canClaimWatchAd && !ads.busy,
      amount: reward,
      remaining: remaining,
      unlockProgress: remaining == null || total <= 0
          ? 1
          : 1 - remaining.inMilliseconds / (total * 1000),
      format: (d) => ads.busy
          ? '…'
          : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
      readyLabel: ru ? 'За рекламу' : 'Watch ad',
      onClaim: () => watchRewardedAd(context),
    );
  }
}

class _DailyPlusCard extends StatelessWidget {
  const _DailyPlusCard({required this.economy});
  final EconomyStore economy;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final multiplier = _premiumMultLabel(economy);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('daily-plus-card'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => showPlusSheet(context),
        child: GamePanel(
          gradient: GameUi.coolPanelGradient,
          accent: const Color(0xFF724A07),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const GameArtwork(GameArt.plus, size: 24),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      ru ? 'Подписка Plus' : 'Plus subscription',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF724A07),
                      ),
                    ),
                  ),
                  if (economy.hasPremium)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF00644C),
                    ),
                  Tooltip(
                    message: economy.hasPremium
                        ? (ru ? 'Управлять' : 'Manage')
                        : (ru ? 'Подробнее' : 'Details'),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFF724A07),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ru
                    ? 'Ежедневные награды ×$multiplier. Без рекламы в игре.'
                    : 'Daily rewards ×$multiplier. No in-game ads.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: GameUi.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPlusSheet(BuildContext context) {
  AppAnalytics.tapPlus();
  return showModalBottomSheet<void>(
    sheetAnimationStyle: GameUi.windowAnimationStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PlusSheet(),
  );
}

/// Совместимость со старым именем.
Future<void> showPlusManageSheet(BuildContext context) =>
    showPlusSheet(context);

class _PlusSheet extends StatelessWidget {
  const _PlusSheet();

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final economy = context.watch<EconomyStore>();
    final active = economy.hasPremium;
    final billing = context.watch<PlayBillingService?>();
    final price =
        context.watch<PlayBillingService?>()?.price('plus_weekly') ?? '—';
    final next =
        economy.premiumNextChargeAt ??
        DateTime.now().add(const Duration(days: 7));
    const mint = Color(0xFF00644C);

    return GameSheetChrome(
      heightFactor: 0.90,
      fitContent: true,
      glass: GameGlass.none,
      backgroundGradient: GameUi.navySheetGradient,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: ListView(
          shrinkWrap: true,
          children: [
            GameSheetHeader(
              title: active ? l10n.plusManageTitle : l10n.plusOfferTitle,
              leading: Icon(
                Icons.workspace_premium_rounded,
                color: GameUi.yellow,
              ),
              trailing: active
                  ? const Icon(Icons.check_circle_rounded, color: GameUi.mint)
                  : null,
            ),
            const SizedBox(height: 8),
            GamePanel(
              gradient: GameUi.coolPanelGradient,
              accent: mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlusBenefitRow(
                    icon: Icons.videocam_off_outlined,
                    text: l10n.plusManageBenefitAds,
                  ),
                  const SizedBox(height: 6),
                  _PlusBenefitRow(
                    icon: Icons.auto_awesome_rounded,
                    text: l10n.plusManageBenefitDaily,
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CrystalCubeIcon(size: 14, glow: false),
                        SizedBox(width: 3),
                        Text(
                          '×2',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF065781),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GamePanel(
              gradient: GameUi.coolPanelGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Localizations.localeOf(context).languageCode == 'ru'
                        ? '$price / неделю · автопродление'
                        : '$price / week · auto-renewing',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(height: 6),
                    Text(
                      Localizations.localeOf(context).languageCode == 'ru'
                          ? 'Доступ до ${_fmtDate(next)}'
                          : 'Access until ${_fmtDate(next)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: GameUi.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              Localizations.localeOf(context).languageCode == 'ru'
                  ? 'Продлевается еженедельно в Google Play. Отмена в любой момент; доступ — до конца оплаченного периода.'
                  : 'Renews weekly in Google Play. Cancel anytime; access remains until the paid period ends.',
              style: const TextStyle(
                color: GameUi.muted,
                fontSize: 11,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            if (active)
              OutlinedButton(
                onPressed: () => manageGoogleSubscription(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GameUi.ink,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                ),
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ru'
                      ? 'Управлять в Google Play'
                      : 'Manage in Google Play',
                ),
              )
            else
              FilledButton(
                onPressed: () => buyGoogleProduct(context, 'plus_weekly'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: GameUi.ink,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                ),
                child: Text(
                  l10n.plusSubscribe(price),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            TextButton(
              onPressed: () => restoreGooglePurchases(context),
              style: TextButton.styleFrom(foregroundColor: GameUi.cyan),
              child: Text(
                Localizations.localeOf(context).languageCode == 'ru'
                    ? 'Восстановить покупки'
                    : 'Restore purchases',
              ),
            ),
            if (billing != null && (billing.busy || billing.error != null))
              const GamePanel(
                gradient: GameUi.coolPanelGradient,
                child: GoogleBillingStatus(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlusBenefitRow extends StatelessWidget {
  const _PlusBenefitRow({
    required this.icon,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00644C)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _DailyPane extends StatelessWidget {
  const _DailyPane({required this.economy, required this.format});

  final EconomyStore economy;
  final String Function(Duration) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rewards = economy.config.dailyRewardTokens;
    final upcomingDay = economy.upcomingStreakDay.clamp(1, rewards.length);
    final claimedToday = !economy.canClaimDaily;
    final claimedCount = claimedToday
        ? economy.dailyStreak
        : (upcomingDay - 1).clamp(0, rewards.length);
    final premium = economy.hasPremium;
    final multLabel = _premiumMultLabel(economy);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: RepaintBoundary(child: _DailyPlusCard(economy: economy)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowHeight = _dailyRowHeight(
                context,
                constraints.maxWidth - 44,
                MediaQuery.textScalerOf(context).scale(12) > 16,
                premium,
                multLabel,
              );
              return ListView(
                key: const ValueKey('daily-days-scroll'),
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                children: [
                  Text(
                    claimedToday
                        ? l10n.dailyStreakActive(economy.dailyStreak)
                        : l10n.dailyStreakHint,
                    style: const TextStyle(
                      color: GameUi.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(rewards.length, (i) {
                    final day = i + 1;
                    final base = economy.config.dailyTokensForStreak(
                      i,
                      premium: false,
                    );
                    final amount = economy.config.dailyTokensForStreak(
                      i,
                      premium: premium,
                    );
                    final isClaimed = day <= claimedCount;
                    final isToday = !claimedToday && day == upcomingDay;
                    final isWaiting =
                        claimedToday &&
                        day ==
                            (economy.dailyStreak + 1).clamp(1, rewards.length);
                    final isLocked = !isClaimed && !isToday && !isWaiting;

                    return _DailyTimelineRow(
                      day: day,
                      height: rowHeight,
                      base: base,
                      amount: amount,
                      hasPremium: premium,
                      multLabel: multLabel,
                      isFirst: i == 0,
                      isLast: i == rewards.length - 1,
                      isClaimed: isClaimed,
                      isToday: isToday,
                      isWaiting: isWaiting,
                      isLocked: isLocked,
                      countdown: isWaiting
                          ? format(economy.untilMidnight)
                          : null,
                      onClaim: isToday
                          ? () async {
                              if (!await ensureResourceAge(context) ||
                                  !context.mounted) {
                                return;
                              }
                              final n = economy.claimDaily();
                              if (n != null) {
                                AppAnalytics.claimDaily(tokens: n);
                                showGameToast(
                                  context,
                                  message: l10n.dailyToast(n),
                                  accent: const Color(0xFF00644C),
                                  flyTo: ToastFlyTarget.crystals,
                                );
                              }
                            }
                          : null,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// Measure the largest labels across all states, so every day shares one
// height while respecting wrapped Plus hints and the owner's text size.
String _formatDailyCountdown(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:'
    '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
    '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

double _dailyRowHeight(
  BuildContext context,
  double width,
  bool largeText,
  bool hasPremium,
  String multLabel,
) {
  final l10n = AppLocalizations.of(context);
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final economy = context.read<EconomyStore>();
  final innerWidth = width - 19;
  double textHeight(
    String text,
    double fontSize,
    FontWeight weight,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(
          context,
        ).style.merge(TextStyle(fontSize: fontSize, fontWeight: weight)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth.clamp(1, double.infinity));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final rewardWidth = largeText ? innerWidth - 8 : innerWidth - 180;
  var hintHeight = 0.0;
  var dayHeight = 20.0;
  var amountHeight = 18.0;
  for (var i = 0; i < economy.config.dailyRewardTokens.length; i++) {
    final base = economy.config.dailyTokensForStreak(i, premium: false);
    final hint = hasPremium
        ? l10n.premiumTimesBase(base, multLabel)
        : l10n.premiumTimesLocked(multLabel);
    final measuredHint = textHeight(hint, 10, FontWeight.w700, rewardWidth);
    if (measuredHint > hintHeight) hintHeight = measuredHint;
    final measuredDay = textHeight(
      ru ? 'День ${i + 1}' : 'Day ${i + 1}',
      12,
      FontWeight.w800,
      largeText ? innerWidth - 25 : 69,
    );
    if (measuredDay > dayHeight) dayHeight = measuredDay;
    final measuredAmount = textHeight(
      '+$base',
      16,
      FontWeight.w900,
      double.infinity,
    );
    if (measuredAmount > amountHeight) amountHeight = measuredAmount;
  }
  var statusHeight = 48.0;
  for (final label in [
    l10n.claimed,
    ru ? 'Завтра' : 'Next',
    ru ? 'Закрыто' : 'Locked',
  ]) {
    final measured =
        textHeight(
          label,
          10.5,
          FontWeight.w800,
          largeText ? innerWidth - 30 : 64,
        ) +
        14;
    if (measured > statusHeight) statusHeight = measured;
  }
  final rewardHeight = amountHeight + hintHeight + 4;
  if (largeText) return dayHeight + rewardHeight + statusHeight + 15;
  final contentHeight = [
    dayHeight,
    rewardHeight,
    statusHeight,
  ].reduce((a, b) => a > b ? a : b);
  return contentHeight + 6;
}

class _DailyTimelineRow extends StatelessWidget {
  const _DailyTimelineRow({
    required this.day,
    required this.height,
    required this.base,
    required this.amount,
    required this.hasPremium,
    required this.multLabel,
    required this.isFirst,
    required this.isLast,
    required this.isClaimed,
    required this.isToday,
    required this.isWaiting,
    required this.isLocked,
    this.countdown,
    this.onClaim,
  });

  final int day;
  final double height;
  final int base;
  final int amount;
  final bool hasPremium;
  final String multLabel;
  final bool isFirst;
  final bool isLast;
  final bool isClaimed;
  final bool isToday;
  final bool isWaiting;
  final bool isLocked;
  final String? countdown;
  final Future<void> Function()? onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final waiting = isWaiting;
    final foreground = waiting
        ? const Color(0xFF103E5C)
        : isClaimed
        ? const Color(0xFF174C3D)
        : isLocked
        ? const Color(0xFF173C54)
        : const Color(0xFF00644C);
    final statusLabel = waiting
        ? countdown!
        : isClaimed
        ? l10n.claimed
        : isLocked
        ? (ru ? 'Закрыто' : 'Locked')
        : l10n.claim;
    final statusIcon = waiting
        ? Icons.schedule_rounded
        : isClaimed
        ? Icons.check_circle_rounded
        : Icons.lock_outline_rounded;
    final status = isToday
        ? FilledButton(
            key: ValueKey('daily-claim-$day'),
            onPressed: () => runResourceAction(
              context,
              context.read<EconomyStore>(),
              'daily',
              () async => await onClaim?.call(),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ).copyWith(backgroundBuilder: GameUi.replayLayer),
            child: Text(l10n.claim, style: const TextStyle(fontSize: 12)),
          )
        : Tooltip(
            message: isLocked
                ? (ru
                      ? 'Откроется после дня ${day - 1}'
                      : 'Unlocks after day ${day - 1}')
                : waiting
                ? (ru ? 'До следующей награды' : 'Time until next reward')
                : statusLabel,
            child: Container(
              key: ValueKey('daily-status-$day'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: waiting
                    ? const Color(0xFFBAD7E7)
                    : isClaimed
                    ? const Color(0xFFB4DECD)
                    : const Color(0xFFB4CBD9),
                border: Border.all(
                  color: waiting
                      ? const Color(0xFF77A6BF)
                      : isClaimed
                      ? const Color(0xFF6AAB91)
                      : const Color(0xFF8EAABD),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: foreground),
                  const SizedBox(width: 4),
                  Flexible(
                    child: waiting
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GameClockBuilder(
                              running: () =>
                                  !context.read<EconomyStore>().canClaimDaily,
                              builder: (_) => Text(
                                _formatDailyCountdown(
                                  context.read<EconomyStore>().untilMidnight,
                                ),
                                key: ValueKey('daily-next-countdown-$day'),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF103E5C),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          )
                        : Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: foreground,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
    final reward = Container(
      key: ValueKey('daily-reward-$day'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrystalCubeIcon(size: 18, glow: false, onLightBackground: true),
                const SizedBox(width: 4),
                Text(
                  '+$amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
          Text(
            hasPremium
                ? l10n.premiumTimesBase(base, multLabel)
                : l10n.premiumTimesLocked(multLabel),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: waiting
                  ? const Color(0xFF334F60)
                  : isLocked
                  ? const Color(0xFF173C54)
                  : const Color(0xFF77500A),
            ),
          ),
        ],
      ),
    );
    final dayLabel = Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isClaimed
                ? const Color(0xFF00644C)
                : waiting
                ? const Color(0xFFB4D3E4)
                : isLocked
                ? const Color(0xFFA6C2D3)
                : const Color(0xFFB0EAD1),
            border: Border.all(
              color: waiting
                  ? const Color(0xFF77A6BF)
                  : isClaimed || isToday
                  ? const Color(0xFF168566)
                  : const Color(0xFF819EB3),
            ),
          ),
          child: isClaimed
              ? const Icon(Icons.check_rounded, size: 14, color: GameUi.text)
              : day == 7
              ? const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFF86580C),
                )
              : isLocked
              ? Icon(Icons.lock_outline_rounded, size: 12, color: foreground)
              : Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            ru ? 'День $day' : 'Day $day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
      ],
    );
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
    return Semantics(
      label:
          '${ru ? 'День' : 'Day'} $day, ${waiting ? (ru ? 'Следующая награда' : 'Next reward') : statusLabel}',
      child: Container(
        key: ValueKey('daily-row-$day'),
        margin: const EdgeInsets.only(bottom: 4),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: GameGlassDecoration(
          glass: isLocked || isClaimed ? GameGlass.none : GameGlass.card,
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: waiting
                ? const [Color(0xFF98D3EB), Color(0xFF75B8D7)]
                : isToday
                ? const [Color(0xFF9BDEC9), Color(0xFF85CEB7)]
                : isClaimed
                ? const [Color(0xFF92C9BC), Color(0xFF7FBCAE)]
                : const [Color(0xFF88B7CE), Color(0xFF7DACCA)],
          ),
          border: Border.all(
            color: day == 7 && !isClaimed
                ? const Color(0xFFDDB868)
                : waiting
                ? const Color(0xFF77A6BF)
                : isToday
                ? const Color(0xFF168566)
                : isClaimed
                ? const Color(0xFF7BAF99)
                : const Color(0xFF8EAABD),
            width: isToday || waiting ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66236497), offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (largeText) ...[
              dayLabel,
              const SizedBox(height: 2),
              Align(child: reward),
              const SizedBox(height: 2),
              Align(alignment: Alignment.centerRight, child: status),
            ] else
              Row(
                children: [
                  SizedBox(width: 86, child: dayLabel),
                  Expanded(child: Center(child: reward)),
                  SizedBox(width: 86, child: status),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopPane extends StatelessWidget {
  const _ShopPane({required this.economy});
  final EconomyStore economy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final billing = context.watch<PlayBillingService?>();
    return LayoutBuilder(
      builder: (context, viewport) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          if (billing != null && (billing.busy || billing.error != null))
            const GamePanel(
              gradient: GameUi.coolPanelGradient,
              child: GoogleBillingStatus(),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < ShopCatalog.packs.length; i++)
                    SizedBox(
                      width: width,
                      child: CrystalPackageCard(
                        compact: viewport.maxHeight < 300,
                        key: ValueKey(
                          'crystal-package-${ShopCatalog.packs[i].id}',
                        ),
                        offer: ShopCatalog.packs[i],
                        tier: i,
                        title: L10nCatalog.packTitle(
                          l10n,
                          ShopCatalog.packs[i].id,
                        ),
                        price:
                            billing?.price(ShopCatalog.packs[i].id) ??
                            (PlayBillingService.enabled
                                ? '—'
                                : ShopCatalog.packs[i].priceLabel),
                        caption: PlayBillingService.enabled
                            ? 'Google Play'
                            : (ru ? 'Покупки скоро' : 'Coming soon'),
                        onTap: () =>
                            buyGoogleProduct(context, ShopCatalog.packs[i].id),
                      ),
                    ),
                ],
              );
            },
          ),
          TextButton(
            onPressed: () => restoreGooglePurchases(context),
            child: Text(
              ru ? 'Восстановить покупки' : 'Restore purchases',
              style: const TextStyle(color: GameUi.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RentPane extends StatefulWidget {
  const _RentPane({required this.economy});

  final EconomyStore economy;

  @override
  State<_RentPane> createState() => _RentPaneState();
}

class _RentPaneState extends State<_RentPane> {
  Timer? _tick;

  EconomyStore get economy => widget.economy;

  static String _formatCooldown(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (economy.hasJumpRental || economy.hasHelmetRental) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _rentJump(BuildContext context, {required bool hour}) async {
    await runResourceAction(context, economy, 'rentJump', () async {
      final l10n = AppLocalizations.of(context);
      if (!economy.canRentJump(hour: hour)) {
        showGameToast(context, message: l10n.rentNotEnough);
        return;
      }
      final extending = economy.hasJumpRental;
      if (!economy.rentJump(hour: hour)) return;
      showGameToast(
        context,
        message: extending
            ? l10n.rentActive(_formatCooldown(economy.jumpRentalRemaining!))
            : l10n.rentJumpTitle,
        accent: const Color(0xFF00644C),
        icon: const Icon(
          Icons.keyboard_double_arrow_up_rounded,
          color: Color(0xFF00644C),
        ),
      );
    });
  }

  Future<void> _rentHelmet(BuildContext context, {required bool hour}) async {
    await runResourceAction(context, economy, 'rentHelmet', () async {
      final l10n = AppLocalizations.of(context);
      if (!economy.canRentHelmet(hour: hour)) {
        showGameToast(context, message: l10n.rentNotEnough);
        return;
      }
      final extending = economy.hasHelmetRental;
      if (!economy.rentHelmet(hour: hour)) return;
      showGameToast(
        context,
        message: extending
            ? l10n.rentActive(_formatCooldown(economy.helmetRentalRemaining!))
            : l10n.rentHelmetTitle,
        accent: const Color(0xFF065781),
        icon: const Icon(Icons.shield_outlined, color: Color(0xFF065781)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gameplay = context.watch<GameplayConfig>();
    final jumpEnabled = gameplay.jumpEnabled;
    final helmetEnabled = gameplay.helmetEnabled;
    final jumpLeft = economy.jumpRentalRemaining;
    final helmetLeft = economy.helmetRentalRemaining;
    final cfg = economy.config;

    if (!jumpEnabled && !helmetEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.rentInactive,
            style: const TextStyle(
              color: GameUi.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final cards = <Widget>[
      if (helmetEnabled)
        _RentalFeatureCard(
          icon: Icons.shield_outlined,
          accent: const Color(0xFF065781),
          title: l10n.rentHelmetTitle,
          description: l10n.rentHelmetSub,
          activeLabel: helmetLeft != null
              ? l10n.rentActive(_formatCooldown(helmetLeft))
              : null,
          shortMinutes: cfg.helmetRentalMinutes,
          shortCost: cfg.helmetRentalCost,
          shortEnabled: economy.canRentHelmet(),
          onShort: () => _rentHelmet(context, hour: false),
          longMinutes: cfg.helmetRentalHourMinutes,
          longCost: cfg.helmetRentalHourCost,
          longListPrice: cfg.helmetRentalHourListPrice,
          longDiscountPercent: cfg.helmetRentalHourDiscountPercent,
          longEnabled: economy.canRentHelmet(hour: true),
          onLong: () => _rentHelmet(context, hour: true),
          actionLabel: helmetLeft != null ? l10n.rentExtend : l10n.rentBuy,
        ),
      if (jumpEnabled)
        _RentalFeatureCard(
          icon: Icons.keyboard_double_arrow_up_rounded,
          accent: const Color(0xFF00644C),
          title: l10n.rentJumpTitle,
          description: l10n.rentJumpSub,
          activeLabel: jumpLeft != null
              ? l10n.rentActive(_formatCooldown(jumpLeft))
              : null,
          shortMinutes: cfg.jumpRentalMinutes,
          shortCost: cfg.jumpRentalCost,
          shortEnabled: economy.canRentJump(),
          onShort: () => _rentJump(context, hour: false),
          longMinutes: cfg.jumpRentalHourMinutes,
          longCost: cfg.jumpRentalHourCost,
          longListPrice: cfg.jumpRentalHourListPrice,
          longDiscountPercent: cfg.jumpRentalHourDiscountPercent,
          longEnabled: economy.canRentJump(hour: true),
          onLong: () => _rentJump(context, hour: true),
          actionLabel: jumpLeft != null ? l10n.rentExtend : l10n.rentBuy,
        ),
    ].reversed.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= 304 &&
            MediaQuery.textScalerOf(context).scale(12) <= 16;
        final width =
            (constraints.maxWidth - 24 - (twoColumns ? 8 : 0)) /
            (twoColumns ? 2 : 1);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          ),
        );
      },
    );
  }
}

class _RentalFeatureCard extends StatelessWidget {
  const _RentalFeatureCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.shortMinutes,
    required this.shortCost,
    required this.shortEnabled,
    required this.onShort,
    required this.longMinutes,
    required this.longCost,
    required this.longEnabled,
    required this.onLong,
    required this.actionLabel,
    this.activeLabel,
    this.longListPrice,
    this.longDiscountPercent,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final String? activeLabel;
  final int shortMinutes;
  final int shortCost;
  final bool shortEnabled;
  final VoidCallback onShort;
  final int longMinutes;
  final int longCost;
  final int? longListPrice;
  final int? longDiscountPercent;
  final bool longEnabled;
  final VoidCallback onLong;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final helmet = icon == Icons.shield_outlined;
    final lightAccent = accent;
    return Container(
      key: ValueKey(helmet ? 'rental-helmet-card' : 'rental-jump-card'),
      padding: const EdgeInsets.all(10),
      decoration: GameGlassDecoration(
        glass: GameGlass.none,
        borderRadius: BorderRadius.circular(GameUi.radius),
        gradient: GameUi.coolPanelGradient,
        border: Border.all(color: lightAccent, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x88236497), offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameArtwork(helmet ? GameArt.helmet : GameArt.jump, size: 28),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: lightAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: GameUi.ink,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (activeLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              activeLabel!,
              style: TextStyle(
                color: lightAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _RentalDurationButton(
            accent: accent,
            minutesLabel: l10n.rentMinsLabel(shortMinutes),
            cost: shortCost,
            actionLabel: actionLabel,
            enabled: shortEnabled,
            onTap: onShort,
          ),
          const SizedBox(height: 8),
          _RentalDurationButton(
            accent: accent,
            minutesLabel: l10n.rentMinsLabel(longMinutes),
            cost: longCost,
            listPrice: longListPrice,
            discountPercent: longDiscountPercent,
            actionLabel: actionLabel,
            enabled: longEnabled,
            onTap: onLong,
          ),
        ],
      ),
    );
  }
}

class _RentalDurationButton extends StatelessWidget {
  const _RentalDurationButton({
    required this.accent,
    required this.minutesLabel,
    required this.cost,
    required this.actionLabel,
    required this.enabled,
    required this.onTap,
    this.listPrice,
    this.discountPercent,
  });

  final Color accent;
  final String minutesLabel;
  final int cost;
  final int? listPrice;
  final int? discountPercent;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final showDiscount =
        discountPercent != null && discountPercent! > 0 && listPrice != null;
    final foreground = enabled ? GameUi.text : const Color(0xFFA4B2BE);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('rental-offer-$minutesLabel-$cost'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(GameUi.radius),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GameUi.radius),
              gradient: enabled
                  ? GameUi.deepPanelGradient
                  : const LinearGradient(
                      colors: [Color(0xFF3B4B5A), Color(0xFF293947)],
                    ),
              border: Border.all(
                color: enabled ? GameUi.cyan : const Color(0xFF677887),
                width: enabled ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        minutesLabel,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    CrystalCostBadge(amount: cost, available: enabled),
                  ],
                ),
                if (showDiscount) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: [
                      Text(
                        '$listPrice',
                        style: TextStyle(
                          fontSize: 10,
                          color: foreground,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        l10n.rentDiscountBadge(discountPercent!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: enabled ? GameUi.yellow : foreground,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      enabled
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_outline_rounded,
                      size: 14,
                      color: enabled ? GameUi.mint : foreground,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        enabled
                            ? actionLabel
                            : ru
                            ? 'Не хватает'
                            : 'Not enough',
                        style: TextStyle(
                          color: enabled ? GameUi.mint : foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _premiumMultLabel(EconomyStore economy) {
  final mult = economy.config.premiumDailyMultiplier;
  return mult == mult.roundToDouble()
      ? '${mult.toInt()}'
      : mult.toStringAsFixed(1);
}

class _EarnPane extends StatelessWidget {
  const _EarnPane({required this.economy});

  final EconomyStore economy;

  static const _shopOnlyIds = {'watch_ad'};
  static const _telegramIds = {
    'enable_notifications',
    'invite_friend',
    'social_post',
    'rate_app',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = economy.config.earnActions
        .where(
          (a) =>
              !_shopOnlyIds.contains(a.id) &&
              (!AppTargetConfig.isMobile || !_telegramIds.contains(a.id)),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      children: [
        Text(
          l10n.earnPreviewHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: GameUi.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        const InviteActionCard(),
        ...actions.map((a) {
          final done = economy.isEarnClaimed(a.id);
          final unlocked = economy.isEarnUnlocked(a.id);
          final locked = !done && !unlocked;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: done || locked
                  ? null
                  : () => runResourceAction(
                      context,
                      economy,
                      'earn-${a.id}',
                      () async {
                        if (!await ensureResourceAge(context) ||
                            !context.mounted) {
                          return;
                        }
                        final n = economy.claimEarnAction(a.id);
                        if (n != null) {
                          showGameToast(
                            context,
                            message: l10n.crystalsPlus(n),
                            flyTo: ToastFlyTarget.crystals,
                          );
                        }
                      },
                    ),
              child: Opacity(
                opacity: locked ? 0.55 : 1,
                child: GamePanel(
                  gradient: GameUi.coolPanelGradient,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  accent: done
                      ? const Color(0xFF00644C)
                      : (unlocked && !done ? const Color(0xFF724A07) : null),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10nCatalog.earnTitle(l10n, a),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              locked
                                  ? l10n.earnBonusLocked
                                  : L10nCatalog.earnSubtitle(l10n, a),
                              style: const TextStyle(
                                color: GameUi.inkMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (done)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF00644C),
                          size: 20,
                        )
                      else if (locked)
                        const Icon(
                          Icons.lock_outline,
                          color: GameUi.inkMuted,
                          size: 20,
                        )
                      else
                        _CrystalRewardBadge(amount: a.reward),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CrystalRewardBadge extends StatelessWidget {
  const _CrystalRewardBadge({required this.amount});
  final int amount;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CrystalCubeIcon(size: 16, glow: false),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          '+$amount',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: GameUi.ink,
          ),
        ),
      ),
    ],
  );
}
