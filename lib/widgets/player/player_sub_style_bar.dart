import 'package:flutter/material.dart';
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

    return Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 64,
        left: 20,
        right: 20,
      ),
      child: PlayerGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                const SizedBox(width: 8),
                const Text(
                  'SUBTITLE SIZE',
                  style: TextStyle(
                    color: PlayerTheme.inkSubtle,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Stepper and Display
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: PlayerTheme.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PlayerTheme.edgeSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16, color: Colors.white),
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
                      style: const TextStyle(
                        color: PlayerTheme.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
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
              const SizedBox(width: 4),
              PlayerIconButton(
                size: 32,
                iconSize: 15,
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Reset to 100%',
                backgroundColor: PlayerTheme.raised,
                borderRadius: 8,
                onPressed: () => onScaleChanged(1.0),
              ),
            ],

            const SizedBox(width: 6),
            const SizedBox(
              height: 20,
              child: VerticalDivider(color: PlayerTheme.edgeSoft, width: 1),
            ),
            const SizedBox(width: 6),

            // Close Button
            PlayerIconButton(
              size: 32,
              iconSize: 15,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              backgroundColor: PlayerTheme.raised,
              borderRadius: 8,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    ),
  );
}
}
