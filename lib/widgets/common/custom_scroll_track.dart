import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom Scroll Track
// ─────────────────────────────────────────────────────────────────────────────

class CustomScrollTrack extends StatefulWidget {
  final ScrollController controller;
  final Axis axis;
  final double length;

  const CustomScrollTrack({
    super.key,
    required this.controller,
    this.axis = Axis.vertical,
    this.length = 300.0,
  });

  @override
  State<CustomScrollTrack> createState() => _CustomScrollTrackState();
}

class _CustomScrollTrackState extends State<CustomScrollTrack> {
  // Drives the thumb through a listenable so scrolling does not `setState` the
  // whole track: rebuilding it re-ran the full-length BackdropFilter below.
  final ValueNotifier<double> _thumbFraction = ValueNotifier<double>(0.0);
  bool _isHovering = false;
  bool _isDragging = false;
  final double _thumbSize = 60.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateThumbFromScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateThumbFromScroll);
    _thumbFraction.dispose();
    super.dispose();
  }

  void _updateThumbFromScroll() {
    if (!widget.controller.hasClients || _isDragging) return;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return;

    _thumbFraction.value =
        (widget.controller.position.pixels / max).clamp(0.0, 1.0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.controller.hasClients) return;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return;

    final usableTrack = widget.length - _thumbSize;
    final delta = widget.axis == Axis.vertical ? details.delta.dy : details.delta.dx;

    _thumbFraction.value =
        (_thumbFraction.value + delta / usableTrack).clamp(0.0, 1.0);

    widget.controller.jumpTo(_thumbFraction.value * max);
  }

  void _scroll(double direction) {
    if (!widget.controller.hasClients) return;
    // For horizontal PageView, scroll by the viewport dimension instead of raw pixels, or 400 for lists
    final offsetStep = widget.axis == Axis.horizontal 
        ? widget.controller.position.viewportDimension
        : 400.0;
    
    final target = widget.controller.position.pixels + (direction * offsetStep);
    widget.controller.animateTo(
      target.clamp(0.0, widget.controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVert = widget.axis == Axis.vertical;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedOpacity(
        opacity: _isHovering || _isDragging ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isVert ? 16 : 8, 
                horizontal: isVert ? 8 : 16
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: _thumbFraction,
                builder: (context, fraction, _) {
                  final thumbPosition = fraction * (widget.length - _thumbSize);
                  return isVert
                      ? _buildVerticalLayout(thumbPosition)
                      : _buildHorizontalLayout(thumbPosition);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(double thumbPosition) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverArrow(
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: () => _scroll(-1),
        ),
        const SizedBox(height: 16),
        _buildTrackDragArea(thumbPosition, true),
        const SizedBox(height: 16),
        _HoverArrow(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: () => _scroll(1),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(double thumbPosition) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverArrow(
          icon: Icons.keyboard_arrow_left_rounded,
          onTap: () => _scroll(-1),
        ),
        const SizedBox(width: 16),
        _buildTrackDragArea(thumbPosition, false),
        const SizedBox(width: 16),
        _HoverArrow(
          icon: Icons.keyboard_arrow_right_rounded,
          onTap: () => _scroll(1),
        ),
      ],
    );
  }

  Widget _buildTrackDragArea(double thumbPosition, bool isVert) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: isVert ? (_) => setState(() => _isDragging = true) : null,
      onVerticalDragUpdate: isVert ? _onDragUpdate : null,
      onVerticalDragEnd: isVert ? (_) => setState(() => _isDragging = false) : null,
      onVerticalDragCancel: isVert ? () => setState(() => _isDragging = false) : null,
      
      onHorizontalDragStart: !isVert ? (_) => setState(() => _isDragging = true) : null,
      onHorizontalDragUpdate: !isVert ? _onDragUpdate : null,
      onHorizontalDragEnd: !isVert ? (_) => setState(() => _isDragging = false) : null,
      onHorizontalDragCancel: !isVert ? () => setState(() => _isDragging = false) : null,
      
      child: Container(
        height: isVert ? widget.length : 24, // Wider hit area
        width: isVert ? 24 : widget.length, 
        alignment: Alignment.center,
        child: Container(
          height: isVert ? widget.length : 6, // Visual track
          width: isVert ? 6 : widget.length,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: isVert ? thumbPosition : -2,
                left: isVert ? -2 : thumbPosition,
                bottom: isVert ? null : -2,
                right: isVert ? -2 : null,
                child: Container(
                  height: isVert ? _thumbSize : null,
                  width: isVert ? null : _thumbSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HoverArrow({required this.icon, required this.onTap});

  @override
  State<_HoverArrow> createState() => _HoverArrowState();
}

class _HoverArrowState extends State<_HoverArrow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovering ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Icon(
            widget.icon,
            color: _isHovering ? const Color(0xFF7C5CFF) : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}
