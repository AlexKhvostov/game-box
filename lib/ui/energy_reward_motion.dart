import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'energy_widgets.dart';
import 'hud_fly_targets.dart';
import '../data/economy_store.dart';

double _clamp(double n) => n.clamp(0.0, 1.0);
double _ease(double n) => 1 - math.pow(1 - n, 3).toDouble();
double _pop(double n) =>
    1 + 2.70158 * math.pow(n - 1, 3) + 1.70158 * math.pow(n - 1, 2);

/// The final UI-kit playEnergyReward timeline, in CSS/logical pixels.
/// All motion is driven by elapsed time; it never credits or persists energy.
class EnergyRewardFrame {
  EnergyRewardFrame(double progress, {required this.reduced})
    : p = _clamp(progress);
  final double p;
  final bool reduced;
  double get appearance => _clamp(p / .1125);
  double get flight => reduced ? 0 : _clamp((p - .4) / .4);
  double get fly => flight < .5
      ? 4 * flight * flight * flight
      : 1 - math.pow(-2 * flight + 2, 3) / 2;
  double get scale =>
      reduced ? 1 : (.82 + .18 * _pop(appearance)) * (1 - .78 * fly);
  double get opacity => appearance * (1 - _clamp((flight - .76) / .24));
  double get roll => reduced ? p : _clamp((p - .8) / .2);
  double get hit => reduced ? 0 : math.sin(math.pi * _clamp((p - .83) / .17));
  Offset position(Offset from, Offset to) => Offset(
    from.dx + (to.dx - from.dx) * fly,
    from.dy +
        (to.dy - from.dy) * fly -
        (reduced ? 0 : math.sin(math.pi * flight) * 30),
  );
}

class _RewardEvent {
  const _RewardEvent(
    this.from,
    this.to,
    this.amount,
    this.before,
    this.after,
    this.width,
    this.ru,
  );
  final Offset from, to;
  final int amount, before, after;
  final double width;
  final bool ru;
}

class EnergyRewardMotion extends StatefulWidget {
  const EnergyRewardMotion({
    super.key,
    required this.child,
    this.owner,
    this.economy,
    this.sourceKey,
  });
  final Widget child;
  final Object? owner;

  /// Optional shared observer: all confirmed credits, independent of their
  /// source (bonus, video, purchase, feedback or invite), use one presentation.
  final EconomyStore? economy;
  final GlobalKey? sourceKey;
  @override
  State<EnergyRewardMotion> createState() => EnergyRewardMotionState();
}

