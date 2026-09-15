import 'dart:io';

import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/theme/custom_background_service.dart';
import '../../services/theme/dock_settings.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/manga/manga_settings.dart';
import '../../services/music/music_settings.dart';
import '../../services/diagnostics/renderer_backend.dart';
import 'appearance/audiobook_settings_page.dart';
import 'appearance/custom_background_settings_page.dart';
import 'appearance/dock_settings_page.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Appearance & Interface',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
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
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
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
                        iconColor: currentPalette.primaryColor,
                        title: 'Custom Background & Wallpaper',
                        subtitle: 'Upload custom photos, choose curated dark wallpapers, and blend theme ambient lighting',
                        badgeText: customBg.hasCustomBackground ? 'Custom Active' : 'Default Theme',
                        badgeColor: customBg.hasCustomBackground ? currentPalette.primaryColor : Colors.white38,
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
                        iconColor: const Color(0xFF7C5CFF),
                        title: 'Liquid Glass Setup',
                        subtitle: 'Adjust hover impact, wobble spring physics, lens refraction, and chromatic aberration',
                        badgeText: glassEnabled ? preset.label : 'Disabled',
                        badgeColor: glassEnabled ? const Color(0xFF7C5CFF) : Colors.white38,
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

              // Button 2: Liquid Dock / Navbar Items
              ValueListenableBuilder<Map<String, bool>>(
                valueListenable: DockSettings.enabledNotifier,
                builder: (context, enabledMap, _) {
                  final activeCount = enabledMap.values.where((v) => v).length;
                  return _buildSectionButton(
                    icon: Icons.dock_rounded,
                    iconColor: const Color(0xFF7C5CFF),
                    title: 'Liquid Dock / Deck Navbar',
                    subtitle: 'Choose which navigation shortcuts appear in the bottom liquid glass dock across all screens',
                    badgeText: '$activeCount / ${DockItemKey.values.length} Items',
                    badgeColor: const Color(0xFF7C5CFF),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DockSettingsPage(),
                        ),
                      );
                      setState(() {});
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
                    iconColor: currentPalette.primaryColor,
                    title: 'Home Page UI & Themes',
                    subtitle: 'Color schemes, "Because you have on your list" smart slider, hero spotlight, and card density',
                    badgeText: currentPalette.name,
                    badgeColor: currentPalette.primaryColor,
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
                        iconColor: currentPalette.primaryColor,
                        title: 'Live TV & Sports UI',
                        subtitle: 'Broadcast hero spotlight, channel card density, category ordering, and live badge styling',
                        badgeText: spotlightEnabled ? 'Spotlight ON' : 'Compact',
                        badgeColor: currentPalette.primaryColor,
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
                        iconColor: currentPalette.primaryColor,
                        title: 'Manga UI & Reader Atmosphere',
                        subtitle: 'Ambient moving lighting, card density, reading layout widths, webtoon/horizontal modes, and page deck preview',
                        badgeText: readingMode == MangaReadingMode.webtoon ? 'Webtoon' : 'Horizontal',
                        badgeColor: currentPalette.primaryColor,
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
                        iconColor: currentPalette.primaryColor,
                        title: 'Audiobook UI & Player Studio',
                        subtitle: 'Hero spotlight, 5 distinct player designs, drag & drop modular studio, waveform canvas scrubber, and custom controls',
                        badgeText: playerPreset.label.split(' ').first,
                        badgeColor: currentPalette.primaryColor,
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
                        iconColor: currentPalette.primaryColor,
                        title: 'Music UI & Player Studio',
                        subtitle: 'Hero spotlight, lossless badges, dual-engine customizer for both mini dock bar and fullscreen turntable/equalizer',
                        badgeText: fullPreset.label.split(' ').first,
                        badgeColor: currentPalette.primaryColor,
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              _buildScopeTile(
                icon: Icons.dock_rounded,
                title: 'Bottom Liquid Dock',
                description: 'Dock items react dynamically with your custom hover magnification, proximity ripples, and wobble springs.',
              ),
              const SizedBox(height: 10),
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
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
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.speed_rounded,
                      color: Color(0xFF00E5FF),
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
                            const Expanded(
                              child: Text(
                                'Graphics Backend',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                backend.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Skia is recommended on Windows here — '
                          'Impeller coincided with an NVIDIA driver crash.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1.25,
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
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Restart the app to apply — the backend is fixed when the engine starts.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.4),
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
    final color = backend == RendererBackend.skia
        ? const Color(0xFF00E5FF)
        : const Color(0xFF7C5CFF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => RendererBackendSettings.setBackend(backend),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? color : Colors.white38,
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
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      backend.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.3,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.25,
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
                color: Colors.white.withValues(alpha: 0.3),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
