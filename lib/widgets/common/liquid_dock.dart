import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../services/theme/design_tokens.dart';
import '../../services/theme/glass_settings.dart';
import 'focusable_card.dart';
import 'performance_liquid_lens.dart';

/// Item corner radius. Deliberately smaller than the container's so the pill
/// reads as sitting *in* the dock rather than being another dock.
const double _dockItemRadius = 14;

/// Dock corner radius. Was 32, which fought the 14–18px radii used by every
/// other surface in the app.
const double _dockContainerRadius = 24;

/// Padding and icon-to-label gap of the expanded active item.
const double _dockActivePadding = 14;
const double _dockActiveGap = 8;

/// The active item's label. Matches the app's 13.5px label step so the dock
/// reads as the same family as the rest of the shell.
const TextStyle _dockActiveLabelStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  height: 1.0,
);

/// Width of the expanded (active) item: its padding, icon, gap and label.
///
/// Measured with a [TextPainter] rather than read back from layout, because the
/// dock has to know the row's width *before* laying it out to decide whether it
/// scrolls. A pill that only widened after layout would clip the last
/// destination or leave the scroll arrows unused.
double _dockActiveItemWidth(String label, double size) {
  final labelWidth = (TextPainter(
    text: TextSpan(text: label, style: _dockActiveLabelStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout())
      .width;

  return math.max(
    size,
    _dockActivePadding * 2 + size * 0.45 + _dockActiveGap + labelWidth + 2,
  );
}

class DockItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// True for the destination currently on screen.
  ///
  /// The dock had no such concept: every item rendered identically, so the only
  /// way to tell where you were was to remember what you tapped. That is
  /// tolerable with a pointer and a tooltip, and impossible on a TV remote.
  final bool isActive;

  const DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
}

/// A single retained liquid lens containing lightweight dock items.
///
/// One lens preserves the refraction effect without the previous cost of a
/// separate shader and jelly simulation for every item.
class LiquidDock extends StatefulWidget {
  final List<DockItem> items;
  final double baseItemSize;
  final double maxItemSize;
  final double maxWidth;

  const LiquidDock({
    super.key,
    required this.items,
    this.baseItemSize = 48,
    this.maxItemSize = 72,
    this.maxWidth = 600,
  });

  @override
  State<LiquidDock> createState() => _LiquidDockState();
}

class _LiquidDockState extends State<LiquidDock> {
  final ScrollController _scrollController = ScrollController();
  /// Pointer X in global coordinates, compared against measured item centres.
  double? _mouseX;
  bool _dockHovered = false;
  bool _isWarmingUp = false;

  final List<GlobalKey> _itemKeys = <GlobalKey>[];

  GlobalKey _itemKeyAt(int index) {
    while (_itemKeys.length <= index) {
      _itemKeys.add(GlobalKey());
    }
    return _itemKeys[index];
  }

  /// Jelly proximity for [index], from where the item actually is.
  ///
  /// Centres are read off the render boxes instead of computed as
  /// `index * itemExtent`: the active item is a wider pill, so a positional
  /// formula drifts by its extra width for every item after it and the jelly
  /// swells the wrong neighbour. Reading the boxes also costs nothing worth
  /// caching — a dozen parent lookups per hover event.
  double _proximityFor(int index) {
    final mouse = _mouseX;
    if (!_dockHovered || mouse == null || index >= _itemKeys.length) return 0;

    final box =
        _itemKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;

    final range = widget.baseItemSize * GlassSettings.hoverProximity.value;
    final distance =
        (mouse - box.localToGlobal(Offset(box.size.width / 2, 0)).dx).abs();
    if (distance >= range) return 0;

    return math.pow(1 - distance / range, 1.45).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _prewarmDockAnimation();
  }

  /// Pre-warms GPU shaders, layer composition, jelly physics, and proximity layout
  /// by sweeping mouse state across all dock items under the intro overlay.
  void _prewarmDockAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !GlassSettings.enabled.value) return;

      final itemExtent = widget.baseItemSize + 10;
      final totalWidth = widget.items.length * itemExtent + 32;

      // Start prewarm sweep after initial layout stabilizes during intro screen
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      setState(() {
        _dockHovered = true;
        _isWarmingUp = true;
      });

      // Sweep hover position across all dock items so every item's shader/jelly texture is warmed up
      const steps = 12;
      for (int i = 0; i <= steps; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted || !_isWarmingUp) break;
        final progress = i / steps;
        setState(() {
          _mouseX = progress * totalWidth;
        });
      }

      await Future.delayed(const Duration(milliseconds: 40));

      if (mounted && _isWarmingUp) {
        setState(() {
          _dockHovered = false;
          _mouseX = null;
          _isWarmingUp = false;
        });
      }
    });
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final effectiveMaxWidth = math.min(
      widget.maxWidth,
      isMobile ? screenWidth * 0.94 : screenWidth * 0.88,
    );
    final itemSize = isMobile
        ? math.min(widget.baseItemSize, 44.0)
        : widget.baseItemSize;
    final itemExtent = widget.baseItemSize + 10;
    // The active item is a pill rather than a square, so the row has to be
    // budgeted for its label before it is laid out.
    final activeExtra = widget.items
        .where((item) => item.isActive)
        .fold<double>(
          0,
          (extra, item) =>
              extra + _dockActiveItemWidth(item.label, itemSize) - itemSize,
        );
    final contentWidth = widget.items.length * itemExtent + 32 + activeExtra;
    final needsScrolling = contentWidth > effectiveMaxWidth;
    final scrollAreaWidth = needsScrolling
        ? math.max(60.0, effectiveMaxWidth - 68.0)
        : contentWidth;

    final dockContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (needsScrolling)
          SizedBox(
            width: 32,
            height: 48,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 20),
              onPressed: () => _scrollBy(-180),
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: scrollAreaWidth,
          ),
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              scrollbars: false,
              overscroll: false,
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.items.length, (index) {
                  return Padding(
                    key: _itemKeyAt(index),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _DockItemWidget(
                      item: widget.items[index],
                      size: itemSize,
                      hoverSize: isMobile
                          ? math.min(widget.maxItemSize, 56.0)
                          : widget.maxItemSize,
                      proximity: _proximityFor(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        if (needsScrolling)
          SizedBox(
            width: 32,
            height: 48,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () => _scrollBy(180),
            ),
          ),
      ],
    );

    return MouseRegion(
      onEnter: (_) {
        if (GlassSettings.enabled.value) {
          setState(() => _dockHovered = true);
        }
      },
      onHover: (event) {
        if (GlassSettings.enabled.value) {
          setState(() => _mouseX = event.position.dx);
        }
      },
      onExit: (_) {
        if (_dockHovered || _mouseX != null) {
          setState(() {
            _dockHovered = false;
            _mouseX = null;
          });
        }
      },
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius:
                BorderRadius.all(Radius.circular(_dockContainerRadius)),
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: PerformanceLiquidLens(
            style: PerformanceGlassStyles.dock,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_dockContainerRadius),
                // A gradient wash that is heavier at the top is what actually
                // reads as a lit pane of glass. It cannot be done with
                // per-side border colours: BoxDecoration requires a uniform
                // border whenever a borderRadius is set.
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)],
                ),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: dockContent,
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination: an icon that expands into a labelled accent pill when it is
/// the page you are on.
///
/// Stateless by design — hover, focus and press now come from [FocusableCard],
/// which is also what makes the dock usable with a remote. The previous
/// "optimized" path was a bare [GestureDetector], which is pointer-only, so on a
/// TV the dock could not be reached at all.
class _DockItemWidget extends StatelessWidget {
  final DockItem item;
  final double size;
  final double hoverSize;
  final double proximity;

