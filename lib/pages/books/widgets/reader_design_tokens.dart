import 'package:flutter/material.dart';

/// Design tokens for the ZPlay Reader.
/// Enforces consistent 4pt-based spacing, standard radii, custom soft shadows,
/// named motion curves/durations, and typography scales across all reader components.
class ReaderTokens {
  ReaderTokens._();

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SPACING SCALE (4pt Base)
  // ──────────────────────────────────────────────────────────────────────────
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ──────────────────────────────────────────────────────────────────────────
  // 2. RADIUS SCALE
  // ──────────────────────────────────────────────────────────────────────────
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;
  static const double radius32 = 32.0;

  static const BorderRadius rounded4 = BorderRadius.all(Radius.circular(radius4));
  static const BorderRadius rounded8 = BorderRadius.all(Radius.circular(radius8));
  static const BorderRadius rounded12 = BorderRadius.all(Radius.circular(radius12));
  static const BorderRadius rounded16 = BorderRadius.all(Radius.circular(radius16));
  static const BorderRadius rounded24 = BorderRadius.all(Radius.circular(radius24));
  static const BorderRadius rounded32 = BorderRadius.all(Radius.circular(radius32));

  // ──────────────────────────────────────────────────────────────────────────
  // 3. ELEVATION & CUSTOM SOFT SHADOWS
  // ──────────────────────────────────────────────────────────────────────────
  /// Subtle shadow for small floating elements, exit pills, and list cards
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x0F000000), // alpha 0.06
    blurRadius: 8.0,
    spreadRadius: 0.0,
    offset: Offset(0, 2),
  );

  /// Medium soft shadow for book covers, customization sheet, and floating chevrons
  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x1A000000), // alpha 0.10
    blurRadius: 16.0,
    spreadRadius: 0.0,
    offset: Offset(0, 4),
  );

  /// Ambient spotlight glow for the Focus Mode active line box
  static BoxShadow shadowGlow(Color accentColor) {
    return BoxShadow(
      color: accentColor.withValues(alpha: 0.22),
      blurRadius: 20.0,
      spreadRadius: 0.0,
      offset: Offset.zero,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. MOTION TOKENS
  // ──────────────────────────────────────────────────────────────────────────
  /// Micro feedback (button press, chip select)
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Curve curveFast = Curves.easeOut;

  /// Top and bottom bar chrome fade + slide
  static const Duration motionChrome = Duration(milliseconds: 200);
  static const Curve curveChrome = Curves.easeInOutCubic;

  /// Focus mode highlight box sliding animation
  static const Duration motionFocusLine = Duration(milliseconds: 220);
  static const Curve curveFocusLine = Curves.easeInOutCubic;

  /// Focus mode per-line dim / undim (lags slightly behind box for natural lighting)
  static const Duration motionFocusOpacity = Duration(milliseconds: 260);
  static const Curve curveFocusOpacity = Curves.easeInOut;

  /// Customization sheet / drawer open & close
  static const Duration motionSheet = Duration(milliseconds: 260);
  static const Curve curveSheet = Curves.easeOutCubic;

  /// Theme switch crossfade
  static const Duration motionThemeSwitch = Duration(milliseconds: 300);
  static const Curve curveThemeSwitch = Curves.easeInOut;

  // ──────────────────────────────────────────────────────────────────────────
  // 5. TYPOGRAPHY CONSTANTS & UI SCALES
  // ──────────────────────────────────────────────────────────────────────────
  static const String uiFont = 'Poppins';
  static const String defaultSerifFont = 'Georgia';

  static const TextStyle caption = TextStyle(
    fontFamily: uiFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle primaryLabel = TextStyle(
    fontFamily: uiFont,
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: uiFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}
