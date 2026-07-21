import 'package:flutter/material.dart';

ThemeData buildGameTheme() {
  const bg = Color(0xFF0E1419);
  const surface = Color(0xFF172028);
  const accent = Color(0xFF3DDC97);
  const danger = Color(0xFFFF5A5F);
  const muted = Color(0xFF8B9AAB);

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
    colorScheme: base,
    scaffoldBackgroundColor: bg,
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
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
