// Shared with the verifier build. Actual physics/config are compiled directly
// from the application's reviewed Dart sources by build_android_replay.py.
import 'dart:math';
import 'geometry.dart';
import 'world.dart';
import 'config.dart';
import 'random.dart';

Map<String, dynamic> replay(Map<String, dynamic> input) {
  final raw = input['config'] as Map<String, dynamic>;
  final source = GameplayConfig.fromBlocks(
    enemies: EnemiesConfig.fromJson(raw['enemies']),
    player: PlayerConfig.fromJson(raw['player']),
    field: FieldConfig.fromJson(raw['field']),
    game: GameConfig.fromJson(raw['game']),
    mobileEnemies: raw['mobileEnemies'] is Map<String, dynamic>
        ? MobileEnemyPace.fromJson(raw['mobileEnemies'])
        : const MobileEnemyPace(),
  );
  final pace = source.mobileEnemies,
      step = source.playerSize * GameWorld.characterSizeScale * .1;
  final config = GameplayConfig(
    enemies: EnemiesConfig(
      areaMultiplier: source.enemies.areaMultiplier,
      aspects: source.enemyAspects,
      angleMinDeg: source.angleMinDeg,
      angleMaxDeg: source.angleMaxDeg,
      speedMin: pace.startSpeedSteps * step * (1 - pace.speedVariation),
      speedMax: pace.startSpeedSteps * step * (1 + pace.speedVariation),
      accelMin:
          pace.accelerationSteps * step * (1 - pace.accelerationVariation),
      accelMax:
          pace.accelerationSteps * step * (1 + pace.accelerationVariation),
      collideWithEachOther: source.enemiesCollide,
      spinDegPerSec: source.enemySpinDegPerSec,
    ),
    player: source.player,
    field: source.field,
    game: GameConfig.fromJson({
      ...source.game.toJson(),
      'speedRampSeconds': 0.0,
    }),
  );
  final inset =
      (config.borderWidth / 2 + .5).clamp(.5, 12) + config.borderWidth / 2;
  final world = GameWorld(
    config: config,
    field: const Size(380, 380),
    rng: ReplayRandom(input['requestId']),
    wallInset: inset,
  )..resetLayout();
  var helmet = input['hadHelmet'] == true, dead = false;
  final hasJump = input['hadJump'] == true;
  double startLeft = max(0, config.startInvulnSec), helmetLeft = 0, elapsed = 0;
  bool invulnerable() => startLeft > 0 || helmetLeft > 0;
  void collision() {
    if (invulnerable()) return;
    final wall = world.wallsKillPlayer && world.playerHitsBorder();
    if (!wall && !world.playerHitsEnemy()) return;
    if (helmet) {
      helmet = false;
      helmetLeft = max(0, config.helmetInvulnSec);
      if (!wall) world.repelEnemiesFromPlayer();
    } else {
      dead = true;
    }
  }

  final events = input['proof']['events'] as List;
  if (input['proof']['version'] != 1 || events.length > 600000)
    throw const FormatException('proof format');
  for (final value in events) {
    if (dead) throw const FormatException('events after death');
    final e = value as List;
    switch (e[0]) {
      case 0:
        if (e.length != 2 || e[1] is! num) throw const FormatException('tick');
        final ms = (e[1] as num).toDouble();
        if (!ms.isFinite || ms <= 0 || ms > 50)
          throw const FormatException('tick duration');
        elapsed += ms;
        if (elapsed > 3600000) throw const FormatException('run duration');
        final dt = ms / 1000;
        world.tickJump(dt);
        world.tickPlay(dt, elapsed / 1000, checkPlayerHits: !invulnerable());
        startLeft = max(0, startLeft - dt);
        helmetLeft = max(0, helmetLeft - dt);
        if (!world.wallsKillPlayer && world.playerHitsBorder())
          world.clampPlayerToField();
        collision();
      case 1:
        if (e.length != 3 || e[1] is! num || e[2] is! num)
          throw const FormatException('move');
        final dx = (e[1] as num).toDouble(), dy = (e[2] as num).toDouble();
        if (!dx.isFinite || !dy.isFinite || dx.abs() > 2000 || dy.abs() > 2000)
          throw const FormatException('move bounds');
        world.movePlayerBy(Offset(dx, dy), checkEnemies: !invulnerable());
        if (!world.wallsKillPlayer && world.playerHitsBorder())
          world.clampPlayerToField();
        collision();
      case 2:
        if (e.length != 1 || !hasJump || !world.tryJump(nowMs: elapsed))
          throw const FormatException('jump cooldown');
      default:
        throw const FormatException('event');
    }
  }
  if (!dead) throw const FormatException('unfinished run');
  return {
    'timeMs': elapsed.floor(),
    'runDistance': max(
      0.0,
      world.playerDistance / max(1e-6, world.playerSize * .1),
    ).round(),
    'riskCount': world.nearMissCount,
  };
}
