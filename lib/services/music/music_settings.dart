import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_page_settings.dart';

enum MusicFullscreenPreset {
  vinylStudio('Vinyl Turntable Studio', 'Rotating 33rpm vinyl disc with tonearm and warm studio atmosphere'),
  cyberWaveform('Cyberpunk Wave Visualizer', 'Real-time animated audio visualizer canvas with neon glow'),
  liquidGlassNeo('Liquid Glass Sanctuary', 'Deep optical refraction glass sheets powered by liquid_glass_easy'),
  cinematicArtwork('Cinematic Poster Focus', 'Massive edge-to-edge immersive album art with blurred atmosphere'),
  customStudio('Custom Drag & Drop Full Player', 'Your fully customized, arranged and styled fullscreen player');

  final String label;
  final String description;
  const MusicFullscreenPreset(this.label, this.description);
}

enum MusicSeekbarStyle {
  waveformEqualizer('Dynamic Audio Waveform Canvas', 'Procedural animated waveform bars with live equalizer scrubbing'),
  neonGradient('Neon Gradient Progress Bar', 'Multi-color vibrant linear gradient scrubber with glowing tip'),
  liquidGlassSlider('Liquid Glass Track Slider', 'Refractive frosted glass slider track with smooth thumb'),
  standardSlider('Precision Tactile Slider', 'Tactile interactive glass track with timecode readouts'),
  radialDial('Radial Circular Ring Dial', 'Radial circular dial scrubber for compact modern interfaces');

  final String label;
  final String description;
  const MusicSeekbarStyle(this.label, this.description);
}

enum MusicPlayButtonStyle {
  liquidGlassNeo('Liquid Glass Neomorphic'),
  circleGlow('Aura Glow Circle'),
  neonSquare('Neon Glass Square'),
  pillPulse('Wide Accent Pill');

  final String label;
  const MusicPlayButtonStyle(this.label);
}

enum MusicHoverEffect {
  scaleBounce('Scale & Spring Bounce'),
  glowAura('Theme Accent Glow Aura'),
  glassRipple('Liquid Glass Ripple'),
  tilt3D('3D Subtle Tilt Perspective');

  final String label;
  const MusicHoverEffect(this.label);
}

enum MusicArtworkStyle {
  vinylSpinningDisc('Spinning Vinyl Disc with Center Label'),
  floatingCard3D('3D Floating Glass Card with Elevation'),
  square3D('Rounded Neomorphic Square with Glow'),
  glowSphere('Atmospheric Glow Orb');

  final String label;
  const MusicArtworkStyle(this.label);
}

enum MusicCardDensity {
  compact('Compact (Dense Grid)', 0.88),
  standard('Standard (Balanced)', 1.0),
  spacious('Spacious (Large Covers)', 1.15);

  final String label;
  final double scale;
  const MusicCardDensity(this.label, this.scale);
}

abstract final class MusicSettings {
  // Atmosphere & Lighting Keys
  static const _keyEnableAmbientLights = 'music_enable_ambient_lights';
  static const _keyAmbientPattern = 'music_ambient_pattern';
  static const _keyAmbientIntensity = 'music_ambient_intensity';
  static const _keyAmbientSpeed = 'music_ambient_speed';

  // Discovery & UI Keys
  static const _keyEnableSpotlight = 'music_enable_spotlight';
  static const _keyShowTrendingArtists = 'music_show_trending_artists';
  static const _keyCardDensity = 'music_card_density';
  static const _keyShowLosslessBadge = 'music_show_lossless_badge';
  static const _keyCardHoverGlow = 'music_card_hover_glow';

  // Fullscreen Player Keys
  static const _keySelectedFullscreenPreset = 'music_selected_fullscreen_preset';
  static const _keyCustomSeekbarStyle = 'music_custom_seekbar_style';
  static const _keyCustomPlayButtonStyle = 'music_custom_play_button_style';
  static const _keyCustomHoverEffect = 'music_custom_hover_effect';
  static const _keyCustomArtworkStyle = 'music_custom_artwork_style';
  static const _keyComponentOrderFullscreen = 'music_component_order_fullscreen';
  static const _keyEnableLiquidGlass = 'music_enable_liquid_glass';
  static const _keyShowLyricsDrawer = 'music_show_lyrics_drawer';
  static const _keyShowQueueDrawer = 'music_show_queue_drawer';

  // Atmosphere Notifiers
  static final ValueNotifier<bool> enableAmbientLights = ValueNotifier<bool>(true);
  static final ValueNotifier<AmbientLightPattern> ambientLightPattern =
      ValueNotifier<AmbientLightPattern>(AmbientLightPattern.dualOrbs);
  static final ValueNotifier<double> ambientLightIntensity = ValueNotifier<double>(0.22);
  static final ValueNotifier<double> ambientLightSpeed = ValueNotifier<double>(1.0);

