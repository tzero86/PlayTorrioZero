import 'package:flutter/material.dart';

import '../../services/theme/design_tokens.dart';
import 'focusable_card.dart';

/// One option in a [SegmentedTabs] control.
@immutable
class SegmentedTabOption<T> {
  const SegmentedTabOption({
    required this.value,
    required this.label,
    this.count,
  });

  final T value;
  final String label;

  /// Shown under the label. Null hides the number, for callers whose data has
  /// no meaningful count — a wrong number is worse than none.
  final int? count;
}

/// A single-choice control: one track, equal-width segments, and one accent
/// indicator that slides to whichever segment is selected.
///
/// Built because the app hand-rolls this pattern repeatedly — `ChoiceChip` rows
/// in IPTV, audiobooks and books, text tabs with per-tab underlines on Home —
/// and every one of those is pointer-sized with no D-pad story. Two things are
/// deliberate here:
///
/// * **Equal-width segments.** The indicator is then placed arithmetically
///   instead of measured, so the slide cannot drift out of alignment as labels
///   or counts change.
/// * **Focus is a ring, selection is a fill.** A focused segment and a selected
///   one look different, which they did not before: on a remote you could move
///   onto a tab and not tell whether you were on the one already chosen.
class SegmentedTabs<T> extends StatelessWidget {
  final List<SegmentedTabOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Announced by screen readers as the name of the whole control.
  final String? semanticsLabel;

  /// Defaults to the 44px comfortable minimum target.
  final double height;

  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.semanticsLabel,
    this.height = 44,
  }) : assert(options.length > 1, 'a segmented control needs two or more tabs');

  static const double _trackRadius = 12;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = ZplayTokens.of(context);

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(_trackRadius),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(_alignX(selected), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / options.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius:
                              BorderRadius.circular(_trackRadius - _inset),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: _Segment(
                        option: option,
                        selected: option.value == selected,
                        radius: BorderRadius.circular(_trackRadius - _inset),
                        onTap: () => onSelected(option.value),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// -1 for the first segment and +1 for the last, matching the [Expanded] that
  /// shares its index.
  double _alignX(T value) {
    final index = options.indexWhere((option) => option.value == value);
    if (index < 0) return 0;
    return index * 2 / (options.length - 1) - 1;
  }
}

class _Segment<T> extends StatelessWidget {
  final SegmentedTabOption<T> option;
  final bool selected;
  final BorderRadius radius;
  final VoidCallback onTap;

  const _Segment({
    required this.option,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = ZplayTokens.of(context);
    final foreground =
        selected ? tokens.onAccent : Colors.white.withValues(alpha: 0.62);
    final secondary = selected
        ? tokens.onAccent.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      selected: selected,
      label: option.count == null
          ? option.label
          : '${option.label}, ${option.count} titles',
      // Own the whole segment: without excluding the descendants a screen
      // reader announces the label and the count as two separate items, with
      // no button or selected state on either. Re-stating the tap action here
      // is part of that — excluding descendants would otherwise drop it.
      onTap: onTap,
      excludeSemantics: true,
      child: FocusableCard(
        onTap: onTap,
        builder: (context, state) => CardFocusRing(
          focused: state.focused,
          radius: radius,
          child: Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(SegmentedTabs._inset),
            decoration: BoxDecoration(
              // Hover is suppressed on the selected segment so the accent fill
              // goes on meaning exactly one thing: the option you are on.
              color: selected || !state.highlighted
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: radius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  // A narrow segment must ellipsise rather than wrap, or it
                  // would push the control past its fixed height.
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (option.count != null)
                  Text(
                    '${option.count}',
                    // Tabular figures so the number cannot jitter.
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: secondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
