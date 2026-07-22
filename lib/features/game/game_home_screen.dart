import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../data/economy_store.dart';
import '../../domain/gameplay_config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/crystal_cube_icon.dart';
import '../balance/crystals_sheet.dart';
import '../leaderboard/leaderboard_sheet.dart';
import '../result/result_screen.dart';
import '../result/share_score_sheet.dart';
import 'game_field_painter.dart';
import 'game_world.dart';
import 'lives_sheet.dart';

enum _Phase { idle, playing, result }

/// Гиперказуальный цикл: поле сверху, hint снизу.
/// Касание в любой части экрана управляет игроком (кроме HUD-кнопок).
class GameHomeScreen extends StatefulWidget {
  const GameHomeScreen({super.key});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with TickerProviderStateMixin {
  static const _hudHeight = 52.0;

  late final Ticker _ticker;
  late final AnimationController _hintPulse;
  late final ValueNotifier<int> _frame;
  GameWorld? _world;
  Size _fieldSize = Size.zero;
  GameplayConfig? _boundConfig;
  bool _ensureScheduled = false;

  _Phase _phase = _Phase.idle;
  Duration _lastElapsed = Duration.zero;
  int _aliveMs = 0;
  int _resultMs = 0;
  double _rampT = 0;
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _frame = ValueNotifier<int>(0);
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hintPulse.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _ensureWorld(Size field, GameplayConfig config) {
    if (field.isEmpty || !field.width.isFinite || !field.height.isFinite) {
      return;
    }
    if (_world != null && _fieldSize == field && _boundConfig == config) {
      return;
    }
    _fieldSize = field;
    _boundConfig = config;
    _world = GameWorld(config: config, field: field)..resetLayout();
  }

  /// Не ставим post-frame на каждый rebuild — иначе очередь растёт и эмулятор падает.
  void _scheduleEnsureWorld(Size field, GameplayConfig config) {
    if (_world != null && _fieldSize == field && _boundConfig == config) {
      return;
    }
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      if (!mounted) return;
      final before = _world;
      _ensureWorld(field, config);
      if (before != _world) setState(() {});
    });
  }

  void _resetToIdle() {
    final config = _boundConfig;
    final field = _fieldSize;
    setState(() {
      _phase = _Phase.idle;
      _aliveMs = 0;
      _rampT = 0;
      _lastElapsed = Duration.zero;
      _session++;
      if (config != null && field != Size.zero) {
        _world = GameWorld(config: config, field: field)..resetLayout();
      }
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final world = _world;
    if (world == null || !mounted) return;
    if (_phase == _Phase.result) return;

    try {
      final rawDtMs = (_lastElapsed == Duration.zero)
          ? 16
          : (elapsed - _lastElapsed).inMilliseconds;
      _lastElapsed = elapsed;
      if (rawDtMs <= 0) return;
      final dtMs = min(50, rawDtMs);
      final dt = dtMs / 1000.0;
      final config = context.read<GameplayConfig>();

      if (_phase == _Phase.idle) {
        world.tickIdle(dt);
        _frame.value++;
        return;
      }

      if (_phase == _Phase.playing) {
        final rampSec = max(0.05, config.speedRampSeconds);
        final idleMult = config.idleSpeedMultiplier;
        _rampT = min(rampSec, _rampT + dt);
        final t = (_rampT / rampSec).clamp(0.0, 1.0);
        final speedMult =
            idleMult + (1.0 - idleMult) * Curves.easeOut.transform(t);

        _aliveMs += dtMs;
        world.tickPlay(dt, _aliveMs / 1000.0, speedMult: speedMult);

        if (world.playerHitsBorder() || world.playerHitsEnemy()) {
          _endGame();
          return;
        }
        _frame.value++;
      }
    } catch (e, st) {
      debugPrint('Game tick error: $e\n$st');
    }
  }

  void _endGame() {
    if (_phase != _Phase.playing) return;
    _ticker.stop();
    setState(() {
      _phase = _Phase.result;
      _resultMs = _aliveMs;
    });
    context.read<EconomyStore>().recordBestTime(_aliveMs);
  }

  void _onTouchStart() {
    if (_phase != _Phase.idle) return;
    final economy = context.read<EconomyStore>();
    if (!economy.canPlay) {
      showLivesSheet(context);
      return;
    }
    if (!economy.tryStartGame()) return;
    setState(() {
      _phase = _Phase.playing;
      _aliveMs = 0;
      _rampT = 0;
      _lastElapsed = Duration.zero;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase == _Phase.idle) {
      _onTouchStart();
      return;
    }
    if (_phase != _Phase.playing || _world == null) return;
    _world!.movePlayerBy(details.delta);
    if (_world!.playerHitsBorder() || _world!.playerHitsEnemy()) {
      _endGame();
    } else {
      _frame.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final config = context.watch<GameplayConfig>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final world = _world;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1419),
      body: SafeArea(
        child: Stack(
          children: [
            // Визуальный layout
            Column(
              children: [
                const SizedBox(height: _hudHeight),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = min(constraints.maxWidth, 380.0);
                      final size = Size(side, side);
                      _scheduleEnsureWorld(size, config);
                      if (world == null) {
                        return SizedBox(width: side, height: side);
                      }
                      return Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: _frame,
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: size,
                                    painter: GameFieldPainter(
                                      world: world,
                                      accent: theme.colorScheme.primary,
                                      danger: theme.colorScheme.error,
                                      fieldColor: theme.colorScheme.surface,
                                      borderColor: theme.colorScheme.primary,
                                      borderWidth: config.borderWidth,
                                      cornerRadius: 18,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _phase == _Phase.idle && config.game.startHintEnabled
                      ? _TapToStartBanner(
                          pulse: _hintPulse,
                          title: l10n.appTitle,
                          text: economy.canPlay
                              ? l10n.tapHintPlayful
                              : l10n.noLivesOpenCrystals,
                        )
                      : const SizedBox.expand(),
                ),
              ],
            ),
            // Касание всего экрана (под HUD-кнопками)
            if (_phase != _Phase.result)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _onTouchStart(),
                  onPanStart: (_) => _onTouchStart(),
                  onPanUpdate: _onPanUpdate,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            // HUD поверх жестов — кнопки перехватывают клики
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: _Hud(
                  onLivesTap: () => showLivesSheet(context),
                  onCrystalsTap: () => showCrystalsSheet(context),
                  onRecordTap: () => showLeaderboardSheet(context),
                  frame: _frame,
                  timeMs: () {
                    if (_phase == _Phase.result) return _resultMs;
                    if (_phase == _Phase.playing) return _aliveMs;
                    return null;
                  },
                ),
              ),
            ),
            if (_phase == _Phase.result)
              ResultOverlay(
                key: ValueKey('result-$_session-$_resultMs'),
                timeMs: _resultMs,
                onOk: _resetToIdle,
                onShare: () async {
                  await showShareScoreSheet(
                    context,
                    timeMs: _resultMs,
                  );
                  if (mounted) _resetToIdle();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TapToStartBanner extends StatelessWidget {
  const _TapToStartBanner({
    required this.pulse,
    required this.title,
    required this.text,
  });

  final Animation<double> pulse;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Center(
          child: Container(
            margin: const EdgeInsets.fromLTRB(28, 8, 28, 24),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF1A2A32),
                    const Color(0xFF243840),
                    t,
                  )!,
                  const Color(0xFF12181E),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFF3DDC97).withValues(alpha: 0.35),
                  const Color(0xFF7EE0FF).withValues(alpha: 0.55),
                  t,
                )!,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3DDC97)
                      .withValues(alpha: 0.12 + t * 0.18),
                  blurRadius: 18 + t * 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.2,
                    color: Color.lerp(
                      const Color(0xFF7EE0FF).withValues(alpha: 0.75),
                      const Color(0xFF3DDC97),
                      t,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Transform.scale(
                  scale: 0.96 + t * 0.06,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      height: 1.25,
                      color: Color.lerp(
                        const Color(0xFFE8EEF4),
                        const Color(0xFFB8F4FF),
                        t * 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0.45 + t * 0.35,
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF7EE0FF),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.onLivesTap,
    required this.onCrystalsTap,
    required this.onRecordTap,
    required this.frame,
    required this.timeMs,
  });

  final VoidCallback onLivesTap;
  final VoidCallback onCrystalsTap;
  final VoidCallback onRecordTap;
  final ValueNotifier<int> frame;
  final int? Function() timeMs;

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final theme = Theme.of(context);

    return Row(
      children: [
        GestureDetector(
          onTap: onLivesTap,
          child: _HudChip(
            icon: Icon(Icons.favorite, size: 16, color: theme.colorScheme.error),
            label: '${economy.lives}',
            highlight: true,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCrystalsTap,
          child: _HudChip(
            icon: const CrystalCubeIcon(size: 16, glow: false),
            label: '${economy.tokens}',
            highlight: true,
          ),
        ),
        const Spacer(),
        ListenableBuilder(
          listenable: frame,
          builder: (context, _) {
            final ms = timeMs();
            if (ms != null) {
              final totalSec = ms ~/ 1000;
              final minutes = (totalSec ~/ 60).toString().padLeft(2, '0');
              final seconds = (totalSec % 60).toString().padLeft(2, '0');
              final millis = (ms % 1000).toString().padLeft(3, '0');
              return Text(
                '$minutes:$seconds.$millis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.primary,
                  fontSize: 26,
                ),
              );
            }
            if (economy.bestTimeMs > 0) {
              return GestureDetector(
                onTap: onRecordTap,
                child: _HudChip(
                  icon: Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: '${(economy.bestTimeMs / 1000).toStringAsFixed(2)}s',
                  highlight: true,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const Spacer(),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final Widget icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? const Color(0xFF7EE0FF).withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
