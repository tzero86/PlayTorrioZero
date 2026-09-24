import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../services/audiobook/audiobook_settings.dart';
import '../../../services/home/home_page_settings.dart';
import '../../../widgets/audiobook/audiobook_interactive_physics_button.dart';
import '../../../widgets/audiobook/audiobook_waveform_seekbar.dart';
import '../../../widgets/common/animated_ambient_background.dart';
import '../../../widgets/common/focusable_card.dart';
import '../../../widgets/common/segmented_tabs.dart';
import 'audiobook_player_studio_page.dart';

class AudiobookSettingsPage extends StatefulWidget {
  const AudiobookSettingsPage({super.key});

  @override
  State<AudiobookSettingsPage> createState() => _AudiobookSettingsPageState();
}

class _AudiobookSettingsPageState extends State<AudiobookSettingsPage> {
  // Mock player states for live interactive studio preview
  bool _previewIsPlaying = false;
  Duration _previewPosition = const Duration(minutes: 14, seconds: 20);
  final Duration _previewDuration = const Duration(minutes: 42, seconds: 15);
  double _previewSpeed = 1.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;

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
          'Audiobook UI & Player Studio',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // ── 1. Color Themes & Accents ──
              _buildSectionHeader('COLOR THEMES & ACCENTS'),
              const SizedBox(height: 12),
              _buildThemesGrid(),

              const SizedBox(height: 28),

              // ── 2. Ambient Background Lighting ──
              _buildSectionHeader('AMBIENT BACKGROUND LIGHTING & MOVING GLOWS'),
              const SizedBox(height: 12),
              _buildAmbientLightsCard(palette),

              const SizedBox(height: 28),

              // ── 3. Discovery & Posters ──
              _buildSectionHeader('DISCOVERY & AUDIOBOOK POSTERS'),
              const SizedBox(height: 12),
              _buildDiscoveryConfigCard(palette),

              const SizedBox(height: 28),

              // ── Enter Visual Player Studio Banner ──
              _buildEnterPlayerStudioBanner(palette),

              const SizedBox(height: 28),

              // ── 4. Player Presets ──
              _buildSectionHeader('CHOOSE AUDIO PLAYER PRESET'),
              const SizedBox(height: 12),
              _buildPlayerPresetSelector(palette),

              const SizedBox(height: 28),

