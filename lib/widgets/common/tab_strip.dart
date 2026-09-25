import 'package:flutter/material.dart';

import '../../services/theme/design_tokens.dart';
import 'focusable_card.dart';

/// One option in a [TabStrip].
@immutable
class TabStripOption<T> {
  const TabStripOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;

  /// Drawn before the label. Null leaves the pill text-only.
  final IconData? icon;
}

/// A horizontally scrolling row of content-sized pills, for an unbounded number
/// of short options.
///
/// **Why this is not [SegmentedTabs].** `SegmentedTabs` is structurally an
/// equal-width control: it clamps its track to the available width and divides it
/// into equal segments (`trackWidth / options.length`), so seven vertical labels
/// on a 390 px phone get about 56 px each against a `_minSegmentWidth` of 78 and
/// the labels crush, while its sliding indicator is a fraction of the track,
/// which stops meaning anything the moment the row is allowed to scroll. Making
/// it scroll would mean discarding both of the things it is good at. This control
/// is the opposite trade: pills as wide as their own text, a scroll position
/// instead of an indicator, and no assumption that the options fit. It stays a
/// single-select control with a 44 px target, the same keyboard and D-pad story
/// as [SegmentedTabs] because both are built on [FocusableCard], and the same
/// token vocabulary, so the two look like siblings even though they behave
/// differently.
///
/// Use [SegmentedTabs] when the labels fit and the choice is a mode switch; use
/// this when the count is data-driven.
class TabStrip<T> extends StatefulWidget {
  const TabStrip({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.semanticsLabel,
    this.height = 44,
  });

  final List<TabStripOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Announced by screen readers as the name of the whole control.
  final String? semanticsLabel;

  /// Defaults to the 44 px comfortable minimum target. A caller that wants the
  /// ten-foot target passes its own.
  final double height;

  @override
  State<TabStrip<T>> createState() => _TabStripState<T>();
}

class _TabStripState<T> extends State<TabStrip<T>> {
  final ScrollController _scroll = ScrollController();

  /// One key per pill, so the selected one can be located in the viewport and
  /// asked to reveal itself. Index-aligned with [TabStrip.options].
  late List<GlobalKey> _pillKeys;

  /// Reviewed after every scroll so the fades track the row's ends rather than
  /// being painted permanently, which would dim the first and last pill of a row
  /// that has nothing to scroll.
  bool _atStart = true;
  bool _atEnd = true;

  /// Scroll offsets land on fractions of a pixel, so an exact comparison leaves
  /// a fade on at the very end of the row.
  static const double _edgeTolerance = ZplaySpacing.s2;

  /// Each fade is capped below half the row so the two can never meet in the
  /// middle of a very narrow strip.
  static const double _maxFadeExtent = 0.45;

