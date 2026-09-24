import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/player/skip_segment_model.dart';
import 'player_glass.dart';
import '../common/focusable_card.dart';

/// Timeline scrubber with buffered progress and interactive hover / drag preview.
class PlayerSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration? buffered;
  final ValueListenable<Duration>? positionListenable;
  final ValueListenable<Duration?>? bufferedListenable;
  final List<MediaSkipSegment> skipSegments;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<bool>? onScrubbingChanged;

  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.buffered,
    this.positionListenable,
    this.bufferedListenable,
    this.skipSegments = const [],
    required this.onSeek,
    this.onScrubbingChanged,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  bool _isHovered = false;
  bool _isScrubbing = false;
  double? _scrubFraction;
  double? _hoverFraction;
  bool _showRemainingTime = true;

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      return '-${_formatDuration(-d)}';
    }
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${d.inMinutes}:$seconds';
  }

  void _updateScrub(double localX, double width) {
    if (width <= 0) return;
    final frac = (localX / width).clamp(0.0, 1.0);
    setState(() {
      _scrubFraction = frac;
    });
  }

  void _commitSeek() {
    if (_scrubFraction != null && widget.duration.inMilliseconds > 0) {
      final targetMs = (_scrubFraction! * widget.duration.inMilliseconds).round();
      widget.onSeek(Duration(milliseconds: targetMs));
    }
    setState(() {
      _isScrubbing = false;
      _scrubFraction = null;
    });
    widget.onScrubbingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.positionListenable != null) {
      return ValueListenableBuilder<Duration>(
        valueListenable: widget.positionListenable!,
        builder: (context, pos, _) {
          if (widget.bufferedListenable != null) {
            return ValueListenableBuilder<Duration?>(
              valueListenable: widget.bufferedListenable!,
              builder: (context, buf, _) => _buildRow(context, pos, buf),
            );
          }
          return _buildRow(context, pos, widget.buffered);
        },
      );
    }
    return _buildRow(context, widget.position, widget.buffered);
  }

  Widget _buildRow(BuildContext context, Duration currentPosition, Duration? currentBuffered) {
    final totalMs = widget.duration.inMilliseconds;
    final currentMs = currentPosition.inMilliseconds;
    final currentFraction = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final bufferedMs = currentBuffered?.inMilliseconds ?? 0;
    final bufferedFraction = totalMs > 0 ? (bufferedMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final activeFraction = _scrubFraction ?? currentFraction;

    final remainingDuration = widget.duration - currentPosition;

    return Row(
      children: [
        // Time Start
        Container(
          constraints: const BoxConstraints(minWidth: 46),
          child: Text(
            _formatDuration(_scrubFraction != null
                ? Duration(milliseconds: (_scrubFraction! * totalMs).round())
                : currentPosition),
            style: const TextStyle(
              color: PlayerTheme.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Scrubber Track
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (e) => setState(() {
                  _isHovered = true;
                  _hoverFraction = (e.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                }),
                onHover: (e) => setState(() {
                  _hoverFraction = (e.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                }),
                onExit: (_) => setState(() {
                  _isHovered = false;
                  _hoverFraction = null;
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (e) {
                    setState(() {
                      _isScrubbing = true;
                    });
                    widget.onScrubbingChanged?.call(true);
                    _updateScrub(e.localPosition.dx, trackWidth);
                  },
                  onHorizontalDragUpdate: (e) {
                    _updateScrub(e.localPosition.dx, trackWidth);
                  },
                  onHorizontalDragEnd: (_) => _commitSeek(),
                  onTapDown: (e) {
                    setState(() {
                      _isScrubbing = true;
                    });
                    widget.onScrubbingChanged?.call(true);
                    _updateScrub(e.localPosition.dx, trackWidth);
                  },
                  onTapUp: (_) => _commitSeek(),
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track Background
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: (_isHovered || _isScrubbing) ? 8 : 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Stack(
                            children: [
                              // Buffered Track
                              if (bufferedFraction > 0)
                                FractionallySizedBox(
                                  widthFactor: bufferedFraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),

                              // Skip Segments Highlights (Intro, Recap, Credits)
                              if (totalMs > 0 && widget.skipSegments.isNotEmpty)
                                ...widget.skipSegments.map((seg) {
                                  final sFrac = ((seg.startMs ?? 0) / totalMs).clamp(0.0, 1.0);
                                  final eFrac = ((seg.endMs ?? totalMs) / totalMs).clamp(0.0, 1.0);
                                  final segWidth = ((eFrac - sFrac) * trackWidth).clamp(2.0, trackWidth);
                                  final isCredits = seg.type == 'credits';
                                  final color = isCredits
                                      ? const Color(0x9910B981)
                                      : const Color(0x99F59E0B);

                                  return Positioned(
                                    left: sFrac * trackWidth,
                                    width: segWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),

                        // Played Progress Bar (Gradient)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: (_isHovered || _isScrubbing) ? 8 : 6,
                          width: trackWidth * activeFraction,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [PlayerTheme.accent, const Color(0xFF9D84FF)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: PlayerTheme.accent.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        // Interactive Scrubber Thumb Dot
                        Positioned(
                          left: (trackWidth * activeFraction - ((_isHovered || _isScrubbing) ? 8 : 6))
                              .clamp(0.0, trackWidth - 16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: (_isHovered || _isScrubbing) ? 16 : 12,
                            height: (_isHovered || _isScrubbing) ? 16 : 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: PlayerTheme.accent.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Floating Timestamp Preview Bubble on Hover / Scrub
                        if ((_isHovered || _isScrubbing) && (_hoverFraction != null || _scrubFraction != null)) ...[
                          Positioned(
                            left: (trackWidth * (_scrubFraction ?? _hoverFraction!) - 28)
                                .clamp(0.0, trackWidth - 56),
                            top: -32,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xF0080C12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: PlayerTheme.edge),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                _formatDuration(
                                  Duration(
                                    milliseconds:
                                        ((_scrubFraction ?? _hoverFraction!) * totalMs).round(),
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        // Time End / Remaining Toggle
        FocusableCard(
          onTap: () => setState(() => _showRemainingTime = !_showRemainingTime),
          builder: (context, _) {
            return Container(
              constraints: const BoxConstraints(minWidth: 46),
              alignment: Alignment.centerRight,
              child: Text(
                _showRemainingTime
                    ? (_formatDuration(-remainingDuration))
                    : _formatDuration(widget.duration),
                style: const TextStyle(
                  color: PlayerTheme.inkMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
