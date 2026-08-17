import 'package:flutter/material.dart';

/// Peeke CMMS-ERP — strict 3-color system sampled from the official logo asset.
class GlossColors {
  GlossColors._();

  static const Color sky = Color(0xFFD3EFFD);
  static const Color navy = Color(0xFF272A6D);
  static const Color teal = Color(0xFF55AAAC);

  /// Deeper teal for plate meta lines / icons — stronger contrast on cyan gloss.
  /// Use on cyan plates for role/dept meta, secondary icons, and invite status.
  static const Color tealDeep = Color(0xFF2A7A7C);

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

  /// Corner radius for confirmation/detail dialogs (AlertDialog, Dialog).
  /// Distinct from [tileRadius]/[fieldRadius] — dialogs read closer to a
  /// system surface, so they get a bit more roundness than list tiles.
  static const double dialogRadius = 20;
  static const double tileMinHeight = 50;

  /// Practical locked height: fits floating label + dense input + dropdown.
  /// (35px clipped labels; Material3 needs ~48.)
  static const double fieldHeight = 48;

  /// Comfortable gap between consecutive form fields / list tiles.
  static const double fieldGap = 8;

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

  /// Primary line on cyan plates (name) — navy, sits on the bottom.
  static TextStyle get tileName => logoMark.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  /// Meta line on cyan plates (role / depts / pending) — deeper teal, normal weight.
  /// Depth comes from [GlossColors.tealDeep], not from heavier type.
  static TextStyle get tileMeta => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.15,
        color: GlossColors.tealDeep,
      );

  /// Legacy alias
  static TextStyle get tileLine => tileName;

  /// 3D gloss plate — cyan/sky depth from gradient + shadow only (no stroke).
  /// Gradient ends near teal family so meta/icons in tealDeep read as one system.
  static BoxDecoration get plate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD0EEF7),
            Color(0xFFB0DCEB),
            Color(0xFF6FA8B8),
            Color(0xFF4A8A96),
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

  /// Navy gloss plate — same depth model as [plate]: bright top specular →
  /// mid body → deep base, dual shadow. Used for selected chips (contrast).
  static BoxDecoration get navyPlate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5B62C4), // specular highlight
            Color(0xFF3E4498),
            Color(0xFF2A2E78),
            Color(0xFF1A1D52), // deep base
          ],
          stops: [0.0, 0.32, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  /// Field outer shell — same cyan gloss language as member tiles, pill radius.
  static BoxDecoration get fieldPlate => BoxDecoration(
        borderRadius: BorderRadius.circular(fieldRadius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD0EEF7),
            Color(0xFFB0DCEB),
            Color(0xFF6FA8B8),
            Color(0xFF4A8A96),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

  /// Borderless input on top of [fieldPlate] — label floats in the gloss.
  static InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: logoMark.copyWith(fontSize: 13),
      floatingLabelStyle: logoAccent.copyWith(fontSize: 11),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.28),
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }

  static InputDecoration compactField(String label) => fieldDecoration(label);

  static Widget fieldShell({required Widget child}) {
    return Container(
      height: fieldHeight,
      decoration: fieldPlate,
      alignment: Alignment.center,
      child: child,
    );
  }

  static Widget glossCta({
    required String label,
    required VoidCallback? onTap,
    bool busy = false,
    double? height,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
  }) {
    final h = height ?? tileMinHeight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        child: Ink(
          height: h,
          padding: padding,
          decoration: plate,
          child: Center(
            widthFactor: 1,
            child: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GlossColors.navy,
                    ),
                  )
                : Text(
                    label,
                    style: logoMark.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: GlossColors.navy,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static Widget navyCta({
    required String label,
    required VoidCallback? onTap,
    bool busy = false,
    double? height,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
  }) =>
      glossCta(
        label: label,
        onTap: onTap,
        busy: busy,
        height: height,
        padding: padding,
      );
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
          borderRadius: BorderRadius.circular(GlossSurfaces.tileRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GlossColors.sky,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlossSurfaces.dialogRadius),
        ),
        titleTextStyle: GlossSurfaces.logoMark.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GlossSurfaces.logoMark.copyWith(
          fontSize: 14,
          height: 1.35,
        ),
      ),
      dividerColor: GlossColors.teal,
      textTheme: base.textTheme.apply(
        bodyColor: GlossColors.navy,
        displayColor: GlossColors.navy,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.28),
        isDense: true,
        contentPadding:
            const EdgeInsets.fromLTRB(16, 10, 12, 10),
        labelStyle: GlossSurfaces.logoMark.copyWith(fontSize: 13),
        floatingLabelStyle: GlossSurfaces.logoAccent.copyWith(fontSize: 11),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
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
