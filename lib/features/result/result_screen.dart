import '../../ui/energy_widgets.dart';
import '../../ui/game_ui.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/economy_config.dart';
import '../../domain/arcade_rules.dart';
import '../../domain/round_delivery.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_catalog.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_toast.dart';
import '../balance/crystals_sheet.dart';
import 'share_social_sheet.dart';
import 'run_summary.dart';

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
    this.rewardClaimed = true,
    this.onClaimReward,
    this.previousBestTimeMs,
  });

  final int timeMs;
  final double runDistance;
  final int riskCount;
  final List<String> newlyUnlockedEarnIds;
  final VoidCallback onOk;
  final VoidCallback onShare;
  final bool rewardClaimed;
  final Future<bool> Function()? onClaimReward;
  final int? previousBestTimeMs;

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
  Timer? _entryWorkTimer;
  int _crystalsPending = 0;
  int _flightsLeft = 0;
  EconomyStore? _economy;
  bool _sharing = false;

  bool _claiming = false;
  late bool _rewardClaimed;

  @override
  void initState() {
    super.initState();
    _rewardClaimed = widget.rewardClaimed;
    _c = AnimationController(
      vsync: this,
      duration: GameUi.instantWindows
          ? Duration.zero
          : const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.98,
      end: 1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    if (GameUi.instantWindows) _c.value = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _economy = context.read<EconomyStore>();
      // Network notifications and reward effects must not compete with entry.
      void afterEntry() {
        if (!mounted) return;
        context.read<ScoresStore>().refreshIfStale();
        if (_rewardClaimed) _scheduleCrystalFlights();
      }

      if (GameUi.instantWindows) {
        // Display immediately, still keep network/rewards off its first frame.
        _entryWorkTimer = Timer(const Duration(milliseconds: 320), afterEntry);
      } else {
        _c.forward().then((_) => afterEntry());
      }
    });
  }

  int _crystalsFromRisk(EconomyStore economy) => economy.energyEnabled
      ? widget.riskCount ~/ max(1, economy.config.riskRewardEvery)
      : ArcadeRules.riskReward(economy.config, widget.riskCount);

  int _crystalsFromRun(EconomyStore economy) => economy.energyEnabled
      ? widget.runDistance.round() ~/ max(1, economy.config.runRewardEvery)
      : ArcadeRules.runReward(economy.config, widget.runDistance.round());
  void _scheduleCrystalFlights() {
    final economy = _economy ?? context.read<EconomyStore>();
    _economy = economy;
    // Energy receipts are presented once from the confirmed wallet delta.
    // Keep the old split crystal flights only for the legacy economy.
    if (economy.energyEnabled) return;
    _crystalsPending = _crystalsFromRisk(economy) + _crystalsFromRun(economy);
    _flightsLeft = min(3, _crystalsPending);
    if (_crystalsPending <= 0) return;

    void fireNext() {
      if (!mounted || _crystalsPending <= 0) return;
      // Balance was already credited when the round finished.
      final amount = (_crystalsPending / max(1, _flightsLeft)).ceil();
      _crystalsPending -= amount;
      _flightsLeft--;
      final l10n = AppLocalizations.of(context);
      showGameToast(
        context,
        message: economy.energyEnabled
            ? '+$amount ⚡'
            : l10n.crystalsPlus(amount),
        flyTo: economy.energyEnabled
            ? ToastFlyTarget.energy
            : ToastFlyTarget.crystals,
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
    _crystalsPending = 0;
  }

  @override
  void dispose() {
    _entryWorkTimer?.cancel();
    _crystalFlyTimer?.cancel();
    _crystalsPending = 0;
    _c.dispose();
    super.dispose();
  }

  String _formatTime(int ms) => (ms / 1000.0).toStringAsFixed(3);

  bool _closed = false;
  void _onOk() {
    if (_closed) return;
    _closed = true;
    _flushPendingCrystals();
    widget.onOk();
  }

  void _onOpenLeaderboard() {
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
        riskCount: widget.riskCount,
        runSteps: widget.runDistance.round(),
        betterPercent: rank.totalCount == 0 || !rank.percentileKnown
            ? null
            : rank.percentile,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openEarn() async {
    await showCrystalsSheet(context, initialTab: 3);
  }

  Future<void> _claimReward() async {
    if (_claiming || _rewardClaimed || widget.onClaimReward == null) return;
    setState(() => _claiming = true);
    try {
      final claimed = await widget.onClaimReward!();
      if (!mounted || !claimed) return;
      setState(() => _rewardClaimed = true);
      _scheduleCrystalFlights();
    } finally {
      if (mounted) setState(() => _claiming = false);
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

  String _tr(String ru, String en) =>
      Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

  Future<void> _showTip(String tip, EconomyStore economy) async {
    final l10n = AppLocalizations.of(context);
    final risk = _crystalsFromRisk(economy);
    final run = _crystalsFromRun(economy);
    final reward = tip == 'reward';
    await showDialog<void>(
      animationStyle: GameUi.windowAnimationStyle,
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          key: ValueKey('result-$tip-tip'),
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(14),
          decoration: GameUi.panel(radius: 14),
          child: SingleChildScrollView(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: GameUi.ink,
                fontSize: 13,
                height: 1.4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reward
                        ? _tr('За что награда', 'How you earned it')
                        : tip == 'risk'
                        ? _tr('Что такое риск', 'What is risk?')
                        : _tr('Как считается пробег', 'How distance works'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: GameUi.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reward
                        ? economy.energyEnabled
                              ? _tr(
                                  'Энергия складывается из риска и пробега этой попытки.',
                                  'Energy comes from risk and distance in this run.',
                                )
                              : _tr(
                                  'Кристаллы складываются из риска и пробега этой попытки.',
                                  'Crystals come from risk and distance in this run.',
                                )
                        : tip == 'risk'
                        ? l10n.riskTipHow
                        : l10n.runTipHow,
                    style: const TextStyle(
                      color: GameUi.ink,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (reward) ...[
                    const SizedBox(height: 10),
                    _RewardLine(
                      label: '${l10n.playInfoNear}: ${widget.riskCount}',
                      amount: risk,
                    ),
                    _RewardLine(
                      label:
                          '${l10n.playInfoRun}: ${widget.runDistance.round()}',
                      amount: run,
                    ),
                    _RewardLine(
                      label: _tr('Всего', 'Total'),
                      amount: risk + run,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    economy.energyEnabled
                        ? _tr(
                            'За каждые ${max(1, economy.config.riskRewardEvery)} рисков — 1 ⚡. За каждые ${max(1, economy.config.runRewardEvery)} шагов — 1 ⚡.',
                            'Every ${max(1, economy.config.riskRewardEvery)} risks: 1 ⚡. Every ${max(1, economy.config.runRewardEvery)} steps: 1 ⚡.',
                          )
                        : reward
                        ? '${l10n.riskTipConvert(max(1, economy.config.riskRewardEvery), max(0, economy.config.riskRewardTokens))}\n${l10n.runTipConvert(max(1, economy.config.runRewardEvery), max(0, economy.config.runRewardTokens))}'
                        : tip == 'risk'
                        ? l10n.riskTipConvert(
                            max(1, economy.config.riskRewardEvery),
                            max(0, economy.config.riskRewardTokens),
                          )
                        : l10n.runTipConvert(
                            max(1, economy.config.runRewardEvery),
                            max(0, economy.config.runRewardTokens),
                          ),
                    style: const TextStyle(
                      color: GameUi.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(_tr('Понятно', 'Got it')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final economy = context.watch<EconomyStore>();
    final scores = context.watch<ScoresStore>();
    final earned = _crystalsFromRisk(economy) + _crystalsFromRun(economy);
    final attempt = scores.latestAttempt;
    final matchingAttempt = attempt != null && attempt.timeMs == widget.timeMs;
    final credited = economy.energyEnabled
        ? matchingAttempt && attempt.shared
        : _rewardClaimed;
    final pending = matchingAttempt && scores.isAttemptPending(attempt.id);
    final practice = matchingAttempt && !attempt.shared && !pending;
    final saveStatus = matchingAttempt
        ? attempt.shared
              ? l10n.scoreAutoSaved
              : attempt.deliveryError != null
              ? RoundDelivery.message(
                  attempt.deliveryError!,
                  ru: Localizations.localeOf(context).languageCode == 'ru',
                )
              : pending
              ? l10n.scoreSyncPending
              : l10n.scorePracticeOnly
        : l10n.scoreAutoSave;
    final previousBest = widget.previousBestTimeMs ?? economy.bestTimeMs;
    final isRecord = widget.timeMs > previousBest;
    final unlocked = _unlockedActions(economy);
    final seconds = _tr('с', 's');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onOk();
      },
      child: FadeTransition(
        opacity: _fade,
        child: RepaintBoundary(
          child: Material(
            color: GameUi.modalBarrier,
            child: GestureDetector(
              key: const ValueKey('result-backdrop'),
              behavior: HitTestBehavior.opaque,
              onTap: _onOk,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: RunSummary(
                    title: _tr('Результат попытки', 'Run result'),
                    headline: isRecord
                        ? _tr('Новый рекорд!', 'New personal best!')
                        : _tr('Ваш результат', 'Your result'),
                    time: '${_formatTime(widget.timeMs)} $seconds',
                    best:
                        '${isRecord && previousBest > 0 ? _tr('Предыдущий рекорд', 'Previous best') : _tr('Ваш рекорд', 'Your best')}: ${_formatTime(isRecord && previousBest > 0 ? previousBest : max(widget.timeMs, economy.bestTimeMs))} $seconds',
                    riskLabel: l10n.playInfoNear,
                    runLabel: _tr('Шаги', 'Steps'),
                    risks: widget.riskCount,
                    steps: widget.runDistance.round(),
                    riskBonus: _crystalsFromRisk(economy),
                    runBonus: _crystalsFromRun(economy),
                    credited: credited,
                    onRisk: () => _showTip('risk', economy),
                    onRun: () => _showTip('run', economy),
                    claim:
                        !economy.energyEnabled && !_rewardClaimed && earned > 0
                        ? TextButton.icon(
                            key: const ValueKey('result-claim-reward'),
                            onPressed: _claiming || widget.onClaimReward == null
                                ? null
                                : _claimReward,
                            icon: _claiming
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : economy.energyEnabled
                                ? const Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                    color: energyNeon,
                                  )
                                : const CrystalCubeIcon(size: 14, glow: false),
                            label: Text(
                              _tr(
                                'Получить бонус +$earned',
                                'Collect bonus +$earned',
                              ),
                            ),
                          )
                        : null,
                    unlocked: unlocked.isEmpty
                        ? null
                        : TextButton(
                            onPressed: _openEarn,
                            child: Text(
                              '${l10n.earnBonusUnlocked(L10nCatalog.earnTitle(l10n, unlocked.first))}${unlocked.length > 1 ? ' · +${unlocked.length - 1}' : ''}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                    status: _ResultSaveStatus(
                      status: saveStatus,
                      pending: pending,
                      practice: practice,
                    ),
                    actions: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _onOpenLeaderboard,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE4F6FF),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(l10n.leaderboardTitle),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _sharing ? null : _onShareSocial,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE4F6FF),
                                ),
                                icon: const Icon(
                                  Icons.ios_share_rounded,
                                  size: 15,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(l10n.shareSocial),
                                ),
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          key: const ValueKey('result-replay'),
                          onPressed: _onOk,
                          style: GameUi.replayStyle(context),
                          icon: const Icon(Icons.replay_rounded, size: 24),
                          label: Text(_tr('Ещё раз', 'Play again')),
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
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.label, required this.amount});
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: GameUi.ink)),
        ),
        Text('+$amount', style: const TextStyle(color: GameUi.ink)),
        const SizedBox(width: 4),
        context.watch<EconomyStore?>()?.energyEnabled == true
            ? const Icon(Icons.bolt_rounded, size: 14, color: energyNeon)
            : const CrystalCubeIcon(size: 14),
      ],
    ),
  );
}

/// Reserved status area prevents the dialog jumping when sync acknowledges a run.
class _ResultSaveStatus extends StatelessWidget {
  const _ResultSaveStatus({
    required this.status,
    required this.pending,
    required this.practice,
  });
  final String status;
  final bool pending, practice;
  static final _heightCache = <(double, double, TextDirection), double>{};
  static const style = TextStyle(
    fontFamily: 'Roboto',
    color: Color(0xFFC4DEEB),
    fontSize: 11,
    height: 1.3,
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final key = (
        constraints.maxWidth,
        MediaQuery.textScalerOf(context).scale(11),
        Directionality.of(context),
      );
      var height = _heightCache[key] ?? 0.0;
      if (!_heightCache.containsKey(key)) {
        for (final locale in const [Locale('ru'), Locale('en')]) {
          final l10n = lookupAppLocalizations(locale);
          for (final text in [
            l10n.scoreAutoSaved,
            l10n.scoreSyncPending,
            l10n.scorePracticeOnly,
            l10n.scoreAutoSave,
          ]) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
            )..layout(maxWidth: max(1, constraints.maxWidth - 37));
            height = max(height, painter.height);
            painter.dispose();
          }
        }
        if (_heightCache.length >= 8) _heightCache.clear();
        _heightCache[key] = height;
      }
      return Container(
        constraints: BoxConstraints(minHeight: height + 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: pending || practice
              ? const Color(0x802D5066)
              : const Color(0x80103738),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              pending
                  ? Icons.cloud_upload_outlined
                  : practice
                  ? Icons.offline_bolt_outlined
                  : Icons.check_circle_rounded,
              size: 16,
              color: const Color(0xFF90EED9),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                status,
                key: const ValueKey('result-save-status'),
                style: style,
              ),
            ),
          ],
        ),
      );
    },
  );
}
