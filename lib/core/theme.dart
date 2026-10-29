import 'package:flutter/material.dart';

abstract final class Palette {
  static const paper = Color(0xFFF8F7F3);
  static const ink = Color(0xFF203B32);
  static const forest = Color(0xFF265846);
  static const moss = Color(0xFFDCE5D9);
  static const muted = Color(0xFF778179);
  static const line = Color(0xFFE5E7DF);
  static const coral = Color(0xFFDA7459);
  static const gold = Color(0xFFE9CF8D);
}

ThemeData livingTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.forest,
    brightness: dark ? Brightness.dark : Brightness.light,
    surface: dark ? const Color(0xFF17241F) : Palette.paper,
    primary: dark ? const Color(0xFFB6D6BD) : Palette.forest,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: dark ? const Color(0xFFEBEEE6) : Palette.ink,
          displayColor: dark ? const Color(0xFFEBEEE6) : Palette.ink,
        )
        .copyWith(
          displayLarge: TextStyle(
            color: scheme.onSurface,
            fontFamily: 'Newsreader',
            fontSize: 56,
            height: 1.03,
            letterSpacing: -2,
          ),
          displayMedium: TextStyle(
            color: scheme.onSurface,
            fontFamily: 'Newsreader',
            fontSize: 42,
            height: 1.1,
            letterSpacing: -1.3,
          ),
          headlineLarge: TextStyle(
            color: scheme.onSurface,
            fontFamily: 'Newsreader',
            fontSize: 36,
            height: 1.12,
            letterSpacing: -0.7,
          ),
          headlineMedium: TextStyle(
            color: scheme.onSurface,
            fontFamily: 'Newsreader',
            fontSize: 29,
            height: 1.15,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            color: scheme.onSurface,
            fontFamily: 'Newsreader',
            fontSize: 24,
            height: 1.2,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: scheme.onSurface,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF24372C) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
