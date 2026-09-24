import 'package:flutter/material.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../services/home/home_page_settings.dart';
import '../../../services/music/music_settings.dart';
import '../../../widgets/common/segmented_tabs.dart';
import '../../../widgets/music/music_waveform_seekbar.dart';
import 'music_player_studio_page.dart';

class MusicSettingsPage extends StatefulWidget {
  const MusicSettingsPage({super.key});

  @override
  State<MusicSettingsPage> createState() => _MusicSettingsPageState();
}

class _MusicSettingsPageState extends State<MusicSettingsPage> {
  final bool _previewIsPlaying = false;
  Duration _previewPos = const Duration(minutes: 1, seconds: 20);

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
          'Music UI & Player Atmosphere',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Enter Music Player Studio Banner
              _buildEnterPlayerStudioBanner(palette),
              const SizedBox(height: 28),

              // 2. Visual Theme Palette
              _buildSectionHeader('VISUAL THEME PALETTE'),
              const SizedBox(height: 12),
              _buildThemesGrid(),
              const SizedBox(height: 28),

              // 3. Ambient Moving Background Lights
              _buildSectionHeader('AMBIENT ATMOSPHERE & GLOW'),
              const SizedBox(height: 12),
              _buildAmbientLightsCard(palette),
              const SizedBox(height: 28),

              // 4. Discovery & Layout Settings
              _buildSectionHeader('DISCOVERY & CATALOG CONFIGURATION'),
              const SizedBox(height: 12),
              _buildDiscoveryConfigCard(palette),
              const SizedBox(height: 28),

              // 5. Mini Player Bar Presets
              _buildSectionHeader('MINI PLAYER BAR PRESETS'),
              const SizedBox(height: 12),
              _buildMiniPlayerPresetSelector(palette),
              const SizedBox(height: 28),

              // 6. Fullscreen Player Presets
              _buildSectionHeader('FULLSCREEN PLAYER PRESETS'),
              const SizedBox(height: 12),
              _buildFullscreenPlayerPresetSelector(palette),
              const SizedBox(height: 28),

              // 7. Custom Player Quick Customizer
              _buildSectionHeader('CUSTOM PLAYER ENGINE DESIGNER'),
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

