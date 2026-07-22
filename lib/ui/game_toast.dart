import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'crystal_cube_icon.dart';
import 'hud_fly_targets.dart';

export 'hud_fly_targets.dart' show ToastFlyTarget;

/// Яркий тост: вспышка → полёт к чипу HUD (кристалы / жизни) → исчезновение.
void showGameToast(
  BuildContext context, {
  required String message,
  Widget? icon,
  Color? accent,
  ToastFlyTarget flyTo = ToastFlyTarget.none,
  bool festive = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _GameToastHost(
      message: message,
      icon: icon ??
          (flyTo == ToastFlyTarget.lives
              ? const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF5A5F),
                  size: 26,
                )
              : const CrystalCubeIcon(size: 28)),
      accent: accent ??
          (flyTo == ToastFlyTarget.lives
              ? const Color(0xFF3DDC97)
              : const Color(0xFF7EE0FF)),
      flyTo: flyTo,
      festive: festive,
      onFinished: () {
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _GameToastHost extends StatefulWidget {
  const _GameToastHost({
    required this.message,
    required this.icon,
    required this.accent,
    required this.flyTo,
    required this.festive,
    required this.onFinished,
  });

  final String message;
  final Widget icon;
  final Color accent;
  final ToastFlyTarget flyTo;
  final bool festive;
  final VoidCallback onFinished;

  @override
  State<_GameToastHost> createState() => _GameToastHostState();
}

class _GameToastHostState extends State<_GameToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Offset _start = Offset.zero;
  Offset _end = Offset.zero;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Быстро, но заметно: ~0.95s
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.festive ? 1100 : 920),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final start = Offset(size.width / 2, size.height * 0.30);
      final end = widget.flyTo == ToastFlyTarget.none
          ? Offset(size.width / 2, size.height * 0.14)
          : (HudFlyTargets.centerOf(widget.flyTo) ??
              HudFlyTargets.fallbackOf(widget.flyTo, size));
      setState(() {
        _start = start;
        _end = end;
        _ready = true;
      });
      _c.forward().whenComplete(widget.onFinished);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 0..0.22 — яркое появление; дальше полёт к цели
          final appear = (t / 0.22).clamp(0.0, 1.0);
          final flyRaw = ((t - 0.20) / 0.80).clamp(0.0, 1.0);
          final fly = Curves.easeInCubic.transform(flyRaw);

          final pos = Offset.lerp(_start, _end, fly)!;
          final pop = Curves.easeOutBack.transform(appear);
          final scale = (1.05 * pop) * (1.0 - 0.72 * fly);
          // К концу полёта быстро гаснет
          final opacity = fly < 0.55
              ? appear
              : (appear * (1.0 - ((fly - 0.55) / 0.45))).clamp(0.0, 1.0);

          return Stack(
            children: [
              if (widget.festive)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FestiveBurstPainter(
                      progress: t,
                      origin: _start,
                      accent: widget.accent,
                    ),
                  ),
                ),
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale.clamp(0.12, 1.2),
                      child: _ToastCard(
                        message: widget.message,
                        icon: widget.icon,
                        accent: widget.accent,
                        festive: widget.festive,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.accent,
    required this.festive,
  });

  final String message;
  final Widget icon;
  final Color accent;
  final bool festive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: festive
                ? [
                    const Color(0xFFFF8A5C),
                    Color.lerp(accent, const Color(0xFFC44BFF), 0.45)!,
                    const Color(0xFF1A2A35),
                  ]
                : [
                    const Color(0xFF1A2A35),
                    Color.lerp(const Color(0xFF1A2A35), accent, 0.28)!,
                  ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: festive ? 0.85 : 0.55),
            width: festive ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: festive ? 0.55 : 0.35),
              blurRadius: festive ? 28 : 20,
              offset: const Offset(0, 8),
            ),
            if (festive)
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                blurRadius: 18,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: festive ? 17 : 15,
                  color: const Color(0xFFE8EEF4),
                  shadows: festive
                      ? const [
                          Shadow(
                            color: Color(0x88FFD54F),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FestiveBurstPainter extends CustomPainter {
  _FestiveBurstPainter({
    required this.progress,
    required this.origin,
    required this.accent,
  });

  final double progress;
  final Offset origin;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02 || progress > 0.75) return;
    final burst = Curves.easeOut.transform((progress / 0.45).clamp(0.0, 1.0));
    final fade = (1.0 - ((progress - 0.25) / 0.5).clamp(0.0, 1.0));
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final ang = (i / 18) * math.pi * 2 + rnd.nextDouble() * 0.2;
      final dist = 28 + burst * (70 + rnd.nextDouble() * 50);
      final p = origin + Offset(math.cos(ang) * dist, math.sin(ang) * dist);
      final paint = Paint()
        ..color = (i.isEven ? accent : const Color(0xFFFFD54F))
            .withValues(alpha: 0.85 * fade)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 2.2 + (1 - burst) * 2.5, paint);
    }
    // Центральная вспышка
    canvas.drawCircle(
      origin,
      18 + burst * 40,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.16 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _FestiveBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}
