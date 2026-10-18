import '../ui/game_ui.dart';
import 'package:flutter/material.dart';

ThemeData buildGameTheme() {
  const bg = GameUi.background;
  const surface = GameUi.surface;
  const accent = GameUi.cyan;
  const danger = GameUi.heart;
  const muted = GameUi.muted;

  final base = ColorScheme.dark(
    surface: surface,
    primary: accent,
    secondary: accent,
    error: danger,
    onPrimary: bg,
    onSecondary: bg,
    onSurface: const Color(0xFFE8EEF4),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: base,
    scaffoldBackgroundColor: bg,
    dialogTheme: DialogThemeData(
      barrierColor: GameUi.modalBarrier,
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameUi.sheetRadius),
        side: const BorderSide(color: GameUi.line),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: GameUi.text,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: GameUi.muted,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      modalBarrierColor: GameUi.modalBarrier,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Color(0xFFE8EEF4),
      elevation: 0,
      centerTitle: true,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: GameUi.text,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameUi.radius),
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ).copyWith(
            backgroundBuilder: GameUi.primaryLayer,
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? GameUi.muted
                  : GameUi.text,
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: GameUi.text,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameUi.radius),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ).copyWith(
            backgroundBuilder: GameUi.primaryLayer,
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? GameUi.muted
                  : GameUi.text,
            ),
          ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFFEDFAFF),
      contentTextStyle: TextStyle(color: GameUi.inkMuted),
      actionTextColor: GameUi.ink,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF91FFD0)
            : const Color(0xFFD3DFE5),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: Color(0xFFE8EEF4)),
      bodyMedium: TextStyle(color: muted),
    ),
  );
}
