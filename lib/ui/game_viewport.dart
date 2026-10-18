import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Telegram's standard field (380) plus its two 16-unit margins.
/// The entire navigator uses one coordinate system, including modal routes.
class GameViewport extends StatelessWidget {
  const GameViewport({super.key, required this.child});
  final Widget child;
  static const referenceWidth = 412.0;
  static const referenceFieldSide = 380.0;

  static double scaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ViewportScale>()?.scale ?? 1;

  static double scaleFor(double width) => math.min(width / referenceWidth, 1);

  /// Geometry already scales with width. Text also responds to short screens,
  /// and system enlargement is bounded by the room available for game windows.
  /// Keyboard insets are deliberately excluded: typing must not resize text.
  static TextScaler textScalerFor(
    TextScaler system, {
    required Size size,
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    final viewportScale = scaleFor(size.width);
    final logicalHeight =
        math.max(0.0, size.height - viewPadding.vertical) / viewportScale;
    final shortScreenFactor = math.sqrt(logicalHeight / 740).clamp(.9, 1.0);
    final widthAllowance = ((size.width - 320) / 92).clamp(0.0, 1.0);
    final heightAllowance = ((logicalHeight - 560) / 180).clamp(0.0, 1.0);
    final systemLimit = math.min(
      1.15 + .25 * widthAllowance,
      1.1 + .3 * heightAllowance,
    );
    return _ViewportTextScaler(
      system.clamp(maxScaleFactor: systemLimit),
      shortScreenFactor,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final scale = scaleFor(constraints.maxWidth);
      final width = math.min(constraints.maxWidth, referenceWidth);
      EdgeInsets logical(EdgeInsets value) => value / scale;
      final theme = Theme.of(context);
      // Button bounds use the same reference units as their text and surface.
      const target = 48.0;
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: width / scale,
                height: constraints.maxHeight / scale,
                child: _ViewportScale(
                  scale: scale,
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(width / scale, constraints.maxHeight / scale),
                      textScaler: textScalerFor(
                        media.textScaler,
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        viewPadding: media.viewPadding,
                      ),
                      devicePixelRatio: media.devicePixelRatio * scale,
                      padding: logical(media.padding),
                      viewPadding: logical(media.viewPadding),
                      viewInsets: logical(media.viewInsets),
                      systemGestureInsets: logical(media.systemGestureInsets),
                    ),
                    child: Theme(
                      data: theme.copyWith(
                        filledButtonTheme: FilledButtonThemeData(
                          style: theme.filledButtonTheme.style?.copyWith(
                            minimumSize: WidgetStatePropertyAll(
                              Size(target, target),
                            ),
                          ),
                        ),
                        outlinedButtonTheme: OutlinedButtonThemeData(
                          style: theme.outlinedButtonTheme.style?.copyWith(
                            minimumSize: WidgetStatePropertyAll(
                              Size(target, target),
                            ),
                          ),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style:
                              (theme.textButtonTheme.style ??
                                      const ButtonStyle())
                                  .copyWith(
                                    minimumSize: WidgetStatePropertyAll(
                                      Size(target, target),
                                    ),
                                  ),
                        ),
                        iconButtonTheme: IconButtonThemeData(
                          style:
                              (theme.iconButtonTheme.style ??
                                      const ButtonStyle())
                                  .copyWith(
                                    minimumSize: WidgetStatePropertyAll(
                                      Size(target, target),
                                    ),
                                  ),
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ViewportTextScaler extends TextScaler {
  const _ViewportTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _ViewportTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

class _ViewportScale extends InheritedWidget {
  const _ViewportScale({required this.scale, required super.child});
  final double scale;
  @override
  bool updateShouldNotify(_ViewportScale oldWidget) => scale != oldWidget.scale;
}
