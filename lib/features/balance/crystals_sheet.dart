import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../domain/currency.dart';
import '../../domain/economy_config.dart';
import '../../domain/shop_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_catalog.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sheet.dart';
import '../../ui/game_toast.dart';

Future<void> showCrystalsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CrystalsSheet(),
  );
}

class _CrystalsSheet extends StatefulWidget {
  const _CrystalsSheet();

  @override
  State<_CrystalsSheet> createState() => _CrystalsSheetState();
}

class _CrystalsSheetState extends State<_CrystalsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ticker?.cancel();
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
    final base = economy.config.timedBonusTokens;
    if (!economy.hasPremium) return base;
    return (base * economy.config.premiumDailyMultiplier).round();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return GameSheetChrome(
      heightFactor: 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GamePanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      accent: const Color(0xFF7EE0FF),
                      child: Row(
                        children: [
                          const CrystalCubeIcon(size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.crystals,
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  '${economy.tokens}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF7EE0FF),
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GiftButton(
                    canClaim: economy.canClaimTimedBonus,
                    amount: _giftAmount(economy),
                    remaining: economy.timedBonusRemaining,
                    format: _fmt,
                    readyLabel: l10n.giftReady,
                    onClaim: () {
                      final n = economy.claimTimedBonus();
                      if (n != null) {
                        showGameToast(context, message: l10n.giftToast(n));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            tabs: [
              Tab(text: l10n.tabDaily, height: 36),
              Tab(text: l10n.tabShop, height: 36),
              Tab(text: l10n.tabEarn, height: 36),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DailyPane(economy: economy, format: _fmt),
                _ShopPane(economy: economy),
                _EarnPane(economy: economy),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: _PlusStrip(economy: economy),
          ),
        ],
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({
    required this.canClaim,
    required this.amount,
    required this.remaining,
    required this.format,
    required this.readyLabel,
    required this.onClaim,
  });

  final bool canClaim;
  final int amount;
  final Duration? remaining;
  final String Function(Duration) format;
  final String readyLabel;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canClaim ? onClaim : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: canClaim
                  ? const [
                      Color(0xFFFF8A5C),
                      Color(0xFFE85D75),
                      Color(0xFFC44BFF),
                    ]
                  : const [Color(0xFF243040), Color(0xFF1A2430)],
            ),
            border: Border.all(
              color: canClaim
                  ? const Color(0xFFFFD28A).withValues(alpha: 0.55)
                  : const Color(0xFF7EE0FF).withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 20,
                  color: canClaim
                      ? const Color(0xFFFFF1C1)
                      : const Color(0xFF7EE0FF),
                ),
                const SizedBox(height: 2),
                Text(
                  '+$amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.1,
                    color: canClaim
                        ? const Color(0xFFFFF6DE)
                        : const Color(0xFF7EE0FF),
                  ),
                ),
                Text(
                  canClaim ? readyLabel : format(remaining ?? Duration.zero),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: canClaim ? Colors.white70 : const Color(0xFFE0C8FF),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Компактная, ненавязчивая полоска подписки.
class _PlusStrip extends StatelessWidget {
  const _PlusStrip({required this.economy});

  final EconomyStore economy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 18,
            color: theme.colorScheme.primary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.plusTitle(Currency.brand),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  l10n.plusBenefits,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: economy.hasPremium
                ? null
                : () {
                    economy.activatePremiumPreview();
                    showGameToast(
                      context,
                      message: l10n.plusToast(Currency.brand),
                      accent: const Color(0xFF3DDC97),
                    );
                  },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              economy.hasPremium
                  ? l10n.plusActive
                  : l10n.plusButton(ShopCatalog.subscribePrice),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      children: List.generate(rewards.length, (i) {
        final day = i + 1;
        final amount = economy.config.dailyTokensForStreak(
          i,
          premium: economy.hasPremium,
        );
        final isClaimed = day <= claimedCount;
        final isToday = !claimedToday && day == upcomingDay;
        final isWaiting = claimedToday &&
            day == (economy.dailyStreak + 1).clamp(1, rewards.length);

        return GamePanel(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          accent: isToday ? const Color(0xFF3DDC97) : null,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isClaimed ? const Color(0xFF3DDC97) : Colors.white10,
                ),
                child: isClaimed
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF0E1419),
                      )
                    : Text(
                        '$day',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.dayReward(day, amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isToday)
                FilledButton(
                  onPressed: () {
                    final n = economy.claimDaily();
                    if (n != null) {
                      showGameToast(
                        context,
                        message: l10n.dailyToast(n),
                        accent: const Color(0xFF3DDC97),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(84, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(l10n.claim),
                )
              else if (isWaiting)
                Container(
                  constraints: const BoxConstraints(minWidth: 84),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1A2830),
                    border: Border.all(
                      color: const Color(0xFF7EE0FF).withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    format(economy.untilMidnight),
                    style: const TextStyle(
                      color: Color(0xFF7EE0FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              else if (isClaimed)
                SizedBox(
                  width: 84,
                  child: Text(
                    l10n.claimed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3DDC97),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _ShopPane extends StatelessWidget {
  const _ShopPane({required this.economy});

  final EconomyStore economy;

  EarnAction? get _adOffer {
    for (final a in economy.config.earnActions) {
      if (a.id == 'watch_ad') return a;
    }
    return const EarnAction(
      id: 'watch_ad',
      title: 'Watch an ad',
      subtitle: 'Short video',
      reward: 5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ad = _adOffer!;
    final adReward = economy.hasPremium
        ? (ad.reward * economy.config.premiumDailyMultiplier).round()
        : ad.reward;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      children: [
        // Бесплатно за рекламу — многоразово
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final n = economy.claimWatchAd(fallbackReward: ad.reward);
              showGameToast(context, message: l10n.crystalsPlus(n));
            },
            child: GamePanel(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              accent: const Color(0xFF7EE0FF),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF7EE0FF).withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      color: Color(0xFF7EE0FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shopWatchAd,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          l10n.shopWatchAdSub,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '+$adReward',
                          style: const TextStyle(
                            color: Color(0xFF7EE0FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF3DDC97).withValues(alpha: 0.25),
                      border: Border.all(
                        color: const Color(0xFF3DDC97).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      l10n.shopFree,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: Color(0xFF3DDC97),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ...ShopCatalog.packs.map((offer) {
          final badge = L10nCatalog.packBadge(l10n, offer.badgeKey);
          final shown = economy.hasPremium
              ? (offer.crystals * economy.config.premiumDailyMultiplier)
                  .round()
              : offer.crystals;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final n = economy.grantCrystals(offer.crystals);
                showGameToast(context, message: l10n.crystalsPlus(n));
              },
              child: GamePanel(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                accent: const Color(0xFF7EE0FF),
                child: Row(
                  children: [
                    const CrystalCubeIcon(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                L10nCatalog.packTitle(l10n, offer.id),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3DDC97),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '+$shown',
                            style: const TextStyle(
                              color: Color(0xFF7EE0FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      offer.priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EarnPane extends StatelessWidget {
  const _EarnPane({required this.economy});

  final EconomyStore economy;

  static const _shopOnlyIds = {'watch_ad'};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = economy.config.earnActions
        .where((a) => !_shopOnlyIds.contains(a.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      children: [
        Text(
          l10n.earnPreviewHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontSize: 11,
              ),
        ),
        const SizedBox(height: 8),
        ...actions.map((a) {
          final done = economy.isEarnClaimed(a.id);
          final reward = economy.hasPremium
              ? (a.reward * economy.config.premiumDailyMultiplier).round()
              : a.reward;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: done
                  ? null
                  : () {
                      final n = economy.claimEarnAction(a.id);
                      if (n != null) {
                        showGameToast(
                          context,
                          message: l10n.crystalsPlus(n),
                        );
                      }
                    },
              child: GamePanel(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                accent: done ? const Color(0xFF3DDC97) : null,
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
                            L10nCatalog.earnSubtitle(l10n, a),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (done)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF3DDC97),
                        size: 20,
                      )
                    else
                      Text(
                        '+$reward',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF7EE0FF),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
