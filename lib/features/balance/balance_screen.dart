import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../domain/shop_catalog.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_toast.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);
    final timedLeft = economy.timedBonusRemaining;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Баланс', style: theme.textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _BalanceCard(balance: economy.tokens),
                ),
                const SizedBox(width: 12),
                _BoostButton(
                  canClaim: economy.canClaimTimedBonus,
                  remaining: timedLeft,
                  amount: economy.config.timedBonusTokens,
                  formatDuration: _formatDuration,
                  onClaim: () {
                    final n = economy.claimTimedBonus();
                    if (n != null) {
                      showGameToast(
                        context,
                        message: 'Gift! +$n',
                        flyTo: ToastFlyTarget.crystals,
                        festive: true,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (economy.hasPremium)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                'Plus активна · Daily ×2',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Магазин'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DailyTab(economy: economy),
                _ShopTab(economy: economy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3340),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(
          color: const Color(0xFF7EE0FF).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const CrystalCubeIcon(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crystals',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '$balance',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 28,
                    color: const Color(0xFF7EE0FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostButton extends StatefulWidget {
  const _BoostButton({
    required this.canClaim,
    required this.remaining,
    required this.amount,
    required this.formatDuration,
    required this.onClaim,
  });

  final bool canClaim;
  final Duration? remaining;
  final int amount;
  final String Function(Duration) formatDuration;
  final VoidCallback onClaim;

  @override
  State<_BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<_BoostButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _BoostButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (!widget.canClaim) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final ice = widget.canClaim ? 0.0 : (0.35 + _pulse.value * 0.55);
        final glow = widget.canClaim
            ? 0.55
            : (0.25 + _pulse.value * 0.45);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.canClaim ? widget.onClaim : null,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 124,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFFFF8A5C),
                      const Color(0xFF7EE0FF),
                      ice * 0.85,
                    )!,
                    Color.lerp(
                      const Color(0xFFE85D75),
                      const Color(0xFF4CC9F0),
                      ice * 0.75,
                    )!,
                    Color.lerp(
                      const Color(0xFFC44BFF),
                      const Color(0xFF90E0EF),
                      ice * 0.7,
                    )!,
                  ],
                ),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFFFFD28A),
                    const Color(0xFFE8FBFF),
                    ice,
                  )!
                      .withValues(alpha: 0.55 + glow * 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0xFFFF8A5C),
                      const Color(0xFF7EE0FF),
                      ice,
                    )!
                        .withValues(alpha: 0.25 + glow * 0.35),
                    blurRadius: 14 + glow * 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        size: 30,
                        color: Color.lerp(
                          const Color(0xFFFFF1C1),
                          const Color(0xFFE8FBFF),
                          ice,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${widget.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1,
                          color: Color.lerp(
                            const Color(0xFFFFF6DE),
                            const Color(0xFFE8FBFF),
                            ice,
                          ),
                        ),
                      ),
                      Text(
                        'кристалла',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          height: 1.1,
                          color: Color.lerp(
                            const Color(0xFFFFF6DE),
                            const Color(0xFFD9F6FF),
                            ice,
                          )!
                              .withValues(alpha: 0.92),
                        ),
                      ),
                      if (!widget.canClaim) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.formatDuration(
                            widget.remaining ?? Duration.zero,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Color.lerp(
                              const Color(0xFFE8FBFF),
                              Colors.white,
                              _pulse.value,
                            ),
                            shadows: [
                              Shadow(
                                color: const Color(0xFF7EE0FF)
                                    .withValues(alpha: 0.7 * _pulse.value),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Забрать',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFF6DE),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!widget.canClaim)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.18 + ice * 0.12),
                                const Color(0xFF7EE0FF)
                                    .withValues(alpha: 0.08 + ice * 0.18),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DailyTab extends StatelessWidget {
  const _DailyTab({required this.economy});

  final EconomyStore economy;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  void _claim(BuildContext context) {
    final n = economy.claimDaily();
    if (n != null) {
      showGameToast(
        context,
        message: 'Day ${economy.dailyStreak}: +$n',
        accent: const Color(0xFF3DDC97),
        flyTo: ToastFlyTarget.crystals,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rewards = economy.config.dailyRewardTokens;
    final upcomingDay = economy.upcomingStreakDay.clamp(1, rewards.length);
    final claimedToday = !economy.canClaimDaily;
    final claimedCount = claimedToday
        ? economy.dailyStreak
        : (upcomingDay - 1).clamp(0, rewards.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          claimedToday
              ? 'Серия ${economy.dailyStreak} дн. · пропуск суток сбрасывает на день 1'
              : 'Забирайте награду каждый день подряд',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ...List.generate(rewards.length, (i) {
          final day = i + 1;
          final amount = economy.config.dailyTokensForStreak(
            i,
            premium: economy.hasPremium,
          );
          final isClaimed = day <= claimedCount;
          final isToday = !claimedToday && day == upcomingDay;
          final isWaiting = claimedToday &&
              day == (economy.dailyStreak + 1).clamp(1, rewards.length);
          final isLocked = !isClaimed && !isToday && !isWaiting;

          return _DailyTimelineRow(
            day: day,
            amount: amount,
            isFirst: i == 0,
            isLast: i == rewards.length - 1,
            isClaimed: isClaimed,
            isToday: isToday,
            isWaiting: isWaiting,
            isLocked: isLocked,
            countdown: isWaiting ? _fmt(economy.untilMidnight) : null,
            onClaim: isToday ? () => _claim(context) : null,
          );
        }),
      ],
    );
  }
}

enum _DayStatus { claimed, today, waiting, locked }

class _DailyTimelineRow extends StatelessWidget {
  const _DailyTimelineRow({
    required this.day,
    required this.amount,
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
  final int amount;
  final bool isFirst;
  final bool isLast;
  final bool isClaimed;
  final bool isToday;
  final bool isWaiting;
  final bool isLocked;
  final String? countdown;
  final VoidCallback? onClaim;

  _DayStatus get _status {
    if (isClaimed) return _DayStatus.claimed;
    if (isToday) return _DayStatus.today;
    if (isWaiting) return _DayStatus.waiting;
    return _DayStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final nodeColor = switch (status) {
      _DayStatus.claimed => const Color(0xFF3DDC97),
      _DayStatus.today => const Color(0xFF3DDC97),
      _DayStatus.waiting => const Color(0xFF7EE0FF),
      _DayStatus.locked => Colors.white24,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (isClaimed || isToday || isWaiting
                            ? nodeColor.withValues(alpha: 0.45)
                            : Colors.white12),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == _DayStatus.claimed
                        ? nodeColor
                        : const Color(0xFF0E1419),
                    border: Border.all(color: nodeColor, width: 2.5),
                  ),
                  child: status == _DayStatus.claimed
                      ? const Icon(Icons.check, size: 11, color: Color(0xFF0E1419))
                      : null,
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (isClaimed
                            ? const Color(0xFF3DDC97).withValues(alpha: 0.45)
                            : Colors.white12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClaim,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isToday
                          ? const Color(0xFF3DDC97).withValues(alpha: 0.12)
                          : const Color(0xFF1A242C),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF3DDC97)
                            : isWaiting
                                ? const Color(0xFF7EE0FF).withValues(alpha: 0.45)
                                : Colors.white10,
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'День $day',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isLocked ? Colors.white38 : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  CrystalCubeIcon(
                                    size: 16,
                                    glow: isToday,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+$amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isToday
                                          ? const Color(0xFF3DDC97)
                                          : isClaimed
                                              ? Colors.white70
                                              : Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _DayActionChip(
                          status: status,
                          countdown: countdown,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayActionChip extends StatelessWidget {
  const _DayActionChip({
    required this.status,
    this.countdown,
  });

  final _DayStatus status;
  final String? countdown;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _DayStatus.claimed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF3DDC97).withValues(alpha: 0.15),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Color(0xFF3DDC97)),
              SizedBox(width: 4),
              Text(
                'Получено',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3DDC97),
                ),
              ),
            ],
          ),
        );
      case _DayStatus.today:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF3DDC97), Color(0xFF1FA876)],
            ),
          ),
          child: const Text(
            'Получить',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E1419),
            ),
          ),
        );
      case _DayStatus.waiting:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF7EE0FF).withValues(alpha: 0.12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ожидание',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7EE0FF),
                ),
              ),
              if (countdown != null)
                Text(
                  countdown!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7EE0FF),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        );
      case _DayStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white10,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 14, color: Colors.white38),
              SizedBox(width: 4),
              Text(
                'Закрыто',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab({required this.economy});

  final EconomyStore economy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Packs',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Чем больше пакет — тем выгоднее цена за кристалл.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ...ShopCatalog.packs.map((offer) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  economy.grantCrystals(offer.crystals);
                  showGameToast(
                    context,
                    message: '+${offer.crystals}',
                    flyTo: ToastFlyTarget.crystals,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const CrystalCubeIcon(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '+${offer.crystals}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        offer.priceLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.18),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Plus',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Daily ×2',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: economy.hasPremium
                    ? null
                    : () {
                        economy.activatePremiumPreview();
                        showGameToast(
                          context,
                          message: 'Plus · Daily ×2',
                          accent: const Color(0xFF3DDC97),
                          icon: const Icon(
                            Icons.workspace_premium,
                            color: Color(0xFF3DDC97),
                          ),
                        );
                      },
                child: Text(
                  economy.hasPremium
                      ? 'Plus'
                      : 'Plus · ${ShopCatalog.subscribePrice}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
