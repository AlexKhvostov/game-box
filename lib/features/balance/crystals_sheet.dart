import 'dart:async';
import 'dart:math' as math;

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
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
    return economy.config.timedBonusTokens;
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
                    unlockProgress: economy.timedBonusUnlockProgress,
                    format: _fmt,
                    readyLabel: l10n.giftReady,
                    onClaim: () {
                      final n = economy.claimTimedBonus();
                      if (n != null) {
                        showGameToast(
                          context,
                          message: l10n.giftToast(n),
                          flyTo: ToastFlyTarget.crystals,
                          festive: true,
                        );
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

class _GiftButton extends StatefulWidget {
  const _GiftButton({
    required this.canClaim,
    required this.amount,
    required this.remaining,
    required this.unlockProgress,
    required this.format,
    required this.readyLabel,
    required this.onClaim,
  });

  final bool canClaim;
  final int amount;
  final Duration? remaining;
  /// 0..1 — сколько «разморозилось» по часовой стрелке.
  final double unlockProgress;
  final String Function(Duration) format;
  final String readyLabel;
  final VoidCallback onClaim;

  @override
  State<_GiftButton> createState() => _GiftButtonState();
}

class _GiftButtonState extends State<_GiftButton>
    with TickerProviderStateMixin {
  late final AnimationController _shake;
  late final AnimationController _pulse;
  late final Animation<double> _shakeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));
    _pulseAnim = Tween<double>(begin: 1, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _onFrozenTap() async {
    if (_shake.isAnimating || _pulse.isAnimating) return;
    await _shake.forward(from: 0);
    _shake.reset();
    for (var i = 0; i < 4; i++) {
      if (!mounted) return;
      await _pulse.forward(from: 0);
      if (!mounted) return;
      await _pulse.reverse();
    }
  }

  void _onTap() {
    if (widget.canClaim) {
      widget.onClaim();
    } else {
      _onFrozenTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canClaim = widget.canClaim;
    final progress = widget.unlockProgress.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _pulse]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 108,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Праздничный «разблокированный» фон
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF8A5C),
                          Color(0xFFE85D75),
                          Color(0xFFC44BFF),
                        ],
                      ),
                    ),
                    child: SizedBox(width: 108, height: 78),
                  ),
                  // Лёд: тает по часовой стрелке
                  if (!canClaim)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FrostClockUnlockPainter(progress: progress),
                      ),
                    ),
                  // Рамка только когда готово (в кулдауне контур рисует painter)
                  if (canClaim)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFD28A).withValues(alpha: 0.65),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8A5C).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Контент
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BonusGiftMark(ready: canClaim),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CrystalCubeIcon(
                              size: 13,
                              glow: canClaim,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '+${widget.amount}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                height: 1.05,
                                color: canClaim
                                    ? const Color(0xFFFFF6DE)
                                    : const Color(0xFFE8F6FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        ScaleTransition(
                          scale: canClaim
                              ? const AlwaysStoppedAnimation(1)
                              : _pulseAnim,
                          child: Text(
                            canClaim
                                ? widget.readyLabel
                                : widget.format(
                                    widget.remaining ?? Duration.zero,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: canClaim
                                  ? Colors.white70
                                  : Color.lerp(
                                      const Color(0xFFB8E7FF),
                                      const Color(0xFFFFFFFF),
                                      _pulse.value,
                                    ),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кулдаун по контуру кнопки: трек всегда виден, заливка по часовой.
class _FrostClockUnlockPainter extends CustomPainter {
  _FrostClockUnlockPainter({required this.progress});

  final double progress;

  static const _radius = 16.0;
  static const _stroke = 6.0;

  Path _contourPath(Size size) {
    final inset = _stroke / 2 + 0.5;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final rr = math.min(_radius - 1, math.min(rect.width, rect.height) / 2);
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    final r = Radius.circular(rr);

    return Path()
      ..moveTo(left + rect.width / 2, top)
      ..lineTo(right - rr, top)
      ..arcToPoint(Offset(right, top + rr), radius: r)
      ..lineTo(right, bottom - rr)
      ..arcToPoint(Offset(right - rr, bottom), radius: r)
      ..lineTo(left + rr, bottom)
      ..arcToPoint(Offset(left, bottom - rr), radius: r)
      ..lineTo(left, top + rr)
      ..arcToPoint(Offset(left + rr, top), radius: r)
      ..lineTo(left + rect.width / 2, top);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final frostAlpha = (0.55 * (1.0 - progress)).clamp(0.0, 0.55);
    if (frostAlpha > 0.02) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(26, 48, 64, frostAlpha),
              Color.fromRGBO(21, 40, 56, frostAlpha + 0.06),
              Color.fromRGBO(30, 58, 78, frostAlpha),
            ],
          ).createShader(rect),
      );
    }

    final path = _contourPath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;

    // Полный контур-трек — всегда виден
    canvas.drawPath(
      metric.extractPath(0, total),
      Paint()
        ..color = const Color(0xFF1A2E3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      metric.extractPath(0, total),
      Paint()
        ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke - 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final filled = total * progress.clamp(0.0, 1.0);
    if (filled > 0.5) {
      final progressPath = metric.extractPath(0, filled);
      canvas.drawPath(
        progressPath,
        Paint()
          ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke + 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        progressPath,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF7EE0FF),
              Color(0xFFB8F4FF),
              Color(0xFFFFD54F),
              Color(0xFF7EE0FF),
            ],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrostClockUnlockPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Понятный бонус-подарок: коробка + бант + лёгкое свечение.
class _BonusGiftMark extends StatelessWidget {
  const _BonusGiftMark({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final lid = ready ? const Color(0xFFFFD54F) : const Color(0xFF7EE0FF);
    final box = ready ? const Color(0xFFFF8A5C) : const Color(0xFF3A5160);
    final ribbon = ready ? const Color(0xFFFFF1C1) : const Color(0xFFB8F4FF);

    return SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ready)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: lid.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          // Коробка
          Positioned(
            bottom: 0,
            child: Container(
              width: 20,
              height: 14,
              decoration: BoxDecoration(
                color: box,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: ribbon.withValues(alpha: 0.55)),
              ),
            ),
          ),
          // Крышка
          Positioned(
            top: 4,
            child: Container(
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color: lid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Вертикальная лента
          Positioned(
            bottom: 0,
            child: Container(
              width: 4,
              height: 14,
              color: ribbon.withValues(alpha: 0.9),
            ),
          ),
          // Бант
          Positioned(
            top: 0,
            child: Icon(
              Icons.loyalty_rounded,
              size: 12,
              color: ribbon,
            ),
          ),
        ],
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      l10n.plusBenefits,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    Text(
                      ' · ',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const CrystalCubeIcon(size: 12, glow: false),
                    const SizedBox(width: 3),
                    const Text(
                      '×2',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD54F),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.plusDailyBoost,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: const Color(0xFFFFECB3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
    final premium = economy.hasPremium;
    final multLabel = _premiumMultLabel(economy);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      children: [
        Text(
          claimedToday
              ? l10n.dailyStreakActive(economy.dailyStreak)
              : l10n.dailyStreakHint,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(rewards.length, (i) {
          final day = i + 1;
          final base = economy.config.dailyTokensForStreak(i, premium: false);
          final amount = economy.config.dailyTokensForStreak(
            i,
            premium: premium,
          );
          final isClaimed = day <= claimedCount;
          final isToday = !claimedToday && day == upcomingDay;
          final isWaiting = claimedToday &&
              day == (economy.dailyStreak + 1).clamp(1, rewards.length);
          final isLocked = !isClaimed && !isToday && !isWaiting;

          return _DailyTimelineRow(
            day: day,
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
            countdown: isWaiting ? format(economy.untilMidnight) : null,
            onClaim: isToday
                ? () {
                    final n = economy.claimDaily();
                    if (n != null) {
                      showGameToast(
                        context,
                        message: l10n.dailyToast(n),
                        accent: const Color(0xFF3DDC97),
                        flyTo: ToastFlyTarget.crystals,
                      );
                    }
                  }
                : null,
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
  final VoidCallback? onClaim;

  _DayStatus get _status {
    if (isClaimed) return _DayStatus.claimed;
    if (isToday) return _DayStatus.today;
    if (isWaiting) return _DayStatus.waiting;
    return _DayStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            width: 26,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (isClaimed || isToday || isWaiting
                            ? nodeColor.withValues(alpha: 0.5)
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
                    border: Border.all(color: nodeColor, width: 2.4),
                    boxShadow: isToday || isClaimed
                        ? [
                            BoxShadow(
                              color: nodeColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: status == _DayStatus.claimed
                      ? const Icon(
                          Icons.check,
                          size: 11,
                          color: Color(0xFF0E1419),
                        )
                      : Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isLocked ? Colors.white38 : Colors.white70,
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (isClaimed
                            ? const Color(0xFF3DDC97).withValues(alpha: 0.5)
                            : Colors.white12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClaim,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isToday
                          ? const Color(0xFF3DDC97).withValues(alpha: 0.12)
                          : const Color(0xFF151C22),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF3DDC97)
                            : isWaiting
                                ? const Color(0xFF7EE0FF)
                                    .withValues(alpha: 0.45)
                                : Colors.white10,
                        width: isToday ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            '${l10n.periodDay} $day',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isLocked ? Colors.white38 : Colors.white70,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: _CrystalRewardBadge(
                              amount: amount,
                              base: base,
                              hasPremium: hasPremium,
                              multLabel: multLabel,
                              emphasized: isToday || !isLocked,
                              showPlusHint: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 86,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _DayActionChip(
                              status: status,
                              countdown: countdown,
                              claimLabel: l10n.claim,
                              claimedLabel: l10n.claimed,
                            ),
                          ),
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

class _CrystalRewardBadge extends StatelessWidget {
  const _CrystalRewardBadge({
    required this.amount,
    this.base,
    this.hasPremium = false,
    this.multLabel,
    this.emphasized = true,
    this.showPlusHint = false,
  });

  final int amount;
  final int? base;
  final bool hasPremium;
  final String? multLabel;
  final bool emphasized;
  /// Только для Daily: формула ×2 / подсказка Plus.
  final bool showPlusHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseAmount = base ?? amount;
    final label = multLabel ?? '2';
    final showActiveDouble =
        showPlusHint && hasPremium && amount != baseAmount;
    final showLockedHint = showPlusHint && !hasPremium;
    final border = showActiveDouble
        ? const Color(0xFFFFD54F).withValues(alpha: 0.55)
        : const Color(0xFF7EE0FF).withValues(alpha: emphasized ? 0.55 : 0.3);
    final glow = showActiveDouble
        ? const Color(0xFFFFD54F).withValues(alpha: 0.22)
        : const Color(0xFF7EE0FF).withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: showActiveDouble
              ? [
                  const Color(0xFFFFD54F).withValues(alpha: 0.2),
                  const Color(0xFF7EE0FF).withValues(alpha: 0.12),
                ]
              : [
                  const Color(0xFF7EE0FF).withValues(alpha: 0.2),
                  const Color(0xFF3DDC97).withValues(alpha: 0.14),
                ],
        ),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CrystalCubeIcon(size: 14, glow: emphasized),
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: showActiveDouble
                  ? const Color(0xFFFFECB3)
                  : const Color(0xFFB8F4FF),
              letterSpacing: 0.2,
              shadows: [
                Shadow(
                  color: showActiveDouble
                      ? const Color(0x88FFD54F)
                      : const Color(0x887EE0FF),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          if (showActiveDouble) ...[
            const SizedBox(width: 6),
            Text(
              l10n.premiumTimesBase(baseAmount, label),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFD54F),
                height: 1,
              ),
            ),
          ] else if (showLockedHint) ...[
            const SizedBox(width: 6),
            Text(
              l10n.premiumTimesLocked(label),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayActionChip extends StatelessWidget {
  const _DayActionChip({
    required this.status,
    required this.claimLabel,
    required this.claimedLabel,
    this.countdown,
  });

  final _DayStatus status;
  final String claimLabel;
  final String claimedLabel;
  final String? countdown;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _DayStatus.claimed:
        return Text(
          claimedLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF3DDC97),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
      case _DayStatus.today:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF3DDC97), Color(0xFF1FA876)],
            ),
          ),
          child: Text(
            claimLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E1419),
            ),
          ),
        );
      case _DayStatus.waiting:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A2830),
            border: Border.all(
              color: const Color(0xFF7EE0FF).withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            countdown ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7EE0FF),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      case _DayStatus.locked:
        return const SizedBox.shrink();
    }
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
              showGameToast(
                context,
                message: l10n.crystalsPlus(n),
                flyTo: ToastFlyTarget.crystals,
              );
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
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shopWatchAd,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          l10n.shopWatchAdSub,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _CrystalRewardBadge(amount: ad.reward),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:
                              const Color(0xFF3DDC97).withValues(alpha: 0.25),
                          border: Border.all(
                            color: const Color(0xFF3DDC97)
                                .withValues(alpha: 0.55),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ...ShopCatalog.packs.map((offer) {
          final packBadge = L10nCatalog.packBadge(l10n, offer.badgeKey);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final n = economy.grantCrystals(offer.crystals);
                showGameToast(
                  context,
                  message: l10n.crystalsPlus(n),
                  flyTo: ToastFlyTarget.crystals,
                );
              },
              child: GamePanel(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                accent: const Color(0xFF7EE0FF),
                child: Row(
                  children: [
                    const CrystalCubeIcon(size: 28),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10nCatalog.packTitle(l10n, offer.id),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (packBadge != null)
                            Text(
                              packBadge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3DDC97),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _CrystalRewardBadge(amount: offer.crystals),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        offer.priceLabel,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
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
                          flyTo: ToastFlyTarget.crystals,
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
                      _CrystalRewardBadge(amount: a.reward),
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
