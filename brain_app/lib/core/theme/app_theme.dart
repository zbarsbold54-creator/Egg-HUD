/// EDITH-themed Material theme. Spider-Man holographic HUD identity:
/// monochrome white graphics, elegant geometric details, minimal futuristic.
/// Phone UI uses white on dark, mirroring the 128x64 monochrome display.
library;

import 'package:flutter/material.dart';

class AppTheme {
  static const Color edithWhite = Color(0xFFFFFFFF);
  static const Color edithIce = Color(0xFFE8F4FF);
  static const Color edithGrey = Color(0xFFB0BEC5);
  static const Color hudWhite = Color(0xFFFFFFFF);
  static const Color hudBlack = Color(0xFF000000);
  static const Color hudGrey = Color(0xFF9E9E9E);
  static const Color hudDark = Color(0xFF0A0A0A);
  static const Color hudPanel = Color(0xFF1A1A1A);

  // Backwards-compat aliases (internal code)
  static const Color jarvisYellow = edithWhite;
  static const Color jarvisAmber = edithIce;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: hudDark,
        colorScheme: const ColorScheme.dark(
          primary: edithWhite,
          secondary: edithIce,
          surface: hudPanel,
          onSurface: hudWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: hudDark,
          foregroundColor: hudWhite,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: hudPanel,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: hudWhite, fontWeight: FontWeight.w300),
          titleLarge: TextStyle(color: hudWhite, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(color: hudWhite),
          bodySmall: TextStyle(color: hudGrey),
        ),
      );
}
