import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/books/reader_settings.dart';
import '../../../widgets/common/focusable_card.dart';
import 'reader_design_tokens.dart';

class ReaderCustomizationSheet extends StatefulWidget {
  final String? realBookSampleText;

  const ReaderCustomizationSheet({
    super.key,
    this.realBookSampleText,
  });

  static Future<void> show(BuildContext context, {String? realBookSampleText}) {
    final isDesktop = MediaQuery.of(context).size.width > 760;

    if (isDesktop) {
      // Right side panel on desktop
      return showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close Settings',
        barrierColor: Colors.black.withValues(alpha: 0.4),
        transitionDuration: ReaderTokens.motionSheet,
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: ReaderCustomizationSheet(realBookSampleText: realBookSampleText),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curved = CurvedAnimation(parent: anim1, curve: ReaderTokens.curveSheet);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: child,
          );
        },
      );
    }

    // Bottom sheet on mobile
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReaderCustomizationSheet(realBookSampleText: realBookSampleText),
    );
  }

  @override
  State<ReaderCustomizationSheet> createState() => _ReaderCustomizationSheetState();
}

class _ReaderCustomizationSheetState extends State<ReaderCustomizationSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showResetSuccess = false;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _triggerReset() {
    HapticFeedback.lightImpact();
    ReaderSettings.resetToDefaults();
    setState(() => _showResetSuccess = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showResetSuccess = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettingsData>(
      valueListenable: ReaderSettings.settingsNotifier,
      builder: (context, settings, _) {
        final isDesktop = MediaQuery.of(context).size.width > 760;

        final container = Container(
          width: isDesktop ? 380 : double.infinity,
          height: isDesktop ? double.infinity : null,
          constraints: isDesktop
              ? null
              : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: settings.surfaceColor,
            borderRadius: isDesktop
                ? const BorderRadius.horizontal(left: Radius.circular(ReaderTokens.radius24))
                : const BorderRadius.vertical(top: Radius.circular(ReaderTokens.radius24)),
            border: Border.all(color: settings.borderColor),
            boxShadow: const [ReaderTokens.shadowMd],
          ),
          child: Column(
            mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Mobile Drag Handle
              if (!isDesktop)
                Container(
                  margin: const EdgeInsets.only(top: ReaderTokens.space12, bottom: ReaderTokens.space8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: settings.secondaryTextColor.withValues(alpha: 0.30),
                    borderRadius: ReaderTokens.rounded4,
                  ),
                ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ReaderTokens.space24,
                  ReaderTokens.space12,
                  ReaderTokens.space16,
                  ReaderTokens.space8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: settings.accentColor, size: 18),
                        const SizedBox(width: ReaderTokens.space8),
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontFamily: ReaderTokens.uiFont,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: settings.textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: settings.secondaryTextColor, size: 18),
                      tooltip: 'Close settings',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Real Book Text Live Preview
              _buildLivePreview(settings),

              // Underline Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: ReaderTokens.space24,
                  vertical: ReaderTokens.space8,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: settings.borderColor)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicatorColor: settings.accentColor,
                  indicatorWeight: 2.5,
                  labelColor: settings.accentColor,
                  unselectedLabelColor: settings.secondaryTextColor,
                  labelStyle: ReaderTokens.tabLabel,
                  tabs: const [
                    Tab(text: 'Typography'),
                    Tab(text: 'Theme'),
                    Tab(text: 'Layout'),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: settings.accentColor,
                    inactiveTrackColor: settings.borderColor,
                    thumbColor: settings.accentColor,
                    showValueIndicator: ShowValueIndicator.onlyForContinuous,
                    valueIndicatorColor: settings.accentColor,
                    valueIndicatorTextStyle: const TextStyle(
                      fontFamily: ReaderTokens.uiFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTypographyTab(settings),
                      _buildThemeTab(settings),
                      _buildLayoutTab(settings),
                    ],
                  ),
                ),
              ),

