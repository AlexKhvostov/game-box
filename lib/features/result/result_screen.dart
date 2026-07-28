import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/economy_config.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_catalog.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_toast.dart';
import '../../ui/info_tip_bubble.dart';
import '../../ui/resting_cube_icon.dart';
import '../balance/crystals_sheet.dart';
import 'share_social_sheet.dart';

/// Результат: подложка + появление.
class ResultOverlay extends StatefulWidget {
  const ResultOverlay({
    super.key,
    required this.timeMs,
    required this.runDistance,
    required this.riskCount,
    this.newlyUnlockedEarnIds = const [],
    required this.onOk,
    required this.onShare,
  });

  final int timeMs;
  final double runDistance;
  final int riskCount;
  final List<String> newlyUnlockedEarnIds;
  final VoidCallback onOk;
  final VoidCallback onShare;

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  Timer? _crystalFlyTimer;
  int _crystalsPending = 0;
  EconomyStore? _economy;
  bool _sharing = false;
  /// `risk` | `run` | null
  String? _statTip;
  final GlobalKey _riskStatKey = GlobalKey();
  final GlobalKey _runStatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.12, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _economy = context.read<EconomyStore>();
      context.read<ScoresStore>().refreshIfStale();
      _scheduleCrystalFlights();
    });
  }

  int _crystalsFromRisk(EconomyStore economy) {
    final every = economy.config.riskRewardEvery.clamp(1, 999);
    final reward = economy.config.riskRewardTokens.clamp(0, 999);
    if (reward <= 0) return 0;
    return widget.riskCount ~/ every * reward;
  }

  int _crystalsFromRun(EconomyStore economy) {
    final every = economy.config.runRewardEvery.clamp(1, 999999);
    final reward = economy.config.runRewardTokens.clamp(0, 999);
    if (reward <= 0) return 0;
    return widget.runDistance.round() ~/ every * reward;
  }

  void _scheduleCrystalFlights() {
    final economy = _economy ?? context.read<EconomyStore>();
    _economy = economy;
    _crystalsPending = _crystalsFromRisk(economy) + _crystalsFromRun(economy);
    if (_crystalsPending <= 0) return;

    void fireNext() {
      if (!mounted || _crystalsPending <= 0) return;
      economy.grantCrystals(1);
      _crystalsPending--;
      final l10n = AppLocalizations.of(context);
      showGameToast(
        context,
        message: l10n.crystalsPlus(1),
        flyTo: ToastFlyTarget.crystals,
      );
      if (_crystalsPending > 0) {
        _crystalFlyTimer = Timer(const Duration(milliseconds: 360), fireNext);
      }
    }

    _crystalFlyTimer = Timer(const Duration(milliseconds: 520), fireNext);
  }

  void _flushPendingCrystals() {
    _crystalFlyTimer?.cancel();
    _crystalFlyTimer = null;
    final n = _crystalsPending;
    _crystalsPending = 0;
    if (n <= 0) return;
    final economy = _economy;
    if (economy != null) {
      economy.grantCrystals(n);
    } else if (mounted) {
      context.read<EconomyStore>().grantCrystals(n);
    }
  }

  @override
  void dispose() {
    _crystalFlyTimer?.cancel();
    final n = _crystalsPending;
    _crystalsPending = 0;
    if (n > 0) {
      _economy?.grantCrystals(n);
    }
    _c.dispose();
    super.dispose();
  }

  String _formatTime(int ms) => (ms / 1000.0).toStringAsFixed(3);

  void _onOk() {
    _flushPendingCrystals();
    widget.onOk();
  }

  void _onSaveToLeaderboard() {
    _flushPendingCrystals();
    widget.onShare();
  }

  Future<void> _onShareSocial() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final scores = context.read<ScoresStore>();
      final rank = scores.rankFor(widget.timeMs, period: 'day');
      await showShareSocialSheet(
        context,
        timeMs: widget.timeMs,
        betterPercent: rank.totalCount == 0 ? null : rank.percentile,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openEarn() async {
    await showCrystalsSheet(context, initialTab: 3);
  }

  void _toggleTip(String tip) {
    final next = _statTip == tip ? null : tip;
    setState(() => _statTip = next);
    if (next != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _statTip == next) setState(() {});
      });
    }
  }

  List<EarnAction> _unlockedActions(EconomyStore economy) {
    final out = <EarnAction>[];
    for (final id in widget.newlyUnlockedEarnIds) {
      for (final a in economy.config.earnActions) {
        if (a.id == id) {
          out.add(a);
          break;
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = theme.colorScheme.primary;
    final economy = context.watch<EconomyStore>();
    final rank =
        context.watch<ScoresStore>().rankFor(widget.timeMs, period: 'day');

    final riskEvery = economy.config.riskRewardEvery.clamp(1, 999);
    final riskReward = economy.config.riskRewardTokens.clamp(0, 999);
    final riskEarned =
        riskReward > 0 ? widget.riskCount ~/ riskEvery * riskReward : 0;
    final runEvery = economy.config.runRewardEvery.clamp(1, 999999);
    final runReward = economy.config.runRewardTokens.clamp(0, 999);
    final runDist = widget.runDistance.round();
    final runEarned = runReward > 0 ? runDist ~/ runEvery * runReward : 0;

    final rankText = rank.totalCount == 0
        ? l10n.newScore
        : l10n.rankToday(rank.percentile);

    final unlocked = _unlockedActions(economy);

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    const Color(0xFF0A1014).withValues(alpha: 0.88),
                    const Color(0xFF070B0E).withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: unlocked.isEmpty ? 12 : 12.0 + unlocked.length * 76,
                    bottom: 12,
                  ),
                  child: SlideTransition(
                    position: _slide,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 18, 20, 18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(
                                        accent,
                                        const Color(0xFF1A242C),
                                        0.72,
                                      )!,
                                      const Color(0xFF12181E),
                                      const Color(0xFF0E1419),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Логотип / имя игры
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: const Color(0xFF0C1218)
                                            .withValues(alpha: 0.72),
                                        border: Border.all(
                                          color: const Color(0xFF7EE0FF)
                                              .withValues(alpha: 0.28),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          6,
                                          14,
                                          6,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const RestingCubeIcon(size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.appTitle,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.6,
                                                height: 1,
                                                color: Color(0xFFB8F4FF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      l10n.newScore.toUpperCase(),
                                      style: TextStyle(
                                        letterSpacing: 2.4,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(widget.timeMs),
                                      style: TextStyle(
                                        fontSize: 52,
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                        height: 1,
                                        letterSpacing: -0.5,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.seconds,
                                      style: TextStyle(
                                        letterSpacing: 1.6,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      rankText,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        height: 1.4,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _CompactStat(
                                            key: _riskStatKey,
                                            label: l10n.playInfoNear,
                                            value: '${widget.riskCount}',
                                            accent: const Color(0xFFFFC107),
                                            selected: _statTip == 'risk',
                                            onTap: () => _toggleTip('risk'),
                                            earned: riskEarned > 0
                                                ? l10n.riskCrystalsEarned(
                                                    riskEarned)
                                                : null,
                                            rateEvery: riskReward > 0
                                                ? riskEvery
                                                : null,
                                            rateReward: riskReward > 0
                                                ? riskReward
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _CompactStat(
                                            key: _runStatKey,
                                            label: l10n.playInfoRun,
                                            value: '$runDist',
                                            accent: const Color(0xFF7EE0FF),
                                            selected: _statTip == 'run',
                                            onTap: () => _toggleTip('run'),
                                            earned: runEarned > 0
                                                ? l10n.riskCrystalsEarned(
                                                    runEarned)
                                                : null,
                                            rateEvery: runReward > 0
                                                ? runEvery
                                                : null,
                                            rateReward: runReward > 0
                                                ? runReward
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _sharing ? null : _onShareSocial,
                                    icon: _sharing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.ios_share_rounded,
                                            size: 18,
                                          ),
                                    label: Text(l10n.shareSocial),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color:
                                            accent.withValues(alpha: 0.55),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _onSaveToLeaderboard,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.28),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(l10n.share),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _onOk,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(l10n.ok),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
            if (unlocked.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in unlocked) ...[
                          _EarnUnlockBanner(
                            title: l10n.earnBonusUnlocked(
                              L10nCatalog.earnTitle(l10n, action),
                            ),
                            subtitle: l10n.earnUnlockedBannerTap,
                            onTap: _openEarn,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (_statTip != null)
              Positioned.fill(
                child: InfoTipBubble(
                  anchorKey:
                      _statTip == 'risk' ? _riskStatKey : _runStatKey,
                  body: _statTip == 'risk'
                      ? l10n.riskTipHow
                      : l10n.runTipHow,
                  footnote: _statTip == 'risk'
                      ? l10n.riskTipConvert(
                          riskEvery,
                          riskReward > 0 ? riskReward : 1,
                        )
                      : l10n.runTipConvert(
                          runEvery,
                          runReward > 0 ? runReward : 1,
                        ),
                  accent: _statTip == 'risk'
                      ? const Color(0xFFFFC107)
                      : const Color(0xFF7EE0FF),
                  onDismiss: () => setState(() => _statTip = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EarnUnlockBanner extends StatelessWidget {
  const _EarnUnlockBanner({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B3A2E),
                Color(0xFF122018),
                Color(0xFF0E1612),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF3DDC97).withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3DDC97).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3DDC97).withValues(alpha: 0.16),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: Color(0xFF3DDC97),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFFE8EEF4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Компактный стат: лейбл · значение · (+кристалы); курс справа сверху.
class _CompactStat extends StatelessWidget {
  const _CompactStat({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.earned,
    this.rateEvery,
    this.rateReward,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final String value;
  final Color accent;
  final String? earned;
  final int? rateEvery;
  final int? rateReward;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasRate =
        rateEvery != null && rateReward != null && rateReward! > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withValues(alpha: selected ? 0.32 : 0.22),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.75 : 0.32),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: accent.withValues(alpha: selected ? 0.95 : 0.55),
                  ),
                  if (hasRate) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rateEvery!}=',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const CrystalCubeIcon(size: 9),
                        if (rateReward! > 1)
                          Text(
                            '$rateReward',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accent.withValues(alpha: 0.85),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (earned != null) ...[
                    const CrystalCubeIcon(size: 11),
                    const SizedBox(width: 3),
                    Text(
                      earned!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7EE0FF),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
