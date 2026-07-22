import 'package:flutter/material.dart';

import 'crystal_cube_icon.dart';

/// Красивый игровой тост (появление / исчезновение).
void showGameToast(
  BuildContext context, {
  required String message,
  Widget? icon,
  Color? accent,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _GameToastHost(
      message: message,
      icon: icon ?? const CrystalCubeIcon(size: 28),
      accent: accent ?? const Color(0xFF7EE0FF),
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
    required this.onFinished,
  });

  final String message;
  final Widget icon;
  final Color accent;
  final VoidCallback onFinished;

  @override
  State<_GameToastHost> createState() => _GameToastHostState();
}

class _GameToastHostState extends State<_GameToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 28),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, -0.4), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 55),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -0.25))
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 27,
      ),
    ]).animate(_c);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 26),
    ]).animate(_c);

    _c.forward().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 56, left: 24, right: 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A2A35),
                            Color.lerp(
                                  const Color(0xFF1A2A35),
                                  widget.accent,
                                  0.25,
                                ) ??
                                const Color(0xFF1A2A35),
                          ],
                        ),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.icon,
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFFE8EEF4),
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
          ),
        ),
      ),
    );
  }
}
