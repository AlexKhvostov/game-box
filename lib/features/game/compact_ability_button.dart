import 'package:flutter/material.dart';
import '../../ui/ability_ring.dart';

/// Fixed geometry across off / on / spent and off / ready / cooling. Time and
/// arc come from the real game callbacks; this widget owns no gameplay clock.
class CompactAbilityButton extends StatelessWidget {
  const CompactAbilityButton({
    super.key,
    required this.helmet,
    required this.active,
    required this.broken,
    required this.ru,
    required this.progress,
    required this.remainingMs,
    required this.frame,
    this.onTap,
  });
  final bool helmet, active, broken, ru;
  final double Function() progress, remainingMs;
  final Listenable frame;
  final VoidCallback? onTap;
  Widget _artwork() {
    final art = Image.asset(
      helmet
          ? 'assets/branding/ui/simple-energy-helmet.png'
          : 'assets/branding/ui/jump-v1.png',
      fit: helmet ? BoxFit.cover : BoxFit.contain,
      width: 31,
      height: 31,
      cacheWidth: 128,
      excludeFromSemantics: true,
    );
    return CustomPaint(
      key: ValueKey(helmet ? 'helmet-ability-ring' : 'jump-ability-ring'),
      foregroundPainter: AbilityRingPainter(
        active: active,
        broken: broken,
        progress: helmet ? null : progress,
        repaint: frame,
        hideReady: true,
      ),
      child: Opacity(
        opacity: active && !broken ? 1 : .65,
        child: helmet
            ? ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const RadialGradient(
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, .55, 1],
                ).createShader(rect),
                child: art,
              )
            : art,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ListenableBuilder(
      listenable: frame,
      child: _artwork(),
      builder: (context, artwork) {
        final ms = helmet || !active
            ? 0.0
            : remainingMs().clamp(0.0, double.infinity);
        final cooling = !helmet && active && ms > 0;
        final status = !active
            ? (ru ? 'Выкл.' : 'Off')
            : broken
            ? (ru ? 'Разбит' : 'Broken')
            : helmet
            ? (ru ? 'Вкл.' : 'On')
            : cooling
            ? '${ru ? (ms / 1000).toStringAsFixed(1).replaceAll('.', ',') : (ms / 1000).toStringAsFixed(1)} ${ru ? 'с' : 's'}'
            : (ru ? 'Готов' : 'Ready');
        final color = !active
            ? const Color(0xFFA5BDD3)
            : broken
            ? const Color(0xFFFFD77C)
            : cooling
            ? Colors.white
            : const Color(0xFFA6FFE3);
        return Semantics(
          button: onTap != null,
          label:
              '${helmet ? (ru ? 'Шлем' : 'Helmet') : (ru ? 'Прыжок' : 'Jump')}: $status',
          child: SizedBox(
            width: 72,
            height: 44,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Container(
                  key: ValueKey(
                    helmet ? 'compact-helmet-face' : 'compact-jump-face',
                  ),
                  width: 72,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF074167), Color(0xFF01182E)],
                    ),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF6EF1FF)
                          : const Color(0xFF3AA8CE),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: active
                            ? const Color(0x5500C7FF)
                            : const Color(0x2200AAFF),
                        blurRadius: 7,
                      ),
                      const BoxShadow(
                        color: Color(0xFF052C46),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 1,
                        top: 1,
                        width: 32,
                        height: 32,
                        child: artwork!,
                      ),
                      Positioned(
                        left: 33,
                        right: 6,
                        top: 12,
                        height: 15,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            status,
                            key: !helmet && active
                                ? ValueKey(
                                    cooling
                                        ? 'jump-cooldown-status'
                                        : 'jump-ready-status',
                                  )
                                : null,
                            style: TextStyle(
                              color: color,
                              fontSize: broken ? 9.5 : 10.5,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!cooling)
                        Positioned(
                          left: 46,
                          top: 6,
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: .5),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      if (onTap != null)
                        const Positioned(
                          right: 0,
                          top: 10,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF63DEFF),
                            size: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
