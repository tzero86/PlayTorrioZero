import 'package:flutter/material.dart';
import 'player_glass.dart';

/// Playback speed and sleep timer floating popover menu.
class PlayerSpeedMenu extends StatefulWidget {
  final double currentRate;
  final ValueChanged<double> onRateSelected;
  final VoidCallback onClose;

  const PlayerSpeedMenu({
    super.key,
    required this.currentRate,
    required this.onRateSelected,
    required this.onClose,
  });

  @override
  State<PlayerSpeedMenu> createState() => _PlayerSpeedMenuState();
}

class _PlayerSpeedMenuState extends State<PlayerSpeedMenu> {
  static const List<double> _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  int? _selectedSleepMinutes;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (320.0).clamp(240.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'PLAYBACK SPEED',
                  style: TextStyle(
                    color: PlayerTheme.inkSubtle,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              PlayerIconButton(
                size: 28,
                iconSize: 14,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Speed Preset List
          Column(
            children: _presets.map((rate) {
              final isSelected = (widget.currentRate - rate).abs() < 0.01;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    widget.onRateSelected(rate);
                    widget.onClose();
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? PlayerTheme.raised : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? PlayerTheme.edge : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rate == 1.0
                              ? 'Normal (1.0×)'
                              : '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)}×',
                          style: TextStyle(
                            color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: PlayerTheme.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),
          const Divider(color: PlayerTheme.edgeSoft, height: 1),
          const SizedBox(height: 10),

          // Sleep Timer Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'SLEEP TIMER',
              style: TextStyle(
                color: PlayerTheme.inkSubtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [15, 30, 45, 60].map((min) {
              final active = _selectedSleepMinutes == min;
              return PlayerToggleChip(
                active: active,
                label: '$min min',
                onClick: () {
                  setState(() {
                    _selectedSleepMinutes = active ? null : min;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
