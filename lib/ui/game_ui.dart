import 'package:flutter/material.dart';
import 'dart:async';
import 'crystal_cube_icon.dart';
import '../app/app_target.dart';

/// Runtime visual tokens from the approved UI-kit. No economy or input logic.
abstract final class GameUi {
  static bool get instantWindows => AppTargetConfig.isMobile;
  static AnimationStyle? get windowAnimationStyle =>
      instantWindows ? AnimationStyle.noAnimation : null;
  static const text = Color(0xFFF0FBFF);
  static const muted = Color(0xFFA9CBE4);
  static const ink = Color(0xFF082E4C);
  static const inkMuted = Color(0xFF103E5C);
  static const mint = Color(0xFF43ECC0);
  static const cyan = Color(0xFF79F1F5);
  static const yellow = Color(0xFFFFD54A);
  static const line = Color(0xFF59C9DC);
  static const background = Color(0xFF061B2D);

  /// One backdrop for modal routes and in-place result windows.
  static const modalBarrier = Color(0xB8061B2D);
  static const surface = Color(0xFF16587B);
  static const heart = Color(0xFFFF6B7A);
  static const radius = 10.0;
  static const sheetRadius = 18.0;
  static const touchSize = 48.0;
  static double touchTarget(BuildContext context) => touchSize;
  static const compactActionHeight = 32.0;
  static const compactRowHeight = 56.0;
  static const shopWindowHeight = 512.0;
  static const sectionGap = 8.0;
  static const panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDCFDFB), Color(0xFFABE8F2)],
  );
  // Shared cool blue cards over the navy shop, profile and recovery windows.
  static const coolPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9DD9EF), Color(0xFF79BEDB), Color(0xFF6CB5D6)],
    stops: [0, .35, 1],
  );
  static const navySheetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF123E58), Color(0xFF082E4C), Color(0xFF061B2D)],
  );
  static const deepPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF153F58), Color(0xFF0D2A40)],
  );
  static const hudGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF367F9F), Color(0xFF155976), Color(0xFF082E4C)],
    stops: [0, .2, 1],
  );
  static const sheetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF9BE4F3), Color(0xFF6CD2E7), Color(0xFF43B3D6)],
    stops: [0, .25, 1],
  );

  static BoxDecoration hudPanel({Color? accent}) => BoxDecoration(
    gradient: hudGradient,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: accent ?? const Color(0xFF79DBE9)),
    boxShadow: const [
      BoxShadow(color: Color(0xAA031A2C), offset: Offset(0, 2)),
    ],
  );

  static Widget primaryLayer(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    return _actionLayer(context, states, child, replay: false);
  }

  static Widget replayLayer(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => _actionLayer(context, states, child, replay: true);

  static ButtonStyle replayStyle(BuildContext context) =>
      FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        foregroundColor: GameUi.text,
      ).copyWith(backgroundBuilder: replayLayer);

  /// Shared bevel for approved primary actions. Size and hit targets belong to
  /// callers. Explicit legacy dark foregrounds get a readable frosted core.
  static Widget neonSurface({
    required Widget child,
    bool enabled = true,
    bool pressed = false,
    bool focused = false,
    bool lightCore = false,
    bool paintOnly = false,
    double cornerRadius = 11,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final surface = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(
          color: enabled
              ? (focused ? const Color(0xFFFFF1A3) : const Color(0xFF61F4FF))
              : const Color(0xFF315169),
          width: focused ? 2 : 1.3,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: enabled
              ? const [
                  Color(0xFF55D9F2),
                  Color(0xFF0B6689),
                  Color(0xFF062A43),
                  Color(0xFF39BCD6),
                ]
              : const [Color(0xFF17384A), Color(0xFF0A2133)],
          stops: enabled ? const [0, .16, .86, 1] : null,
        ),
        boxShadow: enabled
            ? [
                const BoxShadow(color: Color(0x3842E7FF), blurRadius: 10),
                BoxShadow(
                  color: const Color(0x88031529),
                  offset: Offset(0, pressed ? 1 : 2),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius - 3),
          border: Border.all(
            color: enabled ? const Color(0x8886EFFF) : const Color(0xFF244254),
            width: .7,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: !enabled
                ? (lightCore
                      ? const [Color(0xFFB6C8D5), Color(0xFF8AA7BC)]
                      : const [Color(0xFF102B3D), Color(0xFF0A2133)])
                : lightCore
                ? const [
                    Color(0xFFE0FFFF),
                    Color(0xFFB6F4FC),
                    Color(0xFF8FD9ED),
                  ]
                : const [
                    Color(0xFF2077A0),
                    Color(0xFF0C3C59),
                    Color(0xFF06283F),
                    Color(0xFF082C45),
                  ],
            stops: !enabled || lightCore ? null : const [0, .20, .73, 1],
          ),
        ),
        padding: padding,
        child: paintOnly ? const SizedBox.shrink() : child,
      ),
    );
    if (!paintOnly) return surface;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: IgnorePointer(child: surface)),
        child,
      ],
    );
  }

  static bool _darkContent(Widget? widget) {
    if (widget == null) return false;
    if (widget is Text &&
        widget.style?.color != null &&
        widget.style!.color!.computeLuminance() < .22) {
      return true;
    }
    if (widget is Icon &&
        widget.color != null &&
        widget.color!.computeLuminance() < .22) {
      return true;
    }
    if (widget is RichText && _darkSpan(widget.text)) return true;
    if (widget is MultiChildRenderObjectWidget) {
      return widget.children.any(_darkContent);
    }
    if (widget is SingleChildRenderObjectWidget) {
      return _darkContent(widget.child);
    }
    if (widget is ProxyWidget) return _darkContent(widget.child);
    return false;
  }

  static bool _darkSpan(InlineSpan span) {
    if (span.style?.color != null &&
        span.style!.color!.computeLuminance() < .22) {
      return true;
    }
    return span is TextSpan && (span.children?.any(_darkSpan) ?? false);
  }

  static Widget _actionLayer(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child, {
    required bool replay,
  }) {
    final button = context.widget;
    final explicitForeground = button is ButtonStyleButton
        ? button.style?.foregroundColor?.resolve(states)
        : null;
    final lightCore =
        explicitForeground != null &&
            explicitForeground.computeLuminance() < .22 ||
        _darkContent(button is ButtonStyleButton ? button.child : child);
    return Container(
      margin: EdgeInsets.symmetric(vertical: replay ? 4 : 6),
      child: neonSurface(
        enabled: !states.contains(WidgetState.disabled),
        pressed: states.contains(WidgetState.pressed),
        focused: states.contains(WidgetState.focused),
        lightCore: lightCore,
        paintOnly: true,
        cornerRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(states.contains(WidgetState.focused) ? 3 : 1),
          child: Center(child: child),
        ),
      ),
    );
  }

  static BoxDecoration panel({
    Color? accent,
    double radius = radius,
    Gradient? gradient,
    GameGlass glass = GameGlass.card,
  }) => GameGlassDecoration(
    glass: glass,
    borderRadius: BorderRadius.circular(radius),
    gradient: gradient ?? panelGradient,
    border: Border.all(
      color: accent?.withValues(alpha: .65) ?? const Color(0xFFECFCFF),
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x66236497), offset: Offset(0, 2)),
      BoxShadow(color: Color(0x260A4266), blurRadius: 6, offset: Offset(0, 3)),
    ],
  );
}

