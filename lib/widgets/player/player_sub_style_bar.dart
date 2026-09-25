import 'package:flutter/material.dart';
import '../../services/theme/design_tokens.dart';
import 'player_glass.dart';

/// Top floating subtitle appearance and size scaling toolbar.
class PlayerSubStyleBar extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onClose;

  const PlayerSubStyleBar({
    super.key,
    required this.scale,
    required this.onScaleChanged,
    required this.onClose,
  });

  static const List<double> _presets = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final percent = (scale * 100).round();
    final tokens = context.tokens;

    return Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 64,
        left: 20,
        right: 20,
      ),
      child: PlayerGlassCard(
        borderRadius: ZplayRadius.md,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: ZplaySpacing.s8,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Label
            Row(
              children: [
                Icon(
                  Icons.format_size_rounded,
                  size: 16,
                  color: PlayerTheme.accent,
                ),
                const SizedBox(width: ZplaySpacing.s8),
                Text(
                  'SUBTITLE SIZE',
                  style: ZplayType.overline
                      .copyWith(size: 10.5, weight: FontWeight.w700)
                      .toStyle(color: PlayerTheme.inkSubtle),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Stepper and Display
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: PlayerTheme.raised,
                borderRadius: ZplayRadius.smAll,
                border: Border.all(color: PlayerTheme.edgeSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: tokens.textPrimary,
                    ),
                    onPressed: () => onScaleChanged(((scale - 0.1) * 10).round() / 10.0),
                    tooltip: 'Decrease size',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 54),
                    alignment: Alignment.center,
                    child: Text(
                      '$percent%',
                      style: ZplayType.bodySmall
                          .copyWith(size: 12.5, weight: FontWeight.w700)
                          .toStyle(color: PlayerTheme.ink, tabular: true),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: tokens.textPrimary,
                    ),
                    onPressed: () => onScaleChanged(((scale + 0.1) * 10).round() / 10.0),
                    tooltip: 'Increase size',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Quick Preset Chips
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _presets.map((p) {
                final isSelected = (scale - p).abs() < 0.04;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PlayerToggleChip(
                    active: isSelected,
                    label: '${(p * 100).toInt()}%',
                    onClick: () => onScaleChanged(p),
                  ),
                );
              }).toList(),
            ),

            // Reset Button (if not default 1.0)
            if ((scale - 1.0).abs() > 0.04) ...[
              const SizedBox(width: ZplaySpacing.s4),
              PlayerIconButton(
                size: 32,
                iconSize: 15,
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Reset to 100%',
                backgroundColor: PlayerTheme.raised,
                borderRadius: ZplayRadius.sm,
                onPressed: () => onScaleChanged(1.0),
              ),
            ],

            const SizedBox(width: 6),
            SizedBox(
              height: ZplaySpacing.s20,
              child: VerticalDivider(color: tokens.borderDefault, width: 1),
            ),
            const SizedBox(width: 6),

            // Close Button
            PlayerIconButton(
              size: 32,
              iconSize: 15,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              backgroundColor: PlayerTheme.raised,
              borderRadius: ZplayRadius.sm,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    ),
  );
}
}
