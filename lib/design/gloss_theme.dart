import 'package:flutter/material.dart';

/// Peeke CMMS-ERP — strict 3-color system sampled from the official logo asset.
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

  static const double fieldRadius = 28;
  static const double tileRadius = 16;
  static const double tileMinHeight = 50;

  /// Shared control height so TextField and Dropdown match exactly.
  static const double fieldHeight = 44;

  static const TextStyle logoMark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: GlossColors.navy,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle logoAccent = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: GlossColors.teal,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// Primary line on plates (name).
  static TextStyle get tileName => logoMark.copyWith(
        fontSize: 13,
        height: 1.2,
      );

  /// Secondary line on plates (title · depts) — teal depth.
  static TextStyle get tileMeta => logoAccent.copyWith(
        fontSize: 12,
        height: 1.2,
        color: GlossColors.teal,
      );

  /// Legacy alias
  static TextStyle get tileLine => tileName;

  /// 3D gloss plate — depth from gradient + shadow only (no stroke).
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
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  /// Navy / indigo CTA plate (Send invite, primary actions).
  static BoxDecoration get navyPlate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A3F8F),
            Color(0xFF2E3278),
            Color(0xFF272A6D),
            Color(0xFF1E2154),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  static InputDecoration fieldDecoration(String label) {
    final radius = BorderRadius.circular(fieldRadius);
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: logoMark.copyWith(fontSize: 14),
      floatingLabelStyle: logoAccent.copyWith(fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  /// Force identical outer height for text + dropdown fields.
  static InputDecoration compactField(String label) {
    return fieldDecoration(label).copyWith(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
