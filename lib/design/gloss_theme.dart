import 'package:flutter/material.dart';

/// Peeke CMMS-ERP brand tokens — aligned with launcher icon (2026-08-11).
/// Provider: Peeke Automation
class GlossColors {
  GlossColors._();

  /// Light sky field (icon background)
  static const Color sky = Color(0xFFE8F4FC);

  /// Page / scaffold
  static const Color pageBg = Color(0xFFF0F7FC);

  /// Cards & surfaces
  static const Color card = Color(0xFFFFFFFF);

  /// Deep navy — primary mark / headings
  static const Color navy = Color(0xFF0B1F3A);

  /// Alias for body text
  static const Color ink = navy;

  /// Soft teal — accent / systems
  static const Color teal = Color(0xFF2A9D8F);

  /// Primary interactive accent
  static const Color accent = teal;

  static const Color muted = Color(0xFF5B6B7C);
  static const Color border = Color(0xFFD6E4F0);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
}

class GlossTheme {
  GlossTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GlossColors.navy,
        primary: GlossColors.navy,
        secondary: GlossColors.teal,
        surface: GlossColors.card,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: GlossColors.pageBg,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: GlossColors.card,
        foregroundColor: GlossColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: GlossColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GlossColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GlossColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlossColors.teal, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlossColors.navy,
          foregroundColor: Colors.white,
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
    );
  }
}