/// Paint-only layers from contrast-gloss revision2. They share the existing
/// decoration bounds and cannot affect layout, text, hit areas or game physics.
enum GameGlass { none, sheet, card, button, selected }

class GameGlassDecoration extends BoxDecoration {
  const GameGlassDecoration({
    this.glass = GameGlass.card,
    super.color,
    super.gradient,
    super.image,
    super.border,
    super.borderRadius,
    super.boxShadow,
  });
  final GameGlass glass;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GameGlassPainter(this, super.createBoxPainter(onChanged), onChanged);
}

class _GameGlassPainter extends BoxPainter {
  _GameGlassPainter(this.decoration, this.base, super.onChanged);
  final GameGlassDecoration decoration;
  final BoxPainter base;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    base.paint(canvas, offset, configuration);
    if (decoration.glass == GameGlass.none || configuration.size == null) {
      return;
    }
    final rect = offset & configuration.size!;
    final radius =
        decoration.borderRadius?.resolve(configuration.textDirection) ??
        BorderRadius.zero;
    canvas.save();
    canvas.clipRRect(radius.toRRect(rect).deflate(1));
    void layer(Gradient gradient) =>
        canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    if (decoration.glass == GameGlass.sheet ||
        decoration.glass == GameGlass.card) {
      layer(
        const LinearGradient(
          begin: Alignment(-.766, -.643),
          end: Alignment(.766, .643),
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color(0x59FFFFFF),
            Color(0x59FFFFFF),
            Colors.transparent,
            Colors.transparent,
            Color(0x1AFFFFFF),
            Color(0x1AFFFFFF),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [0, .27, .27, .34, .34, .74, .74, .80, .80, 1],
        ),
      );
    }
    if (decoration.glass == GameGlass.card ||
        decoration.glass == GameGlass.selected) {
      layer(
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: decoration.glass == GameGlass.selected
              ? const [Color(0x26FFFFFF), Colors.transparent]
              : const [
                  Color(0x99FFFFFF),
                  Color(0x33FFFFFF),
                  Colors.transparent,
                  Colors.transparent,
                ],
          stops: decoration.glass == GameGlass.selected
              ? const [0, .35]
              : const [0, .05, .24, 1],
        ),
      );
    }
    if (decoration.glass == GameGlass.button) {
      // CSS ellipse 68% 75% at 22% 0%; paint in a normalized ellipse.
      canvas.save();
      canvas.translate(rect.left + rect.width * .22, rect.top);
      canvas.scale(rect.width * .68, rect.height * .75);
      canvas.drawRect(
        Rect.fromLTRB(-2, -2, 2, 2),
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xB3FFFFFF), Color(0x33FFFFFF), Colors.transparent],
            stops: [0, .46, .68],
          ).createShader(const Rect.fromLTWH(-1, -1, 2, 2)),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  void dispose() {
    base.dispose();
    super.dispose();
  }
}

