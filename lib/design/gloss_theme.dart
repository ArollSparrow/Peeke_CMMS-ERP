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

/// Shared surfaces + type — use everywhere (Team tiles, CTAs, forms).
class GlossSurfaces {
  GlossSurfaces._();

  /// Landing login field / pill radius.
  static const double fieldRadius = 28;

  /// Raised list tiles / action plates.
  static const double tileRadius = 16;

  /// Vertical rhythm for plate tiles (matches Send invite / landing actions).
  static const double tileMinHeight = 50;

  /// Logo wordmark feel: medium weight, tight tracking.
  static const TextStyle logoMark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: GlossColors.navy,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// Logo accent / secondary labels.
  static const TextStyle logoAccent = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: GlossColors.teal,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// Body line on gloss plates (name · title, depts).
  static TextStyle get tileLine => logoMark.copyWith(
        fontSize: 13,
        height: 1.25,
      );

  /// Standard 3D gloss plate (light top → deeper bottom).
  static BoxDecoration get plate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD0EEF7),
            Color(0xFFB0DCEB),
            Color(0xFF7EB9CE),
            Color(0xFF5FA3BB),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        border: Border.all(
          color: GlossColors.teal.withValues(alpha: 0.75),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 7),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.07),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  /// Landing-page text field decoration (28px pill, soft fill).
  static InputDecoration fieldDecoration(String label) {
    final radius = BorderRadius.circular(fieldRadius);
    return InputDecoration(
      labelText: label,
      labelStyle: logoMark.copyWith(fontSize: 14),
      floatingLabelStyle: logoAccent.copyWith(fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide:
            BorderSide(color: GlossColors.teal.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: GlossColors.teal),
      ),
    );
  }
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

    final fieldRadius = BorderRadius.circular(GlossSurfaces.fieldRadius);

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
          borderRadius: BorderRadius.circular(GlossSurfaces.tileRadius),
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
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        labelStyle: GlossSurfaces.logoMark.copyWith(fontSize: 14),
        floatingLabelStyle: GlossSurfaces.logoAccent.copyWith(fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: GlossColors.teal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide:
              BorderSide(color: GlossColors.teal.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: GlossColors.navy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GlossColors.navy,
          foregroundColor: GlossColors.sky,
          minimumSize: const Size.fromHeight(GlossSurfaces.tileMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlossSurfaces.fieldRadius),
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
