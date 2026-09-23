import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../services/player/player_settings.dart';
import 'player_glass.dart';

/// Responsive, rich Subtitle Customization Modal with live preview,
/// presets, typography, colors, background boxes, outlines, shadows, and libass options.
class PlayerSubStyleModal extends StatefulWidget {
  final Player? player;
  final VoidCallback onClose;

  const PlayerSubStyleModal({
    super.key,
    this.player,
    required this.onClose,
  });

  @override
  State<PlayerSubStyleModal> createState() => _PlayerSubStyleModalState();
}

class _PlayerSubStyleModalState extends State<PlayerSubStyleModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _textColorPalette = [
    {'name': 'White', 'hex': '#FFFFFFFF', 'color': Color(0xFFFFFFFF)},
    {'name': 'Cinema Yellow', 'hex': '#FFFFEB3B', 'color': Color(0xFFFFEB3B)},
    {'name': 'Amber Gold', 'hex': '#FFFFC107', 'color': Color(0xFFFFC107)},
    {'name': 'Electric Cyan', 'hex': '#00E5FF', 'color': Color(0xFF00E5FF)},
    {'name': 'Neon Green', 'hex': '#00E676', 'color': Color(0xFF00E676)},
    {'name': 'Vibrant Orange', 'hex': '#FF9100', 'color': Color(0xFFFF9100)},
    {'name': 'Soft Rose', 'hex': '#FF80AB', 'color': Color(0xFFFF80AB)},
    {'name': 'Light Gray', 'hex': '#D1D5DB', 'color': Color(0xFFD1D5DB)},
  ];

  static const List<Map<String, dynamic>> _boxColorOptions = [
    {'name': 'None', 'hex': '#00000000', 'desc': 'Transparent'},
    {'name': '25% Dark', 'hex': '#40000000', 'desc': 'Subtle'},
    {'name': '50% Dark', 'hex': '#80000000', 'desc': 'Standard Box'},
    {'name': '75% Dark', 'hex': '#BF000000', 'desc': 'High Contrast'},
    {'name': '100% Solid', 'hex': '#FF000000', 'desc': 'Opaque Black'},
    {'name': '50% Indigo', 'hex': '#800F172A', 'desc': 'Slate Tint'},
  ];

  static const List<Map<String, dynamic>> _borderColorPalette = [
    {'name': 'Black', 'hex': '#FF000000', 'color': Color(0xFF000000)},
    {'name': 'Dark Slate', 'hex': '#FF1E293B', 'color': Color(0xFF1E293B)},
    {'name': 'White', 'hex': '#FFFFFFFF', 'color': Color(0xFFFFFFFF)},
    {'name': 'Gold', 'hex': '#FFFFD700', 'color': Color(0xFFFFD700)},
    {'name': 'Crimson', 'hex': '#FFE11D48', 'color': Color(0xFFE11D48)},
    {'name': 'Neon Cyan', 'hex': '#FF00E5FF', 'color': Color(0xFF00E5FF)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColorFromHex(String hex, {Color fallback = Colors.white}) {
    var str = hex.replaceAll('#', '').trim();
    if (str.length == 6) {
      str = 'FF$str';
    }
    if (str.length == 8) {
      final val = int.tryParse(str, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 600;
    final isLandscapeMobile = screen.height < 500;

    final double cardWidth;
    if (isCompact) {
      cardWidth = (screen.width - 24).clamp(320.0, 560.0);
    } else if (isLandscapeMobile) {
      cardWidth = (screen.width - 32).clamp(440.0, 680.0);
    } else {
      cardWidth = (640.0).clamp(460.0, screen.width - 48);
    }

    final double cardHeight;
    if (isLandscapeMobile) {
      cardHeight = (screen.height - 32).clamp(240.0, screen.height - 20);
    } else if (isCompact) {
      cardHeight = (screen.height * 0.85).clamp(420.0, 660.0);
    } else {
      cardHeight = (screen.height * 0.76).clamp(520.0, 720.0);
    }

    return ValueListenableBuilder<int>(
      valueListenable: PlayerSettings.changeNotifier,
      builder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: PlayerGlassCard(
              width: cardWidth,
              height: cardHeight,
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // 1. Header Bar
                  _buildHeader(context, isCompact || isLandscapeMobile),

                  // 2. Interactive Live Preview
                  _buildLivePreview(isLandscapeMobile),

                  // 3. Quick Presets Carousel
                  _buildPresetsBar(),

                  // 4. Tab Bar Navigation
                  _buildTabBar(),

                  // 5. Scrollable Tab View Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTypographyTab(),
                        _buildColorsAndBoxTab(),
                        _buildOutlinesAndShadowsTab(),
                        _buildPositionAndLayoutTab(),
                        _buildAdvancedTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Header
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 8 : 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: isSmall ? 28 : 34,
                height: isSmall ? 28 : 34,
                decoration: BoxDecoration(
                  color: PlayerTheme.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.subtitles_rounded,
                  color: PlayerTheme.accent,
                  size: isSmall ? 16 : 19,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtitle Appearance',
                    style: TextStyle(
                      color: PlayerTheme.ink,
                      fontSize: isSmall ? 13.5 : 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'libass / libmpv hardware-rendered subtitles',
                    style: TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Reset Button
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded, size: 19, color: PlayerTheme.inkMuted),
                tooltip: 'Reset Subtitle Defaults',
                onPressed: () => PlayerSettings.resetSubtitleDefaults(player: widget.player),
              ),
              // Close Button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Live Subtitle Preview Area
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLivePreview(bool isLandscapeMobile) {
    if (isLandscapeMobile) return const SizedBox.shrink();

    final textColor = _parseColorFromHex(PlayerSettings.subColor.value);
    final boxColor = _parseColorFromHex(PlayerSettings.subBackColor.value, fallback: Colors.transparent);
    final borderColor = _parseColorFromHex(PlayerSettings.subBorderColor.value, fallback: Colors.black);
    final shadowColor = _parseColorFromHex(PlayerSettings.subShadowColor.value, fallback: Colors.black54);

    final fontName = PlayerSettings.subFont.value == 'subfont'
        ? 'Poppins'
        : PlayerSettings.subFont.value;

    final fontSize = (PlayerSettings.subFontSize.value * 0.55 * PlayerSettings.subScale.value).clamp(11.0, 32.0);
    final borderSize = (PlayerSettings.subBorderSize.value * 0.75).clamp(0.0, 5.0);
    final shadowOffset = PlayerSettings.subShadowOffset.value * 1.2;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF020617), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient grid / video frame simulator
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: _VideoGridPainter(),
              ),
            ),
          ),

          // Live Subtitle Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ZPlay • Sample Subtitle Preview',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontName,
                fontSize: fontSize,
                fontWeight: PlayerSettings.subBold.value ? FontWeight.bold : FontWeight.w600,
                fontStyle: PlayerSettings.subItalic.value ? FontStyle.italic : FontStyle.normal,
                color: textColor,
                shadows: [
                  if (borderSize > 0) ...[
                    Shadow(color: borderColor, offset: Offset(-borderSize, -borderSize)),
                    Shadow(color: borderColor, offset: Offset(borderSize, -borderSize)),
                    Shadow(color: borderColor, offset: Offset(borderSize, borderSize)),
                    Shadow(color: borderColor, offset: Offset(-borderSize, borderSize)),
                  ],
                  if (shadowOffset > 0)
                    Shadow(
                      color: shadowColor,
                      offset: Offset(shadowOffset, shadowOffset),
                      blurRadius: shadowOffset * 1.5,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Presets Horizontal Bar
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPresetsBar() {
    final activePreset = PlayerSettings.subStylePreset.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: SubtitleStylePreset.values.map((preset) {
            final isSelected = activePreset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => PlayerSettings.setSubStylePreset(preset, player: widget.player),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (preset != SubtitleStylePreset.custom)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _parseColorFromHex(preset.textColor),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 0.8),
                          ),
                        ),
                      Text(
                        preset.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab Bar Navigation
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x18000000),
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: PlayerTheme.accent,
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: PlayerTheme.inkSubtle,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Typography', icon: Icon(Icons.text_fields_rounded, size: 16)),
          Tab(text: 'Colors & Box', icon: Icon(Icons.palette_rounded, size: 16)),
          Tab(text: 'Outline & Shadow', icon: Icon(Icons.border_style_rounded, size: 16)),
          Tab(text: 'Position', icon: Icon(Icons.vertical_align_bottom_rounded, size: 16)),
          Tab(text: 'Advanced / ASS', icon: Icon(Icons.tune_rounded, size: 16)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 1: Typography
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTypographyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Font Family Selector
        _buildSectionTitle('FONT FAMILY'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: PlayerTheme.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PlayerTheme.edgeSoft),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: PlayerSettings.popularFonts.contains(PlayerSettings.subFont.value)
                  ? PlayerSettings.subFont.value
                  : 'subfont',
              isExpanded: true,
              dropdownColor: const Color(0xFF131826),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
              items: PlayerSettings.popularFonts.map((f) {
                final label = f == 'subfont' ? 'Default (ZPlay Subfont)' : f;
                return DropdownMenuItem<String>(
                  value: f,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: f == 'subfont' ? 'Poppins' : f,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) PlayerSettings.setSubFont(val, player: widget.player);
              },
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Base Font Size Slider
        _buildSectionTitle('BASE FONT SIZE (${PlayerSettings.subFontSize.value}pt)'),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.white70),
              onPressed: () => PlayerSettings.setSubFontSize(PlayerSettings.subFontSize.value - 2, player: widget.player),
            ),
            Expanded(
              child: SliderTheme(
                data: _sliderTheme(),
                child: Slider(
                  value: PlayerSettings.subFontSize.value.toDouble(),
                  min: 16.0,
                  max: 72.0,
                  divisions: 28,
                  onChanged: (v) => PlayerSettings.setSubFontSize(v.round(), player: widget.player),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white70),
              onPressed: () => PlayerSettings.setSubFontSize(PlayerSettings.subFontSize.value + 2, player: widget.player),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Scale Multiplier Slider
        _buildSectionTitle('SCALE MULTIPLIER (${(PlayerSettings.subScale.value * 100).round()}%)'),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subScale.value,
            min: 0.5,
            max: 2.5,
            divisions: 20,
            onChanged: (v) => PlayerSettings.setSubScale(v, player: widget.player),
          ),
        ),

        const SizedBox(height: 14),

        // Bold and Italic Toggles
        Row(
          children: [
            Expanded(
              child: _buildToggleTile(
                title: 'Bold Text',
                icon: Icons.format_bold_rounded,
                value: PlayerSettings.subBold.value,
                onChanged: (val) => PlayerSettings.setSubBold(val, player: widget.player),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToggleTile(
                title: 'Italic Text',
                icon: Icons.format_italic_rounded,
                value: PlayerSettings.subItalic.value,
                onChanged: (val) => PlayerSettings.setSubItalic(val, player: widget.player),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 2: Colors & Box
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildColorsAndBoxTab() {
    final activeColor = PlayerSettings.subColor.value;
    final activeBox = PlayerSettings.subBackColor.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Text Color Palette
        _buildSectionTitle('SUBTITLE TEXT COLOR'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _textColorPalette.map((item) {
            final isSelected = activeColor.toLowerCase() == (item['hex'] as String).toLowerCase();
            return InkWell(
              onTap: () => PlayerSettings.setSubColor(item['hex'], player: widget.player),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: item['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Background Box Style
        _buildSectionTitle('BACKGROUND BOX (ACCESSIBILITY & READABILITY)'),
        const SizedBox(height: 10),
        Column(
          children: _boxColorOptions.map((opt) {
            final isSelected = activeBox.toLowerCase() == (opt['hex'] as String).toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => PlayerSettings.setSubBackColor(opt['hex'], player: widget.player),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? PlayerTheme.accentSoft : PlayerTheme.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _parseColorFromHex(opt['hex']),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white30),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            opt['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        opt['desc'] as String,
                        style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 3: Outlines & Shadows
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildOutlinesAndShadowsTab() {
    final activeBorderColor = PlayerSettings.subBorderColor.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Outline Color Selector
        _buildSectionTitle('OUTLINE / BORDER COLOR'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _borderColorPalette.map((item) {
            final isSelected = activeBorderColor.toLowerCase() == (item['hex'] as String).toLowerCase();
            return InkWell(
              onTap: () => PlayerSettings.setSubBorderColor(item['hex'], player: widget.player),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: item['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Outline Thickness Slider
        _buildSectionTitle('OUTLINE THICKNESS (${PlayerSettings.subBorderSize.value.toStringAsFixed(1)}px)'),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subBorderSize.value,
            min: 0.0,
            max: 6.0,
            divisions: 12,
            onChanged: (v) => PlayerSettings.setSubBorderSize(v, player: widget.player),
          ),
        ),

        const SizedBox(height: 18),

        // Drop Shadow Offset Slider
        _buildSectionTitle('DROP SHADOW OFFSET (${PlayerSettings.subShadowOffset.value.toStringAsFixed(1)}px)'),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subShadowOffset.value,
            min: 0.0,
            max: 6.0,
            divisions: 12,
            onChanged: (v) => PlayerSettings.setSubShadowOffset(v, player: widget.player),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 4: Position & Layout
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPositionAndLayoutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Horizontal Alignment
        _buildSectionTitle('HORIZONTAL ALIGNMENT'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAlignButton('Left', 'left', Icons.format_align_left_rounded),
            const SizedBox(width: 8),
            _buildAlignButton('Center', 'center', Icons.format_align_center_rounded),
            const SizedBox(width: 8),
            _buildAlignButton('Right', 'right', Icons.format_align_right_rounded),
          ],
        ),

        const SizedBox(height: 20),

        // Bottom Margin
        _buildSectionTitle('BOTTOM MARGIN / OFFSET (${PlayerSettings.subMarginY.value.round()}px)'),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subMarginY.value,
            min: 10.0,
            max: 150.0,
            divisions: 28,
            onChanged: (v) => PlayerSettings.setSubMarginY(v, player: widget.player),
          ),
        ),

        const SizedBox(height: 20),

        // Vertical Screen Position
        _buildSectionTitle('VERTICAL POSITION (${PlayerSettings.subPos.value.round()}%)'),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subPos.value,
            min: 0.0,
            max: 100.0,
            divisions: 20,
            onChanged: (v) => PlayerSettings.setSubPos(v, player: widget.player),
          ),
        ),
      ],
    );
  }

  Widget _buildAlignButton(String title, String alignVal, IconData icon) {
    final isSelected = PlayerSettings.subAlignX.value == alignVal;
    return Expanded(
      child: InkWell(
        onTap: () => PlayerSettings.setSubAlignX(alignVal, player: widget.player),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : PlayerTheme.inkSubtle, size: 18),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 5: Advanced / ASS Script Behavior
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAdvancedTab() {
    final activeOverride = PlayerSettings.subAssOverride.value;

    final overrideModes = [
      {
        'val': 'no',
        'title': 'Preserve Anime & SSA/ASS Styling (Recommended)',
        'subtitle': 'Leaves SSA/ASS anime subtitles untouched to preserve custom karaoke, styling & positions. Plain SRT/VTT are styled with your custom theme.',
      },
      {
        'val': 'scale',
        'title': 'Scale Only',
        'subtitle': 'Applies size scaling to SSA/ASS scripts while preserving their fonts, colors, and author typography.',
      },
      {
        'val': 'yes',
        'title': 'Override Colors & Outlines',
        'subtitle': 'Applies your custom colors and outlines on top of SSA/ASS subtitle scripts.',
      },
      {
        'val': 'force',
        'title': 'Force Full Override (Aggressive)',
        'subtitle': 'Forces all custom fonts, colors, and styles onto all subtitle formats (may break anime effects).',
      },
    ];

    final useLibass = PlayerSettings.useLibass.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionTitle('SUBTITLE RENDERING ENGINE'),
        const SizedBox(height: 10),
        
        // Flutter Engine Option
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => PlayerSettings.setUseLibass(false, player: widget.player),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !useLibass ? PlayerTheme.accentSoft : PlayerTheme.raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !useLibass ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: useLibass,
                    activeColor: PlayerTheme.accent,
                    onChanged: (val) {
                      if (val != null) PlayerSettings.setUseLibass(val, player: widget.player);
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flutter Subtitle Engine (Recommended)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '100% reliable hardware-accelerated subtitle overlay across Android, iOS, Windows, Mac, and Linux with full styling support.',
                          style: TextStyle(
                            color: PlayerTheme.inkSubtle,
                            fontSize: 11,
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
        ),

        // Native libass Option
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => PlayerSettings.setUseLibass(true, player: widget.player),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: useLibass ? PlayerTheme.accentSoft : PlayerTheme.raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: useLibass ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: useLibass,
                    activeColor: PlayerTheme.accent,
                    onChanged: (val) {
                      if (val != null) PlayerSettings.setUseLibass(val, player: widget.player);
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Native MPV libass Engine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Direct GPU video texture rendering powered by libass with bundled Poppins font and SSA/ASS script layout support.',
                          style: TextStyle(
                            color: PlayerTheme.inkSubtle,
                            fontSize: 11,
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
        ),

        _buildSectionTitle('SSA / ASS FANSUB SCRIPT OVERRIDE MODE'),
        const SizedBox(height: 10),
        ...overrideModes.map((m) {
          final isSelected = activeOverride == m['val'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => PlayerSettings.setSubAssOverride(m['val']!, player: widget.player),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? PlayerTheme.accentSoft : PlayerTheme.raised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: m['val']!,
                      groupValue: activeOverride,
                      activeColor: PlayerTheme.accent,
                      onChanged: (val) {
                        if (val != null) PlayerSettings.setSubAssOverride(val, player: widget.player);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            m['subtitle']!,
                            style: const TextStyle(
                              color: PlayerTheme.inkSubtle,
                              fontSize: 11,
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
        }),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper Component Builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: PlayerTheme.inkSubtle,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PlayerTheme.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlayerTheme.edgeSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Switch.adaptive(
            value: value,
            activeColor: PlayerTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      activeTrackColor: PlayerTheme.accent,
      inactiveTrackColor: Colors.white12,
      thumbColor: Colors.white,
    );
  }
}

class _VideoGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
