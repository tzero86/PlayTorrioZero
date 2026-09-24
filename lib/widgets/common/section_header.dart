import 'package:flutter/material.dart';

import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import 'focusable_card.dart';

/// Clean section header — title on left, optional count, optional trailing
/// widget / "See All" on right.
///
/// The count is a muted, tabular number rather than a badge. Accent is a signal
/// for state — what you are on, what is live — and a rail title is neither, so
/// three rails wearing no number and a fourth wearing an accent pill was both
/// inconsistent and decorative. Tabular figures keep the header from shifting
/// as the number changes.
///
/// "See All" is a [FocusableCard], so it is reachable with a remote and carries
/// the app's single focus ring. It was a [TextButton] with
/// `minimumSize: Size.zero` and `tapTargetSize: shrinkWrap`, which left a target
/// roughly 28px tall — well under the comfortable minimum, on the control most
/// likely to be wanted from across a room.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// How many items the section holds. Hidden when null: a rail that does not
  /// know its count should show nothing rather than guess.
  final int? count;

  final VoidCallback? onSeeAll;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.onSeeAll,
    this.trailing,
  });

  static const BorderRadius _actionRadius =
      BorderRadius.all(Radius.circular(10));

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            if (onSeeAll != null) const SizedBox(width: 8),
          ],
          if (onSeeAll != null)
            FocusableCard(
              onTap: onSeeAll,
              builder: (context, state) => CardFocusRing(
                focused: state.focused,
                radius: _actionRadius,
                child: AnimatedContainer(
                  duration: ZplayMotion.fast,
                  curve: ZplayMotion.standard,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: _actionRadius,
                    color: state.highlighted
                        ? primaryColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
