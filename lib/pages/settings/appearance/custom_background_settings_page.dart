import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../services/theme/custom_background_service.dart';
import '../../../widgets/common/animated_ambient_background.dart';

class CustomBackgroundSettingsPage extends StatefulWidget {
  const CustomBackgroundSettingsPage({super.key});

  @override
  State<CustomBackgroundSettingsPage> createState() => _CustomBackgroundSettingsPageState();
}

class _CustomBackgroundSettingsPageState extends State<CustomBackgroundSettingsPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : AppThemeService.currentPalette.value.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handlePickImage() async {
    setState(() => _isUploading = true);
    final success = await CustomBackgroundService.pickAndSetImage();
    setState(() => _isUploading = false);

    if (success) {
      _showSnack('Background image uploaded and applied across all UI!');
    }
  }

  Future<void> _handleApplyUrl() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      _showSnack('Please enter a valid HTTP or HTTPS image URL.', isError: true);
      return;
    }

    await CustomBackgroundService.setImageUrl(text);
    _urlController.clear();
    _showSnack('Custom background URL applied!');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<CustomBackgroundData>(
          valueListenable: CustomBackgroundService.notifier,
          builder: (context, customBg, _) {
            final hasWallpaper = customBg.hasCustomBackground;

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
                  'Custom Background & Wallpaper',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      // ── Header description ──
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Upload your own photo or choose a curated wallpaper. Theme colors and moving ambient lights softly blend into the background for a unified look.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.4,
                          ),
                        ),
                      ),

                      // ── 1. Live Interactive Preview Canvas ──
                      Container(
                        height: 200,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.primaryColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryColor.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: AnimatedAmbientBackground(),
                            ),
                            // Simulated UI Card overlay
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: palette.cardBackgroundColor.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: palette.primaryColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: palette.primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Live Atmosphere Preview',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            hasWallpaper
                                                ? 'Wallpaper active with ${palette.name} ambient lighting'
                                                : 'Default ${palette.name} theme background',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── 2. Action Buttons (Upload / Remove) ──
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _handlePickImage,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.add_photo_alternate_rounded, size: 20),
                              label: Text(
                                _isUploading ? 'Uploading...' : 'Upload Photo from Device',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          if (hasWallpaper) ...[
                            const SizedBox(width: 12),
                            IconButton.filledTonal(
                              tooltip: 'Reset to Default Background',
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.12),
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await CustomBackgroundService.clearBackground();
                                _showSnack('Background reset to default theme.');
                              },
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── URL Input Bar ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: Colors.white38, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Or paste image URL (https://...)',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 12.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _handleApplyUrl(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_paste_rounded, color: Colors.white54, size: 18),
                              tooltip: 'Paste from Clipboard',
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null) {
                                  _urlController.text = data!.text!.trim();
                                }
                              },
                            ),
                            TextButton(
                              onPressed: _handleApplyUrl,
                              child: Text(
                                'Apply',
                                style: TextStyle(
                                  color: palette.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── 3. Curated Wallpaper Presets ──
                      Text(
                        'CURATED DARK WALLPAPERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 460;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isNarrow ? 2 : 3,
                              childAspectRatio: isNarrow ? 1.55 : 1.45,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: CustomBackgroundService.presets.length,
                            itemBuilder: (context, index) {
                              final preset = CustomBackgroundService.presets[index];
                              final isSelected = customBg.imageUrl == preset.fullUrl;

                          return InkWell(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await CustomBackgroundService.applyPreset(preset);
                              _showSnack('Applied "${preset.title}" wallpaper');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(preset.previewUrl),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: palette.primaryColor.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.85),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: palette.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 6,
                                    left: 8,
                                    right: 8,
                                    child: Text(
                                      preset.title,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                    ),

                      const SizedBox(height: 28),

                      // ── 4. Atmosphere & Blending Controls ──
                      Text(
                        'WALLPAPER & LIGHT BLENDING CONTROLS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            // Opacity / Visibility Slider
                            _buildSliderTile(
                              icon: Icons.opacity_rounded,
                              title: 'Photo Visibility / Darkness',
                              valueText: '${(customBg.opacity * 100).round()}%',
                              value: customBg.opacity,
                              min: 0.10,
                              max: 1.0,
                              activeColor: palette.primaryColor,
                              onChanged: (v) => CustomBackgroundService.setOpacity(v),
                            ),
                            const Divider(color: Colors.white10, height: 24),

                            // Blur Slider
                            _buildSliderTile(
                              icon: Icons.blur_on_rounded,
                              title: 'Photo Soft Blur',
                              valueText: '${customBg.blur.toStringAsFixed(1)} px',
                              value: customBg.blur,
                              min: 0.0,
                              max: 24.0,
                              activeColor: palette.primaryColor,
                              onChanged: (v) => CustomBackgroundService.setBlur(v),
                            ),
                            const Divider(color: Colors.white10, height: 24),

                            // Theme Tint Slider
                            _buildSliderTile(
                              icon: Icons.color_lens_outlined,
                              title: 'Theme Color Tint Overlay',
                              valueText: '${(customBg.themeTintOpacity * 100).round()}%',
                              value: customBg.themeTintOpacity,
                              min: 0.0,
                              max: 0.80,
                              activeColor: palette.primaryColor,
                              onChanged: (v) => CustomBackgroundService.setThemeTintOpacity(v),
                            ),
                            const Divider(color: Colors.white10, height: 24),

                            // Moving Ambient Lights Switch
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeColor: palette.primaryColor,
                              title: const Text(
                                'Blend Moving Ambient Lights',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                'Softly illuminates and animates theme lights over your wallpaper',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              value: customBg.blendThemeLights,
                              onChanged: (v) => CustomBackgroundService.setBlendThemeLights(v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: activeColor,
            inactiveTrackColor: Colors.white12,
            thumbColor: activeColor,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
