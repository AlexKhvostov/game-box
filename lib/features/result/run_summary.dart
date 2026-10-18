import 'package:provider/provider.dart';
import '../../data/economy_store.dart';
import '../../ui/energy_widgets.dart';
import 'package:flutter/material.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_run_scene.dart';
import '../../ui/crystal_cube_icon.dart';

/// A run first, its earned bonuses second. The two metrics share fixed columns.
class RunSummary extends StatelessWidget {
  const RunSummary({
    super.key,
    required this.title,
    required this.headline,
    required this.time,
    required this.best,
    required this.riskLabel,
    required this.runLabel,
    required this.risks,
    required this.steps,
    required this.riskBonus,
    required this.runBonus,
    required this.credited,
    required this.onRisk,
    required this.onRun,
    required this.status,
    required this.actions,
    this.claim,
    this.unlocked,
  });
  final String title, headline, time, best, riskLabel, runLabel;
  final int risks, steps, riskBonus, runBonus;
  final bool credited;
  final VoidCallback onRisk, onRun;
  final Widget status, actions;
  final Widget? claim, unlocked;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              key: const ValueKey('result-card'),
              constraints: BoxConstraints(
                maxWidth: 358,
                maxHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    24,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF061B2B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFC4F1FF), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.5),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Transform.translate(
                          // Larger system text needs more space above the art;
                          // keep the cube below the record as well as above metrics.
                          offset: Offset(
                            0,
                            52.0 *
                                (MediaQuery.textScalerOf(context).scale(1) - 1)
                                    .clamp(0.0, 1.0),
                          ),
                          child: Image(
                            key: const ValueKey('result-scene'),
                            image: GameRunScene.resultProvider(
                              constraints.maxWidth,
                              MediaQuery.devicePixelRatioOf(context),
                            ),
                            // Preserve the complete cube and enemies. The dark
                            // lower edge blends into the card on taller layouts.
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, .27, .55, .74, 1],
                            colors: [
                              Color(0x66051A2A),
                              Color(0x00051A2A),
                              Color(0x00051A2A),
                              Color(0xBB051A2A),
                              Color(0xEE051A2A),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      key: const ValueKey('result-content'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFF0FBFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.loose,
                          child: SingleChildScrollView(
                            key: const ValueKey('result-scroll'),
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            headline,
                                            style: const TextStyle(
                                              color: Color(0xFFF0FBFF),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              time,
                                              key: const ValueKey(
                                                'result-time',
                                              ),
                                              style: const TextStyle(
                                                color: Color(0xFFF0FBFF),
                                                fontSize: 46,
                                                height: 1.15,
                                                fontWeight: FontWeight.w900,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                top: 3,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xED061B2B),
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: const Color(
                                                    0x5581DAEA,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                best,
                                                key: const ValueKey(
                                                  'result-best',
                                                ),
                                                style: const TextStyle(
                                                  color: Color(0xFFF0FBFF),
                                                  fontSize: 11,
                                                  height: 1.3,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Keep the cube and enemies visible between the score
                                // and metrics. The picture itself fills the whole card.
                                LayoutBuilder(
                                  builder: (_, constraints) => SizedBox(
                                    height: constraints.maxWidth * .52,
                                  ),
                                ),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _RunMetric(
                                          key: const ValueKey('result-risk'),
                                          label: riskLabel,
                                          value: risks,
                                          bonus: riskBonus,
                                          credited: credited,
                                          risk: true,
                                          onTap: onRisk,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _RunMetric(
                                          key: const ValueKey('result-run'),
                                          label: runLabel,
                                          value: steps,
                                          bonus: runBonus,
                                          credited: credited,
                                          risk: false,
                                          onTap: onRun,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ?claim,
                                ?unlocked,
                                const SizedBox(height: 8),
                                status,
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: actions,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RunMetric extends StatelessWidget {
  const _RunMetric({
    super.key,
    required this.label,
    required this.value,
    required this.bonus,
    required this.credited,
    required this.risk,
    required this.onTap,
  });
  final String label;
  final int value, bonus;
  final bool credited, risk;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0x9E061B2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x5581DAEA)),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GameMetricIcon(risk: risk, size: 12),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFC4DEEB),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 11,
                    color: Color(0xFFC4DEEB),
                  ),
                ],
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.3,
                  color: Color(0xFFF0FBFF),
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (bonus > 0)
                Row(
                  children: [
                    context.watch<EconomyStore?>()?.energyEnabled == true
                        ? const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: energyNeon,
                          )
                        : const CrystalCubeIcon(size: 12, glow: false),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '+$bonus ${credited ? (ru ? 'получено' : 'earned') : (ru ? 'бонус' : 'bonus')}',
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          color: Color(0xFF8BFFE0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