              // Bottom Actions: "Reset to Defaults" button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ReaderTokens.space24,
                  vertical: ReaderTokens.space12,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: settings.borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _showResetSuccess ? Icons.check_rounded : Icons.restart_alt_rounded,
                        size: 16,
                        color: _showResetSuccess ? const Color(0xFF10B981) : settings.secondaryTextColor,
                      ),
                      label: Text(
                        _showResetSuccess ? 'Reset ✓' : 'Reset to Defaults',
                        style: TextStyle(
                          fontFamily: ReaderTokens.uiFont,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _showResetSuccess ? const Color(0xFF10B981) : settings.secondaryTextColor,
                        ),
                      ),
                      onPressed: _triggerReset,
                    ),
                    Text(
                      'v2.0',
                      style: TextStyle(
                        fontFamily: ReaderTokens.uiFont,
                        fontSize: 11,
                        color: settings.secondaryTextColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return container;
      },
    );
  }

  Widget _buildLivePreview(ReaderSettingsData settings) {
    final previewText = widget.realBookSampleText?.isNotEmpty == true
        ? widget.realBookSampleText!
        : '“It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.”';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: ReaderTokens.space24,
        vertical: ReaderTokens.space8,
      ),
      padding: const EdgeInsets.all(ReaderTokens.space16),
      decoration: BoxDecoration(
        color: settings.backgroundColor,
        borderRadius: ReaderTokens.rounded16,
        border: Border.all(color: settings.borderColor),
        boxShadow: const [ReaderTokens.shadowSm],
      ),
      child: Text(
        previewText,
        textAlign: settings.textAlign,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: settings.fontFamily,
          fontSize: settings.fontSize.clamp(14.0, 20.0),
          height: settings.lineSpacing,
          letterSpacing: settings.letterSpacing,
          color: settings.textColor,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. TYPOGRAPHY TAB
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildTypographyTab(ReaderSettingsData settings) {
    final fonts = [
      {'name': 'Georgia', 'key': 'Georgia', 'sub': 'Serif'},
      {'name': 'Merriweather', 'key': 'Merriweather', 'sub': 'Serif'},
      {'name': 'Inter', 'key': 'Inter', 'sub': 'Sans'},
      {'name': 'Poppins', 'key': 'Poppins', 'sub': 'Sans'},
      {'name': 'OpenDyslexic', 'key': 'OpenDyslexic', 'sub': 'Dyslexic'},
      {'name': 'Monospace', 'key': 'Courier New', 'sub': 'Mono'},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(ReaderTokens.space24),
      children: [
        _buildSectionTitle('Font Family', settings),
        const SizedBox(height: ReaderTokens.space8),
        Wrap(
          spacing: ReaderTokens.space8,
          runSpacing: ReaderTokens.space8,
          children: fonts.map((f) {
            final isSelected = settings.fontFamily == f['key'];
            return ChoiceChip(
              label: Text('${f['name']}'),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                ReaderSettings.updateFontFamily(f['key']!);
              },
              selectedColor: settings.accentColor,
              backgroundColor: settings.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: ReaderTokens.rounded8,
                side: BorderSide(
                  color: isSelected ? Colors.transparent : settings.borderColor,
                ),
              ),
              labelStyle: TextStyle(
                fontFamily: f['key'],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : settings.textColor,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ReaderTokens.space24),

        // Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Font Size', settings),
            Text(
              '${settings.fontSize.round()} px',
              style: TextStyle(
                fontFamily: ReaderTokens.uiFont,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: settings.textColor,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text('A', style: TextStyle(fontSize: 12, color: settings.secondaryTextColor, fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: settings.fontSize,
                min: 14,
                max: 34,
                divisions: 10,
                label: '${settings.fontSize.round()}px',
                onChanged: (val) => ReaderSettings.updateFontSize(val),
              ),
            ),
            Text('A', style: TextStyle(fontSize: 22, color: settings.secondaryTextColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: ReaderTokens.space16),

        // Line Spacing Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Line Height', settings),
            Text(
              '${settings.lineSpacing.toStringAsFixed(2)}×',
              style: TextStyle(
                fontFamily: ReaderTokens.uiFont,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: settings.textColor,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.lineSpacing,
          min: 1.2,
          max: 2.2,
          divisions: 10,
          label: '${settings.lineSpacing.toStringAsFixed(2)}×',
          onChanged: (val) => ReaderSettings.updateLineSpacing(val),
        ),
        const SizedBox(height: ReaderTokens.space16),

        // Alignment & First-Line Indent
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Alignment', settings),
                  const SizedBox(height: ReaderTokens.space8),
                  Row(
                    children: [
                      _buildAlignButton(Icons.format_align_left_rounded, TextAlign.left, settings),
                      const SizedBox(width: ReaderTokens.space8),
                      _buildAlignButton(Icons.format_align_justify_rounded, TextAlign.justify, settings),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('First-Line Indent', settings),
                  const SizedBox(height: ReaderTokens.space8),
                  Switch.adaptive(
                    value: settings.firstLineIndent,
                    activeColor: settings.accentColor,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      ReaderSettings.updateFirstLineIndent(val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. THEME & BRIGHTNESS TAB
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildThemeTab(ReaderSettingsData settings) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(ReaderTokens.space24),
      children: [
        _buildSectionTitle('Reading Themes', settings),
        const SizedBox(height: ReaderTokens.space12),
        Row(
          children: [
            _buildThemeSwatchCard(
              label: 'Light',
              theme: ReaderTheme.light,
              current: settings.theme,
              bg: const Color(0xFFFAFAFA),
              textColor: const Color(0xFF1F2328),
              border: const Color(0xFFD0D7DE),
            ),
            const SizedBox(width: ReaderTokens.space8),
            _buildThemeSwatchCard(
              label: 'Sepia',
              theme: ReaderTheme.sepia,
              current: settings.theme,
              bg: const Color(0xFFF4ECD8),
              textColor: const Color(0xFF382717),
              border: const Color(0xFFD4C8B0),
            ),
            const SizedBox(width: ReaderTokens.space8),
            _buildThemeSwatchCard(
              label: 'Dark',
              theme: ReaderTheme.dark,
              current: settings.theme,
              bg: const Color(0xFF141419),
              textColor: const Color(0xFFE6E8ED),
              border: const Color(0xFF2A2E3D),
            ),
            const SizedBox(width: ReaderTokens.space8),
            _buildThemeSwatchCard(
              label: 'AMOLED',
              theme: ReaderTheme.amoled,
              current: settings.theme,
              bg: Colors.black,
              textColor: const Color(0xFFE5E5E5),
              border: const Color(0xFF262626),
            ),
          ],
        ),
        const SizedBox(height: ReaderTokens.space32),

        // In-App Brightness Dimmer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Reader Brightness', settings),
            Text(
              '${(settings.brightness * 100).round()}%',
              style: TextStyle(
                fontFamily: ReaderTokens.uiFont,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: settings.textColor,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.brightness_low_rounded, color: settings.secondaryTextColor, size: 18),
            Expanded(
              child: Slider(
                value: settings.brightness,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                label: '${(settings.brightness * 100).round()}%',
                onChanged: (val) => ReaderSettings.updateBrightness(val),
              ),
            ),
            Icon(Icons.brightness_high_rounded, color: settings.secondaryTextColor, size: 20),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. LAYOUT TAB
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLayoutTab(ReaderSettingsData settings) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(ReaderTokens.space24),
      children: [
        _buildSectionTitle('Page Margins', settings),
        const SizedBox(height: ReaderTokens.space12),
        Row(
          children: [
            _buildMarginChip('Compact', MarginPreset.compact, settings),
            const SizedBox(width: ReaderTokens.space8),
            _buildMarginChip('Balanced', MarginPreset.balanced, settings),
            const SizedBox(width: ReaderTokens.space8),
            _buildMarginChip('Wide', MarginPreset.wide, settings),
          ],
        ),
        const SizedBox(height: ReaderTokens.space24),

        _buildSectionTitle('Reading Mode', settings),
        const SizedBox(height: ReaderTokens.space12),
        Row(
          children: [
            Expanded(
              child: _buildModeButton(
                icon: Icons.unfold_more_rounded,
                label: 'Continuous Scroll',
                mode: ReaderMode.scroll,
                settings: settings,
              ),
            ),
            const SizedBox(width: ReaderTokens.space12),
            Expanded(
              child: _buildModeButton(
                icon: Icons.auto_stories_rounded,
                label: 'Paginated Turns',
                mode: ReaderMode.paginated,
                settings: settings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, ReaderSettingsData settings) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: ReaderTokens.uiFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: settings.secondaryTextColor,
      ),
    );
  }

  Widget _buildThemeSwatchCard({
    required String label,
    required ReaderTheme theme,
    required ReaderTheme current,
    required Color bg,
    required Color textColor,
    required Color border,
  }) {
    final isSelected = theme == current;
    return Expanded(
      child: FocusableCard(
        onTap: () {
          HapticFeedback.lightImpact();
          ReaderSettings.updateTheme(theme);
        },
        builder: (context, _) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: ReaderTokens.rounded12,
            border: Border.all(
              color: isSelected ? const Color(0xFF7C3AED) : border,
              width: isSelected ? 2.2 : 1.0,
            ),
            boxShadow: isSelected ? [ReaderTokens.shadowGlow(const Color(0xFF7C3AED))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mini color swatch dot pair
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: textColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor.withValues(alpha: 0.5), width: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ReaderTokens.space4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: ReaderTokens.uiFont,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlignButton(IconData icon, TextAlign align, ReaderSettingsData settings) {
    final isSelected = settings.textAlign == align;
    return IconButton.filledTonal(
      icon: Icon(icon, size: 20),
      onPressed: () {
        HapticFeedback.selectionClick();
        ReaderSettings.updateTextAlign(align);
      },
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? settings.accentColor : settings.backgroundColor,
        foregroundColor: isSelected ? Colors.white : settings.secondaryTextColor,
        side: BorderSide(color: isSelected ? Colors.transparent : settings.borderColor),
        shape: const RoundedRectangleBorder(borderRadius: ReaderTokens.rounded8),
      ),
    );
  }

  Widget _buildMarginChip(String label, MarginPreset preset, ReaderSettingsData settings) {
    final isSelected = settings.marginPreset == preset;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        selected: isSelected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          ReaderSettings.updateMarginPreset(preset);
        },
        selectedColor: settings.accentColor,
        backgroundColor: settings.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: ReaderTokens.rounded8,
          side: BorderSide(
            color: isSelected ? Colors.transparent : settings.borderColor,
          ),
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required ReaderMode mode,
    required ReaderSettingsData settings,
  }) {
    final isSelected = settings.mode == mode;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ReaderSettings.updateMode(mode);
      },
      borderRadius: ReaderTokens.rounded12,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: ReaderTokens.space12),
        decoration: BoxDecoration(
          color: isSelected ? settings.accentColor.withValues(alpha: 0.15) : settings.backgroundColor,
          borderRadius: ReaderTokens.rounded12,
          border: Border.all(
            color: isSelected ? settings.accentColor : settings.borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? settings.accentColor : settings.secondaryTextColor, size: 20),
            const SizedBox(height: ReaderTokens.space4),
            Text(
              label,
              style: TextStyle(
                fontFamily: ReaderTokens.uiFont,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? settings.accentColor : settings.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
