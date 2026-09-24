import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.dart';

class AppThemePalette {
  final String id;
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color scaffoldBackgroundColor;
  final Color cardBackgroundColor;
  final Color appBarBackgroundColor;

  /// Explicit hover/pressed states for [primaryColor]. Left null by every preset
  /// that pre-dates the token layer, in which case `ZplayTokens` derives them by
  /// lightening and darkening the accent. A palette with pinned brand states sets
  /// them instead of accepting the derived approximation.
  final Color? accentHoverColor;
  final Color? accentPressedColor;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    this.scaffoldBackgroundColor = const Color(0xFF080A0F),
    this.cardBackgroundColor = const Color(0xFF12151E),
    this.appBarBackgroundColor = const Color(0xFF0D1017),
    this.accentHoverColor,
    this.accentPressedColor,
  });
}

abstract final class AppThemeService {
  static const _storageKey = 'app_theme_id';

  static const List<AppThemePalette> palettes = [
    AppThemePalette(
      id: 'amethyst',
      name: 'Amethyst Violet',
      primaryColor: Color(0xFF7C5CFF),
      accentColor: Color(0xFF00E5FF),
      scaffoldBackgroundColor: Color(0xFF080A0F),
      cardBackgroundColor: Color(0xFF12151E),
      appBarBackgroundColor: Color(0xFF0D1017),
    ),
    AppThemePalette(
      id: 'cyberpunk',
      name: 'Cyberpunk Neon',
      primaryColor: Color(0xFFFF2A85),
      accentColor: Color(0xFF00F0FF),
      scaffoldBackgroundColor: Color(0xFF0C0812),
      cardBackgroundColor: Color(0xFF160E1E),
      appBarBackgroundColor: Color(0xFF100A17),
    ),
    AppThemePalette(
      id: 'emerald',
      name: 'Emerald Aurora',
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF34D399),
      scaffoldBackgroundColor: Color(0xFF060F0B),
      cardBackgroundColor: Color(0xFF0E1A14),
      appBarBackgroundColor: Color(0xFF09140F),
    ),
    AppThemePalette(
      id: 'sunset',
      name: 'Sunset Crimson',
      primaryColor: Color(0xFFFF3366),
      accentColor: Color(0xFFFF9900),
      scaffoldBackgroundColor: Color(0xFF0F080B),
      cardBackgroundColor: Color(0xFF1A0E13),
      appBarBackgroundColor: Color(0xFF130A0E),
    ),
    AppThemePalette(
      id: 'sapphire',
      name: 'Midnight Sapphire',
      primaryColor: Color(0xFF3B82F6),
      accentColor: Color(0xFF60A5FA),
      scaffoldBackgroundColor: Color(0xFF060B14),
      cardBackgroundColor: Color(0xFF0E1726),
      appBarBackgroundColor: Color(0xFF09101C),
    ),
    AppThemePalette(
      id: 'amber',
      name: 'Golden Amber',
      primaryColor: Color(0xFFF59E0B),
      accentColor: Color(0xFFFCD34D),
      scaffoldBackgroundColor: Color(0xFF0F0C06),
      cardBackgroundColor: Color(0xFF1A160E),
      appBarBackgroundColor: Color(0xFF141009),
    ),
    AppThemePalette(
      id: 'vampire',
      name: 'Vampire Red',
      primaryColor: Color(0xFFE50914),
      accentColor: Color(0xFFFF4D4D),
      scaffoldBackgroundColor: Color(0xFF0E0607),
      cardBackgroundColor: Color(0xFF1A0C0E),
      appBarBackgroundColor: Color(0xFF14080A),
    ),
    AppThemePalette(
      id: 'barbie',
      name: 'Pink Barbie',
      primaryColor: Color(0xFFFF1493),
      accentColor: Color(0xFFFF80BF),
      scaffoldBackgroundColor: Color(0xFF14050E),
      cardBackgroundColor: Color(0xFF220A18),
      appBarBackgroundColor: Color(0xFF1A0713),
    ),
    // The current brand direction. Cool near-black slate (never pure black) with
    // a single teal accent; hover/pressed are pinned by brand rather than derived.
    // Appended last so existing preset indices are untouched — palettes[0] is
    // still Amethyst Violet, which stays the default until the screens that
    // hardcode 0xFF7C5CFF have migrated (412 occurrences, see DESIGN_AUDIT.md).
    AppThemePalette(
      id: 'zplay',
      name: 'Signal Teal',
      primaryColor: Color(0xFF2FD0C0),
      accentColor: Color(0xFF5ADFD2),
      scaffoldBackgroundColor: Color(0xFF0A0D12),
      cardBackgroundColor: Color(0xFF111621),
      appBarBackgroundColor: Color(0xFF161C29),
      accentHoverColor: Color(0xFF5ADFD2),
      accentPressedColor: Color(0xFF22B3A5),
    ),
  ];

  static final ValueNotifier<AppThemePalette> currentPalette =
      ValueNotifier<AppThemePalette>(palettes[0]);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_storageKey);
    if (id != null) {
      final found = palettes.firstWhere(
        (p) => p.id == id,
        orElse: () => palettes[0],
      );
      currentPalette.value = found;
    }
  }

  static Future<void> setPalette(AppThemePalette palette) async {
    currentPalette.value = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, palette.id);
  }

  /// The design-token set for [palette] — the semantic colours every screen can
  /// migrate onto. Derives from the five palette colours only, so all presets
  /// (including any added later) are supported without per-preset code.
  static ZplayTokens tokensFor(AppThemePalette palette) => ZplayTokens.derive(
    accent: palette.primaryColor,
    accentHover: palette.accentHoverColor,
    accentPressed: palette.accentPressedColor,
    bg: palette.scaffoldBackgroundColor,
    surface: palette.cardBackgroundColor,
    surfaceRaised: palette.appBarBackgroundColor,
  );

  /// Tokens for the active palette, for code without a `BuildContext`. Memoised
  /// on palette identity — [AppThemePalette] is immutable and every preset is a
  /// const, so the derivation runs once per palette switch instead of once per
  /// call.
  static ZplayTokens get currentTokens {
    final palette = currentPalette.value;
    if (!identical(_tokensFor, palette)) {
      _tokensFor = palette;
      _tokens = tokensFor(palette);
    }
    return _tokens;
  }

  static AppThemePalette? _tokensFor;
  static late ZplayTokens _tokens;

  static ThemeData createThemeData(AppThemePalette palette) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.scaffoldBackgroundColor,
      useMaterial3: true,
      colorSchemeSeed: palette.primaryColor,
      extensions: [tokensFor(palette)],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBarBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.cardBackgroundColor,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
