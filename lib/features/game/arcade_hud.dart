import '../balance/energy_sheet.dart';
import '../../ui/neon_hud_capsule.dart';
import '../../ui/energy_reward_motion.dart';
import '../../ui/game_ui.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'compact_ability_button.dart';
export '../../ui/ability_ring.dart' show AbilityRingPainter;
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/gameplay_config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/hud_fly_targets.dart';
import '../balance/crystals_sheet.dart';

String arcadeTimer(int ms) {
  ms = ms.clamp(0, 99 * 60000);
  return '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
}

class ArcadeHud extends StatefulWidget {
  const ArcadeHud({
    super.key,
    required this.frame,
    required this.timeMs,
    required this.jumpProgress,
    required this.onLivesTap,
    required this.onCrystalsTap,
    required this.onRecordTap,
    required this.onProfileTap,
    this.onLeave,
    this.jumpWarnLit = false,
    this.animationFrame,
    this.compact = false,
    this.isPlaying = false,
    this.riskCount,
    this.runDistance,
    this.jumpRemainingMs,
    this.helmetActive,
    this.helmetEquipped,
    this.onTimerTap,
  });
  final Listenable frame;
  final Listenable? animationFrame;
  final int Function() timeMs;
  final double Function() jumpProgress;
  final double Function()? jumpRemainingMs;

  /// During a round the helmet is spent after one hit, even while rented.
  final bool? helmetActive;

  /// Rental enabled for this round; remains true after its protection breaks.
  final bool? helmetEquipped;

  /// Invoked by holding the timer; ranking has its own top card.
  final VoidCallback? onTimerTap;
  final VoidCallback onLivesTap, onCrystalsTap, onRecordTap, onProfileTap;
  final VoidCallback? onLeave;
  final bool jumpWarnLit, compact, isPlaying;
  final int Function()? riskCount, runDistance;
  @override
  State<ArcadeHud> createState() => _ArcadeHudState();
}