  // Discovery Notifiers
  static final ValueNotifier<bool> enableSpotlight = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showTrendingArtists = ValueNotifier<bool>(true);
  static final ValueNotifier<MusicCardDensity> cardDensity =
      ValueNotifier<MusicCardDensity>(MusicCardDensity.standard);
  static final ValueNotifier<bool> showLosslessBadge = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> cardHoverGlow = ValueNotifier<bool>(true);

  // Fullscreen Player Notifiers
  static final ValueNotifier<MusicFullscreenPreset> selectedFullscreenPreset =
      ValueNotifier<MusicFullscreenPreset>(MusicFullscreenPreset.vinylStudio);
  static final ValueNotifier<MusicSeekbarStyle> customSeekbarStyle =
      ValueNotifier<MusicSeekbarStyle>(MusicSeekbarStyle.waveformEqualizer);
  static final ValueNotifier<MusicPlayButtonStyle> customPlayButtonStyle =
      ValueNotifier<MusicPlayButtonStyle>(MusicPlayButtonStyle.liquidGlassNeo);
  static final ValueNotifier<MusicHoverEffect> customHoverEffect =
      ValueNotifier<MusicHoverEffect>(MusicHoverEffect.glassRipple);
  static final ValueNotifier<MusicArtworkStyle> customArtworkStyle =
      ValueNotifier<MusicArtworkStyle>(MusicArtworkStyle.vinylSpinningDisc);
  static final ValueNotifier<bool> enableLiquidGlass = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showLyricsDrawer = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showQueueDrawer = ValueNotifier<bool>(true);
  static final ValueNotifier<List<String>> componentOrderFullscreen = ValueNotifier<List<String>>([
    'artwork',
    'title',
    'qualityBadge',
    'seekbar',
    'mainControls',
    'secondaryControls',
    'extraActions',
  ]);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    enableAmbientLights.value = prefs.getBool(_keyEnableAmbientLights) ?? true;
    final patternStr = prefs.getString(_keyAmbientPattern);
    ambientLightPattern.value = AmbientLightPattern.values.firstWhere(
      (p) => p.name == patternStr,
      orElse: () => AmbientLightPattern.dualOrbs,
    );
    ambientLightIntensity.value = prefs.getDouble(_keyAmbientIntensity) ?? 0.22;
    ambientLightSpeed.value = prefs.getDouble(_keyAmbientSpeed) ?? 1.0;

    enableSpotlight.value = prefs.getBool(_keyEnableSpotlight) ?? true;
    showTrendingArtists.value = prefs.getBool(_keyShowTrendingArtists) ?? true;
    final densityStr = prefs.getString(_keyCardDensity);
    cardDensity.value = MusicCardDensity.values.firstWhere(
      (d) => d.name == densityStr,
      orElse: () => MusicCardDensity.standard,
    );
    showLosslessBadge.value = prefs.getBool(_keyShowLosslessBadge) ?? true;
    cardHoverGlow.value = prefs.getBool(_keyCardHoverGlow) ?? true;

    final fullPresetStr = prefs.getString(_keySelectedFullscreenPreset);
    selectedFullscreenPreset.value = MusicFullscreenPreset.values.firstWhere(
      (p) => p.name == fullPresetStr,
      orElse: () => MusicFullscreenPreset.vinylStudio,
    );

    final seekbarStr = prefs.getString(_keyCustomSeekbarStyle);
    customSeekbarStyle.value = MusicSeekbarStyle.values.firstWhere(
      (s) => s.name == seekbarStr,
      orElse: () => MusicSeekbarStyle.waveformEqualizer,
    );

    final playBtnStr = prefs.getString(_keyCustomPlayButtonStyle);
    customPlayButtonStyle.value = MusicPlayButtonStyle.values.firstWhere(
      (b) => b.name == playBtnStr,
      orElse: () => MusicPlayButtonStyle.liquidGlassNeo,
    );

    final hoverStr = prefs.getString(_keyCustomHoverEffect);
    customHoverEffect.value = MusicHoverEffect.values.firstWhere(
      (h) => h.name == hoverStr,
      orElse: () => MusicHoverEffect.glassRipple,
    );

    final artStr = prefs.getString(_keyCustomArtworkStyle);
    customArtworkStyle.value = MusicArtworkStyle.values.firstWhere(
      (a) => a.name == artStr,
      orElse: () => MusicArtworkStyle.vinylSpinningDisc,
    );

    enableLiquidGlass.value = prefs.getBool(_keyEnableLiquidGlass) ?? true;
    showLyricsDrawer.value = prefs.getBool(_keyShowLyricsDrawer) ?? true;
    showQueueDrawer.value = prefs.getBool(_keyShowQueueDrawer) ?? true;

