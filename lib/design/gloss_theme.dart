import 'package:flutter/material.dart';

/// Peeke CMMS-ERP — strict 3-color system sampled from the official logo asset.
///
/// Sampled from `assets/branding/peeke_icon.png` (2026-08-11):
/// 1. [sky]  `#D3EFFD` — logo field + every screen background
/// 2. [navy] `#272A6D` — "Peeke" wordmark (primary text / buttons)
/// 3. [teal] `#55AAAC` — network nodes + "CMMS-ERP" (accents / links)
///
/// [danger] is reserved for error messages only (not brand chrome).
class GlossColors {
  GlossColors._();

  static const Color sky = Color(0xFFD3EFFD);
  static const Color navy = Color(0xFF272A6D);
  static const Color teal = Color(0xFF55AAAC);

  /// User-facing errors (friendly messages)
  static const Color danger = Color(0xFFC62828);

  static const Color pageBg = sky;
  static const Color card = sky;
  static const Color ink = navy;
  static const Color accent = teal;
  static const Color muted = teal;
  static const Color border = teal;
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
        error: GlossColors.danger,
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
        fillColor: Colors.white.withValues(alpha: 0.55),
        labelStyle: const TextStyle(color: GlossColors.navy),
        floatingLabelStyle: const TextStyle(color: GlossColors.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GlossColors.teal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: GlossColors.teal.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlossColors.navy,
          foregroundColor: GlossColors.sky,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GlossColors.navy,
        ),
      ),
      iconTheme: const IconThemeData(color: GlossColors.navy),
    );
  }
}