class _ArcadeHudState extends State<ArcadeHud> {
  Timer? _rentTick;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _rentTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final config = context.watch<GameplayConfig>();
    final scores = context.watch<ScoresStore?>();
    final day = scores?.scoresForNamedPeriod('day');
    final topDay = day == null || day.isEmpty ? null : day.first.timeMs;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final l10n = AppLocalizations.of(context);
    if ((economy.hasJumpRental || economy.hasHelmetRental) &&
        (ModalRoute.isCurrentOf(context) ?? true)) {
      _rentTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _rentTick?.cancel();
      _rentTick = null;
    }
    String rent(Duration? d) => d == null
        ? '--:--'
        : '${(d.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    Text amount(String value, {double size = 18, Key? key}) => Text(
      value,
      key: key,
      style: TextStyle(
        fontSize: size,
        height: 1.05,
        color: GameUi.text,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    Widget resource(Widget icon, String value, String label) => SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: 20, child: Center(child: icon)),
                const SizedBox(width: 4),
                amount(value),
              ],
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.05,
                color: GameUi.muted,
              ),
            ),
          ),
        ],
      ),
    );
    Widget card(
      String name,
      String label,
      Widget child,
      VoidCallback action, {
      Key? target,
      int flex = 1,
    }) => Expanded(
      flex: flex,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: !widget.isPlaying,
          label: label,
          child: InkWell(
            key: ValueKey('hud-$name-card'),
            onTap: widget.isPlaying ? null : action,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: target,
              width: double.infinity,
              height: double.infinity,
              decoration: economy.energyEnabled ? null : GameUi.hudPanel(),
              padding: economy.energyEnabled
                  ? const EdgeInsets.all(.5)
                  : const EdgeInsets.all(3),
              child: economy.energyEnabled
                  ? child
                  : Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: child),
                    ),
            ),
          ),
        ),
      ),
    );
    Widget boost(bool helmet) {
      final active = helmet
          ? (widget.helmetEquipped ??
                (economy.energyEnabled
                    ? economy.helmetSelected
                    : economy.hasHelmetRental))
          : (economy.energyEnabled
                ? economy.jumpSelected
                : economy.hasJumpRental);
      final broken = helmet && active && widget.helmetActive == false;
      final energyCost = helmet
          ? economy.energyConfig.helmetExtraCost
          : economy.energyConfig.jumpExtraCost;
      final duration = rent(
        helmet ? economy.helmetRentalRemaining : economy.jumpRentalRemaining,
      );
      final label = helmet ? l10n.rentHelmetTitle : l10n.rentJumpTitle;
      return Tooltip(
        message: economy.energyEnabled
            ? '$label · +$energyCost ${ru ? 'энергия за попытку' : 'energy per run'}'
            : '$label · ${ru ? 'аренда' : 'rent'} $duration',
        child: CompactAbilityButton(
          key: ValueKey(helmet ? 'hud-helmet-button' : 'hud-jump-button'),
          helmet: helmet,
          active: active,
          broken: broken,
          ru: ru,
          progress: widget.jumpProgress,
          remainingMs: () =>
              widget.jumpRemainingMs?.call() ??
              (1 - widget.jumpProgress()).clamp(0.0, 1.0) *
                  config.jumpCooldownSec.clamp(2.0, 3600.0) *
                  1000,
          frame: widget.animationFrame ?? widget.frame,
          onTap: widget.isPlaying
              ? null
              : () => economy.energyEnabled
                    ? showEnergyAbilitySheet(context, helmet: helmet)
                    : showCrystalsSheet(context, initialTab: 2),
        ),
      );
    }

    final clock = RepaintBoundary(
      child: ListenableBuilder(
        listenable: widget.frame,
        builder: (context, _) => GestureDetector(
          key: const ValueKey('hud-debug-toggle'),
          behavior: HitTestBehavior.opaque,
          onLongPress: widget.onTimerTap,
          child: SizedBox.expand(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    amount(
                      arcadeTimer(widget.timeMs()),
                      size: 30,
                      key: const ValueKey('arcade-top-timer'),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${ru ? 'Риск' : 'Risk'} ${widget.riskCount?.call() ?? 0} · ${ru ? 'Пробег' : 'Run'} ${widget.runDistance?.call() ?? 0}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        color: GameUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.hasBoundedHeight
              ? math.min(104.0, constraints.maxHeight)
              : 104.0;
          return SizedBox(
            key: const ValueKey('arcade-hud-content'),
            height: height,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (economy.energyEnabled) ...[
                        EnergyRewardCounter(
                          economy: economy,
                          builder: (amount) => card(
                            'energy',
                            '${ru ? 'Энергия' : 'Energy'}: $amount',
                            const NeonHudEnergy(),
                            widget.onCrystalsTap,
                            target: HudFlyTargets.energyKey,
                            flex: 17,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        card(
                          'lives',
                          '${l10n.statLives}: ${economy.lives}',
                          resource(
                            const Icon(
                              Icons.favorite,
                              color: GameUi.heart,
                              size: 18,
                            ),
                            '${economy.lives}',
                            l10n.statLives,
                          ),
                          widget.onLivesTap,
                          target: HudFlyTargets.livesKey,
                        ),
                        const SizedBox(width: 4),
                        card(
                          'crystals',
                          '${l10n.crystals}: ${economy.tokens}',
                          resource(
                            const CrystalCubeIcon(size: 20, glow: false),
                            '${economy.tokens}',
                            l10n.crystals,
                          ),
                          widget.onCrystalsTap,
                          target: HudFlyTargets.crystalsKey,
                        ),
                        const SizedBox(width: 4),
                      ],
                      card(
                        'ranking',
                        ru
                            ? 'Рейтинг · лучший результат сегодня'
                            : 'Leaderboard · best today',
                        economy.energyEnabled
                            ? NeonHudRecord(
                                value: topDay == null
                                    ? '—'
                                    : (topDay / 1000).toStringAsFixed(3),
                                label: ru ? 'Топ дня' : 'Today’s best',
                              )
                            : resource(
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  color: GameUi.yellow,
                                  size: 16,
                                ),
                                topDay == null
                                    ? '—'
                                    : (topDay / 1000).toStringAsFixed(3),
                                ru ? 'Топ дня' : 'Today’s best',
                              ),
                        widget.onRecordTap,
                        target: const ValueKey('hud-record-button'),
                        flex: economy.energyEnabled ? 10 : 1,
                      ),
                      const SizedBox(width: 4),
                      card(
                        'account',
                        '${ru ? 'Аккаунт · мой рекорд' : 'Account · my best'} ${(economy.bestTimeMs / 1000).toStringAsFixed(3)}',
                        economy.energyEnabled
                            ? NeonHudRecord(
                                account: true,
                                value: (economy.bestTimeMs / 1000)
                                    .toStringAsFixed(3),
                                label: ru ? 'Мой рекорд' : 'My best',
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    key: const ValueKey('hud-player-icon'),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: GameUi.background,
                                      border: Border.all(color: GameUi.cyan),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.asset(
                                      'assets/branding/ui/hud-player-portrait-v1.png',
                                      cacheWidth: 128,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  amount(
                                    (economy.bestTimeMs / 1000).toStringAsFixed(
                                      3,
                                    ),
                                    size: 12,
                                    key: const ValueKey('hud-account-record'),
                                  ),
                                ],
                              ),
                        widget.onProfileTap,
                        flex: economy.energyEnabled ? 10 : 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (widget.onLeave != null)
                          IconButton(
                            onPressed: widget.onLeave,
                            icon: const Icon(Icons.arrow_back, size: 18),
                          ),
                        SizedBox(
                          width: 72,
                          child: config.helmetEnabled ? boost(true) : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: clock),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 72,
                          child: config.jumpEnabled ? boost(false) : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