  const _DockItemWidget({
    required this.item,
    required this.size,
    required this.hoverSize,
    required this.proximity,
  });

  static const BorderRadius _radius =
      BorderRadius.all(Radius.circular(_dockItemRadius));

  /// The jelly: items swell as the pointer approaches, and further on hover.
  ///
  /// Growth is capped by the dock's declared maximum item size so a large
  /// hover-scale setting cannot push an item past the slot beside it.
  double _scaleFor(CardInteraction state) {
    if (state.pressed) return 0.92;

    final ceiling = math.max(1.0, hoverSize / size);
    final hoverScale = math.min(GlassSettings.hoverScale.value, ceiling);
    final amount = state.hovered ? 1.0 : proximity;
    return (1 + (hoverScale - 1) * amount) * (state.hovered ? hoverScale : 1.0);
  }

  /// The item's own box, including the active pill.
  ///
  /// On the glass path the inactive background stays clear so the lens beneath
  /// is what you see — but the accent pill is painted in both paths, because
  /// the two cannot be allowed to disagree about which page you are on.
  Widget _content(
    BuildContext context,
    CardInteraction state, {
    required bool glass,
  }) {
    final tokens = ZplayTokens.of(context);
    final active = item.isActive;

    final glyph = Icon(
      item.icon,
      size: size * 0.45,
      color: active
          ? tokens.onAccent
          : Colors.white.withValues(alpha: state.highlighted ? 1.0 : 0.88),
    );

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: active ? _dockActivePadding : 0),
      decoration: BoxDecoration(
        borderRadius: _radius,
        color: active
            ? tokens.accent
            : glass
                ? Colors.transparent
                : Colors.white
                    .withValues(alpha: state.highlighted ? 0.16 : 0.07),
        border:
            active || glass ? null : Border.all(color: tokens.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The active item already shows its name, so the tooltip is left for
          // the destinations that are still a glyph to guess at.
          if (active)
            glyph
          else
            Tooltip(message: item.label, child: glyph),
          if (active) ...[
            const SizedBox(width: _dockActiveGap),
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: _dockActiveLabelStyle.copyWith(color: tokens.onAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullLiquid(BuildContext context, CardInteraction state) {
    final wobble = GlassSettings.wobbleIntensity.value;

    return LiquidGlassButton(
      padding: EdgeInsets.zero,
      height: size,
      touch: LiquidGlassTouch(
        flex: wobble > 1.4
            ? const LiquidGlassFlex.pronounced()
            : const LiquidGlassFlex(),
      ),
      style: GlassSettings.createButtonGlassStyle(),
      // Purely decorative: [FocusableCard] owns activation now, so leaving this
      // wired would fire the destination twice per click.
      onPressed: null,
      child: _content(context, state, glass: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = item.isActive;

    return RepaintBoundary(
      child: FocusableCard(
        onTap: item.onTap,
        builder: (context, state) => CardFocusRing(
          focused: state.focused,
          radius: _radius,
          child: ValueListenableBuilder<bool>(
            valueListenable: GlassSettings.enabled,
            builder: (context, glass, _) => AnimatedScale(
              scale: _scaleFor(state),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: size,
                width: active ? _dockActiveItemWidth(item.label, size) : size,
                child: glass
                    ? _buildFullLiquid(context, state)
                    : _content(context, state, glass: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
