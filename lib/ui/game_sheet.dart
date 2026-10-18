import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_ui.dart';

/// Общий «стеклянный» стиль шитов: тёмный градиент, мягкая рамка.
class GameSheetChrome extends StatelessWidget {
  const GameSheetChrome({
    super.key,
    required this.child,
    this.heightFactor = 0.90,
    this.fitContent = false,
    this.heightLimit,
    this.modal = false,
    this.glass = GameGlass.sheet,
    this.backgroundImage,
    this.backgroundGradient = GameUi.sheetGradient,
    this.softShadow = true,
  });

  final Widget child;
  final double heightFactor;
  final bool fitContent;
  final double? heightLimit;
  final bool modal;
  final GameGlass glass;
  final DecorationImage? backgroundImage;
  final Gradient backgroundGradient;
  final bool softShadow;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = math.min(
      math.min(
        media.size.height * heightFactor.clamp(0.0, 0.92),
        heightLimit ?? double.infinity,
      ),
      math.max(0.0, media.size.height - media.padding.top - 16),
    );
    // Keep the decorated sheet in its own layer while the route slides it.
    return RepaintBoundary(
      child: Container(
        height: fitContent ? null : h,
        constraints: BoxConstraints(maxHeight: h),
        decoration: GameGlassDecoration(
          glass: glass,
          image: backgroundImage,
          borderRadius: modal
              ? BorderRadius.circular(GameUi.sheetRadius)
              : const BorderRadius.vertical(
                  top: Radius.circular(GameUi.sheetRadius),
                ),
          gradient: backgroundGradient,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFBAF1FF), width: 2),
          ),
          boxShadow: softShadow
              ? [
                  BoxShadow(
                    color: Color(0x55020E1F),
                    blurRadius: 28,
                    offset: Offset(0, -12),
                  ),
                ]
              : null,
        ),
        child: Theme(
          data: gameSheetTheme(context),
          child: DefaultTextStyle(
            style: gameSheetTheme(context).textTheme.bodyMedium!,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  if (!modal) const SizedBox(height: 6),
                  if (!modal)
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Color(0xFFD7F7FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared readable title and accessible close control for every game window.
class GameSheetHeader extends StatelessWidget {
  const GameSheetHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });
  final String title;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (leading != null) ...[leading!, const SizedBox(width: 8)],
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: GameUi.hudGradient,
            border: Border.all(color: const Color(0xFFB9F0FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              color: GameUi.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          width: 32,
          height: 32,
          decoration: GameGlassDecoration(
            glass: GameGlass.button,
            gradient: GameUi.panelGradient,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCFAFF)),
          ),
          child: const Icon(Icons.close_rounded, size: 22, color: GameUi.ink),
        ),
        constraints: BoxConstraints(
          minWidth: GameUi.touchTarget(context),
          minHeight: GameUi.touchTarget(context),
        ),
      ),
    ],
  );
}

ThemeData gameSheetTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      onSurface: GameUi.ink,
      surface: const Color(0xFFB1DEF4),
      primary: const Color(0xFF065781),
      secondary: const Color(0xFF00644C),
      error: const Color(0xFFAB254C),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: GameUi.ink,
      displayColor: GameUi.ink,
    ),
    iconTheme: const IconThemeData(color: GameUi.ink),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: const Color(0xFFD6F5FF),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: GameUi.ink,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: GameUi.ink,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GameUi.ink,
        minimumSize: Size.square(GameUi.touchTarget(context)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF12436B),
      labelStyle: const TextStyle(color: GameUi.inkMuted),
      hintStyle: const TextStyle(color: GameUi.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFC0F0FF)),
      ),
    ),
  );
}

/// Карточка внутри шита — лёгкая, без «дашбордности».
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.accent,
    this.margin,
    this.gradient,
    this.glass = GameGlass.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final GameGlass glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: GameUi.panel(
        accent: accent,
        gradient: gradient,
        glass: glass,
      ),
      child: child,
    );
  }
}