class EnergyRewardMotionState extends State<EnergyRewardMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  _RewardEvent? _event;
  OverlayEntry? _overlay;
  _EnergyReceipts? _receipts;
  Future<void> _finished = Future.value();
  final Set<String> _shownOperations = {};
  int _revision = 0;
  bool _reduced = false;
  Size? _viewport;
  bool get isActive => _event != null;
  EnergyRewardFrame get frame =>
      EnergyRewardFrame(_clock.value, reduced: _reduced);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1600),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) cancel();
        });
  }

  /// Returns false for an overlapping/replayed event. Coordinates are global
  /// anchors of the visible source and main HUD, captured after the wallet ACK.
  bool play({
    required Offset from,
    required Offset to,
    required int amount,
    int before = 0,
    int? after,
    String? operationId,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (!mounted ||
        isActive ||
        amount <= 0 ||
        (operationId != null && _shownOperations.contains(operationId)) ||
        box == null ||
        !box.hasSize) {
      return false;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null || overlayBox == null || !overlayBox.hasSize) {
      return false;
    }
    final end = after ?? before + amount;
    if (end <= before || end - before != amount) return false;
    final mediaSize = MediaQuery.sizeOf(context);
    final view = View.of(context);
    final viewport = mediaSize.isEmpty
        ? view.physicalSize / view.devicePixelRatio
        : mediaSize;
    if (viewport.width < 144 || viewport.height < 208) return false;
    final width = math.min(
      230.0,
      math.min(box.size.width * .86, viewport.width - 40),
    );
    final panel = box.localToGlobal(box.size.center(Offset.zero));
    final sx = panel.dx
        .clamp(
          width / 2 + 16,
          math.max(width / 2 + 16, viewport.width - width / 2 - 16),
        )
        .toDouble();
    final sy = from.dy
        .clamp(104.0, math.max(104.0, viewport.height - 104))
        .toDouble();
    if (operationId != null) _shownOperations.add(operationId);
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    setState(() {
      _event = _RewardEvent(
        overlayBox.globalToLocal(Offset(sx, sy)),
        overlayBox.globalToLocal(to),
        amount,
        before,
        end,
        width,
        Localizations.localeOf(context).languageCode == 'ru',
      );
      _revision++;
    });
    _overlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Directionality(
            textDirection: Directionality.of(context),
            child: DefaultTextStyle(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(decoration: TextDecoration.none),
              child: _buildEffect(),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
    _clock.duration = Duration(milliseconds: _reduced ? 180 : 1600);
    _finished = _clock.forward(from: 0).orCancel.catchError((Object _) {});
    return true;
  }

  void cancel({bool rebuild = true}) {
    if (!isActive) return;
    _clock.stop();
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    _event = null;
    _revision++;
    if (rebuild && mounted) {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(EnergyRewardMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.economy != widget.economy) _bindReceipts();
    if (oldWidget.owner != widget.owner) {
      cancel(rebuild: false);
      _shownOperations.clear();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindReceipts();
    final size = MediaQuery.sizeOf(context);
    if ((_viewport != null && _viewport != size) ||
        !TickerMode.valuesOf(context).enabled) {
      cancel(rebuild: false);
    }
    _viewport = size;
  }

  void _bindReceipts() {
    if (_receipts?.economy == widget.economy) return;
    _receipts?.remove(this);
    _receipts = widget.economy == null
        ? null
        : _EnergyReceipts.forStore(widget.economy!);
    _receipts?.add(this);
  }

  Future<void> _presentReceipt(_EnergyCredit credit) async {
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final source =
        widget.sourceKey?.currentContext?.findRenderObject() as RenderBox?;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final from = source != null && source.attached && source.hasSize
        ? source.localToGlobal(source.size.center(Offset.zero))
        : box.localToGlobal(box.size.center(Offset.zero));
    final target =
        HudFlyTargets.centerOf(ToastFlyTarget.energy) ??
        HudFlyTargets.fallbackOf(
          ToastFlyTarget.energy,
          MediaQuery.sizeOf(context),
        );
    if (play(
      from: from,
      to: target,
      amount: credit.after - credit.before,
      before: credit.before,
      after: credit.after,
      operationId: 'receipt:${credit.id}',
    )) {
      await _finished;
    }
  }

  @override
  void didChangeMetrics() => cancel();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancel();
  }

  @override
  void dispose() {
    _receipts?.remove(this);
    cancel(rebuild: false);
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RewardScope(
    motion: this,
    revision: _revision,
    notifier: _clock,
    child: NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
          cancel();
        }
        return false;
      },
      child: widget.child,
    ),
  );

  Widget _buildEffect() {
    final event = _event;
    if (event == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: event.ru
            ? 'Получено ${event.amount} энергии. Баланс ${event.after}'
            : 'Received ${event.amount} energy. Balance ${event.after}',
        child: ExcludeSemantics(
          child: RepaintBoundary(
            key: const ValueKey('bonus-confirmed-celebration'),
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final f = frame;
                final point = f.position(event.from, event.to);
                final payout = math.min(
                  56.0,
                  math.min(
                    event.width * .25,
                    (event.width - 72) /
                        (event.amount.toString().length + 1) /
                        .75,
                  ),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _BurstPainter(event, f)),
                    ),
                    Positioned(
                      left: point.dx - event.width / 2,
                      top: point.dy - 93,
                      width: event.width,
                      height: 186,
                      child: Transform.scale(
                        key: const ValueKey('energy-reward-flight'),
                        scale: f.scale,
                        child: Opacity(
                          opacity: f.opacity,
                          child: _RewardCard(event: event, payout: payout),
                        ),
                      ),
                    ),
                    if (!_reduced)
                      Positioned.fill(
                        child: CustomPaint(painter: _MotesPainter(event, f)),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EnergyCredit {
  _EnergyCredit(this.owner, this.before, this.after, this.id);
  final String? owner;
  final int before, after, id;
}

/// One observer per wallet prevents duplicate effects when both the game and
/// its energy dialog are mounted. Cached/initial wallets and owner switches
/// establish a baseline; only subsequent confirmed positive deltas celebrate.
class _EnergyReceipts {
  _EnergyReceipts(this.economy) : display = ValueNotifier(economy.energy) {
    _remember();
    economy.addListener(_updated);
  }
  static final _stores = Expando<_EnergyReceipts>();
  static _EnergyReceipts forStore(EconomyStore e) =>
      _stores[e] ??= _EnergyReceipts(e);
  final EconomyStore economy;
  final ValueNotifier<int> display;
  final _hosts = <EnergyRewardMotionState>[];
  final _queue = <_EnergyCredit>[];
  String? _owner;
  int _balance = 0, _serial = 0, _held = 0, _revealed = 0, _generation = 0;
  bool _live = false, _draining = false;
  void _remember() {
    _owner = economy.energyOwner;
    _balance = economy.confirmedEnergy;
    _live =
        economy.energyEnabled &&
        economy.energyClockSynchronized &&
        _owner != null;
  }

  // The wallet is already confirmed/persisted. This projection alone delays
  // the visible receipt; spending, persistence and authorization use the wallet.
  void _paintBalance() =>
      display.value = math.max(0, economy.energy - _held + _revealed);
  void add(EnergyRewardMotionState host) => _hosts.add(host);
  void remove(EnergyRewardMotionState host) {
    _hosts.remove(host);
    if (_hosts.isEmpty) {
      economy.removeListener(_updated);
      _stores[economy] = null;
      _queue.clear();
      _held = _revealed = 0;
      _generation++;
    }
  }

  void _updated() {
    final owner = _owner, before = _balance, live = _live;
    _remember();
    if (_owner != owner || !_live) {
      _queue.clear();
      _held = _revealed = 0;
      _generation++;
      for (final host in List<EnergyRewardMotionState>.of(_hosts)) {
        host.cancel();
      }
    }
    final credit = live && _live && owner == _owner && _balance > before;
    if (credit) {
      _held += _balance - before;
      _queue.add(_EnergyCredit(owner, before, _balance, ++_serial));
    }
    _paintBalance();
    if (!credit || _draining) return;
    _draining = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drain());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _drain() async {
    try {
      while (_queue.isNotEmpty && _hosts.isNotEmpty) {
        final credit = _queue.removeAt(0), generation = _generation;
        if (credit.owner != economy.energyOwner) continue;
        final host =
            _hosts.reversed
                .where(
                  (h) =>
                      h.mounted &&
                      (ModalRoute.of(h.context)?.isCurrent ?? true),
                )
                .firstOrNull ??
            _hosts.first;
        if (host.isActive) await host._finished;
        if (credit.owner != economy.energyOwner || generation != _generation) {
          continue;
        }
        if (!host.mounted) {
          _held -= credit.after - credit.before;
          _paintBalance();
          continue;
        }
        void roll() {
          if (generation != _generation) return;
          _revealed = ((credit.after - credit.before) * host.frame.roll)
              .round();
          _paintBalance();
        }

        host._clock.addListener(roll);
        try {
          await host._presentReceipt(credit);
        } finally {
          host._clock.removeListener(roll);
          if (generation == _generation) {
            _held -= credit.after - credit.before;
            _revealed = 0;
            _paintBalance();
          }
        }
      }
    } finally {
      _draining = false;
    }
  }
}

/// The same visual number drives the main HUD and the open energy window.
/// Without a receipt host (isolated component/catalog), show the normal wallet.
class EnergyRewardCounter extends StatelessWidget {
  const EnergyRewardCounter({
    super.key,
    required this.economy,
    required this.builder,
  });
  final EconomyStore economy;
  final Widget Function(int amount) builder;
  @override
  Widget build(BuildContext context) {
    final receipts = _EnergyReceipts._stores[economy];
    if (receipts == null) return builder(economy.energy);
    return ValueListenableBuilder<int>(
      valueListenable: receipts.display,
      builder: (_, amount, child) => builder(amount),
    );
  }
}

class _RewardScope extends InheritedNotifier<AnimationController> {
  const _RewardScope({
    required this.motion,
    required this.revision,
    required super.notifier,
    required super.child,
  });
  final EnergyRewardMotionState motion;
  final int revision;
  static EnergyRewardMotionState? of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_RewardScope>()?.motion;
  @override
  bool updateShouldNotify(_RewardScope oldWidget) =>
      revision != oldWidget.revision || super.updateShouldNotify(oldWidget);
}

/// Keep the source visible and locked; dim only its heading/boost.
class EnergyRewardDim extends StatelessWidget {
  const EnergyRewardDim({super.key, required this.child, this.source = false});
  final Widget child;
  final bool source;
  @override
  Widget build(BuildContext c) {
    final active = _RewardScope.of(c)?.isActive ?? false;
    return IgnorePointer(
      ignoring: active,
      child: Opacity(opacity: active && !source ? .18 : 1, child: child),
    );
  }
}

class EnergyRewardBalance extends StatelessWidget {
  const EnergyRewardBalance({super.key, required this.amount});
  final int amount;
  @override
  Widget build(BuildContext c) {
    final ru = Localizations.localeOf(c).languageCode == 'ru';
    return Semantics(
      container: true,
      label: ru ? 'Баланс $amount энергии' : 'Balance $amount energy',
      child: ExcludeSemantics(
        child: EnergyText(
          amount,
          key: const ValueKey('energy-reward-balance-value'),
          size: 25,
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.event, required this.payout});
  final _RewardEvent event;
  final double payout;
  @override
  Widget build(BuildContext c) => MediaQuery.withNoTextScaling(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          event.ru ? 'Энергия получена!' : 'Energy received!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
            color: Color(0xFFE6FAFF),
            shadows: [
              Shadow(
                color: Color(0xFF00101F),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
              Shadow(color: Color(0xFF00101F), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xA0FFCB37),
                    BlendMode.srcIn,
                  ),
                  child: SvgPicture.asset(
                    'assets/branding/ui/energy-reward-core.svg',
                  ),
                ),
              ),
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFFFA9A),
                    BlendMode.srcIn,
                  ),
                  child: SvgPicture.asset(
                    'assets/branding/ui/energy-reward-core.svg',
                  ),
                ),
              ),
              SvgPicture.asset(
                'assets/branding/ui/energy-reward-core.svg',
                key: const ValueKey('energy-reward-core'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '+${event.amount}',
          key: const ValueKey('energy-reward-payout'),
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: payout,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: const Color(0xFFFFF476),
            shadows: const [Shadow(color: Color(0x5CFFDA40), blurRadius: 9)],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          event.ru ? 'энергии' : 'energy',
          style: const TextStyle(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD5E8F2),
            shadows: [
              Shadow(
                color: Color(0xFF00101F),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.event, this.frame);
  final _RewardEvent event;
  final EnergyRewardFrame frame;
  void _glow(
    Canvas c,
    Offset at,
    Size size,
    List<Color> colors,
    List<double> stops,
    double opacity,
  ) {
    if (opacity <= 0) return;
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(size.width / 2, size.height / 2);
    c.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: colors
              .map((v) => v.withValues(alpha: v.a * opacity))
              .toList(),
          stops: stops,
        ).createShader(const Rect.fromLTWH(-1, -1, 2, 2)),
    );
    c.restore();
  }

  @override
  void paint(Canvas c, Size s) {
    if (frame.reduced) return;
    final p = frame.p,
        from = event.from,
        flareAt = event.from - const Offset(0, 18);
    final celebration = _clamp(p / .6), shine = math.sin(math.pi * celebration);
    final auraScale = .7 + _ease(celebration) * .5;
    _glow(
      c,
      from,
      Size(event.width * 1.45 * auraScale, event.width * 1.35 * auraScale),
      const [
        Color(0xF504223B),
        Color(0xEA04223B),
        Color(0x33FFDC32),
        Colors.transparent,
      ],
      const [0, .26, .47, .70],
      _clamp(p / .1) * (1 - _clamp((p - .4) / .22)),
    );
    final flash = _clamp((p - .04) / .27),
        wave = _clamp((p - .08) / .32),
        flashSize = 130 * (.35 + _ease(flash) * 1.15);
    _glow(
      c,
      flareAt,
      Size.square(flashSize),
      const [
        Color(0xFFFFFDE6),
        Color(0x99FFF8AB),
        Color(0x44FFD52C),
        Colors.transparent,
      ],
      const [0, .15, .4, .7],
      math.sin(math.pi * flash) * .75,
    );
    c.save();
    c.translate(flareAt.dx, flareAt.dy);
    c.rotate(p * 18 * math.pi / 180);
    final rayShader = RadialGradient(
      colors: [
        Colors.transparent,
        Color(0xAAFFE67C).withValues(alpha: shine * .3 * 170 / 255),
        Color(0xAAFFE67C).withValues(alpha: shine * .3 * 170 / 255 * .53),
        Colors.transparent,
      ],
      stops: const [.14, .18, .45, .70],
    ).createShader(const Rect.fromLTWH(-130, -130, 260, 260));
    for (var i = 0; i < 8; i++) {
      final a = (-90 + 6 + i * 45) * math.pi / 180;
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..arcTo(
            const Rect.fromLTWH(-130, -130, 260, 260),
            a,
            6 * math.pi / 180,
            false,
          )
          ..close(),
        Paint()..shader = rayShader,
      );
    }
    c.restore();
    final waveScale = .3 + _ease(wave) * 1.5,
        waveAlpha = math.sin(math.pi * wave) * .55;
    c.drawCircle(
      flareAt,
      65 * waveScale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = waveScale
        ..color = Color(0x60FFE345).withValues(alpha: 96 / 255 * waveAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * waveScale),
    );
    c.drawCircle(
      flareAt,
      65 * waveScale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = waveScale
        ..color = const Color(0xFFFFF3A4).withValues(alpha: waveAlpha),
    );
    for (var i = 0; i < 28; i++) {
      final t = _clamp((p - .055 - (i % 4) * .012) / .46);
      if (t <= 0 || t >= 1) continue;
      final a = i * 2.399963, radius = 45 + (25 + i % 5 * 12) * _ease(t);
      final point =
          from +
          Offset(math.cos(a) * radius, -18 + math.sin(a) * radius + t * t * 18);
      final alpha = math.min(1.0, math.min(t * 12, (1 - t) * 4));
      final star = i % 3 == 0, cyan = (i + 12) % 3 == 0;
      c.save();
      c.translate(point.dx, point.dy);
      c.rotate((i * 25 + t * 45) * math.pi / 180);
      c.scale(1 - t * .5);
      final glow = (cyan ? const Color(0xFF3EDFFF) : const Color(0xFFFFDC56))
          .withValues(alpha: alpha);
      c.drawCircle(
        Offset.zero,
        star ? 3 : 1.5,
        Paint()
          ..color = glow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cyan ? 3 : 2.5),
      );
      if (star) {
        c.drawPath(
          Path()
            ..moveTo(0, -4)
            ..lineTo(.88, -.96)
            ..lineTo(4, 0)
            ..lineTo(.88, .96)
            ..lineTo(0, 4)
            ..lineTo(-.96, .96)
            ..lineTo(-4, 0)
            ..lineTo(-.96, -.96)
            ..close(),
          Paint()..color = const Color(0xFFFFF8C7).withValues(alpha: alpha),
        );
      } else {
        c.drawCircle(
          Offset.zero,
          1.5,
          Paint()
            ..color = (cyan ? const Color(0xFFA3F8FF) : const Color(0xFFFFF2A0))
                .withValues(alpha: alpha),
        );
      }
      c.restore();
    }
    _glow(
      c,
      event.to,
      const Size(76, 54),
      const [Color(0x60FFEB6D), Colors.transparent],
      const [0, 1],
      frame.hit,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => true;
}

class _MotesPainter extends CustomPainter {
  _MotesPainter(this.event, this.frame);
  final _RewardEvent event;
  final EnergyRewardFrame frame;
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 6; i++) {
      final t = _clamp((frame.p - .4 - i * .012) / .34);
      if (t <= 0 || t >= 1) continue;
      final v = t * t * (3 - 2 * t), from = event.from, to = event.to;
      final control =
          from + Offset((i.isOdd ? 1 : -1) * (20 + i * 4), -60 - i * 4);
      final at =
          from * ((1 - v) * (1 - v)) +
          control * (2 * (1 - v) * v) +
          to * (v * v);
      final alpha = math.min(1.0, math.min(t * 12, (1 - t) * 10));
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(.55 + math.sin(math.pi * t) * .65);
      if (i % 3 == 0) {
        c.scale(17 / 24, 23 / 26);
        c.translate(-12, -13);
        final path = Path()
          ..moveTo(14, 1)
          ..lineTo(3, 14)
          ..lineTo(10, 14)
          ..lineTo(8, 25)
          ..lineTo(21, 10)
          ..lineTo(13, 10)
          ..close();
        c.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFCE20).withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        c.drawPath(
          path,
          Paint()..color = const Color(0xFFFFF596).withValues(alpha: alpha),
        );
      } else {
        c.drawCircle(
          Offset.zero,
          4.5,
          Paint()
            ..color = const Color(0xFFFFDC57).withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        c.drawCircle(
          Offset.zero,
          2.5,
          Paint()..color = const Color(0xFFFFF9BC).withValues(alpha: alpha),
        );
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => true;
}