/// Only the countdown subtree rebuilds each second; static windows stay still.
class GameClockBuilder extends StatefulWidget {
  const GameClockBuilder({
    super.key,
    required this.running,
    required this.builder,
  });
  final bool Function() running;
  final WidgetBuilder builder;
  @override
  State<GameClockBuilder> createState() => _GameClockBuilderState();
}

class _GameClockBuilderState extends State<GameClockBuilder> {
  Timer? _timer;
  @override
  Widget build(BuildContext context) {
    final running =
        widget.running() &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (running) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
    return widget.builder(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum GameArt { avatar, ready, crouched, crystals, helmet, jump, plus }

/// The same approved illustration, with a semantic size, in every window.
class GameArtwork extends StatelessWidget {
  const GameArtwork(this.art, {super.key, this.size = 64});
  final GameArt art;
  final double size;
  static const _files = {
    GameArt.avatar: 'player-avatar',
    GameArt.ready: 'hero-ready',
    GameArt.crouched: 'hero-start-crouched',
    GameArt.crystals: 'crystals',
    GameArt.helmet: 'helmet',
    GameArt.jump: 'jump',
    GameArt.plus: 'plus',
  };
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/ui/${_files[art]}-v1.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
  );
}

/// Exact raster render of the approved small SVG, distinct from rental artwork.
class GameAbilityIcon extends StatelessWidget {
  const GameAbilityIcon({
    super.key,
    required this.helmet,
    this.size = 18,
    this.enabled = true,
  });
  final bool helmet, enabled;
  final double size;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .45,
    child: Image.asset(
      'assets/branding/ui/ability-${helmet ? 'helmet' : 'jump'}.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}

class GameMetricIcon extends StatelessWidget {
  const GameMetricIcon({super.key, required this.risk, this.size = 14});
  final bool risk;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/ui/ability-${risk ? 'risk' : 'distance'}.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

class GameMetric extends StatelessWidget {
  const GameMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final Widget icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: GameUi.panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: GameUi.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: GameUi.text,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class GameRewardAmount extends StatelessWidget {
  const GameRewardAmount({
    super.key,
    required this.amount,
    this.glow = false,
    this.color = GameUi.cyan,
  });
  final int amount;
  final bool glow;
  final Color color;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrystalCubeIcon(size: 13, glow: glow),
        const SizedBox(width: 3),
        Text(
          '+$amount',
          style: TextStyle(
            fontSize: 12,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}
