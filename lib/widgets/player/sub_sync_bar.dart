import 'package:flutter/material.dart';
import 'player_glass.dart';
import '../common/focusable_card.dart';

/// Floating glass toolbar for quick live subtitle delay adjustment.
class SubSyncBar extends StatefulWidget {
  final double delaySec;
  final ValueChanged<double> onDelayChanged;
  final VoidCallback? onEnterTextSync;
  final bool isTextSyncAvailable;
  final VoidCallback onClose;
  final VoidCallback? onSave;

  const SubSyncBar({
    super.key,
    required this.delaySec,
    required this.onDelayChanged,
    this.onEnterTextSync,
    this.isTextSyncAvailable = true,
    required this.onClose,
    this.onSave,
  });

  @override
  State<SubSyncBar> createState() => _SubSyncBarState();
}

class _SubSyncBarState extends State<SubSyncBar> {
  late double _localDelay;
  late double _initialDelay;

  @override
  void initState() {
    super.initState();
    _localDelay = widget.delaySec;
    _initialDelay = widget.delaySec;
  }

  @override
  void didUpdateWidget(covariant SubSyncBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delaySec != widget.delaySec) {
      _localDelay = widget.delaySec;
    }
  }

  void _applyDelay(double value) {
    final rounded = (value * 100).round() / 100.0;
    setState(() => _localDelay = rounded);
    widget.onDelayChanged(rounded);
  }

  void _handleDiscard() {
    _applyDelay(_initialDelay);
    widget.onClose();
  }

  void _handleSave() {
    _initialDelay = _localDelay;
    widget.onSave?.call();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = ((_localDelay - _initialDelay).abs() > 0.01);
    final isNonZero = _localDelay.abs() > 0.01;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: PlayerGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left: Speech Text Sync button
            if (widget.onEnterTextSync != null) ...[
              Material(
                color: widget.isTextSyncAvailable
                    ? PlayerTheme.accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.isTextSyncAvailable ? widget.onEnterTextSync : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_fields_rounded,
                          size: 15,
                          color: widget.isTextSyncAvailable
                              ? PlayerTheme.accent
                              : PlayerTheme.inkSubtle,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Text Sync',
                          style: TextStyle(
                            color: widget.isTextSyncAvailable
                                ? PlayerTheme.ink
                                : PlayerTheme.inkSubtle,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Center: Stepper Buttons & Display Pill
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PlayerTheme.edgeSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepButton(
                    label: '−0.5s',
                    onTap: () => _applyDelay(_localDelay - 0.5),
                    isWide: true,
                  ),
                  _StepButton(
                    label: '−0.1s',
                    onTap: () => _applyDelay(_localDelay - 0.1),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: PlayerTheme.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isNonZero ? PlayerTheme.edge : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_localDelay >= 0 ? '+' : ''}${_localDelay.toStringAsFixed(2)}s',
                          style: TextStyle(
                            color: isNonZero ? PlayerTheme.accent : PlayerTheme.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isNonZero) ...[
                          const SizedBox(width: 6),
                          FocusableCard(
                            onTap: () => _applyDelay(0.0),
                            builder: (context, _) => Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.replay_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StepButton(
                    label: '+0.1s',
                    onTap: () => _applyDelay(_localDelay + 0.1),
                  ),
                  _StepButton(
                    label: '+0.5s',
                    onTap: () => _applyDelay(_localDelay + 0.5),
                    isWide: true,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right: Discard & Save Done & Close
            if (isDirty) ...[
              PlayerIconButton(
                size: 32,
                iconSize: 15,
                icon: const Icon(Icons.undo_rounded),
                tooltip: 'Discard changes',
                onPressed: _handleDiscard,
              ),
              const SizedBox(width: 4),
            ],

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: PlayerTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text(
                'Done',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              onPressed: _handleSave,
            ),
            const SizedBox(width: 4),

            PlayerIconButton(
              size: 32,
              iconSize: 15,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isWide;

  const _StepButton({
    required this.label,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: isWide ? 44 : 38,
          height: 28,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: PlayerTheme.inkMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
