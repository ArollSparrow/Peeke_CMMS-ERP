import 'package:flutter/material.dart';

/// Peeke CMMS-ERP — strict 3-color system sampled from the official logo asset.
///
/// Sampled from `assets/branding/peeke_icon.png` (2026-08-11):
/// 1. [sky]  `#D3EFFD` — logo field + every screen background
/// 2. [navy] `#272A6D` — "Peeke" wordmark (primary text / buttons)
/// 3. [teal] `#55AAAC` — network nodes + "CMMS-ERP" (accents / links)
///
/// Provider: Peeke Automation
class GlossColors {
  GlossColors._();

  /// Logo background (exact sample avg)
  static const Color sky = Color(0xFFD3EFFD);

  /// Logo wordmark navy / indigo
  static const Color navy = Color(0xFF272A6D);

  /// Logo network + CMMS-ERP teal/cyan
  static const Color teal = Color(0xFF55AAAC);

  // Aliases — no extra hues
  static const Color pageBg = sky;
  static const Color card = sky;
  static const Color ink = navy;
  static const Color accent = teal;
  static const Color muted = teal;
  static const Color border = teal;
  static const Color danger = navy;
  static const Color success = teal;
}

class GlossTheme {
  GlossTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: GlossColors.navy,
        onPrimary: GlossColors.sky,
        secondary: GlossColors.teal,
        onSecondary: GlossColors.sky,
        surface: GlossColors.sky,
        onSurface: GlossColors.navy,
        error: GlossColors.navy,
        onError: GlossColors.sky,
      ),
      scaffoldBackgroundColor: GlossColors.sky,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: GlossColors.sky,
        foregroundColor: GlossColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: GlossColors.sky,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GlossColors.teal),
        ),
      ),
      dividerColor: GlossColors.teal,
      textTheme: base.textTheme.apply(
        bodyColor: GlossColors.navy,
        displayColor: GlossColors.navy,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GlossColors.sky,
        labelStyle: const TextStyle(color: GlossColors.navy),
        floatingLabelStyle: const TextStyle(color: GlossColors.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.teal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlossColors.navy,
          foregroundColor: GlossColors.sky,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GlossColors.teal,
        ),
      ),
      iconTheme: const IconThemeData(color: GlossColors.navy),
    );
  }
}
