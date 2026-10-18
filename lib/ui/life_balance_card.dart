import 'dart:async';
import 'package:flutter/material.dart';
import 'game_ui.dart';

/// A short double heartbeat followed by a rest. Only the heart repaints.
class LifeBalanceCard extends StatefulWidget {
  const LifeBalanceCard({super.key, required this.lives});
  final int lives;
  @override
  State<LifeBalanceCard> createState() => _LifeBalanceCardState();
}

class _LifeBalanceCardState extends State<LifeBalanceCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.10,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.055), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.055, end: 1.0), weight: 30),
  ]).animate(_controller);
  Timer? _beat;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulse();
  }

  void _updatePulse() {
    _beat?.cancel();
    _beat = null;
    if (!_foreground || MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    _controller.forward(from: 0);
    _beat = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePulse();
  }

  @override
  void dispose() {
    _beat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Semantics(
      label: ru ? 'Ваши жизни: ${widget.lives}' : 'Your lives: ${widget.lives}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24475D), Color(0xFF102C45), Color(0xFF091D32)],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFEF7885), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: ScaleTransition(
                  key: const ValueKey('lives-heart-pulse'),
                  scale: _scale,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: GameUi.heart,
                    size: 34,
                    shadows: [Shadow(color: Color(0x66FF5A70), blurRadius: 10)],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.lives}',
                    key: const ValueKey('lives-balance-amount'),
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: GameUi.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  ru ? 'Ваши жизни' : 'Your lives',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: GameUi.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
