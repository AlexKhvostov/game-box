import '../../ui/game_run_scene.dart';
import '../../ui/energy_reward_motion.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../app/app_target.dart';
import '../../app/gameplay_debug.dart';
import 'game_debug_panel.dart';
import '../../data/app_analytics.dart';
import '../../data/economy_store.dart';
import '../../data/ads_service.dart';
import '../../data/player_preferences.dart';
import '../profile/profile_screen.dart';
import 'arcade_hud.dart';
import '../../data/scores_store.dart';
import '../../domain/gameplay_config.dart';
import '../../domain/arcade_rules.dart';
import '../../domain/round_delivery.dart';
import '../../l10n/app_localizations.dart';
import '../../telegram/telegram_bridge.dart';
import '../../ui/game_sfx.dart';
import '../../ui/game_ui.dart';
import '../../ui/game_viewport.dart';
import '../../ui/audience_gate.dart';
import '../../data/audience_policy.dart';
import '../balance/crystals_sheet.dart';
import '../leaderboard/leaderboard_sheet.dart';
import '../result/result_screen.dart';
import 'game_field_painter.dart';
import 'game_world.dart';
import 'game_start_guard.dart';
import 'impact_burst.dart';
import 'lives_sheet.dart';
import 'lives_recovery_banner.dart';
import 'game_touchpad.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _hudHeight = 112.0;

  late final Ticker _ticker;
  late final AnimationController _hintPulse;
  late final ValueNotifier<int> _frame;

  /// Refresh HUD at Mini App's cadence, independently from field repainting.
  late final ValueNotifier<int> _hudFrame;
  double _hudAccumMs = 0;
  GameWorld? _world;
  Size _fieldSize = Size.zero;
  double _visualFieldSide = GameViewport.referenceFieldSide;
  GameplayConfig? _boundConfig;
  bool _ensureScheduled = false;

  _Phase _phase = _Phase.idle;
  Duration _lastElapsed = Duration.zero;
  int _aliveMs = 0;
  double _elapsedPreciseMs = 0;
  bool _backgrounded = false;
  Timer? _interstitialTimer;
  int _resultMs = 0;
  double _resultRun = 0;
  int _resultRisk = 0;
  bool _resultRewardClaimed = true;
  int _previousBestTimeMs = 0;
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
  double _startInvulnLeft = 0;
  bool get _isInvulnerable => _helmetInvulnLeft > 0 || _startInvulnLeft > 0;

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
  final _debugFrame = ValueNotifier<int>(0);
  bool _debugVisible = false;
  double _debugAccumMs = 0;

  void _debugTimerTap() {
    if (!GameplayDebug.enabled) return;
    setState(() => _debugVisible = !_debugVisible);
    _debugFrame.value++;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  double? _resultArtworkDpr;
  bool _routeCurrent = true;
  bool _exchangeOpen = false;
  final _modalBackdrop = SnapshotController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (_routeCurrent != current) {
      _routeCurrent = current;
      _modalBackdrop.allowSnapshotting =
          !current && !kIsWeb && AppTargetConfig.isMobile;
      _lastElapsed = Duration.zero;
      if (!current) {
        _clearPointers();
        _ticker.stop();
        _hintPulse.stop();
      } else if (_phase != _Phase.result && !_backgrounded) {
        if (!_ticker.isActive) _ticker.start();
        if (_phase == _Phase.idle) _hintPulse.repeat(reverse: true);
      }
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_resultArtworkDpr == dpr) return;
    _resultArtworkDpr = dpr;
    // Decode the full result background before the first defeat, at its
    // displayed width and resolution. The image adds no animation work.
    unawaited(
      precacheImage(
        GameRunScene.resultProvider(
          min(358.0, MediaQuery.sizeOf(context).width - 24) - 3,
          dpr,
        ),
        context,
      ),
    );
    unawaited(precacheImage(GameRunScene.provider(358, dpr), context));
  }

  @override
  void dispose() {
    _debugFrame.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _jumpWarnTimer?.cancel();
    _ticker.dispose();
    _interstitialTimer?.cancel();
    _hintPulse.dispose();
    _frame.dispose();
    _hudFrame.dispose();
    _modalBackdrop.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // A resize can change the pointer transform while the finger stays down.
    // Re-anchor the next movement without losing or restarting the round.
    _primaryLastPos = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    _lastElapsed = Duration.zero;
    _clearPointers();
    if (_backgrounded) {
      _ticker.stop();
      _hintPulse.stop();
    } else if (_routeCurrent && _phase != _Phase.result) {
      if (!_ticker.isActive) _ticker.start();
      if (_phase == _Phase.idle) _hintPulse.repeat(reverse: true);
    }
    // Android account/ranking reconnect is owned by MobileConnection. Keep
    // gameplay's lifecycle independent of the native Google activity.
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
    _world = GameWorld(
      config: config,
      field: field,
      wallInset: ArcadeRules.wallInset(config.borderWidth),
    )..resetLayout();
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
    _interstitialTimer?.cancel();
    _hintPulse.repeat(reverse: true);
    final config = _boundConfig;
    final field = _fieldSize;
    setState(() {
      _phase = _Phase.idle;
      _aliveMs = 0;
      _elapsedPreciseMs = 0;
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
      _startInvulnLeft = 0;
      _idleSpeedWobble = 0;
      _idleSpeedWobbleTarget = 0;
      _runEarnUnlocks.clear();
      if (config != null && field != Size.zero) {
        _world = GameWorld(
          config: config,
          field: field,
          wallInset: ArcadeRules.wallInset(config.borderWidth),
        )..resetLayout();
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
    if (world == null || !mounted || _backgrounded || !_routeCurrent) return;
    if (_phase == _Phase.result) return;

    try {
      final rawDtMs = (_lastElapsed == Duration.zero)
          ? 0.0
          : (elapsed - _lastElapsed).inMicroseconds / 1000.0;
      _lastElapsed = elapsed;
      if (rawDtMs <= 0) return;
      final dtMs = min(50.0, rawDtMs);
      final dt = dtMs / 1000.0;
      final config = context.read<GameplayConfig>();

      if (_debugVisible) {
        _debugAccumMs += dtMs;
        if (_debugAccumMs >= 200) {
          _debugAccumMs = 0;
          _debugFrame.value++;
        }
      }

      _hudAccumMs += dtMs;
      final hudEveryMs = _phase == _Phase.playing ? 33 : 80;
      if (_hudAccumMs >= hudEveryMs) {
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
        final rampSec = max(0.0, config.speedRampSeconds);
        final idleMult = config.idleEnemiesMove
            ? config.idleSpeedMultiplier
            : 0.0;
        _rampT = min(rampSec, _rampT + dt);
        final t = rampSec > 0 ? (_rampT / rampSec).clamp(0.0, 1.0) : 1.0;
        final speedMult = rampSec > 0
            ? idleMult + (1.0 - idleMult) * Curves.easeOut.transform(t)
            : 1.0;

        _elapsedPreciseMs += dtMs;
        _aliveMs = _elapsedPreciseMs.floor();
        world.tickJump(dt);
        final bounces = world.tickPlay(
          dt,
          _elapsedPreciseMs / 1000.0,
          speedMult: speedMult,
          checkPlayerHits: !_isInvulnerable,
        );
        if (bounces.wall > 0) GameSfx.mobWall();
        if (bounces.enemy > 0) GameSfx.mobCollide();
        _sfxRiskIfNeeded(world);

        if (_startInvulnLeft > 0) {
          _startInvulnLeft = max(0.0, _startInvulnLeft - dt);
        }
        if (_helmetInvulnLeft > 0) {
          _helmetInvulnLeft = max(0.0, _helmetInvulnLeft - dt);
        }
        if (world.playerHitsBorder()) {
          if (!world.wallsKillPlayer) {
            world.clampPlayerToField();
          } else if (!_isInvulnerable) {
            _triggerImpact(againstWall: true);
            return;
          }
        }
        if (!_isInvulnerable && world.playerHitsEnemy()) {
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
    if (m == distL) {
      return Offset(0, cy);
    }
    if (m == distR) {
      return Offset(w, cy);
    }
    if (m == distT) {
      return Offset(cx, 0);
    }
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
    if (!againstWall) _world?.repelEnemiesFromPlayer();
    GameSfx.helmetBreak();
    setState(() {
      _runHelmetActive = false;
      _helmetInvulnLeft = max(
        0.0,
        context.read<GameplayConfig>().helmetInvulnSec,
      );
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
    _hintPulse.stop();
    final world = _world;
    setState(() {
      _phase = _Phase.result;
      _resultMs = _aliveMs;
      _resultRun = () {
        final w = world;
        if (w == null) {
          return 0.0;
        }
        return ArcadeRules.runSteps(w.playerDistance, w.playerSize).toDouble();
      }();
      _resultRisk = world?.nearMissCount ?? 0;
      _impacts.clear();
      _clearPointers();
    });
    // Award before the result animation, as in Mini App. The phase guard above
    // makes this transition one-shot; opening/closing the overlay cannot pay again.
    final economy = context.read<EconomyStore>();
    _previousBestTimeMs = economy.bestTimeMs;
    final policy = context.read<AudiencePolicy?>();
    _resultRewardClaimed =
        policy == null ||
        (policy.band != null && policy.band != AgeBand.unknown);
    final newly = economy.completeRound(
      timeMs: _aliveMs,
      runDistance: _resultRun.round(),
      riskCount: _resultRisk,
      grantReward: _resultRewardClaimed,
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
    _interstitialTimer?.cancel();
    final resultSession = _session;
    bool canShowResultAd() =>
        mounted &&
        !_backgrounded &&
        _session == resultSession &&
        _phase == _Phase.result &&
        ModalRoute.of(context)?.isCurrent == true &&
        economy.canShowResultInterstitial;
    _interstitialTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!canShowResultAd()) return;
      final ads = context.read<AdsService?>();
      if (ads != null && await ads.showInterstitial(canShow: canShowResultAd)) {
        economy.markInterstitialShown();
      }
    });
    AppAnalytics.gameFinish(
      timeMs: _aliveMs,
      riskCount: _resultRisk,
      runDistance: _resultRun.round(),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_phase == _Phase.idle) {
      // The HUD sits outside this listener. Every touch in the play area opens
      // the exchange while the recovery invitation is shown.
      if (!context.read<EconomyStore>().canPlay && !_canResumeEnergyRound) {
        _openLivesExchange();
        return;
      }
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

    // Pointer coordinates are already in the viewport's logical units.
    // Convert field display units to the fixed Telegram simulation units.
    _world!.movePlayerBy(
      delta * (GameViewport.referenceFieldSide / _visualFieldSide),
      checkEnemies: !_isInvulnerable,
    );
    if (_world!.playerHitsBorder()) {
      if (!_world!.wallsKillPlayer) {
        _world!.clampPlayerToField();
      } else if (!_isInvulnerable) {
        _triggerImpact(againstWall: true);
        return;
      }
    }
    if (_isInvulnerable) return;
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

  bool _startingRound = false;
  Map<String, dynamic>? _waitingEnergyRound;

  bool get _canResumeEnergyRound {
    final economy = context.read<EconomyStore>();
    if (!economy.energyEnabled) return false;
    final account = context.read<ScoresStore>().account;
    if (account == null) return false;
    if (_waitingEnergyRound?['owner'] == account.id) return true;
    final receipt = account.acceptedRoundLoadout;
    return account.pendingRoundRequestId != null &&
        receipt?['owner'] == account.id &&
        receipt?['activated'] != true;
  }

  final _fieldGeometryKey = GlobalKey();
  (GameWorld, Size)? _checkedGeometryLayout;

  String? _fieldGeometryIssue() {
    final box = _fieldGeometryKey.currentContext?.findRenderObject();
    final world = _world;
    if (world == null || box is! RenderBox || !box.hasSize) {
      return 'field_not_ready';
    }
    GameFieldPainter? drawn;
    void findPainter(Element element) {
      final widget = element.widget;
      if (widget is CustomPaint && widget.painter is GameFieldPainter) {
        drawn = widget.painter as GameFieldPainter;
      }
      element.visitChildElements(findPainter);
    }

    findPainter(_fieldGeometryKey.currentContext! as Element);
    if (drawn == null || !identical(drawn!.world, world)) {
      return 'paint_world_mismatch';
    }
    final view = View.of(context);
    final origin = box.localToGlobal(Offset.zero);
    final end = box.localToGlobal(box.size.bottomRight(Offset.zero));
    return GameStartGuard.check(
      world: world,
      paintedSize: box.size,
      displayedField: Rect.fromPoints(origin, end),
      visibleScreen: Offset.zero & (view.physicalSize / view.devicePixelRatio),
      devicePixelRatio: view.devicePixelRatio,
    );
  }

  void _showGeometryIssue(String issue) {
    _clearPointers();
    debugPrint('Arcade start blocked: $issue');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          Localizations.localeOf(context).languageCode == 'ru'
              ? 'Техническая неполадка игрового поля. Попытка не началась. Попробуйте перезапустить приложение.'
              : 'There is a technical problem with the game field. The run has not started. Please restart the app.',
          key: const ValueKey('game-start-technical-error'),
        ),
      ),
    );
  }

  void _checkPreparedField(GameWorld world, Size size) {
    final layout = (world, size);
    if (_checkedGeometryLayout == layout) return;
    _checkedGeometryLayout = layout;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(world, _world) || _phase != _Phase.idle) {
        return;
      }
      final issue = _fieldGeometryIssue();
      if (issue != null) _showGeometryIssue(issue);
    });
  }

  Future<void> _openLivesExchange() async {
    // The same pointer also reaches the banner button: push only one route.
    if (!mounted || _exchangeOpen) return;
    _exchangeOpen = true;
    _clearPointers();
    try {
      await showLivesSheet(context);
    } finally {
      _exchangeOpen = false;
    }
  }

  void _startGameFromTouch() async {
    if (_startingRound) return;
    final geometryIssue = _fieldGeometryIssue();
    if (geometryIssue != null) {
      _showGeometryIssue(geometryIssue);
      return;
    }
    final economy = context.read<EconomyStore>();
    if (!economy.canPlay && !_canResumeEnergyRound) {
      _clearPointers();
      _openLivesExchange();
      return;
    }
    final scores = context.read<ScoresStore>();
    final gameplay = context.read<GameplayConfig>();
    if (!scores.localHistoryReadable) {
      _clearPointers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            RoundDelivery.message(
              'round_storage_failed',
              ru: Localizations.localeOf(context).languageCode == 'ru',
            ),
          ),
        ),
      );
      return;
    }
    if (scores.rulesUpdateRequired) {
      _clearPointers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            RoundDelivery.message(
              'rules_changed',
              ru: Localizations.localeOf(context).languageCode == 'ru',
            ),
          ),
        ),
      );
      return;
    }
    final energyRun = economy.energyEnabled;
    final waitingReceipt =
        energyRun && _waitingEnergyRound?['owner'] == scores.account?.id
        ? _waitingEnergyRound
        : null;
    // Freeze selection before the first asynchronous request. A toggle or a
    // late profile response must not change a paid attempt's equipment.
    final selectedJump =
        gameplay.jumpEnabled &&
        (energyRun ? economy.jumpSelected : economy.hasJumpRental);
    final selectedHelmet =
        gameplay.helmetEnabled &&
        (energyRun ? economy.helmetSelected : economy.hasHelmetRental);
    if (energyRun && scores.instantRoundsEnabled) {
      final cost =
          economy.energyConfig.baseAttemptCost +
          (selectedHelmet ? economy.energyConfig.helmetExtraCost : 0) +
          (selectedJump ? economy.energyConfig.jumpExtraCost : 0);
      final key = scores.beginInstantRound(
        helmet: selectedHelmet,
        jump: selectedJump,
        cost: cost,
      );
      if (key == null) {
        _clearPointers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ru'
                  ? 'Не удалось сохранить новую попытку на телефоне. Попробуйте ещё раз.'
                  : 'Could not save a new run on this device. Please try again.',
            ),
          ),
        );
        return;
      }
      _launchLocalRound(jump: selectedJump, helmet: selectedHelmet);
      return;
    }
    setState(() => _startingRound = true);
    var confirmed = false;
    try {
      confirmed = waitingReceipt != null
          ? true
          : energyRun
          ? await scores.beginRound(
              helmet: selectedHelmet,
              jump: selectedJump,
              economyRevision: economy.energyConfig.revision,
            )
          : await scores.beginRound();
    } catch (_) {
      /* Show the normal retry message without locking the UI. */
    }
    if (!mounted) {
      if (confirmed && energyRun && waitingReceipt == null) {
        try {
          await scores.cancelRound();
        } catch (_) {}
      }
      return;
    }
    final preparedIssue = _fieldGeometryIssue();
    if (preparedIssue != null || !_routeCurrent || _backgrounded) {
      if (confirmed && energyRun && waitingReceipt == null) {
        try {
          await scores.cancelRound();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _startingRound = false);
      if (preparedIssue != null) _showGeometryIssue(preparedIssue);
      _clearPointers();
      return;
    }
    final error = scores.account?.roundError;
    final refused = {
      'insufficient_energy',
      'insufficient_lives',
      'no_lives',
      'rules_changed',
      'economy_update_required',
      'update_required',
      'revision_mismatch',
      'energy_unavailable',
      'round_canceled',
    }.contains(error);
    final localPractice =
        !confirmed &&
        !refused &&
        scores.account?.pendingRoundRequestId == null &&
        (error == 'online_disabled' ||
            error == 'connection_failed' ||
            (error == null && scores.account?.error == 'connection_failed'));
    if (!confirmed && !localPractice) {
      setState(() => _startingRound = false);
      _clearPointers();
      if (error == 'insufficient_energy' || error == 'insufficient_lives') {
        _openLivesExchange();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ru'
                ? (error == 'rules_changed'
                      ? 'Правила обновились. Перезапустите игру для загрузки настроек.'
                      : 'Не удалось начать попытку. Проверьте подключение.')
                : (error == 'rules_changed'
                      ? 'Rules changed. Restart the game to load the settings.'
                      : 'Could not start a run. Check your connection.'),
          ),
        ),
      );
      return;
    }
    if (confirmed &&
        energyRun &&
        scores.account != null &&
        waitingReceipt == null) {
      try {
        // Once this receipt is acknowledged it cannot be refunded by closing
        // the screen, restarting the app, or a second device racing finish.
        await scores.activateRound();
      } catch (_) {
        if (!mounted) return;
        setState(() => _startingRound = false);
        _clearPointers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ru'
                  ? 'Подтверждаем попытку. Коснитесь поля ещё раз.'
                  : 'Confirming the run. Touch the field again.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final issueAfterActivation = _fieldGeometryIssue();
      if (!_routeCurrent || _backgrounded || issueAfterActivation != null) {
        // Payment is already activated. Keep this exact receipt for the next
        // visible field touch instead of running behind a modal or charging again.
        _waitingEnergyRound = {
          ...?scores.account?.acceptedRoundLoadout,
          'owner': scores.account?.id,
          'helmet':
              scores.account?.acceptedRoundLoadout?['helmet'] ?? selectedHelmet,
          'jump': scores.account?.acceptedRoundLoadout?['jump'] ?? selectedJump,
        };
        setState(() => _startingRound = false);
        _clearPointers();
        if (issueAfterActivation != null) {
          _showGeometryIssue(issueAfterActivation);
        }
        return;
      }
    }
    if ((scores.account == null || localPractice) &&
        !(energyRun
            ? economy.spendEnergyForPractice()
            : economy.tryStartGame())) {
      setState(() => _startingRound = false);
      _clearPointers();
      return;
    }
    if (localPractice && scores.account?.onlineAllowed != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Локальная попытка без общего рейтинга. Подключитесь к сети для сохранения.'
                : 'Local run without shared ranking. Connect to save ranked runs.',
          ),
        ),
      );
    }
    final accepted =
        waitingReceipt ??
        (confirmed && energyRun ? scores.account?.acceptedRoundLoadout : null);
    _launchLocalRound(
      jump: accepted?['jump'] as bool? ?? selectedJump,
      helmet: accepted?['helmet'] as bool? ?? selectedHelmet,
    );
  }

  void _launchLocalRound({required bool jump, required bool helmet}) {
    AppAnalytics.gameStart();
    _hintPulse.stop();
    GameSfx.gameStart();
    final gameplay = context.read<GameplayConfig>();
    setState(() {
      _waitingEnergyRound = null;
      _startingRound = false;
      _phase = _Phase.playing;
      _aliveMs = 0;
      _elapsedPreciseMs = 0;
      _rampT = 0;
      _lastElapsed = Duration.zero;
      _sfxRiskCount = 0;
      _runEarnUnlocks.clear();
      _runHadJump = jump;
      _runHadHelmet = helmet;
      _runHelmetActive = _runHadHelmet;
      _helmetInvulnLeft = 0;
      _startInvulnLeft = max(0.0, gameplay.startInvulnSec);
      _world?.snapEnemiesToHome();
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _tryJump() {
    final config = context.read<GameplayConfig>();
    final economy = context.read<EconomyStore>();
    if (!config.jumpEnabled || _world == null) return;
    if (!(economy.energyEnabled ? _runHadJump : economy.hasJumpRental)) {
      _flashJumpBlocked();
      return;
    }
    if (_world!.tryJump()) {
      GameSfx.jump();
      _frame.value++;
    } else {
      _flashJumpBlocked();
    }
  }

  /// Пара красных вспышек у чипа прыжка в HUD.
  void _flashJumpBlocked() {
    _jumpWarnTimer?.cancel();
    var ticksLeft = 4; // Две короткие вспышки, затем обычное состояние.
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
    final media = MediaQuery.of(context);
    // Includes both rows and every inset before the field. Width scaling is
    // shared with the field, so this proportion remains true on the device.
    final availableHeight = media.size.height - media.padding.vertical;
    final desiredHudHeight = _hudHeight;
    final hudHeight = min(desiredHudHeight, availableHeight * .20);
    final economy = context.watch<EconomyStore>();
    final config = context.watch<GameplayConfig>();
    final prefs = context.watch<PlayerPreferences?>();
    if (prefs == null) {
      GameSfx.applyConfig(config.audio);
    } else {
      prefs.applyAudio(config.audio);
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final world = _world;
    final heroColor = AppTargetConfig.isMobile
        ? GameFieldColors.hero
        : theme.colorScheme.primary;
    final enemyColor = AppTargetConfig.isMobile
        ? GameFieldColors.enemy
        : theme.colorScheme.error;
    final wallColor = config.wallsKillPlayer
        ? enemyColor
        : (AppTargetConfig.isMobile
              ? GameFieldColors.wall
              : theme.colorScheme.primary);

    return EnergyRewardMotion(
      economy: AppTargetConfig.isMobile ? economy : null,
      owner: economy.energyOwner,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: GameUi.background,
        body: ValueListenableBuilder<EdgeInsets>(
          valueListenable: TelegramBridge.viewPadding,
          builder: (context, tgPad, _) {
            // Telegram fullscreen: MediaQuery/SafeArea часто 0 —
            // отступы из safeAreaInset + contentSafeAreaInset.
            final field = Stack(
              key: const ValueKey('arcade-field-scene'),
              children: [
                // The perspective plane starts behind the field and extends
                // beyond its width. It remains when the start caption disappears.
                Positioned(
                  top:
                      hudHeight +
                      min(
                            media.size.width - 32,
                            GameViewport.referenceFieldSide,
                          ) *
                          .35,
                  left: -64,
                  right: -64,
                  bottom: 16,
                  child: const IgnorePointer(child: GameTouchpad()),
                ),
                // Визуальный layout: весь экран под HUD — управление героем.
                // Верхний HUD поверх Stack перехватывает клики (жизни/кристаллы/…).
                // Место под будущий баннер внизу можно вынести из зоны касаний.
                Column(
                  children: [
                    SizedBox(height: hudHeight),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final side = min(
                                    constraints.maxWidth,
                                    GameViewport.referenceFieldSide,
                                  );
                                  final size = Size(side, side);
                                  _visualFieldSide = side;
                                  _scheduleEnsureWorld(
                                    const Size.square(
                                      GameViewport.referenceFieldSide,
                                    ),
                                    config,
                                  );
                                  if (world == null) {
                                    return SizedBox(width: side, height: side);
                                  }
                                  _checkPreparedField(world, size);
                                  return Center(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: kIsWeb
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: wallColor.withValues(
                                                    alpha: 0.16,
                                                  ),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: RepaintBoundary(
                                          key: _fieldGeometryKey,
                                          child: CustomPaint(
                                            key: const ValueKey(
                                              'arcade-game-field',
                                            ),
                                            size: size,
                                            painter: GameFieldPainter(
                                              drawGrid:
                                                  AppTargetConfig.isMobile,
                                              world: world,
                                              accent: heroColor,
                                              danger: enemyColor,
                                              fieldColor: config.field
                                                  .resolveSurfaceColor(
                                                    AppTargetConfig.isMobile
                                                        ? GameFieldColors.floor
                                                        : theme
                                                              .colorScheme
                                                              .surface,
                                                  ),
                                              borderColor: wallColor,
                                              borderWidth: config.borderWidth,
                                              cornerRadius: 18,
                                              repaint: _frame,
                                              frameValue: () => _frame.value,
                                              invulnerableNow: () =>
                                                  _isInvulnerable,
                                              playerPreview:
                                                  _phase == _Phase.idle,
                                              impacts: _impacts,
                                              hasHelmet: _runHelmetActive,
                                              invulnerable: _isInvulnerable,
                                              shadowBrightness:
                                                  config.field.shadowBrightness,
                                              showFace: config.player.showFace,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  16,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_phase == _Phase.idle &&
                                        (!(economy.canPlay ||
                                                _canResumeEnergyRound) ||
                                            config.game.startHintEnabled))
                                      SingleChildScrollView(
                                        child:
                                            !(economy.canPlay ||
                                                _canResumeEnergyRound)
                                            ? LivesRecoveryBanner(
                                                onGetLives: _openLivesExchange,
                                              )
                                            : _TapToStartBanner(
                                                brand: l10n.appTitle,
                                                text: economy.energyEnabled
                                                    ? (Localizations.localeOf(
                                                                context,
                                                              ).languageCode ==
                                                              'ru'
                                                          ? 'Попытка: ${economy.attemptEnergyCost} ⚡ · коснитесь поля'
                                                          : 'Run: ${economy.attemptEnergyCost} ⚡ · touch the field')
                                                    : l10n.tapHintPlayful,
                                              ),
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
                    (economy.canPlay || _canResumeEnergyRound) &&
                    config.game.startHintEnabled &&
                    economy.showSwipeHint)
                  const Positioned.fill(
                    child: IgnorePointer(child: _FingerDragHint()),
                  ),
              ],
            );
            // Freeze only the expensive scene. Wallet/HUD changes must still be
            // painted while a non-opaque dialog covers the game route.
            final frozenField = !kIsWeb && AppTargetConfig.isMobile
                ? SnapshotWidget(
                    key: const ValueKey('game-modal-backdrop'),
                    controller: _modalBackdrop,
                    mode: SnapshotMode.permissive,
                    autoresize: true,
                    child: field,
                  )
                : field;
            final body = Stack(
              key: const ValueKey('arcade-play-area'),
              children: [
                Positioned.fill(child: frozenField),
                // HUD поверх жестов — кнопки перехватывают клики
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    key: const ValueKey('arcade-hud-region'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: SizedBox(
                      height: max(0, hudHeight - 8),
                      child: ArcadeHud(
                        isPlaying: _phase != _Phase.idle || _startingRound,
                        onTimerTap: GameplayDebug.enabled
                            ? _debugTimerTap
                            : null,
                        helmetActive: _phase == _Phase.idle
                            ? (economy.energyEnabled
                                  ? economy.helmetSelected
                                  : economy.hasHelmetRental)
                            : _runHelmetActive,
                        helmetEquipped: _phase == _Phase.idle
                            ? (economy.energyEnabled
                                  ? economy.helmetSelected
                                  : economy.hasHelmetRental)
                            : _runHadHelmet,
                        compact:
                            media.textScaler.scale(12) > 18 &&
                            hudHeight < desiredHudHeight,
                        jumpWarnLit: _jumpWarnLit,
                        frame: _hudFrame,
                        animationFrame: _frame,
                        timeMs: () => _aliveMs,
                        riskCount: () => _world?.nearMissCount ?? 0,
                        runDistance: () => _world == null
                            ? 0
                            : ArcadeRules.runSteps(
                                _world!.playerDistance,
                                _world!.playerSize,
                              ),
                        jumpProgress: () {
                          final w = _world;
                          return w == null
                              ? 1.0
                              : (1 -
                                        w.jumpCooldownRemaining() /
                                            w.jumpCooldownMs)
                                    .clamp(0.0, 1.0);
                        },
                        jumpRemainingMs: () =>
                            _world?.jumpCooldownRemaining() ?? 0,
                        onProfileTap: () => showProfileSheet(context),
                        onLeave: widget.onLeave,
                        onLivesTap: () {
                          AppAnalytics.tapLives();
                          _openLivesExchange();
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
                ),
                if (_debugVisible &&
                    GameplayDebug.enabled &&
                    world != null &&
                    _phase != _Phase.result)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: GameDebugPanel(
                      world: world,
                      frame: _debugFrame,
                      timeMs: () => _aliveMs,
                      phase: () => _phase.name.toUpperCase(),
                    ),
                  ),
                if (_phase == _Phase.result)
                  ResultOverlay(
                    key: ValueKey('result-$_session-$_resultMs'),
                    timeMs: _resultMs,
                    previousBestTimeMs: _previousBestTimeMs,
                    rewardClaimed: _resultRewardClaimed,
                    onClaimReward: () async {
                      if (_resultRewardClaimed) {
                        return true;
                      }
                      final resultSession = _session;
                      final economy = context.read<EconomyStore>();
                      final scores = context.read<ScoresStore>();
                      if (!await ensureResourceAge(context) ||
                          !mounted ||
                          resultSession != _session ||
                          _phase != _Phase.result) {
                        return false;
                      }
                      if (!_resultRewardClaimed) {
                        final attempt = scores.latestAttempt;
                        // The current mobile API grants the round reward itself.
                        // Never add a second local credit on top of its wallet.
                        final serverReward =
                            economy.sendOperation != null &&
                            scores.account != null &&
                            attempt != null &&
                            (attempt.shared ||
                                scores.isAttemptPending(attempt.id));
                        if (serverReward) {
                          await scores.retryPendingResults();
                          if (!mounted ||
                              resultSession != _session ||
                              scores.isAttemptPending(attempt.id)) {
                            return false;
                          }
                          try {
                            await scores.account!.refreshProfile();
                          } catch (_) {
                            return false;
                          }
                          if (!mounted || resultSession != _session) {
                            return false;
                          }
                        } else {
                          economy.grantCrystals(
                            ArcadeRules.roundReward(
                              economy.config,
                              _resultRun.round(),
                              _resultRisk,
                            ),
                          );
                        }
                        _resultRewardClaimed = true;
                      }
                      return true;
                    },
                    runDistance: _resultRun,
                    riskCount: _resultRisk,
                    newlyUnlockedEarnIds: List<String>.from(_runEarnUnlocks),
                    onOk: _resetToIdle,
                    onShare: () async {
                      await showLeaderboardSheet(context);
                    },
                  ),
              ],
            );

            if (AppTargetConfig.isTelegram) {
              return Padding(
                padding: tgPad,
                child: TickerMode(enabled: _routeCurrent, child: body),
              );
            }
            return SafeArea(
              child: TickerMode(enabled: _routeCurrent, child: body),
            );
          },
        ),
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
            if (w < 40 || h < 40) {
              return const SizedBox.shrink();
            }

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

class _TapToStartBanner extends StatelessWidget {
  const _TapToStartBanner({required this.brand, required this.text});
  final String brand;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('game-start-caption'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameArtwork(GameArt.crouched, size: 32),
            const SizedBox(width: 8),
            Text(
              brand,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB8F4FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.25,
            color: Color(0xFFE8EEF4),
          ),
        ),
      ],
    ),
  );
}
