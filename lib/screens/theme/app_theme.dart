import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF497A72);
  static const Color primaryDark  = Color(0xFF3D645D);
  static const Color accentBlue   = Color(0xFF00BFFF);

  // ── Backgrounds ────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF2F5F8);
  static const Color backgroundDark  = Color(0xFF12151B);
  static const Color chatBgLight     = Color(0xFFF0F8F7);
  static const Color chatBgDark      = Color(0xFF0F1115);

  // ── Surface / Card ─────────────────────────────────────────────────
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark  = Color(0xFF1E222D);

  // ── Misc ───────────────────────────────────────────────────────────
  static const Color onlineGreen  = Color(0xFF4CAF50);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color dividerDark  = Color(0xFF2A2A2A);

  // ── Light Theme ────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundLight,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  // ── Dark Theme ─────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: backgroundDark,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );
}
