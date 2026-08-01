import 'package:flutter/material.dart';

/// Minimal Gloss design tokens for Phase 0.
/// Expand widgets in later commits; keep one kit only.
class GlossColors {
  GlossColors._();

  static const Color pageBg = Color(0xFFF4F5F7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A1D26);
  static const Color muted = Color(0xFF6B7280);
  static const Color accent = Color(0xFF5B4B8A);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFDC2626);
}

class GlossTheme {
  GlossTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GlossColors.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: GlossColors.pageBg,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: GlossColors.card,
        foregroundColor: GlossColors.ink,
        elevation: 0,
        centerTitle: false,
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
          borderSide: const BorderSide(color: GlossColors.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlossColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
