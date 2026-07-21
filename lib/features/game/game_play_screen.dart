import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../result/result_screen.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with SingleTickerProviderStateMixin {
  static const double playerSize = 36;
  static const double enemySize = 48;

  late final Ticker _ticker;
  final _rng = Random();

  Size _field = Size.zero;
  Offset _player = Offset.zero;
  final List<_Enemy> _enemies = [];

  Duration _lastElapsed = Duration.zero;
  int _aliveMs = 0;
  double _spawnAcc = 0;
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

  void _startIfNeeded(Size field) {
    if (_running || _finished) return;
    _field = field;
    _player = Offset(
      (field.width - playerSize) / 2,
      (field.height - playerSize) / 2,
    );
    _enemies.clear();
    _aliveMs = 0;
    _spawnAcc = 0;
    _lastElapsed = Duration.zero;
    _running = true;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!_running || _finished) return;
    final dtMs = (_lastElapsed == Duration.zero)
        ? 16
        : (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs <= 0) return;

    final dt = dtMs / 1000.0;
    _aliveMs += dtMs;

    final speedBoost = 1.0 + _aliveMs / 20000.0;
    for (final e in _enemies) {
      e.pos += e.vel * (dt * 60 * speedBoost);
    }
    _enemies.removeWhere(
      (e) =>
          e.pos.dx < -enemySize * 2 ||
          e.pos.dy < -enemySize * 2 ||
          e.pos.dx > _field.width + enemySize * 2 ||
          e.pos.dy > _field.height + enemySize * 2,
    );

    final spawnEvery = max(0.35, 1.1 - _aliveMs / 25000.0);
    _spawnAcc += dt;
    while (_spawnAcc >= spawnEvery) {
      _spawnAcc -= spawnEvery;
      _spawnEnemy();
    }

    final playerRect = Rect.fromLTWH(
      _player.dx,
      _player.dy,
      playerSize,
      playerSize,
    );
    for (final e in _enemies) {
      final enemyRect = Rect.fromLTWH(e.pos.dx, e.pos.dy, e.w, e.h);
      if (playerRect.overlaps(enemyRect)) {
        _endGame();
        return;
      }
    }

    setState(() {});
  }

  void _spawnEnemy() {
    final side = _rng.nextInt(4);
    late Offset pos;
    late Offset vel;
    final base = 2.2 + _rng.nextDouble() * 1.4;
    final w = enemySize * (0.7 + _rng.nextDouble() * 0.8);
    final h = enemySize * (0.7 + _rng.nextDouble() * 0.8);

    switch (side) {
      case 0: // top
        pos = Offset(_rng.nextDouble() * (_field.width - w), -h);
        vel = Offset((_rng.nextDouble() - 0.5) * 1.5, base);
      case 1: // bottom
        pos = Offset(_rng.nextDouble() * (_field.width - w), _field.height);
        vel = Offset((_rng.nextDouble() - 0.5) * 1.5, -base);
      case 2: // left
        pos = Offset(-w, _rng.nextDouble() * (_field.height - h));
        vel = Offset(base, (_rng.nextDouble() - 0.5) * 1.5);
      default: // right
        pos = Offset(_field.width, _rng.nextDouble() * (_field.height - h));
        vel = Offset(-base, (_rng.nextDouble() - 0.5) * 1.5);
    }
    _enemies.add(_Enemy(pos: pos, vel: vel, w: w, h: h));
  }

  Future<void> _endGame() async {
    if (_finished) return;
    _finished = true;
    _running = false;
    _ticker.stop();
    final timeMs = _aliveMs;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(timeMs: timeMs),
      ),
    );
  }

  void _onPan(DragUpdateDetails details) {
    if (!_running) return;
    setState(() {
      _player = Offset(
        (_player.dx + details.delta.dx)
            .clamp(0.0, _field.width - playerSize),
        (_player.dy + details.delta.dy)
            .clamp(0.0, _field.height - playerSize),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _ticker.stop();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  Text(
                    '${(_aliveMs / 1000).toStringAsFixed(1)} с',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = min(constraints.maxWidth, constraints.maxHeight);
                    final size = Size(side, side);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_field != size && !_finished) {
                        _startIfNeeded(size);
                      }
                    });
                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: GestureDetector(
                          onPanUpdate: _onPan,
                          child: CustomPaint(
                            painter: _GamePainter(
                              player: _player,
                              playerSize: playerSize,
                              enemies: _enemies,
                              accent: theme.colorScheme.primary,
                              danger: theme.colorScheme.error,
                              fieldColor: theme.colorScheme.surface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Enemy {
  _Enemy({
    required this.pos,
    required this.vel,
    required this.w,
    required this.h,
  });

  Offset pos;
  Offset vel;
  final double w;
  final double h;
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.player,
    required this.playerSize,
    required this.enemies,
    required this.accent,
    required this.danger,
    required this.fieldColor,
  });

  final Offset player;
  final double playerSize;
  final List<_Enemy> enemies;
  final Color accent;
  final Color danger;
  final Color fieldColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = fieldColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bg,
    );

    final border = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      border,
    );

    final enemyPaint = Paint()..color = danger;
    for (final e in enemies) {
      canvas.drawRect(Rect.fromLTWH(e.pos.dx, e.pos.dy, e.w, e.h), enemyPaint);
    }

    final playerPaint = Paint()..color = accent;
    canvas.drawRect(
      Rect.fromLTWH(player.dx, player.dy, playerSize, playerSize),
      playerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