  Widget _buildThemesGrid() {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, currentPalette, _) {
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
                final theme = AppThemeService.palettes[index];
                final isSelected = theme.name == currentPalette.name;

                return InkWell(
                  onTap: () {
                    AppThemeService.setPalette(theme);
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
                            ? currentPalette.primaryColor
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [theme.primaryColor, theme.accentColor],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            theme.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
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
            valueListenable: MusicSettings.enableAmbientLights,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Moving Background Ambient Lighting',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Dynamic moving glowing orbs reacting with your theme accent colors',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => MusicSettings.setEnableAmbientLights(val),
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),

          Text(
            'Ambient Light Pattern',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<AmbientLightPattern>(
            valueListenable: MusicSettings.ambientLightPattern,
            builder: (context, currentPattern, _) {
              return SegmentedTabs<AmbientLightPattern>(
                selected: currentPattern,
                onSelected: (p) {
                  MusicSettings.setAmbientLightPattern(p);
                },
                options: [
                  for (final p in AmbientLightPattern.values)
                    SegmentedTabOption(value: p, label: p.label),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: MusicSettings.ambientLightIntensity,
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
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: intensity,
                      min: 0.05,
                      max: 0.6,
                      onChanged: (v) => MusicSettings.setAmbientLightIntensity(v),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

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
            valueListenable: MusicSettings.enableSpotlight,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Hero Spotlight Showcase', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Featured bestselling album & track showcase at the top of the music page', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => MusicSettings.setEnableSpotlight(val),
              );
            },
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          ValueListenableBuilder<bool>(
            valueListenable: MusicSettings.showLosslessBadge,
            builder: (context, enabled, _) {
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Lossless Hi-Res Audio Badges', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Displays FLAC / Hi-Res lossless stream indicators on music cards and player', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: enabled,
                activeColor: palette.primaryColor,
                onChanged: (val) => MusicSettings.setShowLosslessBadge(val),
              );
            },
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 8),
          Text('Music Card & Grid Density', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ValueListenableBuilder<MusicCardDensity>(
            valueListenable: MusicSettings.cardDensity,
            builder: (context, density, _) {
              return SegmentedTabs<MusicCardDensity>(
                selected: density,
                onSelected: (d) {
                  MusicSettings.setCardDensity(d);
                },
                options: [
                  for (final d in MusicCardDensity.values)
                    SegmentedTabOption(value: d, label: d.label),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayerPresetSelector(AppThemePalette palette) {
    return ValueListenableBuilder<MusicMiniPlayerPreset>(
      valueListenable: MusicSettings.selectedMiniPreset,
      builder: (context, selectedPreset, _) {
        return Column(
          children: MusicMiniPlayerPreset.values.map((preset) {
            final isSelected = selectedPreset == preset;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? palette.primaryColor.withValues(alpha: 0.12) : const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: ListTile(
                onTap: () => MusicSettings.setSelectedMiniPreset(preset),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    preset == MusicMiniPlayerPreset.floatingGlassIsland
                        ? Icons.blur_on_rounded
                        : preset == MusicMiniPlayerPreset.compactPill
                            ? Icons.crop_portrait_rounded
                            : preset == MusicMiniPlayerPreset.gradientWave
                                ? Icons.graphic_eq_rounded
                                : preset == MusicMiniPlayerPreset.minimalistLine
                                    ? Icons.linear_scale_rounded
                                    : Icons.dashboard_customize_rounded,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  preset.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  preset.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 22)
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFullscreenPlayerPresetSelector(AppThemePalette palette) {
    return ValueListenableBuilder<MusicFullscreenPreset>(
      valueListenable: MusicSettings.selectedFullscreenPreset,
      builder: (context, selectedPreset, _) {
        return Column(
          children: MusicFullscreenPreset.values.map((preset) {
            final isSelected = selectedPreset == preset;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? palette.primaryColor.withValues(alpha: 0.12) : const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: ListTile(
                onTap: () => MusicSettings.setSelectedFullscreenPreset(preset),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    preset == MusicFullscreenPreset.vinylStudio
                        ? Icons.album_rounded
                        : preset == MusicFullscreenPreset.cyberWaveform
                            ? Icons.graphic_eq_rounded
                            : preset == MusicFullscreenPreset.liquidGlassNeo
                                ? Icons.blur_on_rounded
                                : preset == MusicFullscreenPreset.cinematicArtwork
                                    ? Icons.fullscreen_rounded
                                    : Icons.dashboard_customize_rounded,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  preset.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  preset.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 22)
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEnterPlayerStudioBanner(AppThemePalette palette) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            palette.primaryColor.withValues(alpha: 0.3),
            const Color(0xFF10131E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.25),
            blurRadius: 28,
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
                        'Custom Music Player Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.primaryColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DUAL ENGINE',
                          style: TextStyle(color: palette.primaryColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Customize BOTH Mini Player Dock and Fullscreen Player. Drag & drop blocks, waveform equalizers, vinyl turntable & liquid glass buttons.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MusicPlayerStudioPage()),
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
          // Quick Customizer Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Waveform & Controls Preview', style: TextStyle(color: palette.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MusicPlayerStudioPage()),
                  );
                },
                child: const Text('Open Full Studio ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mini preview bar
          MusicWaveformSeekbar(
            position: _previewPos,
            duration: const Duration(minutes: 3, seconds: 30),
            isPlaying: _previewIsPlaying,
            style: MusicSettings.customSeekbarStyle.value,
            onSeek: (p) => setState(() => _previewPos = p),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MusicPlayerStudioPage()),
              );
            },
            icon: const Icon(Icons.dashboard_customize_rounded, size: 18, color: Colors.white),
            label: const Text('Launch Full Custom Player Studio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}
