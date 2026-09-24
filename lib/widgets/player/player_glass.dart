import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/theme/app_theme_service.dart';

/// Design tokens and glass styling for the modern video player UI.
class PlayerTheme {
  // Backgrounds & Surfaces
  static const Color canvas = Color(0xFF080C12);
  static const Color elevated = Color(0xF0101622);
  static const Color raised = Color(0x1AFFFFFF); // 10% white
  static const Color surfaceHover = Color(0x22FFFFFF); // 13% white

  // Borders
  static const Color edge = Color(0x1FFFFFFF); // 12% white
  static const Color edgeSoft = Color(0x12FFFFFF); // 7% white

  // Accents. Sourced from the user's palette rather than a literal: these were
  // pinned to #7C5CFF, which is only the *default* palette's primary, so
  // choosing any other palette left the whole player UI purple regardless.
  static Color get accent => AppThemeService.currentPalette.value.primaryColor;
  static Color get accentSoft => accent.withValues(alpha: 0.20);
  static Color get accentGlow => accent.withValues(alpha: 0.40);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Typography / Text Colors
  static const Color ink = Colors.white;
  static const Color inkMuted = Color(0xB3FFFFFF); // 70% white
  static const Color inkSubtle = Color(0x66FFFFFF); // 40% white
  static const Color inkDisabled = Color(0x33FFFFFF); // 20% white

  // Shadows
  static const List<BoxShadow> menuShadow = [
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, 24),
      blurRadius: 60,
      spreadRadius: -18,
    ),
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 10),
      blurRadius: 30,
      spreadRadius: -5,
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];
}

/// Floating Frosted Glass Card for menus, dialogs, and popovers.
class PlayerGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final List<BoxShadow>? shadows;
  final Color? backgroundColor;

  const PlayerGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.padding = EdgeInsets.zero,
    this.border,
    this.shadows,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? PlayerTheme.menuShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? PlayerTheme.elevated,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: PlayerTheme.edge, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Interactive button with smooth hover effects, tooltips, and badges.
class PlayerIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool active;
  final Color? activeColor;
  final bool showActiveBadge;
  final Color? badgeColor;
  final Color? backgroundColor;
  final double borderRadius;

  const PlayerIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.active = false,
    this.activeColor,
    this.showActiveBadge = false,
    this.badgeColor,
    this.backgroundColor,
    this.borderRadius = 9999,
  });

  @override
  State<PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<PlayerIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GlassSettings.enabled,
      builder: (context, glassEnabled, _) {
        return ValueListenableBuilder<int>(
          valueListenable: GlassSettings.styleRevision,
          builder: (context, _, __) {
            final hoverScaleVal = glassEnabled ? GlassSettings.hoverScale.value : 1.0;
            final effectiveScale = _hovered ? hoverScaleVal : 1.0;

            final bg = widget.active
                ? (widget.activeColor ?? Colors.white.withValues(alpha: 0.22))
                : (_hovered
                    ? (widget.backgroundColor ?? Colors.white.withValues(alpha: 0.12))
                    : (widget.backgroundColor ?? Colors.transparent));

            final iconContent = Stack(
              alignment: Alignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: widget.active ? Colors.white : (_hovered ? Colors.white : PlayerTheme.inkMuted),
                    size: widget.iconSize,
                  ),
                  child: widget.icon,
                ),
                if (widget.showActiveBadge)
                  Positioned(
                    top: widget.size * 0.2,
                    right: widget.size * 0.2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.badgeColor ?? PlayerTheme.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.badgeColor ?? PlayerTheme.accent).withValues(alpha: 0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );

            Widget buttonBody;
            if (glassEnabled) {
              final buttonStyle = GlassSettings.createButtonGlassStyle(
                cornerRadius: widget.borderRadius.clamp(0, widget.size / 2),
                customColor: widget.active
                    ? (widget.activeColor?.withValues(alpha: 0.35) ?? const Color(0x557C5CFF))
                    : (_hovered ? const Color(0x38FFFFFF) : const Color(0x18FFFFFF)),
              );

              buttonBody = RepaintBoundary(
                child: LiquidGlassLens(
                  style: buttonStyle,
                  useImpellerBackdrop: true,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: iconContent,
                  ),
                ),
              );
            } else {
              buttonBody = AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                child: iconContent,
              );
            }

            Widget button = MouseRegion(
              cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPressed,
                child: AnimatedScale(
                  scale: effectiveScale,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: buttonBody,
                ),
              ),
            );

            if (widget.tooltip != null) {
              return Tooltip(
                message: widget.tooltip!,
                waitDuration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: const Color(0xE6080C12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PlayerTheme.edgeSoft),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                child: button,
              );
            }

            return button;
          },
        );
      },
    );
  }
}

/// Rounded pill toggle chip for filters and options.
class PlayerToggleChip extends StatelessWidget {
  final bool active;
  final String label;
  final String? count;
  final VoidCallback onClick;
  final bool disabled;

  const PlayerToggleChip({
    super.key,
    required this.active,
    required this.label,
    this.count,
    required this.onClick,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onClick,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.35 : 1.0,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? PlayerTheme.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: active ? PlayerTheme.edge : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? PlayerTheme.ink : PlayerTheme.inkMuted,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  count!,
                  style: const TextStyle(
                    color: PlayerTheme.inkSubtle,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
