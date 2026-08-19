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

  /// Full-round gloss plate — depth on every edge, not only the bottom.
  /// Diagonal light (top-left) + a top-edge counter-shadow + a thin white
  /// rim highlight keep it reading as one lifted surface, not a flat fill
  /// with a shadow tacked underneath.
  static BoxDecoration get plate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1.0),
          end: Alignment(0.85, 1.0),
          colors: [
            Color(0xFFE8F7FC),
            Color(0xFFC5E8F4),
            Color(0xFF8EBFCE),
            Color(0xFF5A9AAB),
            Color(0xFF4A8A96),
          ],
          stops: [0.0, 0.22, 0.55, 0.82, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      );

  /// Navy gloss — same full-round depth model as [plate]. Used for selected
  /// chips (contrast).
  static BoxDecoration get navyPlate => BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1.0),
          end: Alignment(0.85, 1.0),
          colors: [
            Color(0xFF6B72D4),
            Color(0xFF4A50B0),
            Color(0xFF2E3388),
            Color(0xFF1E2258),
            Color(0xFF15183F),
          ],
          stops: [0.0, 0.22, 0.55, 0.82, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.36),
            blurRadius: 12,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      );

  /// Field outer shell — full-round cyan gloss, pill radius.
  static BoxDecoration get fieldPlate => BoxDecoration(
        borderRadius: BorderRadius.circular(fieldRadius),
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1.0),
          end: Alignment(0.85, 1.0),
          colors: [
            Color(0xFFE8F7FC),
            Color(0xFFC5E8F4),
            Color(0xFF8EBFCE),
            Color(0xFF5A9AAB),
            Color(0xFF4A8A96),
          ],
          stops: [0.0, 0.22, 0.55, 0.82, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: GlossColors.navy.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      );

  /// Borderless input on top of [fieldPlate] — label floats in the gloss.
  /// Vertical padding tuned so floating label + value + dropdown icon fit
  /// inside [fieldHeight] without bottom clipping.
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

  /// Alias — text + dropdown share the same decoration.
  static InputDecoration compactField(String label) => fieldDecoration(label);

  /// Gloss field shell: cyan plate + fixed height + borderless input child.
  /// No hard clip on the child so dropdown value / floating label are not
  /// truncated at the bottom; the plate radius still soft-clips via decoration.
  static Widget fieldShell({required Widget child}) {
    return Container(
      height: fieldHeight,
      decoration: fieldPlate,
      alignment: Alignment.center,
      child: child,
    );
  }

  /// Self-fitting cyan gloss CTA (SEND INVITE, SAVE) — same plate language
  /// as tiles and fields for app-wide uniformity. Navy text on cyan plate.
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

  /// @deprecated Use [glossCta] — kept as alias for any leftover call sites.
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
      // App-wide dialog template — AlertDialog/Dialog inherit these by default.
      // Override per-screen only when layout needs it (e.g. insetPadding).
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
