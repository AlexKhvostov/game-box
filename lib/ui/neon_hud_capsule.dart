import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/economy_store.dart';
import 'energy_reward_motion.dart';
import '../features/leaderboard/ranking_art.dart';

/// Display-only projection of the same contract/clock used by the energy sheet.
class HudBonusState {
  const HudBonusState({
    required this.known,
    required this.ready,
    required this.progress,
    required this.remaining,
  });
  factory HudBonusState.from(EconomyStore economy) {
    final bonus = economy.simpleEnergyBonus;
    final known =
        bonus != null &&
        economy.energyClockSynchronized &&
        !economy.energySubscriptionPending;
    return HudBonusState(
      known: known,
      ready: known && economy.simpleBonusReady,
      progress: known
          ? (1 - bonus.remainingFraction(economy.energyNow)).clamp(0, 1)
          : 0,
      remaining: known ? bonus.remainingAt(economy.energyNow) : Duration.zero,
    );
  }
  final bool known, ready;
  final double progress;
  final Duration remaining;
}

class NeonHudCapsule extends StatelessWidget {
  const NeonHudCapsule({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _CapsulePainter(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: child,
    ),
  );
}

class NeonHudEnergy extends StatefulWidget {
  const NeonHudEnergy({super.key});
  @override
  State<NeonHudEnergy> createState() => _NeonHudEnergyState();
}

class _NeonHudEnergyState extends State<NeonHudEnergy>
    with WidgetsBindingObserver {
  Timer? _tick;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _tick?.cancel();
      _tick = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final state = HudBonusState.from(economy);
    final visible = _foreground && (ModalRoute.isCurrentOf(context) ?? true);
    if (visible && state.known) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final seconds = state.remaining.inSeconds;
    final status = !state.known
        ? (ru ? 'Бонус: уточняем состояние' : 'Bonus status unavailable')
        : state.ready
        ? (ru ? 'Бонус готов' : 'Bonus ready')
        : '${ru ? 'До бонуса' : 'Bonus in'} ${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final pulse = state.ready && !MediaQuery.disableAnimationsOf(context)
        ? .86 +
              .14 *
                  math.sin(
                    economy.energyNow.millisecondsSinceEpoch /
                        2800 *
                        math.pi *
                        2,
                  )
        : 1.0;
    return EnergyRewardCounter(
      economy: economy,
      builder: (displayBalance) => Semantics(
        label: '${ru ? 'Энергия' : 'Energy'}: $displayBalance. $status',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = MediaQuery.sizeOf(context).width <= 335;
              final diameter = math
                  .min(narrow ? 34.0 : 38.0, box.maxHeight - 2)
                  .clamp(12.0, 38.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _CapsulePainter()),
                  ),
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 0,
                    width: narrow ? 18 : 22,
                    child: Center(
                      child: Icon(
                        Icons.bolt_rounded,
                        color: const Color(0xFFFFF168),
                        size: narrow ? 18 : 22,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: diameter + 3,
                    right: diameter + 3,
                    top: 5,
                    bottom: 5,
                    child: FittedBox(
                      key: const ValueKey('hud-energy-amount'),
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$displayBalance',
                        style: const TextStyle(
                          color: Color(0xFFFFF16F),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(color: Color(0x80FFD74F), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 0,
                    bottom: 0,
                    width: diameter,
                    child: Center(
                      child: SizedBox.square(
                        dimension: diameter,
                        child: CustomPaint(
                          key: const ValueKey('hud-bonus-ring'),
                          painter: HudBonusRingPainter(
                            progress: state.progress,
                            ready: state.ready,
                            known: state.known,
                            glow: pulse,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(diameter * .14),
                            child: DecoratedBox(
                              key: const ValueKey('energy-capsule-plus-disc'),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFAAFCFF),
                                  width: .8,
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF066398),
                                    Color(0xFF002145),
                                    Color(0xFF034576),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                key: const ValueKey('hud-energy-plus'),
                                size: diameter * .55,
                                color: const Color(0xFFB9F8FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class NeonHudRecord extends StatelessWidget {
  const NeonHudRecord({
    super.key,
    required this.value,
    required this.label,
    this.account = false,
  });
  final String value, label;
  final bool account;
  @override
  Widget build(BuildContext context) => NeonHudCapsule(
    child: LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 85;
        return Row(
          children: [
            if (account)
              Container(
                key: const ValueKey('hud-player-icon'),
                width: narrow ? 23 : 27,
                height: narrow ? 23 : 27,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF48EBFF)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/branding/ui/hud-player-portrait-v1.png',
                  cacheWidth: 128,
                  fit: BoxFit.contain,
                ),
              )
            else
              RankingArt(
                'trophy',
                width: narrow ? 14 : 18,
                height: narrow ? 20 : 24,
              ),
            const SizedBox(width: 3),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        key: account
                            ? const ValueKey('hud-account-record')
                            : null,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: narrow ? 12 : 14,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: narrow ? 7.5 : 8.5,
                          height: 1.1,
                          color: const Color(0xFFB7E8FC),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
            const SizedBox(
              width: 6,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 12,
                color: Color(0xFF58F1FF),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class HudBonusRingPainter extends CustomPainter {
  const HudBonusRingPainter({
    required this.progress,
    required this.ready,
    required this.known,
    this.glow = 1,
  });
  final double progress, glow;
  final bool ready, known;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF285874)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    if (!known) return;
    final color = ready ? const Color(0xFFFFF17E) : const Color(0xFF35F2FF);
    final sweep = progress.clamp(0, 1) * math.pi * 2;
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: .5 * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    final dot = center + Offset(math.sin(sweep), -math.cos(sweep)) * radius;
    canvas.drawCircle(
      dot,
      1.2,
      Paint()
        ..color = ready ? const Color(0xFFFFF8CE) : const Color(0xFFC9FFFF),
    );
  }

  @override
  bool shouldRepaint(HudBonusRingPainter old) =>
      old.progress != progress ||
      old.ready != ready ||
      old.known != known ||
      old.glow != glow;
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0C6087),
            Color(0xFF06416A),
            Color(0xFF001A30),
            Color(0xFF022F49),
          ],
          stops: [0, .12, .63, 1],
        ).createShader(rect),
    );
    for (final (inset, color, width) in const [
      (1.0, Color(0xFF08D8F0), 1.1),
      (3.0, Color(0xFF8DF7FF), 1.1),
      (5.0, Color(0x5539D6FF), .7),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(inset),
          Radius.circular(size.height / 2 - inset),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
    final line = Rect.fromLTWH(size.width * .2, 3, size.width * .6, 1.1);
    canvas.drawRect(
      line,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0038C9FF), Color(0xFFE7FFFF), Color(0x0038C9FF)],
        ).createShader(line),
    );
  }

  @override
  bool shouldRepaint(_CapsulePainter old) => false;
}
