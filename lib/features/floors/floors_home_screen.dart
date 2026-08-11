import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/economy_store.dart';
import '../../domain/gameplay_config.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sfx.dart';
import '../game/impact_burst.dart';
import 'floors_config.dart';
import 'floors_data.dart';
import 'floors_field_painter.dart';
import 'floors_levels_sheet.dart';
import 'floors_loadout.dart';
import 'floors_map_widget.dart';
import 'floors_progress.dart';
import 'floors_session.dart';
import 'floors_stopwatch.dart';
import 'floors_world.dart';

enum _FloorsPhase {
  idle,
  playing,
  sliding,
  impact,
  floorCleared,
  towerStub,
}

/// Режим «Этажи»: слайд между квадратами, защита после входа, зона «Выход».
class FloorsHomeScreen extends StatefulWidget {
  const FloorsHomeScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FloorsHomeScreen> createState() => _FloorsHomeScreenState();
}

class _FloorsHomeScreenState extends State<FloorsHomeScreen>
    with TickerProviderStateMixin {
  static const _spawnProtectSec = 1.5;
  static const _storyPrefKey = 'floors_story_seen_v1';

  late final Ticker _ticker;
  late final ValueNotifier<int> _frame;
  late final AnimationController _slide;
  late FloorsSession _session;
  /// Плавные часы декора pickups (тик dt, не pointer-frame).
  double _decorSec = 0;

  FloorsWorld? _world;
  FloorsWorld? _worldOutgoing;
  Size _fieldSize = Size.zero;
  GameplayConfig? _arcade;
  bool _ensureScheduled = false;
  WallSide? _enterFrom;
  double? _enterAlong;
  WallSide? _slideExitSide;

  _FloorsPhase _phase = _FloorsPhase.idle;
  Duration _lastElapsed = Duration.zero;
  double _spawnProtectLeft = 0;
  double _exitClockSec = 0;
  final List<ImpactBurst> _impacts = [];
  double _impactHoldSec = 0;

  final Set<int> _pointers = {};
  int? _primaryPointer;
  Offset? _primaryLastPos;

  Offset _eyeLook = Offset.zero;
  Offset? _moveLook;
  double _stillSec = 0;

  bool _storyReady = false;
  bool _showStoryModal = false;
  final List<_CrystalFly> _crystalFlies = [];
  final GlobalKey _crystalHudKey = GlobalKey();
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _session = FloorsSession(FloorCatalog.floor1);
    _frame = ValueNotifier<int>(0);
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onSlideDone();
      });
    _ticker = createTicker(_onTick)..start();
    _loadStoryFlag();
    _loadProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audio = context.read<GameplayConfig>().audio;
      GameSfx.applyConfig(audio);
      GameSfx.ensureMusic();
    });
  }

  Future<void> _loadProgress() async {
    await FloorsProgress.instance.load();
    if (!mounted) return;
    final n = FloorsProgress.instance.currentFloor;
    final def = FloorCatalog.byNumber(n) ?? FloorCatalog.floor1;
    setState(() {
      _session = FloorsSession(def);
    });
    if (_fieldSize != Size.zero) {
      _forceRebuildRoom();
    }
  }

  void _openLevels() {
    showFloorsLevelsSheet(
      context: context,
      progress: FloorsProgress.instance,
      onPlayFloor: _switchToFloor,
    );
  }

  Future<void> _switchToFloor(int floorNumber) async {
    final def = FloorCatalog.byNumber(floorNumber);
    if (def == null) return;
    await FloorsProgress.instance.selectFloor(floorNumber);
    if (!mounted) return;
    _enterFrom = null;
    _enterAlong = null;
    _worldOutgoing = null;
    _slide.stop();
    _slide.value = 0;
    setState(() {
      _session = FloorsSession(def);
      _phase = _FloorsPhase.idle;
      _exitClockSec = 0;
      _crystalFlies.clear();
    });
    _forceRebuildRoom();
  }

  Future<void> _loadStoryFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_storyPrefKey) ?? false;
    if (!mounted) return;
    setState(() {
      _storyReady = true;
      _showStoryModal = !seen;
    });
  }

  Future<void> _dismissStory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storyPrefKey, true);
    if (!mounted) return;
    setState(() => _showStoryModal = false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _slide.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _clearPointers() {
    _pointers.clear();
    _primaryPointer = null;
    _primaryLastPos = null;
  }

  RoomLoadout get _loadout =>
      _session.floor.loadoutFor(_session.row, _session.col);

  bool get _protected => _spawnProtectLeft > 0;

  /// Вспышки с фиксированной скоростью смены альфы; к концу — реже.
  double? get _protectBlinkFactor {
    if (_spawnProtectLeft <= 0) return null;
    final elapsed =
        (_spawnProtectSec - _spawnProtectLeft).clamp(0.0, _spawnProtectSec);
    final progress = (elapsed / _spawnProtectSec).clamp(0.0, 1.0);
    // Интервал между вспышками растёт; длительность самой вспышки — константа.
    final period = 0.12 + progress * progress * 0.70;
    final phase = elapsed % period;
    const flashDur = 0.10;
    if (phase >= flashDur) return 1.0;
    final t = phase / flashDur;
    final dip = sin(pi * t); // 0→1→0 за flashDur
    return 1.0 - 0.78 * dip;
  }

  void _rebuildWorld(Size field, GameplayConfig arcade) {
    _fieldSize = field;
    _arcade = arcade;
    _world = FloorsWorld(
      arcadeConfig: arcade,
      field: field,
      floor: _session.floor,
      row: _session.row,
      col: _session.col,
      loadout: _loadout,
      cell: _session.currentCell,
      enterFrom: _enterFrom,
      enterAlong: _enterAlong,
      showStairs: _session.currentCell.isFloorExit,
      exitClockSec: _exitClockSec,
      crystalCount: _session.crystalRemainingAt(_session.row, _session.col),
      spawnKey: _session.isKeyAt(_session.row, _session.col),
      stairsLocked: _session.currentCell.isFloorExit && !_session.hasFloorKey,
    );
    _enterFrom = null;
    _enterAlong = null;
  }

  void _collectPickups(FloorsWorld world) {
    if (_phase != _FloorsPhase.playing || _protected) return;

    if (world.tryCollectKey()) {
      if (_session.tryPickKeyAt(_session.row, _session.col)) {
        // Сразу открыть выход в этой же комнате (баг: stairsLocked был final).
        world.stairsLocked = false;
        setState(() {});
      }
    }

    final hits = world.tryCollectCrystals();
    if (hits.isEmpty) return;
    final eco = context.read<EconomyStore>();
    final fieldBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final hudBox =
        _crystalHudKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    for (final local in hits) {
      if (!_session.takeCrystalAt(_session.row, _session.col)) continue;
      eco.grantCrystals(1);
      if (fieldBox == null || hudBox == null || overlayBox == null) continue;
      final globalFrom = fieldBox.localToGlobal(local);
      final globalTo = hudBox.localToGlobal(
        Offset(hudBox.size.width / 2, hudBox.size.height / 2),
      );
      _crystalFlies.add(
        _CrystalFly(
          from: overlayBox.globalToLocal(globalFrom),
          to: overlayBox.globalToLocal(globalTo),
        ),
      );
    }
  }

  void _openFullMap() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) {
        final n = _session.floor.size;
        final maxSide = MediaQuery.sizeOf(ctx).shortestSide * 0.86;
        final cell = ((maxSide - 8) / n).clamp(10.0, 36.0);
        return Dialog(
          backgroundColor: const Color(0xFF12181E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: const Color(0xFF3DDC97).withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Карта этажа',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFFE8EEF4),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FloorsMapWidget(
                  session: _session,
                  cellSize: cell,
                  showTitle: false,
                ),
                const SizedBox(height: 10),
                Text(
                  '↑ выход · K ключ · точка — кристаллы',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _fieldColorFor(
    FloorCell cell,
    RoomLoadout loadout,
    GameplayConfig arcade,
    ThemeData theme,
  ) {
    final base = arcade.field.resolveSurfaceColor(theme.colorScheme.surface);
    final tint = cell.isStart
        ? cell
        : FloorCell(
            difficulty: loadout.difficultyPercent,
            isFloorExit: cell.isFloorExit,
          );
    return FloorDefinition.fieldColorForCell(tint, base);
  }

  void _updateEyeLook(double dt, {required bool active}) {
    if (!active) {
      // Превью: мягко смотрит по сторонам.
      final t = _frame.value * 0.045;
      _eyeLook = Offset(sin(t) * 0.55, cos(t * 0.8) * 0.3);
      return;
    }
    final move = _moveLook;
    if (move != null && _stillSec < 0.1) {
      _eyeLook = Offset(
        _eyeLook.dx * 0.35 + move.dx * 0.65,
        _eyeLook.dy * 0.35 + move.dy * 0.65,
      );
      return;
    }
    _stillSec += dt;
    final t = _session.lifeElapsedSec * 1.7 + _frame.value * 0.02;
    final wander = Offset(sin(t) * 0.6, cos(t * 0.75) * 0.35);
    _eyeLook = Offset(
      _eyeLook.dx * 0.82 + wander.dx * 0.18,
      _eyeLook.dy * 0.82 + wander.dy * 0.18,
    );
  }

  void _scheduleEnsureWorld(Size field, GameplayConfig arcade) {
    final needNew =
        _world == null || _fieldSize != field || _arcade != arcade;
    if (!needNew || _phase == _FloorsPhase.sliding) return;
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      if (!mounted || _phase == _FloorsPhase.sliding) return;
      _rebuildWorld(field, arcade);
      setState(() {});
    });
  }

  void _forceRebuildRoom({bool resumePlay = false, bool protect = false}) {
    final arcade = _arcade ?? context.read<GameplayConfig>();
    if (_fieldSize == Size.zero) return;
    _rebuildWorld(_fieldSize, arcade);
    setState(() {
      _phase = resumePlay ? _FloorsPhase.playing : _FloorsPhase.idle;
      _lastElapsed = Duration.zero;
      _impacts.clear();
      _spawnProtectLeft = protect ? _spawnProtectSec : 0;
      if (!resumePlay) _clearPointers();
    });
    _frame.value++;
  }

  void _onSlideDone() {
    if (!mounted) return;
    _worldOutgoing = null;
    _slideExitSide = null;
    _slide.value = 0;
    setState(() {
      _phase = _FloorsPhase.playing;
      // Разгон жизни общий — не сбрасываем при переходе комнаты.
      _spawnProtectLeft = _spawnProtectSec;
      _impacts.clear();
    });
    _frame.value++;
  }

  Offset _slideOffset({
    required WallSide exitSide,
    required double t,
    required bool outgoing,
  }) {
    final eased = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    final w = _fieldSize.width;
    final h = _fieldSize.height;
    if (outgoing) {
      return switch (exitSide) {
        WallSide.right => Offset(-w * eased, 0),
        WallSide.left => Offset(w * eased, 0),
        WallSide.bottom => Offset(0, -h * eased),
        WallSide.top => Offset(0, h * eased),
      };
    }
    return switch (exitSide) {
      WallSide.right => Offset(w * (1 - eased), 0),
      WallSide.left => Offset(-w * (1 - eased), 0),
      WallSide.bottom => Offset(0, h * (1 - eased)),
      WallSide.top => Offset(0, -h * (1 - eased)),
    };
  }

  void _onTick(Duration elapsed) {
    final world = _world;
    if (world == null || !mounted) return;
    if (_phase == _FloorsPhase.floorCleared ||
        _phase == _FloorsPhase.towerStub ||
        _phase == _FloorsPhase.sliding) {
      return;
    }

    try {
      final rawDtMs = (_lastElapsed == Duration.zero)
          ? 16
          : (elapsed - _lastElapsed).inMilliseconds;
      _lastElapsed = elapsed;
      if (rawDtMs <= 0) return;
      final dtMs = min(50, rawDtMs);
      final dt = dtMs / 1000.0;
      final config = world.game.config;
      _decorSec += dt;

      if (_phase == _FloorsPhase.idle) {
        _exitClockSec += dt;
        world.syncExits(_exitClockSec);
        final bounces = world.game.tickIdle(dt);
        world.resolveObstacleBounces();
        if (bounces.wall > 0) GameSfx.mobWall();
        if (bounces.enemy > 0) GameSfx.mobCollide();
        _updateEyeLook(dt, active: false);
        _crystalFlies.removeWhere((f) => !f.update(dt));
        _frame.value++;
        return;
      }

      if (_phase == _FloorsPhase.impact) {
        _impactHoldSec += dt;
        _impacts.removeWhere((b) => !b.update(dt));
        _crystalFlies.removeWhere((f) => !f.update(dt));
        _frame.value++;
        if (_impactHoldSec >= 0.55 && _impacts.isEmpty) {
          _session.respawnAtStart();
          _session.resetLifeProgress();
          _forceRebuildRoom();
        }
        return;
      }

      if (_phase == _FloorsPhase.playing) {
        // Таймеры только в активной фазе (прозрачный превью — нет).
        _session.tickActiveTimers(dt);
        _updateEyeLook(dt, active: true);
        if (_spawnProtectLeft > 0) {
          _spawnProtectLeft = max(0.0, _spawnProtectLeft - dt);
        }
        _exitClockSec += dt;
        world.syncExits(_exitClockSec);
        world.constrainPlayerToDeadlyWalls();

        // Разгон скорости — на всю жизнь, не на комнату.
        final rampSec = max(0.05, config.speedRampSeconds);
        final idleMult = config.idleSpeedMultiplier;
        _session.lifeRampT = min(rampSec, _session.lifeRampT + dt);
        final t = (_session.lifeRampT / rampSec).clamp(0.0, 1.0);
        final speedMult =
            idleMult + (1.0 - idleMult) * Curves.easeOut.transform(t);

        world.game.tickJump(dt);
        final bounces = world.game.tickPlay(
          dt,
          _session.lifeElapsedSec,
          speedMult: speedMult,
        );
        world.resolveObstacleBounces();
        if (bounces.wall > 0) GameSfx.mobWall();
        if (bounces.enemy > 0) GameSfx.mobCollide();
        _impacts.removeWhere((b) => !b.update(dt));
        _collectPickups(world);
        _crystalFlies.removeWhere((f) => !f.update(dt));

        if (world.playerOnStairs()) {
          _onStairsReached();
          return;
        }

        final side = world.crossedExitSide();
        if (side != null) {
          _handleExit(side);
          return;
        }

        if (!_protected) {
          final wallsKill = config.wallsKillPlayer;
          final wallHit =
              world.evaluateBorder() == FloorsBorderHit.deadlyWall;
          final obstHit = world.playerHitsObstacle();
          if (wallHit || obstHit) {
            if (wallsKill) {
              _triggerImpact(againstWall: true);
              return;
            }
            if (obstHit) world.pushPlayerFromObstacles();
          }
          if (world.game.playerHitsEnemy()) {
            _triggerImpact(againstWall: false);
            return;
          }
        }
        _frame.value++;
      }
    } catch (e, st) {
      debugPrint('Floors tick error: $e\n$st');
    }
  }

  void _handleExit(WallSide side) {
    if (_phase == _FloorsPhase.sliding) return;
    final along = _world?.playerAlongForSide(side);
    final enteredFrom = _session.moveThrough(side);
    if (enteredFrom == null) return;

    final arcade = _arcade ?? context.read<GameplayConfig>();
    if (_fieldSize == Size.zero) return;

    _enterFrom = enteredFrom;
    _enterAlong = along;
    _rebuildWorld(_fieldSize, arcade);
    _clearPointers();
    _worldOutgoing = null;
    _slideExitSide = null;
    _slide.stop();
    _slide.value = 0;
    // Без слайд-анимации между клетками — сразу новая комната.
    setState(() {
      _phase = _FloorsPhase.playing;
      _spawnProtectLeft = _spawnProtectSec;
      _impacts.clear();
    });
    _frame.value++;
  }

  void _triggerImpact({required bool againstWall}) {
    if (_phase != _FloorsPhase.playing || _world == null) return;
    final theme = Theme.of(context);
    final w = _world!.game;
    final cx = w.player.dx + w.playerSize / 2;
    final cy = w.player.dy + w.playerSize / 2;
    if (againstWall) {
      GameSfx.heroWall();
    } else {
      GameSfx.heroMob();
    }
    setState(() {
      _impacts
        ..clear()
        ..add(
          ImpactBurst.spawn(
            origin: Offset(cx, cy),
            accent: theme.colorScheme.primary,
            danger: theme.colorScheme.error,
            againstWall: againstWall,
          ),
        );
      _impactHoldSec = 0;
      _phase = _FloorsPhase.impact;
      _spawnProtectLeft = 0;
    });
    _frame.value++;
  }

  void _startRoom() {
    FloorsProgress.instance.registerAttempt(_session.floor.floorNumber);
    setState(() {
      _phase = _FloorsPhase.playing;
      _lastElapsed = Duration.zero;
      _impacts.clear();
      _stillSec = 0;
      _moveLook = null;
      // После тапа на нестартовой клетке — та же защита, сброс при движении.
      _spawnProtectLeft =
          _session.currentCell.isStart ? 0 : _spawnProtectSec;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _onStairsReached() {
    _clearPointers();
    final n = _session.floor.floorNumber;
    final clearTime = _session.floorElapsedSec;
    FloorsProgress.instance.registerClear(n, clearTime);
    final hasNext = FloorCatalog.nextAfter(n) != null;
    setState(() {
      _phase = hasNext ? _FloorsPhase.floorCleared : _FloorsPhase.towerStub;
    });
    _frame.value++;
  }

  void _goNextFloor() {
    if (!_session.enterNextFloor()) {
      setState(() => _phase = _FloorsPhase.towerStub);
      return;
    }
    _enterFrom = null;
    _enterAlong = null;
    _worldOutgoing = null;
    _slide.stop();
    _slide.value = 0;
    _forceRebuildRoom();
  }

  void _retryFloor() {
    _session.resetCampaign();
    _enterFrom = null;
    _enterAlong = null;
    _worldOutgoing = null;
    _slide.stop();
    _slide.value = 0;
    _forceRebuildRoom();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_phase == _FloorsPhase.floorCleared ||
        _phase == _FloorsPhase.towerStub ||
        _phase == _FloorsPhase.sliding) {
      return;
    }
    if (_phase == _FloorsPhase.idle) {
      _pointers
        ..clear()
        ..add(event.pointer);
      _primaryPointer = event.pointer;
      _primaryLastPos = event.localPosition;
      _startRoom();
      return;
    }
    if (_phase != _FloorsPhase.playing) return;
    if (_pointers.isEmpty) {
      _pointers.add(event.pointer);
      _primaryPointer = event.pointer;
      _primaryLastPos = event.localPosition;
      return;
    }
    _pointers.add(event.pointer);
    _tryJump();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_phase != _FloorsPhase.playing || _world == null) return;
    if (event.pointer != _primaryPointer) return;
    final last = _primaryLastPos;
    _primaryLastPos = event.localPosition;
    if (last == null) return;
    final delta = event.localPosition - last;
    if (delta == Offset.zero) return;

    if (delta.distance > 0.5) {
      final n = delta.distance;
      _moveLook = Offset(delta.dx / n, delta.dy / n);
      _stillSec = 0;
    }

    // Первый сдвиг снимает защиту — нельзя гулять «в мерцании».
    if (_spawnProtectLeft > 0 && delta.distance > 0.6) {
      _spawnProtectLeft = 0;
    }

    _world!.game.movePlayerBy(delta);
    _world!.constrainPlayerToDeadlyWalls();
    // Сначала пикапы — иначе ключ не откроет выход в том же жесте.
    _collectPickups(_world!);

    if (_world!.playerOnStairs()) {
      _onStairsReached();
      return;
    }

    final side = _world!.crossedExitSide();
    if (side != null) {
      _handleExit(side);
      return;
    }
    if (!_protected) {
      final wallsKill =
          (_arcade ?? context.read<GameplayConfig>()).game.wallsKillPlayer;
      final wallHit =
          _world!.evaluateBorder() == FloorsBorderHit.deadlyWall;
      final obstHit = _world!.playerHitsObstacle();
      if (wallHit || obstHit) {
        if (wallsKill) {
          _triggerImpact(againstWall: true);
          return;
        }
        if (obstHit) _world!.pushPlayerFromObstacles();
      }
      if (_world!.game.playerHitsEnemy()) {
        _triggerImpact(againstWall: false);
        return;
      }
    }
    _frame.value++;
  }

  void _onPointerUp(PointerUpEvent event) => _releasePointer(event.pointer);

  void _onPointerCancel(PointerCancelEvent event) =>
      _releasePointer(event.pointer);

  void _releasePointer(int pointer) {
    if (!_pointers.remove(pointer)) return;
    if (pointer != _primaryPointer) return;
    if (_pointers.isNotEmpty) {
      _primaryPointer = _pointers.first;
      _primaryLastPos = null;
    } else {
      _primaryPointer = null;
      _primaryLastPos = null;
    }
  }

  void _tryJump() {
    final world = _world;
    if (world == null) return;
    if (!world.game.config.jumpEnabled) return;
    if (world.game.tryJump()) {
      GameSfx.jump();
      _frame.value++;
    }
  }

  Widget _roomPaint(
    FloorsWorld room,
    Size size,
    ThemeData theme,
    GameplayConfig arcade, {
    required bool invuln,
    required bool preview,
  }) {
    final fieldColor = _fieldColorFor(room.cell, room.loadout, arcade, theme);
    final tintCell = room.cell.isStart
        ? room.cell
        : FloorCell(
            difficulty: room.loadout.difficultyPercent,
            isFloorExit: room.cell.isFloorExit,
          );
    final borderTint = Color.lerp(
      theme.colorScheme.primary,
      FloorDefinition.colorForCell(tintCell),
      0.55,
    )!;
    return CustomPaint(
      size: size,
      painter: FloorsFieldPainter(
        floors: room,
        accent: theme.colorScheme.primary,
        danger: theme.colorScheme.error,
        fieldColor: fieldColor,
        borderColor: borderTint,
        borderWidth: arcade.borderWidth,
        cornerRadius: 18,
        frame: _frame.value,
        decorSec: _decorSec,
        playerPreview: preview,
        invulnerable: invuln,
        invulnerableFactor: invuln ? _protectBlinkFactor : null,
        impacts: identical(room, _world) ? _impacts : const [],
        shadowBrightness: arcade.field.shadowBrightness,
        eyeLook: identical(room, _world) ? _eyeLook : Offset.zero,
        showFace: arcade.player.showFace,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arcade = context.watch<GameplayConfig>();
    final economy = context.watch<EconomyStore>();
    GameSfx.applyConfig(arcade.audio);
    final theme = Theme.of(context);
    final world = _world;
    final cell = _session.currentCell;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1419),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Только этот блок кликабелен (кнопки / карта / кристаллы).
                _FloorsOptionsBar(
                  floorTitle: _session.floor.title,
                  crystals: economy.tokens,
                  crystalKey: _crystalHudKey,
                  hasKey: _session.hasFloorKey,
                  onBack: widget.onBack,
                  onMap: _openFullMap,
                  onLevels: _openLevels,
                ),
                // Всё ниже — тачпад, как в аркаде.
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = min(constraints.maxWidth, 360.0);
                              final size = Size(side, side);
                              _scheduleEnsureWorld(size, arcade);
                              if (world == null) {
                                return SizedBox(
                                  key: _fieldKey,
                                  width: side,
                                  height: side,
                                );
                              }
                              return Center(
                                child: ClipRRect(
                                  key: _fieldKey,
                                  borderRadius: BorderRadius.circular(18),
                                  child: SizedBox(
                                    width: side,
                                    height: side,
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge(
                                        [_frame, _slide],
                                      ),
                                      builder: (context, _) {
                                        if (_phase == _FloorsPhase.sliding &&
                                            _worldOutgoing != null &&
                                            _slideExitSide != null) {
                                          final t = _slide.value;
                                          final outO = _slideOffset(
                                            exitSide: _slideExitSide!,
                                            t: t,
                                            outgoing: true,
                                          );
                                          final inO = _slideOffset(
                                            exitSide: _slideExitSide!,
                                            t: t,
                                            outgoing: false,
                                          );
                                          return Stack(
                                            clipBehavior: Clip.hardEdge,
                                            children: [
                                              Transform.translate(
                                                offset: outO,
                                                child: _roomPaint(
                                                  _worldOutgoing!,
                                                  size,
                                                  theme,
                                                  arcade,
                                                  invuln: false,
                                                  preview: false,
                                                ),
                                              ),
                                              Transform.translate(
                                                offset: inO,
                                                child: _roomPaint(
                                                  world,
                                                  size,
                                                  theme,
                                                  arcade,
                                                  invuln: true,
                                                  preview: false,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return _roomPaint(
                                          world,
                                          size,
                                          theme,
                                          arcade,
                                          invuln: _protected,
                                          preview:
                                              _phase == _FloorsPhase.idle,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: ValueListenableBuilder<int>(
                              valueListenable: _frame,
                              builder: (context, value, child) =>
                                  FloorsTimersBar(
                                floorSec: _session.floorElapsedSec,
                                lifeSec: _session.lifeElapsedSec,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: IgnorePointer(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FloorsRadarMap(
                                    session: _session,
                                    cellSize: 16,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _phase == _FloorsPhase.idle &&
                                            cell.isStart
                                        ? const _LoungeCard()
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, value, child) => CustomPaint(
                    painter: _CrystalFlyPainter(_crystalFlies),
                  ),
                ),
              ),
            ),
            if (_storyReady && _showStoryModal)
              _StoryModal(
                floorNumber: _session.floor.floorNumber,
                onClose: _dismissStory,
              ),
            if (_phase == _FloorsPhase.floorCleared)
              _FloorClearedOverlay(
                floorNumber: _session.floor.floorNumber,
                clearTimeSec: _session.floorElapsedSec,
                onNext: _goNextFloor,
                onRetry: _retryFloor,
                onBack: widget.onBack,
              ),
            if (_phase == _FloorsPhase.towerStub)
              _TowerStubOverlay(
                onRetry: _retryFloor,
                onBack: widget.onBack,
              ),
          ],
        ),
      ),
    );
  }
}

class _CrystalFly {
  _CrystalFly({required this.from, required this.to});

  final Offset from;
  final Offset to;
  double t = 0;

  bool update(double dt) {
    t += dt / 0.55;
    return t < 1;
  }

  Offset get pos {
    final e = Curves.easeInCubic.transform(t.clamp(0.0, 1.0));
    return Offset.lerp(from, to, e)!;
  }
}

class _CrystalFlyPainter extends CustomPainter {
  _CrystalFlyPainter(this.flies);

  final List<_CrystalFly> flies;

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flies) {
      final p = f.pos;
      final a = (1 - f.t).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        7,
        Paint()..color = const Color(0xFF7EE0FF).withValues(alpha: 0.35 * a),
      );
      final body = Path()
        ..moveTo(p.dx, p.dy - 6)
        ..lineTo(p.dx + 5, p.dy)
        ..lineTo(p.dx, p.dy + 6)
        ..lineTo(p.dx - 5, p.dy)
        ..close();
      canvas.drawPath(
        body,
        Paint()..color = const Color(0xFF7EE0FF).withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrystalFlyPainter oldDelegate) => true;
}

class _FloorsOptionsBar extends StatelessWidget {
  const _FloorsOptionsBar({
    required this.floorTitle,
    required this.crystals,
    required this.crystalKey,
    required this.hasKey,
    required this.onBack,
    required this.onMap,
    required this.onLevels,
  });

  final String floorTitle;
  final int crystals;
  final GlobalKey crystalKey;
  final bool hasKey;
  final VoidCallback? onBack;
  final VoidCallback onMap;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white70,
              ),
              TextButton.icon(
                onPressed: onMap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3DDC97),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text(
                  'Карта',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: onLevels,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC107),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.account_balance_rounded, size: 18),
                label: const Text(
                  'Этажи',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const Spacer(),
              Padding(
                key: crystalKey,
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CrystalCubeIcon(size: 18, glow: false),
                    const SizedBox(width: 4),
                    Text(
                      '$crystals',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF7EE0FF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            child: Row(
              children: [
                Text(
                  floorTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFFE8EEF4),
                  ),
                ),
                const SizedBox(width: 10),
                _BuffStub(icon: Icons.keyboard_double_arrow_up_rounded, label: 'прыжок'),
                _BuffStub(icon: Icons.shield_outlined, label: 'шлем'),
                _BuffStub(icon: Icons.slow_motion_video_rounded, label: 'slow'),
                const Spacer(),
                _KeyBadge(hasKey: hasKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuffStub extends StatelessWidget {
  const _BuffStub({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Opacity(
        opacity: 0.35,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.hasKey});

  final bool hasKey;

  @override
  Widget build(BuildContext context) {
    final color = hasKey ? const Color(0xFFFFC107) : const Color(0xFF4B5563);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: hasKey
            ? const Color(0xFFFFC107).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: color.withValues(alpha: hasKey ? 0.8 : 0.4)),
        boxShadow: hasKey
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(Icons.vpn_key_rounded, size: 18, color: color),
    );
  }
}

class _LoungeCard extends StatelessWidget {
  const _LoungeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF12181E),
        border: Border.all(
          color: const Color(0xFF3DDC97).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Мира ждёт наверху',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF3DDC97),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Коснись поля — и в путь.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryModal extends StatelessWidget {
  const _StoryModal({
    required this.floorNumber,
    required this.onClose,
  });

  final int floorNumber;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF12181E),
                  border: Border.all(
                    color: const Color(0xFF3DDC97).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/floors/floors_story_tower.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            color: const Color(0xFF1A222C),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.castle_rounded,
                              color: Color(0xFF3DDC97),
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Мира ждёт наверху',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF3DDC97),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'На самом верху башни сидит Мира — твоя младшая сестра. '
                      'Стражи закрыли этажи.\n\n'
                      'Ты не бьёшься — только скользишь мимо. '
                      'Дыры в стенах ведут дальше. '
                      'Упал — снова со старта этажа $floorNumber.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDC97),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text(
                        'Понял — иду к Мире',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кубик лезет по лестнице на следующий этаж (статичная иллюстрация).
class _CubeStairsArt extends StatelessWidget {
  const _CubeStairsArt({this.accent = const Color(0xFF3DDC97)});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CubeStairsPainter(accent: accent),
      child: const SizedBox(height: 140, width: double.infinity),
    );
  }
}

class _CubeStairsPainter extends CustomPainter {
  _CubeStairsPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final floorY = size.height * 0.88;
    final topY = size.height * 0.18;

    // Фон-арка следующего этажа
    final glow = Paint()
      ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, topY + 8), width: 70, height: 36),
        const Radius.circular(12),
      ),
      glow,
    );
    final hatch = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, topY + 6), width: 52, height: 26),
      const Radius.circular(8),
    );
    canvas.drawRRect(hatch, Paint()..color = const Color(0xFF0E1419));
    canvas.drawRRect(
      hatch,
      Paint()
        ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Лестница
    final stairPaint = Paint()
      ..color = const Color(0xFF7EE0FF).withValues(alpha: 0.5)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final u = i / 6;
      final y = floorY + (topY + 28 - floorY) * u;
      final w = 96.0 * (1 - u * 0.4);
      canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y), stairPaint);
    }

    // Кубик на середине лестницы
    const t = 0.42;
    final cubeY = floorY - 8 + (topY + 20 - floorY) * t;
    const cubeSize = 30.0;
    final cube = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cubeY),
        width: cubeSize,
        height: cubeSize,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      cube,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.25)!],
        ).createShader(cube.outerRect),
    );
    canvas.drawRRect(
      cube,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final eyeY = cubeY - cubeSize * 0.08;
    final eyeR = cubeSize * 0.12;
    for (final sx in [-1.0, 1.0]) {
      final ex = cx + sx * cubeSize * 0.2;
      canvas.drawCircle(Offset(ex, eyeY), eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(ex, eyeY - 0.5),
        eyeR * 0.42,
        Paint()..color = const Color(0xFF243040),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CubeStairsPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _FloorClearedOverlay extends StatelessWidget {
  const _FloorClearedOverlay({
    required this.floorNumber,
    required this.clearTimeSec,
    required this.onNext,
    required this.onRetry,
    this.onBack,
  });

  final int floorNumber;
  final double clearTimeSec;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF12181E),
              border: Border.all(
                color: const Color(0xFF7EE0FF).withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Выход найден!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7EE0FF),
                  ),
                ),
                const SizedBox(height: 10),
                _CubeStairsArt(accent: accent),
                const SizedBox(height: 8),
                Text(
                  'Этаж $floorNumber позади · ${_fmtClear(clearTimeSec)}\n'
                  'Кубик поднимается выше.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: const Color(0xFF7EE0FF),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('На этаж ${floorNumber + 1}'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Сначала кампании'),
                ),
                if (onBack != null) ...[
                  TextButton(
                    onPressed: onBack,
                    child: const Text('К выбору режима'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtClear(double sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0) return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
    return '${s.toStringAsFixed(1)} с';
  }
}

class _TowerStubOverlay extends StatelessWidget {
  const _TowerStubOverlay({required this.onRetry, this.onBack});

  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF12181E),
              border: Border.all(
                color: const Color(0xFFFFC107).withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Дальше — пока тупик',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFC107),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Этаж 2 пройден.\n'
                  'Третий этаж башни ещё строится — '
                  'Мира ждёт выше, но лестница пока закрыта.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Сначала с этажа 1'),
                ),
                if (onBack != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onBack,
                    child: const Text('К выбору режима'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
