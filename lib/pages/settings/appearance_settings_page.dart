import 'dart:io';

import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/theme/custom_background_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/manga/manga_settings.dart';
import '../../services/music/music_settings.dart';
import '../../services/diagnostics/renderer_backend.dart';
import 'appearance/audiobook_settings_page.dart';
import 'appearance/custom_background_settings_page.dart';
import 'appearance/home_ui_settings_page.dart';
import 'appearance/liquid_glass_settings_page.dart';
import 'appearance/live_tv_settings_page.dart';
import 'appearance/manga_settings_page.dart';
import 'appearance/music_settings_page.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        surfaceTintColor: Colors.transparent,
        // The shell family draws this header as an opaque palette band with a
        // bottom hairline rather than a translucent wash over the page.
        shape: Border(bottom: tokens.hairline),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appearance & Interface',
          style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Header description
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Fine-tune the visual atmosphere, custom wallpaper background, color palettes, and interface layouts.',
                  style: ZplayType.body.toStyle(color: tokens.textSecondary),
                ),
              ),

              // Button 0: Custom Wallpaper & Atmosphere Background
              ValueListenableBuilder<CustomBackgroundData>(
                valueListenable: CustomBackgroundService.notifier,
                builder: (context, customBg, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.wallpaper_rounded,
                        iconColor: tokens.accent,
                        title: 'Custom Background & Wallpaper',
                        subtitle: 'Upload custom photos, choose curated dark wallpapers, and blend theme ambient lighting',
                        badgeText: customBg.hasCustomBackground ? 'Custom Active' : 'Default Theme',
                        badgeColor: customBg.hasCustomBackground ? tokens.accent : tokens.textMuted,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomBackgroundSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 1: Liquid Glass Setup
              ValueListenableBuilder<bool>(
                valueListenable: GlassSettings.enabled,
                builder: (context, glassEnabled, _) {
                  return ValueListenableBuilder<GlassPreset>(
                    valueListenable: GlassSettings.preset,
                    builder: (context, preset, _) {
                      return _buildSectionButton(
                        icon: Icons.blur_on_rounded,
                        iconColor: tokens.accent,
                        title: 'Liquid Glass Setup',
                        subtitle: 'Adjust hover impact, wobble spring physics, lens refraction, and chromatic aberration',
                        badgeText: glassEnabled ? preset.label : 'Disabled',
                        badgeColor: glassEnabled ? tokens.accent : tokens.textMuted,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiquidGlassSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 3: Home Page UI & Themes
              ValueListenableBuilder<AppThemePalette>(
                valueListenable: AppThemeService.currentPalette,
                builder: (context, currentPalette, _) {
                  return _buildSectionButton(
                    icon: Icons.palette_rounded,
                    iconColor: tokens.accent,
                    title: 'Home Page UI & Themes',
                    subtitle: 'Color schemes, "Because you have on your list" smart slider, hero spotlight, and card density',
                    badgeText: currentPalette.name,
                    badgeColor: tokens.accent,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeUiSettingsPage(),
                        ),
                      );
                      setState(() {});
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 3: Live TV & Sports UI
              ValueListenableBuilder<bool>(
                valueListenable: IptvSettings.enableSpotlight,
                builder: (context, spotlightEnabled, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.live_tv_rounded,
                        iconColor: tokens.accent,
                        title: 'Live TV & Sports UI',
                        subtitle: 'Broadcast hero spotlight, channel card density, category ordering, and live badge styling',
                        badgeText: spotlightEnabled ? 'Spotlight ON' : 'Compact',
                        badgeColor: tokens.accent,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveTvSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 4: Manga UI & Reader Atmosphere
              ValueListenableBuilder<MangaReadingMode>(
                valueListenable: MangaSettings.defaultReadingMode,
                builder: (context, readingMode, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.menu_book_rounded,
                        iconColor: tokens.accent,
                        title: 'Manga UI & Reader Atmosphere',
                        subtitle: 'Ambient moving lighting, card density, reading layout widths, webtoon/horizontal modes, and page deck preview',
                        badgeText: readingMode == MangaReadingMode.webtoon ? 'Webtoon' : 'Horizontal',
                        badgeColor: tokens.accent,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MangaSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 5: Audiobook UI & Player Studio
              ValueListenableBuilder<AudiobookPlayerPreset>(
                valueListenable: AudiobookSettings.selectedPlayerPreset,
                builder: (context, playerPreset, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.headphones_rounded,
                        iconColor: tokens.accent,
                        title: 'Audiobook UI & Player Studio',
                        subtitle: 'Hero spotlight, 5 distinct player designs, drag & drop modular studio, waveform canvas scrubber, and custom controls',
                        badgeText: playerPreset.label.split(' ').first,
                        badgeColor: tokens.accent,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AudiobookSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 6: Music UI & Player Studio
              ValueListenableBuilder<MusicFullscreenPreset>(
                valueListenable: MusicSettings.selectedFullscreenPreset,
                builder: (context, fullPreset, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.music_note_rounded,
                        iconColor: tokens.accent,
                        title: 'Music UI & Player Studio',
                        subtitle: 'Hero spotlight, lossless badges, and fullscreen player studio for layout, seekbar, physics & turntable styling',
                        badgeText: fullPreset.label.split(' ').first,
                        badgeColor: tokens.accent,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MusicSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Windows graphics backend (Skia default, restart to apply).
              if (Platform.isWindows) _buildRendererBackendCard(),

              const SizedBox(height: 28),

              // Visual Overview Notes
              Text(
                'LIVE CUSTOMIZATION SCOPE',
                style: ZplayType.overline.toStyle(color: tokens.textMuted),
              ),
              const SizedBox(height: 12),

              _buildScopeTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Video Player & Watch Screens',
                description: 'Overlays, glass sheets, and media controls render with your custom optical blur, refraction index, and border shimmer.',
              ),
              const SizedBox(height: 10),
              _buildScopeTile(
                icon: Icons.home_rounded,
                title: 'Home Page & Discovery',
                description: 'Adapts to your chosen theme accent colors, smart BestSimilar recommendation slider, and chosen poster density.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRendererBackendCard() {
    return ValueListenableBuilder<RendererBackend>(
      valueListenable: RendererBackendSettings.current,
      builder: (context, backend, _) {
        final tokens = context.tokens;
        final accent = tokens.accent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: ZplayRadius.mdAll,
            border: Border.fromBorderSide(tokens.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: ZplayOpacity.borderStrong),
                      borderRadius: ZplayRadius.smAll,
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Graphics Backend',
                                style: ZplayType.subtitle.toStyle(
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: ZplayOpacity.borderStrong,
                                ),
                                borderRadius: ZplayRadius.xsAll,
                              ),
                              child: Text(
                                backend.label,
                                style: ZplayType.caption.toStyle(color: accent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Skia is recommended on Windows here — '
                          'Impeller coincided with an NVIDIA driver crash.',
                          style: ZplayType.bodySmall.toStyle(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildBackendOption(
                backend: RendererBackend.skia,
                selected: backend == RendererBackend.skia,
              ),
              const SizedBox(height: 8),
              _buildBackendOption(
                backend: RendererBackend.impeller,
                selected: backend == RendererBackend.impeller,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.restart_alt_rounded,
                    size: 14,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Restart the app to apply — the backend is fixed when the engine starts.',
                      style: ZplayType.bodySmall.toStyle(
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackendOption({
    required RendererBackend backend,
    required bool selected,
  }) {
    final tokens = context.tokens;
    // Both rows carry the palette accent; the selected one is distinguished by
    // its fill and border rather than by a second hue.
    final color = tokens.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => RendererBackendSettings.setBackend(backend),
        borderRadius: ZplayRadius.smAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tokens.accentSubtle : tokens.surfaceOverlay,
            borderRadius: ZplayRadius.smAll,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: ZplayOpacity.borderStrong)
                  : tokens.borderDefault,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? color : tokens.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backend == RendererBackend.skia
                          ? 'Skia (Recommended)'
                          : 'Impeller',
                      style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      backend.description,
                      style: ZplayType.bodySmall.toStyle(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZplayRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: ZplayRadius.mdAll,
            border: Border.fromBorderSide(tokens.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: ZplayOpacity.borderStrong),
                  borderRadius: ZplayRadius.smAll,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: ZplayType.subtitle.toStyle(
                              color: tokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(
                              alpha: ZplayOpacity.overlayHover,
                            ),
                            borderRadius: ZplayRadius.xsAll,
                          ),
                          child: Text(
                            badgeText,
                            style: ZplayType.caption.toStyle(color: badgeColor),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: ZplayType.bodySmall.toStyle(
                        color: tokens.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: tokens.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ZplayRadius.mdAll,
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.borderSubtle,
              borderRadius: ZplayRadius.smAll,
            ),
            child: Icon(icon, color: tokens.textEmphasis, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ZplayType.label.toStyle(color: tokens.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
