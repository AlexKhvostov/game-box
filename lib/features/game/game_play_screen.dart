import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../domain/gameplay_config.dart';
import '../../ui/game_status_bar.dart';
import 'game_field_painter.dart';
import 'game_world.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({
    super.key,
    required this.onFinished,
    required this.onExit,
  });

  final ValueChanged<int> onFinished;
  final VoidCallback onExit;

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  GameWorld? _world;
  Size _fieldSize = Size.zero;

  Duration _lastElapsed = Duration.zero;
  int _aliveMs = 0;
  bool _waitingTouch = true;
  bool _running = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureWorld(Size field, GameplayConfig config) {
    if (_finished) return;
    if (_world != null && _fieldSize == field) return;
    _fieldSize = field;
    _world = GameWorld(config: config, field: field)..resetLayout();
    _aliveMs = 0;
    _waitingTouch = true;
    _running = false;
    _lastElapsed = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_finished || _world == null) return;

    if (_waitingTouch) {
      _world!.tickIdle(elapsed.inMilliseconds / 1000.0);
      setState(() {});
      return;
    }

    if (!_running) return;

    final dtMs = (_lastElapsed == Duration.zero)
        ? 16
        : (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs <= 0) return;

    final dt = dtMs / 1000.0;
    _aliveMs += dtMs;
    _world!.tickPlay(dt, _aliveMs / 1000.0);

    if (_world!.playerHitsBorder()) {
      if (!_world!.wallsKillPlayer) {
        _world!.clampPlayerToField();
      } else {
        _endGame();
        return;
      }
    }
    if (_world!.playerHitsEnemy()) {
      _endGame();
      return;
    }

    setState(() {});
  }

  void _armOnTouch() {
    if (_finished || _world == null) return;
    if (_waitingTouch) {
      setState(() {
        _waitingTouch = false;
        _running = true;
        _lastElapsed = Duration.zero;
        _aliveMs = 0;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_finished || _world == null) return;
    _armOnTouch();
    if (!_running) return;

    _world!.movePlayerBy(details.delta);
    if (_world!.playerHitsBorder()) {
      if (!_world!.wallsKillPlayer) {
        _world!.clampPlayerToField();
      } else {
        _endGame();
        return;
      }
    }
    if (_world!.playerHitsEnemy()) {
      _endGame();
      return;
    }
    setState(() {});
  }

  void _endGame() {
    if (_finished) return;
    _finished = true;
    _running = false;
    _ticker.stop();
    final timeMs = _aliveMs;
    widget.onFinished(timeMs);
  }

  void _exit() {
    _ticker.stop();
    widget.onExit();
  }

  String _formatTime(int ms) {
    final totalSec = ms ~/ 1000;
    final minutes = (totalSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSec % 60).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = context.watch<GameplayConfig>();
    final world = _world;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101820), Color(0xFF0E1419)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _armOnTouch(),
                onPanUpdate: _onPanUpdate,
                onTapDown: (_) => _armOnTouch(),
                child: const SizedBox.expand(),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                  child: GameStatusBar(
                    trailing: IconButton(
                      onPressed: _exit,
                      tooltip: 'В меню',
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _formatTime(_aliveMs),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      letterSpacing: 1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = min(constraints.maxWidth, 420.0);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _ensureWorld(Size(side, side), config);
                      });
                      if (world == null) {
                        return SizedBox(width: side, height: side);
                      }
                      return Center(
                        child: IgnorePointer(
                          child: CustomPaint(
                            size: Size(side, side),
                            painter: GameFieldPainter(
                              world: world,
                              accent: theme.colorScheme.primary,
                              danger: theme.colorScheme.error,
                              fieldColor: config.field.resolveSurfaceColor(
                                theme.colorScheme.surface,
                              ),
                              borderColor: config.wallsKillPlayer
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              borderWidth: config.borderWidth,
                              shadowBrightness: config.field.shadowBrightness,
                              showFace: config.player.showFace,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _waitingTouch && config.game.startHintEnabled
                          ? Center(
                              child: Text(
                                'Коснитесь экрана, чтобы начать',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : kDebugMode
                              ? _DebugPanel(
                                  world: world,
                                  aliveMs: _aliveMs,
                                  config: config,
                                )
                              : const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({
    required this.world,
    required this.aliveMs,
    required this.config,
  });

  final GameWorld? world;
  final int aliveMs;
  final GameplayConfig config;

  @override
  Widget build(BuildContext context) {
    if (world == null) return const SizedBox.shrink();
    final lines = <String>[
      'area×: ${config.enemyAreaMultiplier}',
      'angle: ${config.angleMinDeg.toStringAsFixed(0)}–${config.angleMaxDeg.toStringAsFixed(0)}° + 90·n',
      'speed: ${config.speedMin.toStringAsFixed(0)}–${config.speedMax.toStringAsFixed(0)}',
      'accel: ${config.accelMin.toStringAsFixed(0)}–${config.accelMax.toStringAsFixed(0)}',
      ...world!.enemies.asMap().entries.map((e) {
        final en = e.value;
        final sp = en.speedAt(aliveMs / 1000.0);
        return '#${e.key} ${en.w.toStringAsFixed(0)}×${en.h.toStringAsFixed(0)} '
            'n=${en.quadrantN} ∠${en.angleDeg.toStringAsFixed(0)}° '
            'v0=${en.initialSpeed.toStringAsFixed(0)} a=${en.acceleration.toStringAsFixed(1)} '
            'v=${sp.toStringAsFixed(0)}';
      }),
    ];
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        lines.join('\n'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.35,
            ),
      ),
    );
  }
}