              // ── 5. Make Your Custom Player Studio ──
              _buildSectionHeader('MAKE YOUR CUSTOM AUDIOBOOK PLAYER (DRAG & DROP STUDIO)'),
              const SizedBox(height: 12),
              _buildCustomPlayerStudioCard(palette),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.35),
        letterSpacing: 1.1,
      ),
    );
  }

  // ── 1. Themes Grid ──
  Widget _buildThemesGrid() {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, current, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final int crossAxisCount = w < 400 ? 1 : (w < 700 ? 2 : 3);
            final double childAspectRatio = w < 400 ? 4.2 : 2.6;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: AppThemeService.palettes.length,
              itemBuilder: (context, index) {
                final palette = AppThemeService.palettes[index];
                final isSelected = palette.id == current.id;

                return InkWell(
                  onTap: () async {
                    await AppThemeService.setPalette(palette);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12151E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? palette.primaryColor
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [palette.primaryColor, palette.accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: palette.primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            palette.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── 2. Ambient Lighting Card ──
  Widget _buildAmbientLightsCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.enableAmbientLights,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Moving Ambient Atmosphere',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Soft flowing glowing orbs and aurora waves themed to ${palette.name}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setEnableAmbientLights(val),
              );
            },
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          Text(
            'Lighting Flow Pattern',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<AmbientLightPattern>(
            valueListenable: AudiobookSettings.ambientLightPattern,
            builder: (context, currentPattern, _) {
              return SegmentedTabs<AmbientLightPattern>(
                selected: currentPattern,
                onSelected: (p) {
                  AudiobookSettings.setAmbientLightPattern(p);
                },
                options: [
                  for (final p in AmbientLightPattern.values)
                    SegmentedTabOption(value: p, label: p.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Intensity Slider
          ValueListenableBuilder<double>(
            valueListenable: AudiobookSettings.ambientLightIntensity,
            builder: (context, intensity, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Glow Strength / Opacity', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${(intensity * 100).round()}%', style: TextStyle(color: palette.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: palette.primaryColor,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: palette.primaryColor,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: intensity,
                      min: 0.08,
                      max: 0.60,
                      divisions: 26,
                      onChanged: (val) => AudiobookSettings.setAmbientLightIntensity(val),
                    ),
                  ),
                ],
              );
            },
          ),

          // Speed Slider
          ValueListenableBuilder<double>(
            valueListenable: AudiobookSettings.ambientLightSpeed,
            builder: (context, speed, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Motion Drift Speed', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${speed.toStringAsFixed(1)}x', style: TextStyle(color: palette.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: palette.primaryColor,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: palette.primaryColor,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: speed,
                      min: 0.2,
                      max: 3.0,
                      divisions: 14,
                      onChanged: (val) => AudiobookSettings.setAmbientLightSpeed(val),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // Atmosphere Live Preview Box
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  const Positioned.fill(child: AnimatedAmbientBackground()),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones_rounded, color: palette.primaryColor, size: 14),
                          const SizedBox(width: 6),
                          const Text('Live Atmosphere Preview', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Discovery & Posters Config Card ──
  Widget _buildDiscoveryConfigCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.enableSpotlight,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Hero Spotlight Carousel', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Featured bestselling audiobook showcase at the top of the hub', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setEnableSpotlight(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showContinueListening,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show "Continue Listening" Carousel', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Quick resume cards with chapter progress bar and direct play', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowContinueListening(val),
              );
            },
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          Text('Audiobook Poster Card Density', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudiobookCardDensity>(
            valueListenable: AudiobookSettings.cardDensity,
            builder: (context, currentDensity, _) {
              return SegmentedTabs<AudiobookCardDensity>(
                selected: currentDensity,
                onSelected: (d) {
                  AudiobookSettings.setCardDensity(d);
                },
                options: [
                  for (final d in AudiobookCardDensity.values)
                    SegmentedTabOption(value: d, label: d.label),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showCategoryPills,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Quick Genre & Category Badges', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowCategoryPills(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showDurationBadge,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Audiobook Runtime / Total Duration', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowDurationBadge(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.cardHoverGlow,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Poster Card Hover Glow & Elevation', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setCardHoverGlow(val),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 4. Player Presets Selector ──
  Widget _buildPlayerPresetSelector(AppThemePalette palette) {
    return ValueListenableBuilder<AudiobookPlayerPreset>(
      valueListenable: AudiobookSettings.selectedPlayerPreset,
      builder: (context, selectedPreset, _) {
        return Column(
          children: AudiobookPlayerPreset.values.map((preset) {
            final isSelected = preset == selectedPreset;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? palette.primaryColor.withValues(alpha: 0.12) : const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => AudiobookSettings.setSelectedPlayerPreset(preset),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    preset == AudiobookPlayerPreset.modernGlass
                        ? Icons.blur_on_rounded
                        : preset == AudiobookPlayerPreset.vinylStudio
                            ? Icons.album_rounded
                            : preset == AudiobookPlayerPreset.minimalCapsule
                                ? Icons.view_compact_rounded
                                : preset == AudiobookPlayerPreset.immersiveCanvas
                                    ? Icons.fullscreen_rounded
                                    : Icons.dashboard_customize_rounded,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                ),
                title: Text(
                  preset.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Text(
                  preset.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (preset == AudiobookPlayerPreset.customStudio)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AudiobookPlayerStudioPage()),
                            );
                          },
                          icon: Icon(Icons.tune_rounded, size: 14, color: palette.primaryColor),
                          label: Text(
                            'Open Studio',
                            style: TextStyle(color: palette.primaryColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 22),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Enter Visual Player Studio Banner ──
  Widget _buildEnterPlayerStudioBanner(AppThemePalette palette) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            palette.primaryColor.withValues(alpha: 0.28),
            palette.accentColor.withValues(alpha: 0.15),
            const Color(0xFF10131E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [palette.primaryColor, palette.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Visual Custom Player Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.primaryColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'FULL STUDIO',
                          style: TextStyle(color: palette.primaryColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Drag & drop layout elements, procedural waveform canvases, liquid glass buttons, and premade chapters panel in real-time.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AudiobookPlayerStudioPage()),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Enter Custom Player Studio',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      elevation: 4,
                      shadowColor: palette.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Make Your Custom Player Studio ──
  Widget _buildCustomPlayerStudioCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Interactive Player Studio Preview Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF090B10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.primaryColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: palette.primaryColor.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_fix_high_rounded, color: palette.primaryColor, size: 16),
                        const SizedBox(width: 6),
                        const Text('Interactive Studio Preview', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(color: palette.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Artwork Preview
                ValueListenableBuilder<AudiobookArtworkStyle>(
                  valueListenable: AudiobookSettings.customArtworkStyle,
                  builder: (context, artStyle, _) {
                    if (artStyle == AudiobookArtworkStyle.hidden) {
                      return const SizedBox.shrink();
                    }
                    if (artStyle == AudiobookArtworkStyle.vinylDisc) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(color: Colors.white24, width: 3),
                          boxShadow: [
                            BoxShadow(color: palette.primaryColor.withValues(alpha: 0.35), blurRadius: 16),
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.graphic_eq_rounded, color: palette.primaryColor, size: 36),
                        ),
                      );
                    }
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [palette.primaryColor, palette.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: palette.primaryColor.withValues(alpha: 0.4), blurRadius: 16),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.headphones_rounded, color: Colors.white, size: 36),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Text(
                  'The Way of Kings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Brandon Sanderson • Chapter 1: Stormblessed',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),

                const SizedBox(height: 14),

                // Live Seekbar Canvas
                ValueListenableBuilder<AudiobookSeekbarStyle>(
                  valueListenable: AudiobookSettings.customSeekbarStyle,
                  builder: (context, seekStyle, _) {
                    return AudiobookWaveformSeekbar(
                      position: _previewPosition,
                      duration: _previewDuration,
                      isPlaying: _previewIsPlaying,
                      style: seekStyle,
                      onSeek: (pos) => setState(() => _previewPosition = pos),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Live Action Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rewind 10s
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 24),
                      onPressed: () {
                        setState(() {
                          final p = _previewPosition - const Duration(seconds: 10);
                          _previewPosition = p < Duration.zero ? Duration.zero : p;
                        });
                      },
                    ),
                    const SizedBox(width: 12),

                    // Custom Styled Play/Pause Button
                    ValueListenableBuilder<AudiobookPlayButtonStyle>(
                      valueListenable: AudiobookSettings.customPlayButtonStyle,
                      builder: (context, playBtnStyle, _) {
                        return FocusableCard(
                          onTap: () => setState(() => _previewIsPlaying = !_previewIsPlaying),
                          builder: (_, state) => _buildCustomPlayButtonWidget(playBtnStyle, palette, _previewIsPlaying),
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    // Forward 10s
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 24),
                      onPressed: () {
                        setState(() {
                          final p = _previewPosition + const Duration(seconds: 10);
                          _previewPosition = p > _previewDuration ? _previewDuration : p;
                        });
                      },
                    ),

                    const SizedBox(width: 16),

                    // Speed Pill
                    InkWell(
                      onTap: () {
                        setState(() {
                          _previewSpeed = _previewSpeed >= 2.0 ? 1.0 : _previewSpeed + 0.25;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '${_previewSpeed.toStringAsFixed(2)}x',
                          style: TextStyle(color: palette.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Customize Seek Bar Style ──
          Text('Seek Bar / Scrubber Style', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudiobookSeekbarStyle>(
            valueListenable: AudiobookSettings.customSeekbarStyle,
            builder: (context, currentStyle, _) {
              return SegmentedTabs<AudiobookSeekbarStyle>(
                selected: currentStyle,
                onSelected: (s) {
                  AudiobookSettings.setCustomSeekbarStyle(s);
                },
                options: [
                  for (final s in AudiobookSeekbarStyle.values)
                    SegmentedTabOption(value: s, label: s.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Customize Play / Pause Button Style ──
          Text('Play / Pause Button Styling', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudiobookPlayButtonStyle>(
            valueListenable: AudiobookSettings.customPlayButtonStyle,
            builder: (context, currentStyle, _) {
              return SegmentedTabs<AudiobookPlayButtonStyle>(
                selected: currentStyle,
                onSelected: (s) {
                  AudiobookSettings.setCustomPlayButtonStyle(s);
                },
                options: [
                  for (final s in AudiobookPlayButtonStyle.values)
                    SegmentedTabOption(value: s, label: s.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Customize Artwork Display ──
          Text('Artwork Display Style', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudiobookArtworkStyle>(
            valueListenable: AudiobookSettings.customArtworkStyle,
            builder: (context, currentStyle, _) {
              return SegmentedTabs<AudiobookArtworkStyle>(
                selected: currentStyle,
                onSelected: (s) {
                  AudiobookSettings.setCustomArtworkStyle(s);
                },
                options: [
                  for (final s in AudiobookArtworkStyle.values)
                    SegmentedTabOption(value: s, label: s.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Hover & Touch Physics ──
          Text('Button Hover & Touch Physics', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<AudiobookHoverEffect>(
            valueListenable: AudiobookSettings.customHoverEffect,
            builder: (context, currentEffect, _) {
              return SegmentedTabs<AudiobookHoverEffect>(
                selected: currentEffect,
                onSelected: (e) {
                  AudiobookSettings.setCustomHoverEffect(e);
                },
                options: [
                  for (final e in AudiobookHoverEffect.values)
                    SegmentedTabOption(value: e, label: e.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // ── Drag & Drop Component Arranger ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Player Layout Components (Drag to Arrange)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.drag_indicator_rounded, color: palette.primaryColor, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hold and drag any block to reorder how controls appear inside your player',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 10),

          ValueListenableBuilder<List<String>>(
            valueListenable: AudiobookSettings.componentOrder,
            builder: (context, order, _) {
              return ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  final list = List<String>.from(order);
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);
                  AudiobookSettings.setComponentOrder(list);
                },
                children: order.map((key) {
                  final label = _getComponentLabel(key);
                  final icon = _getComponentIcon(key);
                  return Container(
                    key: ValueKey(key),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0F17),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(icon, color: palette.primaryColor, size: 18),
                      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 18),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 14),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.enableLiquidGlass,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Liquid Glass Player Blur & Refraction', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setEnableLiquidGlass(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showSpeedControl,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Playback Speed Selector (0.5x - 2.5x)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowSpeedControl(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showSkip10Buttons,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Skip Forward/Rewind Buttons (±10s)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowSkip10Buttons(val),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: AudiobookSettings.showChaptersQuickButton,
            builder: (context, show, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Quick Chapters Sliding Drawer Button', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                value: show,
                activeColor: palette.primaryColor,
                onChanged: (val) => AudiobookSettings.setShowChaptersQuickButton(val),
              );
            },
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AudiobookPlayerStudioPage()),
                );
              },
              icon: const Icon(Icons.dashboard_customize_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Launch Full Custom Player Studio',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPlayButtonWidget(AudiobookPlayButtonStyle style, AppThemePalette palette, bool isPlaying) {
    final icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final hoverEffect = AudiobookSettings.customHoverEffect.value;

    Widget buttonCore;
    BorderRadius borderRadius;

    if (style == AudiobookPlayButtonStyle.liquidGlassNeo) {
      borderRadius = BorderRadius.circular(18);
      final glassStyle = LiquidGlassStyle(
        shape: const LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: 18,
          clipQuality: LiquidGlassClipQuality.exact,
          borderWidth: 1.5,
          lightIntensity: 1.4,
          lightColor: Color(0xE6FFFFFF),
          lightDirection: 115,
          borderType: OpticalBorder(
            borderSaturation: 1.5,
            ambientIntensity: 1.15,
            borderSolidity: 0.18,
            lightSpread: 0.7,
          ),
        ),
        appearance: LiquidGlassAppearance(
          color: palette.primaryColor.withValues(alpha: 0.15),
          saturation: 1.2,
          blur: const LiquidGlassBlur(sigmaX: 3.0, sigmaY: 3.0),
          shadow: LiquidGlassShadow(
            blur: 14,
            opacity: 0.35,
            color: palette.primaryColor,
          ),
        ),
        refraction: const LiquidGlassRefraction(
          magnification: 1.035,
          chromaticAberration: 0.003,
          refractionType: OpticalRefraction(
            refraction: 1.54,
            refractionWidth: 20,
            depth: 0.75,
          ),
        ),
      );

      buttonCore = LiquidGlassLens(
        style: glassStyle,
        visibility: true,
        useImpellerBackdrop: true,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      );
    } else if (style == AudiobookPlayButtonStyle.roundedSquare) {
      borderRadius = BorderRadius.circular(14);
      buttonCore = Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: palette.primaryColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      );
    } else if (style == AudiobookPlayButtonStyle.accentPill) {
      borderRadius = BorderRadius.circular(24);
      buttonCore = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: palette.primaryColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(
              isPlaying ? 'PAUSE' : 'PLAY',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
            ),
          ],
        ),
      );
    } else {
      borderRadius = BorderRadius.circular(28);
      buttonCore = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.primaryColor,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      );
    }

    return AudiobookInteractivePhysicsButton(
      effect: hoverEffect,
      glowColor: palette.primaryColor,
      borderRadius: borderRadius,
      child: buttonCore,
    );
  }

  String _getComponentLabel(String key) {
    switch (key) {
      case 'artwork':
        return 'Audiobook Cover Artwork Deck';
      case 'title':
        return 'Title, Author & Chapter Label';
      case 'seekbar':
        return 'Seek Bar & Waveform Canvas Scrubber';
      case 'mainControls':
        return 'Main Play / Pause / Skip (±10s) Cluster';
      case 'secondaryControls':
        return 'Speed Selector & Volume Controls';
      case 'chaptersButton':
        return 'Premade Sliding Chapters Panel Trigger';
      default:
        return key;
    }
  }

  IconData _getComponentIcon(String key) {
    switch (key) {
      case 'artwork':
        return Icons.image_rounded;
      case 'title':
        return Icons.title_rounded;
      case 'seekbar':
        return Icons.graphic_eq_rounded;
      case 'mainControls':
        return Icons.play_circle_filled_rounded;
      case 'secondaryControls':
        return Icons.speed_rounded;
      case 'chaptersButton':
        return Icons.format_list_bulleted_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }
}
