import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_world.dart';
import '../../domain/arcade_rules.dart';

/// Live simulation units, independent from the screen's pixel density.
class GameDebugStats {
  GameDebugStats(GameWorld world) {
    count = world.enemies.length;
    if (count == 0) return;
    minSpeed = double.infinity;
    for (final enemy in world.enemies) {
      final speed = enemy.vel.distance;
      currentSpeed += speed;
      initialSpeed += enemy.initialSpeed;
      acceleration += enemy.acceleration;
      minSpeed = math.min(minSpeed, speed);
      maxSpeed = math.max(maxSpeed, speed);
    }
    currentSpeed /= count;
    initialSpeed /= count;
    acceleration /= count;
  }
  int count = 0;
  double currentSpeed = 0, initialSpeed = 0, acceleration = 0;
  double minSpeed = 0, maxSpeed = 0;
}

class GameDebugPanel extends StatelessWidget {
  const GameDebugPanel({
    super.key,
    required this.world,
    required this.frame,
    required this.timeMs,
    required this.phase,
  });
  final GameWorld world;
  final Listenable frame;
  final int Function() timeMs;
  final String Function() phase;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ListenableBuilder(
        listenable: frame,
        builder: (context, _) {
          final stats = GameDebugStats(world);
          final step = ArcadeRules.stepLength(world.playerSize);
          final ru = Localizations.localeOf(context).languageCode == 'ru';
          return Container(
            key: const ValueKey('gameplay-debug-panel'),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xE600101C),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x6635F5C6)),
            ),
            child: Text(
              '${ru ? 'Время раунда' : 'Round time'}: '
              '${(timeMs() / 1000).toStringAsFixed(2)} ${ru ? 'с' : 's'}\n'
              '${ru ? 'Скорость сейчас' : 'Current speed'}: '
              '${(stats.currentSpeed / step).toStringAsFixed(2)} ${ru ? 'шаг/с' : 'steps/s'}\n'
              '${ru ? 'Врагов на поле' : 'Enemies on field'}: ${stats.count}\n'
              '${ru ? 'Каждый враг: старт (шаг/с), ускорение (шаг/с²)' : 'Each enemy: start (steps/s), acceleration (steps/s²)'}\n'
              '${List.generate(world.enemies.length, (i) {
                final enemy = world.enemies[i];
                return '${ru ? 'Враг' : 'Enemy'} ${i + 1}: '
                    '${ru ? 'старт' : 'start'} ${(enemy.initialSpeed / step).toStringAsFixed(2)}, '
                    '${ru ? 'ускорение' : 'acceleration'} +${(enemy.acceleration / step).toStringAsFixed(2)}';
              }).join('\n')}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.25,
                color: Color(0xFF9FFFF0),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    ),
  );
}
