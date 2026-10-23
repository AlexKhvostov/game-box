import '../domain/gameplay_config.dart';
import '../domain/arcade_rules.dart';
import '../features/game/game_world.dart';

/// Phone balance, applied once to the loaded snapshot before creating a round.
abstract final class MobileGameplayTuning {
  static const speedVariation = 0.05;
  static const accelerationVariation = 0.08;

  static GameplayConfig apply(GameplayConfig source) {
    final enemies = source.enemies;
    final step = ArcadeRules.stepLength(
      source.playerSize * GameWorld.characterSizeScale,
    );
    final speed = source.mobileEnemies.startSpeedSteps * step;
    final acceleration = source.mobileEnemies.accelerationSteps * step;
    // A separate ease-out multiplier made the first half-second accelerate
    // much faster than the rest. Phone rounds use v0 + a*t from their first tick.
    final game = source.game.toJson()..['speedRampSeconds'] = 0.0;
    return GameplayConfig(
      enemies: EnemiesConfig(
        areaMultiplier: enemies.areaMultiplier,
        aspects: enemies.aspects,
        angleMinDeg: enemies.angleMinDeg,
        angleMaxDeg: enemies.angleMaxDeg,
        speedMin: speed * (1 - source.mobileEnemies.speedVariation),
        speedMax: speed * (1 + source.mobileEnemies.speedVariation),
        accelMin:
            acceleration * (1 - source.mobileEnemies.accelerationVariation),
        accelMax:
            acceleration * (1 + source.mobileEnemies.accelerationVariation),
        collideWithEachOther: enemies.collideWithEachOther,
        spinDegPerSec: enemies.spinDegPerSec,
      ),
      player: source.player,
      field: source.field,
      game: GameConfig.fromJson(game),
      audio: source.audio,
      mobileEnemies: source.mobileEnemies,
      enemyPace: source.enemyPace,
    );
  }
}
