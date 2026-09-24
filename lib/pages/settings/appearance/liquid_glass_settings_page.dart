import 'package:flutter/material.dart';
import '../../../services/theme/glass_settings.dart';
import '../../../services/theme/app_theme_service.dart';

class LiquidGlassSettingsPage extends StatefulWidget {
  const LiquidGlassSettingsPage({super.key});

  @override
  State<LiquidGlassSettingsPage> createState() => _LiquidGlassSettingsPageState();
}

class _LiquidGlassSettingsPageState extends State<LiquidGlassSettingsPage> {
  bool _previewHovered = false;

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
          'Liquid Glass Setup',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await GlassSettings.resetToDefaults();
              setState(() {});
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Liquid Glass settings reset to defaults.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                ),
              );
            },
            icon: const Icon(Icons.restore_rounded, size: 18, color: Colors.white70),
            label: const Text(
              'Reset',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Master Switch Card
              ValueListenableBuilder<bool>(
                valueListenable: GlassSettings.enabled,
                builder: (context, enabled, _) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12151E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: enabled
                            ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.blur_on_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Liquid Glass',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Real-time refraction shaders, jelly springs, and lenses',
                                style: TextStyle(color: Colors.white54, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: enabled,
                          activeColor: AppThemeService.currentPalette.value.primaryColor,
                          onChanged: (val) {
                            GlassSettings.setEnabled(val);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Interactive Live Sandbox Preview
              _buildLivePreviewCard(),

              const SizedBox(height: 24),

              // Presets Selection
              Text(
                'PRESETS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _buildPresetsRow(),

              const SizedBox(height: 24),

              // Detailed Sliders
              Text(
                'PHYSICS & OPTICAL PARAMETERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Hover Scale Impact
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.hoverScale,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Hover Scale Impact',
                    subtitle: 'Magnification amount when hovering or touching dock items',
                    valueDisplay: '${val.toStringAsFixed(2)}x',
                    value: val,
                    min: 0.95,
                    max: 1.40,
                    divisions: 45,
                    onChanged: (newVal) => GlassSettings.updateCustom(newHoverScale: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 2. Hover Proximity Radius
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.hoverProximity,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Proximity Radius',
                    subtitle: 'Distance threshold where cursor motion ripples to adjacent items',
                    valueDisplay: '${val.toStringAsFixed(1)}x',
                    value: val,
                    min: 1.2,
                    max: 4.0,
                    divisions: 28,
                    onChanged: (newVal) => GlassSettings.updateCustom(newHoverProximity: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 3. Wobble & Elasticity
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.wobbleIntensity,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Wobble & Fluid Elasticity',
                    subtitle: 'Spring bounce intensity and deformation responsiveness',
                    valueDisplay: '${val.toStringAsFixed(1)}x',
                    value: val,
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    onChanged: (newVal) => GlassSettings.updateCustom(newWobbleIntensity: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 4. Lens Refraction Index
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.refractionIndex,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Optical Refraction Index',
                    subtitle: 'Light bending and background warp index inside glass lenses',
                    valueDisplay: val.toStringAsFixed(2),
                    value: val,
                    min: 1.0,
                    max: 2.2,
                    divisions: 24,
                    onChanged: (newVal) => GlassSettings.updateCustom(newRefractionIndex: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 5. Magnification
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.magnification,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Lens Magnification',
                    subtitle: 'Underlying zoom factor seen through the glass volume',
                    valueDisplay: '${val.toStringAsFixed(3)}x',
                    value: val,
                    min: 1.00,
                    max: 1.12,
                    divisions: 24,
                    onChanged: (newVal) => GlassSettings.updateCustom(newMagnification: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 6. Chromatic Aberration (Prism RGB)
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.chromaticAberration,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Chromatic Aberration (Prism Split)',
                    subtitle: 'Separates RGB spectrum colors along optical glass bevels',
                    valueDisplay: val.toStringAsFixed(4),
                    value: val,
                    min: 0.000,
                    max: 0.008,
                    divisions: 32,
                    onChanged: (newVal) => GlassSettings.updateCustom(newChromaticAberration: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 7. Frosted Blur Sigma
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.blurSigma,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Frosted Glass Blur',
                    subtitle: 'Gaussian blur diffusion applied behind glass components',
                    valueDisplay: '${val.toStringAsFixed(1)} px',
                    value: val,
                    min: 0.0,
                    max: 10.0,
                    divisions: 20,
                    onChanged: (newVal) => GlassSettings.updateCustom(newBlurSigma: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 8. Light Intensity
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.lightIntensity,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Specular Light & Shimmer',
                    subtitle: 'Glossy specular reflection and border illumination intensity',
                    valueDisplay: val.toStringAsFixed(2),
                    value: val,
                    min: 0.5,
                    max: 2.5,
                    divisions: 20,
                    onChanged: (newVal) => GlassSettings.updateCustom(newLightIntensity: newVal),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 9. Border Width
              ValueListenableBuilder<double>(
                valueListenable: GlassSettings.borderWidth,
                builder: (context, val, _) {
                  return _buildSliderTile(
                    title: 'Border Width',
                    subtitle: 'Thickness of the refractive outer boundary edge',
                    valueDisplay: '${val.toStringAsFixed(1)} px',
                    value: val,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    onChanged: (newVal) => GlassSettings.updateCustom(newBorderWidth: newVal),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    return ValueListenableBuilder<int>(
      valueListenable: GlassSettings.styleRevision,
      builder: (context, _, __) {
        final enabled = GlassSettings.enabled.value;
        final hoverScaleVal = GlassSettings.hoverScale.value;
        final wobbleVal = GlassSettings.wobbleIntensity.value;

        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2E0854),
                Color(0xFF0F172A),
                Color(0xFF00384D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Background pattern circles
              Positioned(
                top: 20,
                left: 30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppThemeService.currentPalette.value.primaryColor, const Color(0xFFFF2A85)],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 40,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppThemeService.currentPalette.value.primaryColor, const Color(0xFF10B981)],
                    ),
                  ),
                ),
              ),

              // Sandbox Header
              Positioned(
                top: 12,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: enabled ? const Color(0xFF10B981) : Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            enabled ? 'LIVE INTERACTIVE PREVIEW' : 'PREVIEW (ENABLE GLASS ABOVE)',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive glass button & lens
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mock dock button 1
                    MouseRegion(
                      onEnter: (_) => setState(() => _previewHovered = true),
                      onExit: (_) => setState(() => _previewHovered = false),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: (190 / wobbleVal.clamp(0.5, 2.0)).round()),
                        curve: Curves.easeOutBack,
                        width: _previewHovered ? 56 * hoverScaleVal : 56,
                        height: _previewHovered ? 56 * hoverScaleVal : 56,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: GlassSettings.borderWidth.value,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Mock dock button 2
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: GlassSettings.borderWidth.value,
                        ),
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // Mock dock button 3
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: GlassSettings.borderWidth.value,
                        ),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF2A85), size: 24),
                    ),
                  ],
                ),
              ),

              // Helper instruction at bottom
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Hover or tap the icons to preview spring wobble & scale',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetsRow() {
    return ValueListenableBuilder<GlassPreset>(
      valueListenable: GlassSettings.preset,
      builder: (context, currentPreset, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GlassPreset.values.map((preset) {
            final isSelected = preset == currentPreset;
            return ChoiceChip(
              label: Text(preset.label),
              selected: isSelected,
              selectedColor: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.25),
              backgroundColor: const Color(0xFF12151E),
              labelStyle: TextStyle(
                color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white70,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12.5,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (selected) {
                if (selected && preset != GlassPreset.custom) {
                  GlassSettings.applyPreset(preset);
                  setState(() {});
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required String valueDisplay,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  valueDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppThemeService.currentPalette.value.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppThemeService.currentPalette.value.primaryColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: AppThemeService.currentPalette.value.primaryColor,
              overlayColor: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
