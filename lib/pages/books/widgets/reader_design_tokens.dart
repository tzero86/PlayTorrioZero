import 'package:flutter/material.dart';

import '../../../services/theme/app_theme_service.dart';
import '../../../services/theme/design_tokens.dart';

/// Reader chrome vocabulary for the ZPlay Reader.
///
/// The reader family draws two different things: the *page* — paper surface, book
/// text metrics, the light/sepia/dark/amoled swatches — and the *chrome* around
/// it — bars, drawer, customisation sheet, zoom and focus controls. Page values
/// are product data and stay on `ReaderSettingsData`; chrome follows the app
/// palette through the shared contract tokens, so a palette switch restyles the
/// reader with the rest of the shell.
///
/// This class is the reader's chrome bridge: the numeric scales are aliases of
/// [ZplaySpacing]/[ZplayRadius], and the colour members are getters over
/// [AppThemeService.currentTokens] — the same derivation as `context.tokens`,
/// memoised on palette identity, so a reader helper without a `BuildContext` (an
/// `IconButton` factory, a shadow, a `const` list) still resolves the active
/// palette.
class ReaderTokens {
  ReaderTokens._();

  // ──────────────────────────────────────────────────────────────────────────
  // 1. PALETTE-FOLLOWING CHROME COLOURS
  // ──────────────────────────────────────────────────────────────────────────
  /// The contract set for the active palette. Re-derived once per palette switch.
  static ZplayTokens get _tokens => AppThemeService.currentTokens;

  /// Page background of reader chrome scrims and the comic/AMOLED backdrop.
  static Color get bg => _tokens.bg;

  /// Recessed tiles inside chrome: chips, control fills, cover placeholders.
  static Color get surface => _tokens.surface;

  /// Bars sitting on top of the page (reader top/bottom chrome, drawer).
  static Color get surfaceRaised => _tokens.surfaceRaised;

  /// Floating chrome above the page: focus pills, zoom bar, customisation sheet.
  static Color get surfaceOverlay => _tokens.surfaceOverlay;

  static Color get borderSubtle => _tokens.borderSubtle;
  static Color get borderDefault => _tokens.borderDefault;
  static Color get borderStrong => _tokens.borderStrong;

  static Color get textPrimary => _tokens.textPrimary;
  static Color get textEmphasis => _tokens.textEmphasis;
  static Color get textSecondary => _tokens.textSecondary;
  static Color get textMuted => _tokens.textMuted;
  static Color get textDisabled => _tokens.textDisabled;

  static Color get accent => _tokens.accent;
  static Color get accentSubtle => _tokens.accentSubtle;
  static Color get onAccent => _tokens.onAccent;

  static Color get success => _tokens.success;
  static Color get danger => _tokens.danger;

  /// 1px hairline in the default border role, for `Border`/`Divider` sides.
  static BorderSide get hairline => _tokens.hairline;

  /// 1px hairline in the strong divider role.
  static BorderSide get hairlineStrong => _tokens.hairlineStrong;

  // ──────────────────────────────────────────────────────────────────────────
  // 2. SPACING SCALE (4pt base, aliases of [ZplaySpacing])
  // ──────────────────────────────────────────────────────────────────────────
  static const double space4 = ZplaySpacing.s4;
  static const double space8 = ZplaySpacing.s8;
  static const double space12 = ZplaySpacing.s12;
  static const double space16 = ZplaySpacing.s16;
  static const double space24 = ZplaySpacing.s24;
  static const double space32 = ZplaySpacing.s32;
  static const double space48 = ZplaySpacing.s48;
  static const double space64 = ZplaySpacing.s64;

  // ──────────────────────────────────────────────────────────────────────────
  // 3. RADIUS SCALE (aliases of [ZplayRadius], legacy buckets 4→xs, 8/12→sm,
  //    16→md, 24→lg, 32→xl)
  // ──────────────────────────────────────────────────────────────────────────
  static const double radius4 = ZplayRadius.xs;
  static const double radius8 = ZplayRadius.sm;
  static const double radius12 = ZplayRadius.sm;
  static const double radius16 = ZplayRadius.md;
  static const double radius24 = ZplayRadius.lg;
  static const double radius32 = ZplayRadius.xl;

  static const BorderRadius rounded4 = ZplayRadius.xsAll;
  static const BorderRadius rounded8 = ZplayRadius.smAll;
  static const BorderRadius rounded12 = ZplayRadius.smAll;
  static const BorderRadius rounded16 = ZplayRadius.mdAll;
  static const BorderRadius rounded24 = ZplayRadius.lgAll;
  static const BorderRadius rounded32 = ZplayRadius.xlAll;

  // ──────────────────────────────────────────────────────────────────────────
  // 4. ELEVATION & CUSTOM SOFT SHADOWS
  // ──────────────────────────────────────────────────────────────────────────
  /// Subtle shadow for small floating elements, exit pills, and list cards.
  ///
  /// The reader keeps its own elevation scale: the contract layer carries no
  /// shadow token, and callers place these in `const` shadow lists.
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

  /// Ambient spotlight glow for the Focus Mode active line box, tinted with the
  /// active accent so the highlight matches the chrome it sits in.
  static BoxShadow shadowGlow(Color accentColor) {
    return BoxShadow(
      color: accentColor.withValues(alpha: 0.22),
      blurRadius: 20.0,
      spreadRadius: 0.0,
      offset: Offset.zero,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. MOTION TOKENS
  // ──────────────────────────────────────────────────────────────────────────
  // The reader's timings are its own choreography — chrome fade, focus-line
  // slide, per-line dim, sheet and theme crossfade lag each other deliberately —
  // so they stay off the contract's 120/200/320 steps.

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
  // 6. TYPOGRAPHY
  // ──────────────────────────────────────────────────────────────────────────
  /// Reader UI font keys. Chrome text follows the shared type scale and the
  /// ambient theme family; these keys are the reader's own font vocabulary for
  /// book content (`ReaderSettingsData.fontFamily`).
  static const String uiFont = 'Poppins';
  static const String defaultSerifFont = 'Georgia';

  /// Chrome type roles — the shared scale, so reader chrome reads like the shell.
  static TextStyle get caption => ZplayType.body.toStyle();

  static TextStyle get primaryLabel => ZplayType.subtitle.toStyle();

  static TextStyle get tabLabel => ZplayType.label.toStyle();
}