  /// Read here rather than inside the callbacks: the reveal and the pill
  /// transitions run outside build, and the tokens' own guidance is to collapse
  /// the duration and keep the curve when the platform asks for less motion.
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void initState() {
    super.initState();
    _pillKeys = _keysFor(widget.options.length);
    _scroll.addListener(_syncEdges);
    // Metrics do not exist until the first layout, so the initial reveal and the
    // initial fade state both have to wait for it. The reveal is unanimated: the
    // strip is entering already on its selection, not moving to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealSelected(animate: false);
      _syncEdges();
    });
  }

  @override
  void didUpdateWidget(covariant TabStrip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _pillKeys = _keysFor(widget.options.length);
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());
    }
    if (oldWidget.selected != widget.selected) {
      _revealSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncEdges);
    _scroll.dispose();
    super.dispose();
  }

  static List<GlobalKey> _keysFor(int count) =>
      List<GlobalKey>.generate(count, (_) => GlobalKey());

  /// Brings the selected pill into view, centred. Centring rather than "scroll
  /// only if off screen" is deliberate: it is what Flutter's own tab bar does, it
  /// keeps the selected pill away from the fading edge, and it makes the
  /// selection change visible even when the pill was already on screen.
  ///
  /// A live selection change is deferred by one frame. That is not a style
  /// choice: the change arrives through [didUpdateWidget], which runs inside the
  /// parent's build, and a scroll activity started at that point does not
  /// animate at all (measured: the position stays exactly where it was, so the
  /// strip never follows the selection). Deferring costs one frame of the
  /// animation, which starts as the new selection paints, and is invisible.
  void _revealSelected({required bool animate}) {
    final index =
        widget.options.indexWhere((option) => option.value == widget.selected);
    // `indexWhere` returns -1 for a selection that is not among the options, and
    // an empty strip has no key at any index.
    if (index < 0 || index >= _pillKeys.length) return;
    final pillContext = _pillKeys[index].currentContext;
    if (pillContext == null) return;

    if (!animate) {
      // The first layout path, already inside a post-frame callback: a jump has
      // no activity to lose, so it can run now.
      _scrollIntoView(pillContext, animate: false);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pillContext.mounted) return;
      _scrollIntoView(pillContext, animate: true);
    });
  }

  void _scrollIntoView(BuildContext pillContext, {required bool animate}) {
    Scrollable.ensureVisible(
      pillContext,
      alignment: 0.5,
      duration: animate ? _motionDuration : Duration.zero,
      curve: ZplayMotion.standard,
    );
  }

  Duration get _motionDuration =>
      _reduceMotion ? Duration.zero : ZplayMotion.base;

  void _syncEdges() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final atStart = position.pixels <= _edgeTolerance;
    final atEnd = position.pixels >= position.maxScrollExtent - _edgeTolerance;
    if (atStart == _atStart && atEnd == _atEnd) return;
    setState(() {
      _atStart = atStart;
      _atEnd = atEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final duration = _motionDuration;

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) => _withEdgeFades(
            NotificationListener<ScrollMetricsNotification>(
              // Re-checked after metrics change, because a window resize can make
              // a row scrollable without any scroll event at all.
              onNotification: (notification) {
                _syncEdges();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: ZplaySpacing.s8,
                  children: [
                    for (var i = 0; i < widget.options.length; i++)
                      KeyedSubtree(
                        key: _pillKeys[i],
                        child: _Pill<T>(
                          option: widget.options[i],
                          selected: widget.options[i].value == widget.selected,
                          height: widget.height,
                          duration: duration,
                          tokens: tokens,
                          onSelected: () =>
                              widget.onSelected(widget.options[i].value),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            constraints.maxWidth,
          ),
        ),
      ),
    );
  }

  /// Fades the row into the strip instead of clipping it, and only on the sides
  /// that have somewhere to scroll to. A `ShaderMask` with [BlendMode.dstIn] is
  /// what lets the fade reach the pills themselves rather than the strip
  /// background, which a cut-off gradient rectangle would not do.
  Widget _withEdgeFades(Widget child, double width) {
    final leading = !_atStart;
    final trailing = !_atEnd;
    // An unbounded width means the strip is inside a row that sizes to content,
    // and a gradient over an infinite extent is meaningless.
    if ((!leading && !trailing) || !width.isFinite || width <= 0) return child;

    final fade = (ZplaySpacing.s16 / width).clamp(0.0, _maxFadeExtent);
    final colors = <Color>[];
    final stops = <double>[];
    if (leading) {
      colors.addAll(const [Colors.transparent, Colors.white]);
      stops.addAll([0, fade]);
    }
    if (trailing) {
      // A one-sided fade still needs an opaque anchor at its near end, or the
      // gradient would interpolate from the first stop onwards.
      if (!leading) {
        colors.add(Colors.white);
        stops.add(0);
      }
      colors.addAll(const [Colors.white, Colors.transparent]);
      stops.addAll([1 - fade, 1]);
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) =>
          LinearGradient(colors: colors, stops: stops).createShader(rect),
      child: child,
    );
  }
}

/// One pill: label, optional icon, and the whole hit target.
class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.option,
    required this.selected,
    required this.height,
    required this.duration,
    required this.tokens,
    required this.onSelected,
  });

  final TabStripOption<T> option;
  final bool selected;
  final double height;
  final Duration duration;
  final ZplayTokens tokens;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      // Own the pill: without excluding the descendants the label and the icon
      // are announced as separate items with no button or selected state on
      // either, and the tap action would be dropped along with them.
      excludeSemantics: true,
      onTap: onSelected,
      child: FocusableCard(
        onTap: onSelected,
        builder: (context, state) {
          final foreground = selected
              ? tokens.onAccent
              : state.highlighted
                  ? tokens.textPrimary
                  : tokens.textSecondary;

          return Stack(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: ZplayMotion.standard,
                height: height,
                padding:
                    const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16),
                decoration: BoxDecoration(
                  // The unselected pill is a raised chip rather than a hole, so
                  // it stays legible on a page background that is not the canvas.
                  color: selected ? tokens.accent : tokens.surfaceRaised,
                  borderRadius: ZplayRadius.fullAll,
                  border: Border.all(
                    color: selected ? Colors.transparent : tokens.borderDefault,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(option.icon,
                          size: ZplaySpacing.s16, color: foreground),
                      const SizedBox(width: ZplaySpacing.s8),
                    ],
                    Text(
                      option.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: (selected
                              ? ZplayType.label.copyWith(
                                  weight: FontWeight.w600,
                                )
                              : ZplayType.label)
                          .toStyle(color: foreground),
                    ),
                  ],
                ),
              ),
              // Painted over the pill and not as a border on it, for two
              // reasons: a border would resize the pill when focus arrives, and
              // the shared [CardFocusRing] is accent-coloured, which is invisible
              // against the accent fill of the selected pill. Primary text reads
              // against both the fill and the raised chip.
              if (state.focused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: ZplayRadius.fullAll,
                        border: Border.all(
                          color: tokens.textPrimary,
                          width: ZplaySpacing.s2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
