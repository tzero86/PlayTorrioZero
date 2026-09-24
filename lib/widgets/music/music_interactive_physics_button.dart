import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/music/music_settings.dart';
import '../common/focusable_card.dart';

class MusicInteractivePhysicsButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final MusicHoverEffect? effect;
  final Color? glowColor;
  final bool enabled;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const MusicInteractivePhysicsButton({
    super.key,
    required this.child,
    this.onTap,
    this.effect,
    this.glowColor,
    this.enabled = true,
    this.borderRadius,
    this.padding,
  });

  @override
  State<MusicInteractivePhysicsButton> createState() => _MusicInteractivePhysicsButtonState();
}

class _MusicInteractivePhysicsButtonState extends State<MusicInteractivePhysicsButton>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  late final AnimationController _rippleAnimController;
  late final Animation<double> _rippleCurve;

  @override
  void initState() {
    super.initState();
    _rippleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rippleCurve = CurvedAnimation(
      parent: _rippleAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _rippleAnimController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final offset = event.localPosition - center;
    final targetX = (offset.dx / (size.width / 2)).clamp(-1.0, 1.0);
    final targetY = (offset.dy / (size.height / 2)).clamp(-1.0, 1.0);

    if ((targetX - _tiltX).abs() > 0.05 || (targetY - _tiltY).abs() > 0.05) {
      setState(() {
        _tiltX = targetX;
        _tiltY = targetY;
      });
    }
  }

  void _onPointerExit() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
    _rippleAnimController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final activeEffect = widget.effect ?? MusicSettings.customHoverEffect.value;
    final palette = AppThemeService.currentPalette.value;
    final glow = widget.glowColor ?? palette.primaryColor;

    return FocusableCard(
      onTap: widget.onTap,
      // A null `onTap` is how callers disable a step button, so it must not
      // become a focus stop that does nothing when activated.
      enabled: widget.enabled && widget.onTap != null,
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      builder: (context, state) => MouseRegion(
        // Pointer-only: [FocusableCard] owns tap, activation and the cursor, but
        // `tilt3D` needs the raw hover position and the tilt has to reset when
        // the pointer leaves.
        onEnter: (_) {
          if (!widget.enabled) return;
          if (activeEffect == MusicHoverEffect.glassRipple) {
            _rippleAnimController.forward(from: 0.0);
          }
        },
        onHover: (event) {
          if (!widget.enabled || activeEffect != MusicHoverEffect.tilt3D) return;
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            _onPointerHover(event, renderBox.size);
          }
        },
        onExit: (_) => _onPointerExit(),
        child: Listener(
          // Pointer-only: the ripple beat that starts on the way down has no
          // keyboard equivalent, so it keeps its own raw pointer hook.
          onPointerDown: (_) {
            if (!widget.enabled) return;
            if (activeEffect == MusicHoverEffect.glassRipple) {
              _rippleAnimController.forward(from: 0.0);
            }
          },
          child: _buildPhysicsTransform(activeEffect, glow, state),
        ),
      ),
    );
  }

  Widget _buildPhysicsTransform(MusicHoverEffect effect, Color glow, CardInteraction state) {
    switch (effect) {
      case MusicHoverEffect.scaleBounce:
        final scale = state.pressed ? 0.88 : (state.highlighted ? 1.15 : 1.0);
        return AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: state.pressed ? 80 : 220),
          curve: state.pressed ? Curves.easeIn : Curves.elasticOut,
          child: widget.child,
        );

      case MusicHoverEffect.glowAura:
        final scale = state.pressed ? 0.92 : (state.highlighted ? 1.08 : 1.0);
        return AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(30),
              boxShadow: state.highlighted
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: state.pressed ? 0.85 : 0.6),
                        blurRadius: state.pressed ? 30 : 22,
                        spreadRadius: state.pressed ? 3 : 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: state.pressed ? 0.35 : 0.18),
                        blurRadius: 8,
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        );

      case MusicHoverEffect.glassRipple:
        final scale = state.pressed ? 0.93 : (state.highlighted ? 1.07 : 1.0);
        final radius = widget.borderRadius ?? BorderRadius.circular(24);

        return AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _rippleCurve,
            builder: (context, child) {
              final rippleVal = _rippleCurve.value;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: state.highlighted
                      ? [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.35 * (1.0 - rippleVal * 0.3)),
                            blurRadius: 16 + (rippleVal * 12),
                            spreadRadius: rippleVal * 2,
                          ),
                        ]
                      : const [],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (state.highlighted || _rippleAnimController.isAnimating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: state.highlighted ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                  color: Color.lerp(
                                    glow.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.9),
                                    rippleVal * 0.6,
                                  )!,
                                  width: 1.5 + (rippleVal * 0.8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.35 * (1.0 - rippleVal * 0.4)),
                                    glow.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    child!,
                  ],
                ),
              );
            },
            child: widget.child,
          ),
        );

      case MusicHoverEffect.tilt3D:
        final scale = state.pressed ? 0.90 : (state.highlighted ? 1.10 : 1.0);
        final rotateX = -_tiltY * (math.pi / 10);
        final rotateY = _tiltX * (math.pi / 10);

        return AnimatedContainer(
          duration: Duration(milliseconds: state.highlighted ? 60 : 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0025)
            ..rotateX(rotateX)
            ..rotateY(rotateY)
            ..scale(scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(30),
            boxShadow: state.highlighted
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: Offset(_tiltX * 8, _tiltY * 8),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        );
    }
  }
}
