import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../app/app_target.dart';
import '../../data/app_analytics.dart';
import '../../data/economy_store.dart';
import '../../data/scores_store.dart';
import '../../domain/gameplay_config.dart';
import '../../l10n/app_localizations.dart';
import '../../telegram/telegram_bridge.dart';
import '../../ui/crystal_cube_icon.dart';
import '../../ui/game_sfx.dart';
import '../../ui/hud_fly_targets.dart';
import '../../ui/resting_cube_icon.dart';
import '../balance/crystals_sheet.dart';
import '../leaderboard/leaderboard_sheet.dart';
import '../result/result_screen.dart';
import '../result/share_score_sheet.dart';
import 'game_field_painter.dart';
import 'game_world.dart';
import 'impact_burst.dart';
import 'lives_sheet.dart';

enum _Phase { idle, playing, impact, result }

/// Гиперказуальный цикл: поле сверху, hint снизу.
/// Касание в любой части экрана управляет игроком (кроме HUD-кнопок).
class GameHomeScreen extends StatefulWidget {
  const GameHomeScreen({super.key, this.onLeave});

  /// Возврат к выбору режима (если задан).
  final VoidCallback? onLeave;

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with TickerProviderStateMixin {
  static const _hudHeight = 56.0;

  late final Ticker _ticker;
  late final AnimationController _hintPulse;
  late final ValueNotifier<int> _frame;
  /// HUD обновляем реже поля — иначе Flutter-layout каждый кадр на web лагает.
  late final ValueNotifier<int> _hudFrame;
  int _hudAccumMs = 0;
  GameWorld? _world;
  Size _fieldSize = Size.zero;
  GameplayConfig? _boundConfig;
  bool _ensureScheduled = false;

  _Phase _phase = _Phase.idle;
  Duration _lastElapsed = Duration.zero;
  int _aliveMs = 0;
  int _resultMs = 0;
  double _resultRun = 0;
  int _resultRisk = 0;
  double _rampT = 0;
  int _session = 0;
  /// Активные касания на поле (мультитач: 1-й — ход, 2-й — прыжок).
  final Set<int> _pointers = {};
  int? _primaryPointer;
  Offset? _primaryLastPos;
  final List<ImpactBurst> _impacts = [];
  double _impactHoldSec = 0;
  /// Шлем на текущую партию (1 заряд, если аренда была активна на старте).
  bool _runHelmetActive = false;
  /// Аренды на старте раунда — пишутся в score.
  bool _runHadJump = false;
  bool _runHadHelmet = false;
  /// Неуязвимость после разрушения шлема (секунды).
  double _helmetInvulnLeft = 0;
  /// Мигание карточки прыжка, если прыжок без аренды.
  Timer? _jumpWarnTimer;
  bool _jumpWarnLit = false;
  final Random _rng = Random();
  /// Смещение числа скорости в idle (±8), плавно едет к новой цели.
  double _idleSpeedWobble = 0;
  double _idleSpeedWobbleTarget = 0;
  /// Сколько risk уже озвучили в текущей партии.
  int _sfxRiskCount = 0;
  /// Earn-бонусы, открытые в этой партии (плашки только на результате).
  final List<String> _runEarnUnlocks = [];
  int _lastEarnCheckMs = 0;

  @override
  void initState() {
    super.initState();
    _frame = ValueNotifier<int>(0);
    _hudFrame = ValueNotifier<int>(0);
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audio = context.read<GameplayConfig>().audio;
      GameSfx.applyConfig(audio);
      GameSfx.ensureMusic();
    });
  }

  @override
  void dispose() {
    _jumpWarnTimer?.cancel();
    _ticker.dispose();
    _hintPulse.dispose();
    _frame.dispose();
    _hudFrame.dispose();
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
      _clearPointers();
      _impacts.clear();
      _impactHoldSec = 0;
      _runHelmetActive = false;
      _runHadJump = false;
      _runHadHelmet = false;
      _helmetInvulnLeft = 0;
      _idleSpeedWobble = 0;
      _idleSpeedWobbleTarget = 0;
      _runEarnUnlocks.clear();
      if (config != null && field != Size.zero) {
        _world = GameWorld(config: config, field: field)..resetLayout();
      }
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _clearPointers() {
    _pointers.clear();
    _primaryPointer = null;
    _primaryLastPos = null;
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

      // HUD ~10 раз/сек, поле — каждый тик.
      _hudAccumMs += dtMs;
      if (_hudAccumMs >= 100) {
        _hudAccumMs = 0;
        _hudFrame.value++;
      }

      if (_phase == _Phase.impact) {
        _impactHoldSec += dt;
        _impacts.removeWhere((b) => !b.update(dt));
        _frame.value++;
        if (_impactHoldSec >= 0.42) {
          _finishAfterImpact();
        }
        return;
      }

      if (_phase == _Phase.idle) {
        final bounces = world.tickIdle(dt);
        if (bounces.wall > 0) GameSfx.mobWall();
        if (bounces.enemy > 0) GameSfx.mobCollide();
        _tickIdleSpeedWobble(dt);
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
        world.tickJump(dt);
        final bounces =
            world.tickPlay(dt, _aliveMs / 1000.0, speedMult: speedMult);
        if (bounces.wall > 0) GameSfx.mobWall();
        if (bounces.enemy > 0) GameSfx.mobCollide();
        _sfxRiskIfNeeded(world);

        if (_helmetInvulnLeft > 0) {
          _helmetInvulnLeft = max(0.0, _helmetInvulnLeft - dt);
        }
        if (world.playerHitsBorder()) {
          if (!world.wallsKillPlayer) {
            world.clampPlayerToField();
          } else if (_helmetInvulnLeft <= 0) {
            _triggerImpact(againstWall: true);
            return;
          }
        }
        if (_helmetInvulnLeft <= 0 && world.playerHitsEnemy()) {
          _triggerImpact(againstWall: false);
          return;
        }
        if (_impacts.isNotEmpty) {
          _impacts.removeWhere((b) => !b.update(dt));
        }
        _maybeUnlockGameplayEarn();
        _frame.value++;
      }
    } catch (e, st) {
      debugPrint('Game tick error: $e\n$st');
    }
  }

  void _sfxRiskIfNeeded(GameWorld world) {
    if (world.nearMissCount <= _sfxRiskCount) return;
    _sfxRiskCount = world.nearMissCount;
    GameSfx.nearMiss();
  }

  /// Текст вызова на стартовой плашке (не тост во время игры).
  String? _startChallengeText(EconomyStore economy, AppLocalizations l10n) {
    if (!economy.canPlay) return null;
    final firstSec = economy.config.earnSurviveSeconds.clamp(1, 3600);
    final nextSec = economy.config.earnRecordSeconds.clamp(1, 3600);
    final best = economy.bestTimeMs;
    if (best < firstSec * 1000) {
      return l10n.tapHintChallenge(firstSec);
    }
    if (nextSec > firstSec && best < nextSec * 1000) {
      return l10n.tapHintNextChallenge(nextSec);
    }
    return null;
  }

  /// Открывает one-shot бонусы Earn (10с / рекорд 20с / 5 рисков) без тостов.
  void _maybeUnlockGameplayEarn() {
    final world = _world;
    if (world == null || !mounted) return;
    // Не чаще 4 раз/сек — sync дешёвый, но на web лучше не дёргать зря.
    if (_aliveMs - _lastEarnCheckMs < 250 && _aliveMs > 0) return;
    _lastEarnCheckMs = _aliveMs;
    final newly = context.read<EconomyStore>().syncGameplayEarnUnlocks(
          aliveMs: _aliveMs,
          riskCount: world.nearMissCount,
        );
    for (final id in newly) {
      if (!_runEarnUnlocks.contains(id)) _runEarnUnlocks.add(id);
    }
  }

  void _tickIdleSpeedWobble(double dt) {
    _idleSpeedWobble +=
        (_idleSpeedWobbleTarget - _idleSpeedWobble) * min(1.0, dt * 2.8);
    if ((_idleSpeedWobble - _idleSpeedWobbleTarget).abs() < 0.35) {
      // Новая цель: смещение от -8 до +8
      _idleSpeedWobbleTarget = (_rng.nextDouble() * 16.0) - 8.0;
    }
  }

  Offset _impactOrigin({required bool againstWall}) {
    final world = _world!;
    final cx = world.player.dx + world.playerSize / 2;
    final cy = world.player.dy + world.playerSize / 2;
    if (!againstWall) {
      final pr = Rect.fromLTWH(
        world.player.dx,
        world.player.dy,
        world.playerSize,
        world.playerSize,
      );
      for (final e in world.enemies) {
        if (pr.overlaps(e.rect)) {
          return Offset(
            (cx + e.rect.center.dx) / 2,
            (cy + e.rect.center.dy) / 2,
          );
        }
      }
      return Offset(cx, cy);
    }
    // Ближайшая точка на рамке
    final w = world.field.width;
    final h = world.field.height;
    final distL = cx;
    final distR = w - cx;
    final distT = cy;
    final distB = h - cy;
    final m = min(min(distL, distR), min(distT, distB));
    if (m == distL) return Offset(0, cy);
    if (m == distR) return Offset(w, cy);
    if (m == distT) return Offset(cx, 0);
    return Offset(cx, h);
  }

  void _triggerImpact({required bool againstWall}) {
    if (_phase != _Phase.playing || _world == null) return;

    // Шлем: одно касание стены/врага без смерти.
    if (_runHelmetActive) {
      _breakHelmet(againstWall: againstWall);
      return;
    }

    final theme = Theme.of(context);
    final origin = _impactOrigin(againstWall: againstWall);
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
            origin: origin,
            accent: theme.colorScheme.primary,
            danger: theme.colorScheme.error,
            againstWall: againstWall,
          ),
        );
      _impactHoldSec = 0;
      _phase = _Phase.impact;
    });
    _frame.value++;
  }

  void _breakHelmet({required bool againstWall}) {
    final theme = Theme.of(context);
    final origin = _impactOrigin(againstWall: againstWall);
    GameSfx.helmetBreak();
    setState(() {
      _runHelmetActive = false;
      _helmetInvulnLeft =
          context.read<GameplayConfig>().helmetInvulnSec.clamp(0.0, 5.0);
      _impacts.add(
        ImpactBurst.spawn(
          origin: origin,
          accent: const Color(0xFF7EE0FF),
          danger: theme.colorScheme.primary,
          againstWall: againstWall,
        ),
      );
    });
    _frame.value++;
  }

  void _finishAfterImpact() {
    if (_phase != _Phase.impact) return;
    _ticker.stop();
    final world = _world;
    setState(() {
      _phase = _Phase.result;
      _resultMs = _aliveMs;
      _resultRun = () {
        final w = world;
        if (w == null) return 0.0;
        final step = (w.playerSize * 0.1).clamp(1e-6, 1e9);
        return w.playerDistance / step;
      }();
      _resultRisk = world?.nearMissCount ?? 0;
      _impacts.clear();
      _clearPointers();
    });
    context.read<EconomyStore>().recordBestTime(_aliveMs);
    final newly = context.read<EconomyStore>().syncGameplayEarnUnlocks(
          aliveMs: _aliveMs,
          riskCount: _resultRisk,
        );
    for (final id in newly) {
      if (!_runEarnUnlocks.contains(id)) _runEarnUnlocks.add(id);
    }
    context.read<ScoresStore>().recordAttempt(
          _aliveMs,
          riskCount: _resultRisk,
          runDistance: _resultRun.round(),
          hadJump: _runHadJump,
          hadHelmet: _runHadHelmet,
        );
    AppAnalytics.gameFinish(
      timeMs: _aliveMs,
      riskCount: _resultRisk,
      runDistance: _resultRun.round(),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_phase == _Phase.idle) {
      _pointers
        ..clear()
        ..add(event.pointer);
      _primaryPointer = event.pointer;
      _primaryLastPos = event.localPosition;
      _startGameFromTouch();
      return;
    }
    if (_phase != _Phase.playing) return;

    if (_pointers.isEmpty) {
      _pointers.add(event.pointer);
      _primaryPointer = event.pointer;
      _primaryLastPos = event.localPosition;
      return;
    }

    // Уже есть палец на поле — второе (и далее) касание = прыжок.
    _pointers.add(event.pointer);
    _tryJump();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_phase != _Phase.playing || _world == null) return;
    if (event.pointer != _primaryPointer) return;

    final last = _primaryLastPos;
    _primaryLastPos = event.localPosition;
    if (last == null) return;

    final delta = event.localPosition - last;
    if (delta == Offset.zero) return;

    _world!.movePlayerBy(delta);
    if (_world!.playerHitsBorder()) {
      if (!_world!.wallsKillPlayer) {
        _world!.clampPlayerToField();
      } else if (_helmetInvulnLeft <= 0) {
        _triggerImpact(againstWall: true);
        return;
      }
    }
    if (_helmetInvulnLeft > 0) return;
    if (_world!.playerHitsEnemy()) {
      _triggerImpact(againstWall: false);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _releasePointer(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _releasePointer(event.pointer);
  }

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

  void _startGameFromTouch() {
    final economy = context.read<EconomyStore>();
    if (!economy.canPlay) {
      _clearPointers();
      showLivesSheet(context);
      return;
    }
    if (!economy.tryStartGame()) {
      _clearPointers();
      return;
    }
    AppAnalytics.gameStart();
    GameSfx.gameStart();
    final gameplay = context.read<GameplayConfig>();
    setState(() {
      _phase = _Phase.playing;
      _aliveMs = 0;
      _rampT = 0;
      _lastElapsed = Duration.zero;
      _sfxRiskCount = 0;
      _runEarnUnlocks.clear();
      _runHadJump = gameplay.jumpEnabled && economy.hasJumpRental;
      _runHadHelmet = gameplay.helmetEnabled && economy.hasHelmetRental;
      _runHelmetActive = _runHadHelmet;
      _helmetInvulnLeft = 0;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _tryJump() {
    final config = context.read<GameplayConfig>();
    final economy = context.read<EconomyStore>();
    if (!config.jumpEnabled || _world == null) return;
    if (!economy.hasJumpRental) {
      _flashJumpNotRented();
      return;
    }
    if (_world!.tryJump()) {
      GameSfx.jump();
      _frame.value++;
    }
  }

  /// Пара красных вспышек у чипа прыжка в HUD.
  void _flashJumpNotRented() {
    _jumpWarnTimer?.cancel();
    var ticksLeft = 6; // 3 цикла вкл/выкл
    setState(() => _jumpWarnLit = true);
    _jumpWarnTimer = Timer.periodic(const Duration(milliseconds: 110), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      ticksLeft--;
      if (ticksLeft <= 0) {
        t.cancel();
        setState(() => _jumpWarnLit = false);
        return;
      }
      setState(() => _jumpWarnLit = !_jumpWarnLit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final config = context.watch<GameplayConfig>();
    GameSfx.applyConfig(config.audio);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final world = _world;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1419),
      body: ValueListenableBuilder<EdgeInsets>(
        valueListenable: TelegramBridge.viewPadding,
        builder: (context, tgPad, _) {
          // Telegram fullscreen: MediaQuery/SafeArea часто 0 —
          // отступы из safeAreaInset + contentSafeAreaInset.
          final body = Stack(
            children: [
              // Визуальный layout: весь экран под HUD — управление героем.
              // Верхний HUD поверх Stack перехватывает клики (жизни/кристаллы/…).
              // Место под будущий баннер внизу можно вынести из зоны касаний.
              Column(
                children: [
                  const SizedBox(height: _hudHeight),
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
                                      boxShadow: kIsWeb
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: (config.wallsKillPlayer
                                                        ? theme.colorScheme.error
                                                        : theme.colorScheme.primary)
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
                                                accent:
                                                    theme.colorScheme.primary,
                                                danger:
                                                    theme.colorScheme.error,
                                                fieldColor: config.field
                                                    .resolveSurfaceColor(
                                                  theme.colorScheme.surface,
                                                ),
                                                borderColor: config.wallsKillPlayer
                                                    ? theme.colorScheme.error
                                                    : theme.colorScheme.primary,
                                                borderWidth:
                                                    config.borderWidth,
                                                cornerRadius: 18,
                                                frame: _frame.value,
                                                playerPreview:
                                                    _phase == _Phase.idle,
                                                impacts: _impacts,
                                                hasHelmet: _runHelmetActive,
                                                invulnerable:
                                                    _helmetInvulnLeft > 0,
                                                shadowBrightness: config
                                                    .field.shadowBrightness,
                                                showFace:
                                                    config.player.showFace,
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
                          IgnorePointer(
                            child: _PlayInfoBar(
                              frame: _hudFrame,
                              timeMs: () => _aliveMs,
                              enemyCount: () =>
                                  _world?.enemies.length ?? 0,
                              averageSpeed: () {
                                final world = _world;
                                if (world == null || world.enemies.isEmpty) {
                                  return 0.0;
                                }
                                if (_phase == _Phase.result) return 0.0;
                                final cfg = context.read<GameplayConfig>();
                                if (_phase == _Phase.idle) {
                                  final base = world.averageSpeed(
                                    0,
                                    speedMult: cfg.idleSpeedMultiplier,
                                  );
                                  return (base + _idleSpeedWobble)
                                      .clamp(0.0, cfg.hudSpeedScaleMax);
                                }
                                final rampSec =
                                    max(0.05, cfg.speedRampSeconds);
                                final idleMult = cfg.idleSpeedMultiplier;
                                final t =
                                    (_rampT / rampSec).clamp(0.0, 1.0);
                                final speedMult = idleMult +
                                    (1.0 - idleMult) *
                                        Curves.easeOut.transform(t);
                                return world.averageSpeed(
                                  _aliveMs / 1000.0,
                                  speedMult: speedMult,
                                );
                              },
                              playerRun: () {
                                final world = _world;
                                if (world == null) return 0.0;
                                final step =
                                    (world.playerSize * 0.1).clamp(1e-6, 1e9);
                                return world.playerDistance / step;
                              },
                              nearMiss: () =>
                                  _world?.nearMissCount ?? 0,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const _LaptopTouchpad(),
                                  if (_phase == _Phase.idle &&
                                      config.game.startHintEnabled)
                                    _TapToStartBanner(
                                      pulse: _hintPulse,
                                      brand: l10n.appTitle,
                                      challenge: _startChallengeText(
                                        economy,
                                        l10n,
                                      ),
                                      text: economy.canPlay
                                          ? l10n.tapHintPlayful
                                          : l10n.noLivesOpenCrystals,
                                      outOfLives: !economy.canPlay,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Подсказка: полупрозрачный палец водит внизу до первого касания
              if (_phase == _Phase.idle &&
                  config.game.startHintEnabled &&
                  economy.showSwipeHint)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: _FingerDragHint(),
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
                    jumpWarnLit: _jumpWarnLit,
                    onLeave: widget.onLeave,
                    onLivesTap: () {
                      AppAnalytics.tapLives();
                      showLivesSheet(context);
                    },
                    onCrystalsTap: () {
                      AppAnalytics.tapCrystals();
                      showCrystalsSheet(context);
                    },
                    onRecordTap: () {
                      AppAnalytics.tapRecord();
                      showLeaderboardSheet(context);
                    },
                  ),
                ),
              ),
              if (_phase == _Phase.result)
                ResultOverlay(
                  key: ValueKey('result-$_session-$_resultMs'),
                  timeMs: _resultMs,
                  runDistance: _resultRun,
                  riskCount: _resultRisk,
                  newlyUnlockedEarnIds:
                      List<String>.from(_runEarnUnlocks),
                  onOk: _resetToIdle,
                  onShare: () async {
                    AppAnalytics.shareOpen();
                    await showShareScoreSheet(
                      context,
                      timeMs: _resultMs,
                      riskCount: _resultRisk,
                      runDistance: _resultRun.round(),
                      hadJump: _runHadJump,
                      hadHelmet: _runHadHelmet,
                    );
                    if (mounted) _resetToIdle();
                  },
                ),
            ],
          );

          if (AppTargetConfig.isTelegram) {
            return Padding(padding: tgPad, child: body);
          }
          return SafeArea(child: body);
        },
      ),
    );
  }
}

/// Подсказка свайпа: рука с указательным пальцем.
/// Только вперёд: середина → угол → исчезновение → снова середина (другой угол).
/// Никогда не едет обратно по тому же пути.
class _FingerDragHint extends StatefulWidget {
  const _FingerDragHint();

  @override
  State<_FingerDragHint> createState() => _FingerDragHintState();
}

class _FingerDragHintState extends State<_FingerDragHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _toLeft = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener(_onStatus);
    _anim.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Пауза в невидимости у края, затем новый старт из середины
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _toLeft = !_toLeft);
      _anim.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _anim.removeStatusListener(_onStatus);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            if (w < 40 || h < 40) return const SizedBox.shrink();

            const size = 78.0;
            final t = _anim.value;

            // Движение строго 0→1 от центра к углу (без reverse).
            final start = Offset(w * 0.5 - size / 2, h * 0.78);
            final end = Offset(
              _toLeft ? w * 0.02 : w - size - w * 0.02,
              h * 0.58,
            );
            final pos = Offset.lerp(start, end, Curves.easeIn.transform(t))!;

            // Виден по пути; у края полностью прозрачен ДО рестарта из центра
            final opacity = t < 0.08
                ? (t / 0.08)
                : t > 0.82
                    ? ((1.0 - t) / 0.18).clamp(0.0, 1.0)
                    : 1.0;

            return Stack(
              children: [
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: Opacity(
                    opacity: opacity * 0.72,
                    child: Transform.rotate(
                      // Указательный палец смотрит в сторону свайпа
                      angle: _toLeft ? 0.55 : -0.55,
                      child: Icon(
                        Icons.pan_tool_alt_rounded,
                        size: size,
                        color: const Color(0xFFD6EAF4),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LaptopTouchpad extends StatelessWidget {
  const _LaptopTouchpad();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TouchpadPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TouchpadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pad = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(min(28.0, size.shortestSide * 0.12)),
    );

    // Матовая «резина» тачпада
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2A3138),
          Color(0xFF1C2228),
          Color(0xFF171C21),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(pad, fill);

    // Лёгкая кромка как у ноутбука
    canvas.drawRRect(
      pad,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      pad.deflate(1.2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Внутренний блик сверху
    final glossRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.06,
      size.width * 0.84,
      size.height * 0.28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glossRect, const Radius.circular(18)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glossRect),
    );

    // Нижняя «кнопка» / разделитель как на классическом тачпаде
    final grooveY = size.height * 0.78;
    final groove = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, grooveY),
      Offset(size.width * 0.82, grooveY),
      groove,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, grooveY + 1.2),
      Offset(size.width * 0.82, grooveY + 1.2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );

    // Едва заметная сетка текстуры
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.018);
    const step = 11.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        if (((x ~/ step) + (y ~/ step)) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), 0.7, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TapToStartBanner extends StatelessWidget {
  const _TapToStartBanner({
    required this.pulse,
    required this.brand,
    required this.text,
    this.challenge,
    this.outOfLives = false,
  });

  final Animation<double> pulse;
  final String brand;
  final String text;
  final String? challenge;
  final bool outOfLives;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        final accent = outOfLives
            ? const Color(0xFF7EE0FF)
            : const Color(0xFF3DDC97);
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
                    outOfLives
                        ? const Color(0xFF1E2C38)
                        : const Color(0xFF243840),
                    t,
                  )!,
                  const Color(0xFF12181E),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.55),
                  t,
                )!,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12 + t * 0.18),
                  blurRadius: 18 + t * 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Логотип / имя игры — не инструкция «не трогай».
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF0C1218).withValues(alpha: 0.72),
                    border: Border.all(
                      color: const Color(0xFF7EE0FF).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RestingCubeIcon(size: 18),
                        const SizedBox(width: 8),
                        Text(
                          brand,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1,
                            color: Color.lerp(
                              const Color(0xFF9ED8E8),
                              const Color(0xFFB8F4FF),
                              t,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (outOfLives) ...[
                  const SizedBox(height: 12),
                  Transform.translate(
                    offset: Offset(0, sin(t * pi) * 2),
                    child: const RestingCubeIcon(size: 72),
                  ),
                ],
                if (challenge != null) ...[
                  const SizedBox(height: 14),
                  Transform.scale(
                    scale: 0.97 + t * 0.05,
                    child: Text(
                      challenge!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        height: 1.2,
                        color: Color.lerp(
                          const Color(0xFFE8EEF4),
                          const Color(0xFFB8F4FF),
                          t * 0.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1.25,
                      color: Color.lerp(
                        const Color(0xFF9AA8B4),
                        accent.withValues(alpha: 0.9),
                        t * 0.55,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Transform.scale(
                    scale: 0.96 + t * 0.06,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
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
                ],
                if (!outOfLives) ...[
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayInfoBar extends StatelessWidget {
  const _PlayInfoBar({
    required this.frame,
    required this.timeMs,
    required this.enemyCount,
    required this.averageSpeed,
    required this.playerRun,
    required this.nearMiss,
  });

  static const _pulseFrom = 200.0;
  static const _cool = Color(0xFF7EE0FF);
  static const _hot = Color(0xFFFF3D4A);
  static const _labelH = 12.0;
  static const _gapH = 4.0;
  static const _valueH = 22.0;

  final ValueNotifier<int> frame;
  final int Function() timeMs;
  final int Function() enemyCount;
  final double Function() averageSpeed;
  final double Function() playerRun;
  final int Function() nearMiss;

  Color _speedColor(double speed, double scaleMax) {
    final t = Curves.easeIn.transform(
      (speed / scaleMax).clamp(0.0, 1.0),
    );
    return Color.lerp(_cool, _hot, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scaleMax = context
        .watch<GameplayConfig>()
        .hudSpeedScaleMax
        .clamp(50.0, 2000.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ListenableBuilder(
        listenable: frame,
        builder: (context, _) {
          final enemies = enemyCount();
          final speed = averageSpeed();
          final run = playerRun();
          final near = nearMiss();
          final bar = (speed / scaleMax).clamp(0.0, 1.0);
          final color = _speedColor(speed, scaleMax);

          final over =
              ((speed - _pulseFrom) / (scaleMax - _pulseFrom)).clamp(0.0, 1.0);
          final pulse = over <= 0
              ? 0.0
              : (sin(frame.value * (0.22 + over * 0.55)) + 1) / 2;
          final pulseAmp = over * (0.22 + over * 0.45);
          final barScaleY = 1.0 + pulse * pulseAmp;
          // BoxShadow.blur на каждом кадре на web даёт микрофризы.
          final glow = kIsWeb
              ? null
              : color.withValues(alpha: 0.35 + pulse * over * 0.45);
          final displayColor = over <= 0
              ? color
              : Color.lerp(color, Colors.white, pulse * over * 0.35)!;

          final speedBar = SizedBox(
            height: 6,
            child: Transform.scale(
              scaleY: barScaleY,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: glow == null || over <= 0
                      ? null
                      : [
                          BoxShadow(
                            color: glow,
                            blurRadius: 6 + pulse * over * 10,
                            spreadRadius: pulse * over * 1.5,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: bar,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: displayColor,
                  ),
                ),
              ),
            ),
          );

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SizedBox(
                height: _labelH + _gapH + _valueH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 15,
                      child: _InfoChip(
                        label: l10n.playInfoEnemies,
                        value: '$enemies',
                        labelHeight: _labelH,
                        gap: _gapH,
                        valueHeight: _valueH,
                      ),
                    ),
                    Expanded(
                      flex: 15,
                      child: _InfoChip(
                        label: l10n.playInfoSpeed,
                        labelHeight: _labelH,
                        gap: _gapH,
                        valueHeight: _valueH,
                        valueChild: speedBar,
                      ),
                    ),
                    Expanded(
                      flex: 40,
                      child: _InfoTimerChip(timeMs: timeMs()),
                    ),
                    Expanded(
                      flex: 15,
                      child: _InfoChip(
                        label: l10n.playInfoNear,
                        value: '$near',
                        accent: const Color(0xFFFFC107),
                        labelHeight: _labelH,
                        gap: _gapH,
                        valueHeight: _valueH,
                      ),
                    ),
                    Expanded(
                      flex: 15,
                      child: _InfoChip(
                        label: l10n.playInfoRun,
                        value: '${run.round()}',
                        labelHeight: _labelH,
                        gap: _gapH,
                        valueHeight: _valueH,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoTimerChip extends StatelessWidget {
  const _InfoTimerChip({required this.timeMs});

  final int timeMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ms = timeMs.clamp(0, 99 * 60 * 1000);
    final totalSec = ms ~/ 1000;
    final minutes = (totalSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSec % 60).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text(
          '$minutes:$seconds.$millis',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontSize: 48,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: theme.colorScheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _RentalTimerChip extends StatelessWidget {
  const _RentalTimerChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.active,
    this.onTap,
    this.compact = false,
    this.warnFlash = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool active;
  final VoidCallback? onTap;
  final bool compact;
  final bool warnFlash;

  @override
  Widget build(BuildContext context) {
    const warn = Color(0xFFFF5A5F);
    final color = warnFlash
        ? warn
        : (active ? accent : Colors.white38);
    final chip = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 2,
        vertical: compact ? 4 : 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: color),
          SizedBox(width: compact ? 3 : 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: warnFlash
                      ? warn.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color: warnFlash
                  ? warn.withValues(alpha: 0.28)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                // Ширина рамки фиксирована — иначе мигание трясёт HUD.
                width: 1.5,
                color: warnFlash
                    ? warn
                    : (active
                        ? accent.withValues(alpha: 0.55)
                        : Colors.white12),
              ),
            ),
            child: chip,
          ),
        ),
      );
    }

    return SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: chip,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.value,
    this.valueChild,
    this.accent,
    this.labelHeight = 12,
    this.gap = 4,
    this.valueHeight = 16,
  });

  final String label;
  final String? value;
  final Widget? valueChild;
  final Color? accent;
  final double labelHeight;
  final double gap;
  final double valueHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: labelHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: valueHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: valueChild ??
                  Text(
                    value ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: accent ?? const Color(0xFFE8EEF4),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hud extends StatefulWidget {
  const _Hud({
    required this.onLivesTap,
    required this.onCrystalsTap,
    required this.onRecordTap,
    this.onLeave,
    this.jumpWarnLit = false,
  });

  final VoidCallback onLivesTap;
  final VoidCallback onCrystalsTap;
  final VoidCallback onRecordTap;
  final VoidCallback? onLeave;
  final bool jumpWarnLit;

  @override
  State<_Hud> createState() => _HudState();
}

class _HudState extends State<_Hud> {
  Timer? _rentTick;

  static String _fmtRent(Duration? d) {
    if (d == null) return '--:--';
    final total = d.inSeconds.clamp(0, 24 * 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _rentTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rentTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyStore>();
    final gameplay = context.watch<GameplayConfig>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final showJump = gameplay.jumpEnabled;
    final showHelmet = gameplay.helmetEnabled;
    final jumpLeft = economy.jumpRentalRemaining;
    final helmetLeft = economy.helmetRentalRemaining;

    void openRent() => showCrystalsSheet(context, initialTab: 2);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (widget.onLeave != null) ...[
            IconButton(
              onPressed: widget.onLeave,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              color: Colors.white70,
            ),
            const SizedBox(width: 2),
          ],
          GestureDetector(
            onTap: widget.onLivesTap,
            child: KeyedSubtree(
              key: HudFlyTargets.livesKey,
              child: _HudChip(
                icon: Icon(
                  Icons.favorite,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                label: '${economy.lives}',
                highlight: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onCrystalsTap,
            child: KeyedSubtree(
              key: HudFlyTargets.crystalsKey,
              child: _HudChip(
                icon: const CrystalCubeIcon(size: 16, glow: false),
                label: '${economy.tokens}',
                highlight: true,
              ),
            ),
          ),
          if (showJump) ...[
            const SizedBox(width: 6),
            _RentalTimerChip(
              icon: Icons.keyboard_double_arrow_up_rounded,
              label: l10n.rentJumpTitle,
              value: _fmtRent(jumpLeft),
              accent: const Color(0xFF3DDC97),
              active: jumpLeft != null,
              compact: true,
              warnFlash: widget.jumpWarnLit,
              onTap: openRent,
            ),
          ],
          if (showHelmet) ...[
            const SizedBox(width: 6),
            _RentalTimerChip(
              icon: Icons.shield_outlined,
              label: l10n.rentHelmetTitle,
              value: _fmtRent(helmetLeft),
              accent: const Color(0xFF7EE0FF),
              active: helmetLeft != null,
              compact: true,
              onTap: openRent,
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: widget.onRecordTap,
            child: _HudChip(
              icon: Icon(
                Icons.emoji_events_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: economy.bestTimeMs > 0
                  ? '${(economy.bestTimeMs / 1000).toStringAsFixed(2)}s'
                  : '0',
              highlight: true,
            ),
          ),
        ],
      ),
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
