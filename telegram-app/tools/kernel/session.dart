// Incremental browser adapter. Physics/config/tuning compile from frozen Android.
// The server replay remains an independent consumer of the exact event proof.
import 'dart:math';
import 'geometry.dart';
import 'world.dart';
import 'config.dart';
import 'random.dart';
import 'tuning.dart';
import 'guard.dart';
import 'enemy_pace.dart';

class BrowserSession {
  BrowserSession(Map<String, dynamic> input) {
    final raw = input['config'] as Map<String, dynamic>;
    if(input['proofVersion']==2) pace=EnemyPace(raw['enemyPace']);
    config = MobileGameplayTuning.apply(GameplayConfig.fromBlocks(
      enemies: EnemiesConfig.fromJson(raw['enemies']),
      player: PlayerConfig.fromJson(raw['player']),
      field: FieldConfig.fromJson(raw['field']),
      game: GameConfig.fromJson(raw['game']),
      mobileEnemies: MobileEnemyPace.fromJson(raw['mobileEnemies']),
    ));
    world = GameWorld(config: config, field: const Size(380,380),
      rng: ReplayRandom(input['requestId']),
      wallInset: (config.borderWidth / 2 + .5).clamp(.5,12) + config.borderWidth / 2)..resetLayout();
    helmet = input['hadHelmet'] == true;
    hasJump = input['hadJump'] == true;
    if(input['startPose'] != null) world.restoreStartPose(input['startPose']);
    startLeft = max(0,config.startInvulnSec);
  }
  EnemyPace? pace;
  late final GameplayConfig config;
  late final GameWorld world;
  late bool helmet;
  late final bool hasJump;
  late double startLeft;
  double helmetLeft = 0, elapsed = 0;
  bool playing = false, dead = false;
  bool againstWall = false;
  Map<String,double>? impactOrigin;
  int wallBounces = 0, enemyBounces = 0, jumpCount = 0;
  final List<List<num>> events = [];
  List<List<double>>? startPose;
  bool get invulnerable => startLeft > 0 || helmetLeft > 0;
  void idle(double ms) {
    if(playing || dead || !ms.isFinite || ms <= 0 || ms > 50) throw StateError('idle');
    final bounce = world.tickIdle(ms/1000);
    wallBounces = bounce.wall; enemyBounces = bounce.enemy;
  }
  void start() {
    if(playing || dead) throw StateError('start');
    world.startFromIdle();
    startPose = world.startPose;
    wallBounces = 0; enemyBounces = 0;
    playing = true;
  }
  void collision() {
    if(invulnerable) return;
    final wall = world.wallsKillPlayer && world.playerHitsBorder();
    if(!wall && !world.playerHitsEnemy()) return;
    againstWall = wall;
    final cx=world.player.dx+world.playerSize/2,cy=world.player.dy+world.playerSize/2;
    var ix=cx,iy=cy;
    if(wall) {
      final m=min(min(cx,380-cx),min(cy,380-cy));
      if(m==cx) ix=0; else if(m==380-cx) ix=380; else if(m==cy) iy=0; else iy=380;
    } else {
      final pr=Rect.fromLTWH(world.player.dx,world.player.dy,world.playerSize,world.playerSize);
      for(final enemy in world.enemies) { if(pr.overlaps(enemy.rect)){ix=(cx+enemy.rect.center.dx)/2;iy=(cy+enemy.rect.center.dy)/2;break;} }
    }
    impactOrigin={'x':ix,'y':iy};
    if(helmet) {
      helmet = false;
      helmetLeft = max(0,config.helmetInvulnSec);
      if(!wall) world.repelEnemiesFromPlayer();
    } else { dead = true; playing = false; }
  }
  void move(double dx, double dy) {
    if(!playing) throw StateError('move');
    // Android's first fast swipe records 1 ms before it can cause a fatal hit.
    if(elapsed == 0) event([0,1]);
    if(!dead) event([1,dx,dy]);
  }
  void jump() {
    if(!playing || !hasJump || !world.tryJump(nowMs:elapsed)) return;
    jumpCount++;
    events.add([2]);
  }
  void event(List<dynamic> e) {
    final previousPlayer=world.player;
    if(!playing || dead || events.length >= 600000) throw StateError('event');
    if(e[0] == 0) {
      final ms = (e[1] as num).toDouble();
      if(!ms.isFinite || ms <= 0 || ms > 50 || elapsed + ms > 3600000) throw FormatException('tick');
      events.add([0,ms]);
      elapsed += ms;
      final dt = ms/1000;
      pace?.advance(dt);
      world.tickJump(dt);
      final bounce = world.tickPlay(dt, elapsed/1000, checkPlayerHits:!invulnerable, enemySpeedOverride:pace==null?null:pace!.speed*world.playerSize*.1);
      wallBounces = bounce.wall; enemyBounces = bounce.enemy;
      startLeft = max(0,startLeft-dt);
      helmetLeft = max(0,helmetLeft-dt);
    } else if(e[0] == 1) {
      final dx = (e[1] as num).toDouble(), dy = (e[2] as num).toDouble();
      if(!dx.isFinite || !dy.isFinite || dx.abs()>2000 || dy.abs()>2000) throw FormatException('move');
      events.add([1,dx,dy]);
      world.movePlayerBy(Offset(dx,dy), checkEnemies:!invulnerable);
    } else { throw FormatException('event'); }
    if(!world.wallsKillPlayer && world.playerHitsBorder()) world.clampPlayerToField();
    collision();
    if(!dead) pace?.pressOnFloor(fromX:previousPlayer.dx,fromY:previousPlayer.dy,toX:world.player.dx,toY:world.player.dy,playerSize:world.playerSize,grounded:!world.isJumping);

  }
  Map<String,dynamic> get proof => {'version':pace==null?1:2,'events':events,'startPose':startPose};
  String? guard(Map<String,dynamic> input) {
    final r = input['field'] as List<dynamic>, v = input['visible'] as List<dynamic>;
    return GameStartGuard.check(world:world, paintedSize:const Size(380,380),
      displayedField:Rect.fromLTWH((r[0] as num).toDouble(),(r[1] as num).toDouble(),(r[2] as num).toDouble(),(r[3] as num).toDouble()),
      visibleScreen:Rect.fromLTWH((v[0] as num).toDouble(),(v[1] as num).toDouble(),(v[2] as num).toDouble(),(v[3] as num).toDouble()),
      devicePixelRatio:(input['dpr'] as num).toDouble());
  }
  Map<String,dynamic> get snapshot => {
    'brake':pace?.snapshot,
    'playing':playing,'dead':dead,'timeMs':elapsed.floor(),
    'runDistance':max(0.0,world.playerDistance/max(1e-6,world.playerSize*.1)).round(),
    'riskCount':world.nearMissCount,'helmet':helmet,'invulnerable':invulnerable,
    'jumpCooldownMs':world.jumpCooldownRemaining(nowMs:elapsed),'jumpCount':jumpCount,
    'jumpEnabled':hasJump && config.jumpEnabled,'jumpRemainingMs':world.jumpRemaining*1000,
    'player':{'x':world.player.dx,'y':world.player.dy,'size':world.playerSize,'visualScale':world.visualScale,'jumpLift':world.jumpLift},
    'enemies':[for(final e in world.enemies) {'x':e.pos.dx,'y':e.pos.dy,'w':e.w,'h':e.h,'angle':e.orientDeg,'speed':pace==null?e.speedAt(elapsed/1000):pace!.speed*world.playerSize*.1}],
    'wallBounces':wallBounces,'enemyBounces':enemyBounces,
    'againstWall':againstWall,
    'impactOrigin':impactOrigin,'startled':world.enemyAtRiskDistance,
    'nearMissFx':[for(final fx in world.nearMissFx) {'x':fx.origin.dx,'y':fx.origin.dy,'age':fx.age}],
  };
}
