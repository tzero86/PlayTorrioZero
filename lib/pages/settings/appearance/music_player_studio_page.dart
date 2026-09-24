import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../../services/theme/app_theme_service.dart';
import '../../../services/music/music_settings.dart';
import '../../../widgets/common/segmented_tabs.dart';
import '../../../widgets/music/music_interactive_physics_button.dart';
import '../../../widgets/music/music_waveform_seekbar.dart';

class MusicPlayerStudioPage extends StatefulWidget {
  const MusicPlayerStudioPage({super.key});

  @override
  State<MusicPlayerStudioPage> createState() => _MusicPlayerStudioPageState();
}

class _MusicPlayerStudioPageState extends State<MusicPlayerStudioPage> with SingleTickerProviderStateMixin {
  // Studio Player Mode: 0 = Fullscreen Player Studio, 1 = Mini Player Studio
  int _studioPlayerTarget = 0;

  // Live Studio Preview State
  bool _previewIsPlaying = true;
  Duration _previewPosition = const Duration(minutes: 1, seconds: 48);
  final Duration _previewDuration = const Duration(minutes: 3, seconds: 52);
  double _previewVolume = 0.85;
  bool _previewIsLiked = true;
  bool _showLyricsPreview = false;
  bool _showQueuePreview = false;

  late AnimationController _discController;
  int _selectedStudioTab = 0; // 0: Drag & Drop Arranger, 1: Seekbar Canvas, 2: Buttons & Physics, 3: Artwork & Turntable
  int _mobileViewMode = 0; // 0: Studio Designer, 1: Live Interactive Canvas

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    MusicSettings.changeNotifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MusicSettings.changeNotifier.removeListener(_onSettingsChanged);
    _discController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _previewIsPlaying = !_previewIsPlaying;
      if (_previewIsPlaying) {
        _discController.repeat();
      } else {
        _discController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final screenW = MediaQuery.sizeOf(context).width;
    final isDesktop = screenW >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: screenW < 600
            ? const Text(
                'Music Player Studio',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [palette.primaryColor, palette.accentColor],
                      ),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Custom Music Player Studio',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Design mini & fullscreen players, drag components, customize physics & liquid glass',
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.normal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          // Target Switcher Pill (Fullscreen vs Mini Player)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141724),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _studioPlayerTarget = 0),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _studioPlayerTarget == 0 ? palette.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_rounded, size: 14, color: _studioPlayerTarget == 0 ? Colors.white : Colors.white60),
                        if (screenW >= 480) ...[
                          const SizedBox(width: 4),
                          Text('Fullscreen', style: TextStyle(color: _studioPlayerTarget == 0 ? Colors.white : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _studioPlayerTarget = 1),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _studioPlayerTarget == 1 ? palette.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dock_rounded, size: 14, color: _studioPlayerTarget == 1 ? Colors.white : Colors.white60),
                        if (screenW >= 480) ...[
                          const SizedBox(width: 4),
                          Text('Mini Bar', style: TextStyle(color: _studioPlayerTarget == 1 ? Colors.white : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          if (screenW < 520)
            IconButton(
              tooltip: 'Apply As Active Player',
              onPressed: _applyAsActivePlayer,
              icon: Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 24),
            )
          else
            TextButton.icon(
              onPressed: _applyAsActivePlayer,
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              label: const Text('Apply Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: TextButton.styleFrom(
                backgroundColor: palette.primaryColor.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                // Left Panel: Interactive Live Player Canvas Preview
                Expanded(
                  flex: 5,
                  child: _buildLivePlayerCanvas(palette, isDesktop: true),
                ),
                VerticalDivider(width: 1, color: Colors.white.withValues(alpha: 0.08)),
                // Right Panel: Customizer Studio Controls
                Expanded(
                  flex: 6,
                  child: _buildStudioControlsPanel(palette),
                ),
              ],
            )
          : Column(
              children: [
                // Mobile Mode Switcher Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0F17),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mobileViewMode = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _mobileViewMode == 0 ? palette.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _mobileViewMode == 0 ? palette.primaryColor : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 15,
                                  color: _mobileViewMode == 0 ? palette.primaryColor : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Studio Designer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _mobileViewMode == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _mobileViewMode == 0 ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mobileViewMode = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _mobileViewMode == 1 ? palette.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _mobileViewMode == 1 ? palette.primaryColor : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 15,
                                  color: _mobileViewMode == 1 ? palette.primaryColor : Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Live Preview Canvas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _mobileViewMode == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _mobileViewMode == 1 ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mobile View Content
                Expanded(
                  child: _mobileViewMode == 0
                      ? Stack(
                          children: [
                            _buildStudioControlsPanel(palette),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton.extended(
                                onPressed: () => setState(() => _mobileViewMode = 1),
                                backgroundColor: palette.primaryColor,
                                icon: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                                label: const Text(
                                  'Test Live Canvas',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            _buildLivePlayerCanvas(palette, isDesktop: false),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: FloatingActionButton.extended(
                                onPressed: () => setState(() => _mobileViewMode = 0),
                                backgroundColor: const Color(0xFF161A28),
                                icon: Icon(Icons.arrow_back_rounded, color: palette.primaryColor, size: 18),
                                label: const Text(
                                  'Back to Customizer',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  void _applyAsActivePlayer() {
    final palette = AppThemeService.currentPalette.value;
    if (_studioPlayerTarget == 0) {
      MusicSettings.setSelectedFullscreenPreset(MusicFullscreenPreset.customStudio);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom Fullscreen Player Studio layout set as active player!'),
          backgroundColor: palette.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      MusicSettings.setSelectedMiniPreset(MusicMiniPlayerPreset.customStudio);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom Mini Player Studio layout set as active bottom bar!'),
          backgroundColor: palette.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ── LEFT: INTERACTIVE LIVE PLAYER CANVAS PREVIEW ──
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLivePlayerCanvas(AppThemePalette palette, {bool isDesktop = true}) {
    return Container(
      color: const Color(0xFF06080D),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient light orb
          Positioned(
            top: 40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primaryColor.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.expand(),
            ),
          ),

          // Player Container Sandbox (Fullscreen vs Mini)
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _studioPlayerTarget == 0
                    ? _buildFullscreenPlayerCard(palette, isDesktop)
                    : _buildMiniPlayerCard(palette, isDesktop),
              ),
            ),
          ),

          // Synced Lyrics Preview Overlay
          if (_showLyricsPreview)
            Positioned.fill(
              child: _buildLyricsPreviewOverlay(palette),
            ),

          // Queue Preview Overlay
          if (_showQueuePreview)
            Positioned.fill(
              child: _buildQueuePreviewOverlay(palette),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenPlayerCard(AppThemePalette palette, bool isDesktop) {
    final order = MusicSettings.componentOrderFullscreen.value;
    final seekStyle = MusicSettings.customSeekbarStyle.value;
    final artStyle = MusicSettings.customArtworkStyle.value;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.2),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note_rounded, color: palette.primaryColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'FULLSCREEN LIVE STUDIO',
                      style: TextStyle(color: palette.primaryColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _previewIsLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _previewIsLiked ? const Color(0xFFFF4B72) : Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _previewIsLiked = !_previewIsLiked),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_quote_rounded, color: _showLyricsPreview ? palette.primaryColor : Colors.white70, size: 20),
                    onPressed: () => setState(() => _showLyricsPreview = !_showLyricsPreview),
                  ),
                  IconButton(
                    icon: Icon(Icons.queue_music_rounded, color: _showQueuePreview ? palette.primaryColor : Colors.white70, size: 20),
                    onPressed: () => setState(() => _showQueuePreview = !_showQueuePreview),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dynamic Components Rendered according to Drag & Drop Order
          ...order.map((key) => _buildFullscreenPreviewComponent(key, palette, seekStyle, artStyle)),
        ],
      ),
    );
  }

  Widget _buildFullscreenPreviewComponent(
    String key,
    AppThemePalette palette,
    MusicSeekbarStyle seekStyle,
    MusicArtworkStyle artStyle,
  ) {
    switch (key) {
      case 'artwork':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPreviewArtwork(palette, artStyle),
        );

      case 'title':
        return const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              Text(
                'Starboy (feat. Daft Punk)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'The Weeknd • Starboy (Deluxe)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 'qualityBadge':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00D2EF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00D2EF).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_rounded, size: 12, color: Color(0xFF00D2EF)),
                SizedBox(width: 4),
                Text(
                  'FLAC 24-BIT / 96KHZ LOSSLESS',
                  style: TextStyle(color: Color(0xFF00D2EF), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        );

      case 'seekbar':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MusicWaveformSeekbar(
            position: _previewPosition,
            duration: _previewDuration,
            isPlaying: _previewIsPlaying,
            style: seekStyle,
            onSeek: (pos) => setState(() => _previewPosition = pos),
          ),
        );

      case 'mainControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCanvasIconButton(Icons.shuffle_rounded, 22, palette, () {}),
              _buildCanvasIconButton(Icons.skip_previous_rounded, 28, palette, () {}),
              _buildCustomPlayPauseButton(palette),
              _buildCanvasIconButton(Icons.skip_next_rounded, 28, palette, () {}),
              _buildCanvasIconButton(Icons.repeat_rounded, 22, palette, () {}),
            ],
          ),
        );

      case 'secondaryControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.volume_down_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    activeTrackColor: palette.primaryColor,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _previewVolume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => setState(() => _previewVolume = v),
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ],
          ),
        );

      case 'extraActions':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _showLyricsPreview = true),
                icon: Icon(Icons.format_quote_rounded, color: palette.primaryColor, size: 15),
                label: const Text('Synced Lyrics', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showQueuePreview = true),
                icon: Icon(Icons.queue_music_rounded, color: palette.primaryColor, size: 15),
                label: const Text('Playing Queue', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMiniPlayerCard(AppThemePalette palette, bool isDesktop) {
    final order = MusicSettings.componentOrderMini.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: palette.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dock_rounded, color: palette.primaryColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  'MINI PLAYER DOCK PREVIEW',
                  style: TextStyle(color: palette.primaryColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Row(
            children: order.map((key) => _buildMiniPreviewComponent(key, palette)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPreviewComponent(String key, AppThemePalette palette) {
    switch (key) {
      case 'artwork':
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF181C2E),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: palette.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
          ),
        );

      case 'trackInfo':
        return const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Starboy (feat. Daft Punk)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                'The Weeknd • Lossless',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 'mainControls':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCanvasIconButton(Icons.skip_previous_rounded, 20, palette, () {}),
            const SizedBox(width: 4),
            _buildCustomPlayPauseButton(palette, mini: true),
            const SizedBox(width: 4),
            _buildCanvasIconButton(Icons.skip_next_rounded, 20, palette, () {}),
          ],
        );

      case 'extraActions':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _previewIsLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _previewIsLiked ? const Color(0xFFFF4B72) : Colors.white60,
                size: 18,
              ),
              onPressed: () => setState(() => _previewIsLiked = !_previewIsLiked),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPreviewArtwork(AppThemePalette palette, MusicArtworkStyle artStyle) {
    if (artStyle == MusicArtworkStyle.vinylSpinningDisc) {
      return AnimatedBuilder(
        animation: _discController,
        builder: (context, child) => Transform.rotate(
          angle: _previewIsPlaying ? _discController.value * 2 * pi : 0,
          child: child,
        ),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10131E),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 3.5),
            boxShadow: [
              BoxShadow(
                color: palette.primaryColor.withValues(alpha: 0.4),
                blurRadius: 28,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [palette.primaryColor, palette.accentColor],
                ),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }

    if (artStyle == MusicArtworkStyle.floatingCard3D) {
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [palette.primaryColor.withValues(alpha: 0.45), const Color(0xFF161A28)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.album_rounded, color: Colors.white, size: 54),
      );
    }

    if (artStyle == MusicArtworkStyle.glowSphere) {
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              palette.primaryColor.withValues(alpha: 0.8),
              palette.accentColor.withValues(alpha: 0.3),
              const Color(0xFF0F121C),
            ],
          ),
          border: Border.all(color: palette.primaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.6),
              blurRadius: 36,
            ),
          ],
        ),
        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 48),
      );
    }

    // Default: 3D Rounded Square
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF161A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.primaryColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 52),
    );
  }

  Widget _buildCustomPlayPauseButton(AppThemePalette palette, {bool mini = false}) {
    final style = MusicSettings.customPlayButtonStyle.value;
    final hoverEffect = MusicSettings.customHoverEffect.value;
    final icon = _previewIsPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final size = mini ? 38.0 : 54.0;
    final iconSize = mini ? 22.0 : 32.0;

    Widget buttonCore;
    BorderRadius borderRadius;

    if (style == MusicPlayButtonStyle.liquidGlassNeo) {
      borderRadius = BorderRadius.circular(mini ? 12 : 18);
      final glassStyle = LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: mini ? 12 : 18,
          clipQuality: LiquidGlassClipQuality.exact,
          borderWidth: 1.5,
          lightIntensity: 1.5,
          lightColor: const Color(0xE6FFFFFF),
          lightDirection: 115,
          borderType: const OpticalBorder(
            borderSaturation: 1.5,
            ambientIntensity: 1.2,
            borderSolidity: 0.2,
            lightSpread: 0.7,
          ),
        ),
        appearance: LiquidGlassAppearance(
          color: palette.primaryColor.withValues(alpha: 0.15),
          saturation: 1.2,
          blur: const LiquidGlassBlur(sigmaX: 3.0, sigmaY: 3.0),
          shadow: LiquidGlassShadow(
            blur: 16,
            opacity: 0.4,
            color: palette.primaryColor,
          ),
        ),
        refraction: const LiquidGlassRefraction(
          magnification: 1.04,
          chromaticAberration: 0.0035,
          refractionType: OpticalRefraction(
            refraction: 1.55,
            refractionWidth: 22,
            depth: 0.8,
          ),
        ),
      );

      buttonCore = LiquidGlassLens(
        style: glassStyle,
        visibility: true,
        useImpellerBackdrop: true,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      );
    } else if (style == MusicPlayButtonStyle.neonSquare) {
      borderRadius = BorderRadius.circular(mini ? 10 : 16);
      buttonCore = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [palette.primaryColor, palette.accentColor],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    } else if (style == MusicPlayButtonStyle.pillPulse) {
      borderRadius = BorderRadius.circular(30);
      buttonCore = Container(
        width: mini ? 48 : 72,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: palette.primaryColor,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 16,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    } else {
      // Circle Glow
      borderRadius = BorderRadius.circular(size / 2);
      buttonCore = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [palette.primaryColor, palette.accentColor],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.55),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }

    return MusicInteractivePhysicsButton(
      effect: hoverEffect,
      glowColor: palette.primaryColor,
      borderRadius: borderRadius,
      onTap: _togglePlayPause,
      child: buttonCore,
    );
  }

  Widget _buildCanvasIconButton(IconData icon, double size, AppThemePalette palette, VoidCallback onTap) {
    return MusicInteractivePhysicsButton(
      effect: MusicSettings.customHoverEffect.value,
      glowColor: palette.primaryColor,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildLyricsPreviewOverlay(AppThemePalette palette) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          width: 380,
          height: 320,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F121C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Synced Lyrics Sandbox', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: () => setState(() => _showLyricsPreview = false),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView(
                  children: [
                    Text('I\'m tryna put you in the worst mood, ah', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                    const SizedBox(height: 12),
                    Text('P1 cleaner than your church shoes, ah', style: TextStyle(color: palette.primaryColor, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Text('Milli point two just to hurt you, ah', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                    const SizedBox(height: 12),
                    Text('All red Lamb\' just to tease you, ah', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueuePreviewOverlay(AppThemePalette palette) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          width: 380,
          height: 320,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F121C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Playing Queue Sandbox (4 Tracks)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: () => setState(() => _showQueuePreview = false),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView(
                  children: [
                    _buildQueueItem(1, 'Starboy', 'The Weeknd', true, palette),
                    _buildQueueItem(2, 'Party Monster', 'The Weeknd', false, palette),
                    _buildQueueItem(3, 'False Alarm', 'The Weeknd', false, palette),
                    _buildQueueItem(4, 'Reminder', 'The Weeknd', false, palette),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueItem(int num, String title, String artist, bool active, AppThemePalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? palette.primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? palette.primaryColor : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.equalizer_rounded : Icons.music_note_rounded, color: active ? palette.primaryColor : Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$title • $artist', style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ── RIGHT: STUDIO CUSTOMIZATION CONTROLS PANEL ──
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStudioControlsPanel(AppThemePalette palette) {
    return Container(
      color: const Color(0xFF090B10),
      child: Column(
        children: [
          // Studio Sub-Tabs
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0F17),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabChip(0, Icons.drag_indicator_rounded, 'Drag & Drop Layout', palette),
                _buildTabChip(1, Icons.graphic_eq_rounded, 'Seek Bar Canvas', palette),
                _buildTabChip(2, Icons.touch_app_rounded, 'Play Button & Physics', palette),
                _buildTabChip(3, Icons.album_rounded, 'Artwork & Turntable', palette),
              ],
            ),
          ),

          // Active Tab Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                if (_selectedStudioTab == 0) _buildDragAndDropLayoutSection(palette),
                if (_selectedStudioTab == 1) _buildSeekbarCanvasSection(palette),
                if (_selectedStudioTab == 2) _buildPlayButtonPhysicsSection(palette),
                if (_selectedStudioTab == 3) _buildArtworkTurntableSection(palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(int index, IconData icon, String label, AppThemePalette palette) {
    final isSelected = _selectedStudioTab == index;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 16),
        label: Text(label),
        selected: isSelected,
        selectedColor: palette.primaryColor,
        backgroundColor: const Color(0xFF121520),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08)),
        onSelected: (val) {
          if (val) setState(() => _selectedStudioTab = index);
        },
      ),
    );
  }

  // ── Tab 0: Drag & Drop Reorderable Components ──
  Widget _buildDragAndDropLayoutSection(AppThemePalette palette) {
    final isMini = _studioPlayerTarget == 1;

    final componentNames = {
      'artwork': isMini ? 'Mini Cover Art' : 'Album Art & Vinyl Turntable',
      'title': 'Track, Artist & Album Titles',
      'trackInfo': 'Track Title & Quality Badge',
      'qualityBadge': 'Lossless Hi-Res Audio Quality Badge',
      'seekbar': 'Seek Bar Scrubber Canvas',
      'mainControls': 'Primary Controls (Play, Pause, Skip, Shuffle, Repeat)',
      'secondaryControls': 'Secondary Controls (Volume Slider)',
      'extraActions': isMini ? 'Like Track Action' : 'Synced Lyrics & Queue Quick Buttons',
    };

    final componentIcons = {
      'artwork': Icons.album_rounded,
      'title': Icons.title_rounded,
      'trackInfo': Icons.music_note_rounded,
      'qualityBadge': Icons.diamond_rounded,
      'seekbar': Icons.graphic_eq_rounded,
      'mainControls': Icons.play_circle_filled_rounded,
      'secondaryControls': Icons.volume_up_rounded,
      'extraActions': Icons.extension_rounded,
    };

    return ValueListenableBuilder<List<String>>(
      valueListenable: isMini ? MusicSettings.componentOrderMini : MusicSettings.componentOrderFullscreen,
      builder: (context, order, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_indicator_rounded, color: palette.primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  isMini ? 'Mini Player Drag & Drop Arranger' : 'Fullscreen Player Drag & Drop Arranger',
                  style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hold and drag any block to reorder the layout of your ${isMini ? "mini player bar" : "fullscreen player"} in real-time.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
            ),
            const SizedBox(height: 16),

            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIdx, newIdx) {
                if (isMini) {
                  MusicSettings.reorderMiniComponents(oldIdx, newIdx);
                } else {
                  MusicSettings.reorderFullscreenComponents(oldIdx, newIdx);
                }
              },
              children: List.generate(order.length, (index) {
                final key = order[index];
                final name = componentNames[key] ?? key;
                final icon = componentIcons[key] ?? Icons.widgets_rounded;

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(key),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121622),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(Icons.drag_handle_rounded, color: palette.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: palette.primaryColor, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  // ── Tab 1: Seekbar Canvas Section ──
  Widget _buildSeekbarCanvasSection(AppThemePalette palette) {
    return ValueListenableBuilder<MusicSeekbarStyle>(
      valueListenable: MusicSettings.customSeekbarStyle,
      builder: (context, activeStyle, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: palette.primaryColor, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Seek Bar Canvas Scrubber Engine',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select how audio waveforms and scrubbing tracks render across your music player.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
            ),
            const SizedBox(height: 16),

            ...MusicSeekbarStyle.values.map((s) {
              final isSelected = activeStyle == s;
              return InkWell(
                onTap: () => MusicSettings.setCustomSeekbarStyle(s),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryColor.withValues(alpha: 0.14) : const Color(0xFF11141F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          s == MusicSeekbarStyle.waveformEqualizer
                              ? Icons.graphic_eq_rounded
                              : s == MusicSeekbarStyle.neonGradient
                                  ? Icons.linear_scale_rounded
                                  : s == MusicSeekbarStyle.liquidGlassSlider
                                      ? Icons.blur_on_rounded
                                      : s == MusicSeekbarStyle.radialDial
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.tune_rounded,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.description,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ── Tab 2: Play Button & Hover Physics ──
  Widget _buildPlayButtonPhysicsSection(AppThemePalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_filled_rounded, color: palette.primaryColor, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Play Button Aesthetic & Style',
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ValueListenableBuilder<MusicPlayButtonStyle>(
          valueListenable: MusicSettings.customPlayButtonStyle,
          builder: (context, activeBtnStyle, _) {
            return SegmentedTabs<MusicPlayButtonStyle>(
              selected: activeBtnStyle,
              onSelected: (b) {
                MusicSettings.setCustomPlayButtonStyle(b);
              },
              options: [
                for (final b in MusicPlayButtonStyle.values)
                  SegmentedTabOption(value: b, label: b.label),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.touch_app_rounded, color: palette.primaryColor, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Hover & Touch Physics Engine',
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Select the interactive physics feedback applied when hovering or pressing controls.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
        ),
        const SizedBox(height: 12),

        ValueListenableBuilder<MusicHoverEffect>(
          valueListenable: MusicSettings.customHoverEffect,
          builder: (context, activeHover, _) {
            return SegmentedTabs<MusicHoverEffect>(
              selected: activeHover,
              onSelected: (h) {
                MusicSettings.setCustomHoverEffect(h);
              },
              options: [
                for (final h in MusicHoverEffect.values)
                  SegmentedTabOption(value: h, label: h.label),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
        // Live Physics Testing Pad
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF11141F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.primaryColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                'Live Physics Testing Pad',
                style: TextStyle(color: palette.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCanvasIconButton(Icons.skip_previous_rounded, 24, palette, () {}),
                  _buildCustomPlayPauseButton(palette),
                  _buildCanvasIconButton(Icons.skip_next_rounded, 24, palette, () {}),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Artwork & Turntable Section ──
  Widget _buildArtworkTurntableSection(AppThemePalette palette) {
    return ValueListenableBuilder<MusicArtworkStyle>(
      valueListenable: MusicSettings.customArtworkStyle,
      builder: (context, activeArt, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.album_rounded, color: palette.primaryColor, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Artwork & Turntable Presentation',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select how album covers, vinyl turntable animations, and cards display in the player.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
            ),
            const SizedBox(height: 16),

            ...MusicArtworkStyle.values.map((a) {
              final isSelected = activeArt == a;
              return InkWell(
                onTap: () => MusicSettings.setCustomArtworkStyle(a),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primaryColor.withValues(alpha: 0.14) : const Color(0xFF11141F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? palette.primaryColor : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          a == MusicArtworkStyle.vinylSpinningDisc
                              ? Icons.album_rounded
                              : a == MusicArtworkStyle.floatingCard3D
                                  ? Icons.view_carousel_rounded
                                  : a == MusicArtworkStyle.glowSphere
                                      ? Icons.blur_on_rounded
                                      : Icons.crop_square_rounded,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          a.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: palette.primaryColor, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