    final fullOrderList = prefs.getStringList(_keyComponentOrderFullscreen);
    if (fullOrderList != null && fullOrderList.isNotEmpty) {
      componentOrderFullscreen.value = fullOrderList;
    }
  }

  // ── Setters ──
  static Future<void> setEnableAmbientLights(bool value) async {
    enableAmbientLights.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableAmbientLights, value);
    _notify();
  }

  static Future<void> setAmbientLightPattern(AmbientLightPattern pattern) async {
    ambientLightPattern.value = pattern;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAmbientPattern, pattern.name);
    _notify();
  }

  static Future<void> setAmbientLightIntensity(double value) async {
    ambientLightIntensity.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientIntensity, value);
    _notify();
  }

  static Future<void> setAmbientLightSpeed(double value) async {
    ambientLightSpeed.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientSpeed, value);
    _notify();
  }

  static Future<void> setEnableSpotlight(bool value) async {
    enableSpotlight.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableSpotlight, value);
    _notify();
  }

  static Future<void> setCardDensity(MusicCardDensity density) async {
    cardDensity.value = density;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardDensity, density.name);
    _notify();
  }

  static Future<void> setShowLosslessBadge(bool value) async {
    showLosslessBadge.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLosslessBadge, value);
    _notify();
  }

  static Future<void> setCardHoverGlow(bool value) async {
    cardHoverGlow.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCardHoverGlow, value);
    _notify();
  }

  static Future<void> setSelectedFullscreenPreset(MusicFullscreenPreset preset) async {
    selectedFullscreenPreset.value = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedFullscreenPreset, preset.name);
    _notify();
  }

  static Future<void> setCustomSeekbarStyle(MusicSeekbarStyle style) async {
    customSeekbarStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomSeekbarStyle, style.name);
    _notify();
  }

  static Future<void> setCustomPlayButtonStyle(MusicPlayButtonStyle style) async {
    customPlayButtonStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPlayButtonStyle, style.name);
    _notify();
  }

  static Future<void> setCustomHoverEffect(MusicHoverEffect effect) async {
    customHoverEffect.value = effect;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomHoverEffect, effect.name);
    _notify();
  }

  static Future<void> setCustomArtworkStyle(MusicArtworkStyle style) async {
    customArtworkStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomArtworkStyle, style.name);
    _notify();
  }

  static Future<void> setEnableLiquidGlass(bool value) async {
    enableLiquidGlass.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableLiquidGlass, value);
    _notify();
  }

  static Future<void> reorderFullscreenComponents(int oldIndex, int newIndex) async {
    var index = newIndex;
    if (oldIndex < index) {
      index -= 1;
    }
    final list = List<String>.from(componentOrderFullscreen.value);
    final item = list.removeAt(oldIndex);
    list.insert(index, item);
    componentOrderFullscreen.value = list;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyComponentOrderFullscreen, list);
    _notify();
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnableAmbientLights);
    await prefs.remove(_keyAmbientPattern);
    await prefs.remove(_keyAmbientIntensity);
    await prefs.remove(_keyAmbientSpeed);
    await prefs.remove(_keyEnableSpotlight);
    await prefs.remove(_keyCardDensity);
    await prefs.remove(_keyShowLosslessBadge);
    await prefs.remove(_keyCardHoverGlow);
    await prefs.remove(_keySelectedFullscreenPreset);
    await prefs.remove(_keyCustomSeekbarStyle);
    await prefs.remove(_keyCustomPlayButtonStyle);
    await prefs.remove(_keyCustomHoverEffect);
    await prefs.remove(_keyCustomArtworkStyle);
    await prefs.remove(_keyEnableLiquidGlass);
    await prefs.remove(_keyComponentOrderFullscreen);

    enableAmbientLights.value = true;
    ambientLightPattern.value = AmbientLightPattern.dualOrbs;
    ambientLightIntensity.value = 0.22;
    ambientLightSpeed.value = 1.0;
    enableSpotlight.value = true;
    cardDensity.value = MusicCardDensity.standard;
    showLosslessBadge.value = true;
    cardHoverGlow.value = true;
    selectedFullscreenPreset.value = MusicFullscreenPreset.vinylStudio;
    customSeekbarStyle.value = MusicSeekbarStyle.waveformEqualizer;
    customPlayButtonStyle.value = MusicPlayButtonStyle.liquidGlassNeo;
    customHoverEffect.value = MusicHoverEffect.glassRipple;
    customArtworkStyle.value = MusicArtworkStyle.vinylSpinningDisc;
    enableLiquidGlass.value = true;
    componentOrderFullscreen.value = [
      'artwork',
      'title',
      'qualityBadge',
      'seekbar',
      'mainControls',
      'secondaryControls',
      'extraActions',
    ];
    _notify();
  }

  static void _notify() {
    changeNotifier.value++;
  }
}
