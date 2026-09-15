import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/storage/app_image_cache.dart';

class IptvChannelCard extends StatefulWidget {
  final HardcodedChannel channel;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const IptvChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  State<IptvChannelCard> createState() => _IptvChannelCardState();
}

class _IptvChannelCardState extends State<IptvChannelCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final palette = AppThemeService.currentPalette.value;
    final primaryColor = ch.gradient.isNotEmpty ? ch.gradient.first : palette.primaryColor;
    final secondaryColor = ch.gradient.length > 1 ? ch.gradient.last : palette.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: RepaintBoundary(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            scale: _pressed ? 0.96 : (_hovered ? IptvSettings.cardHoverZoom.value : 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster / Gradient Box
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withValues(alpha: 0.85),
                            secondaryColor.withValues(alpha: 0.70),
                            const Color(0xFF0D1017),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _hovered
                                ? primaryColor.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.35),
                            blurRadius: _hovered ? 20 : 10,
                            offset: Offset(0, _hovered ? 8 : 4),
                          ),
                        ],
                        border: Border.all(
                          color: _hovered
                              ? primaryColor.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.12),
                          width: _hovered ? 1.5 : 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Ambient Pattern Lines / Glow
                            Positioned(
                              top: -20,
                              right: -20,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),

                            // Channel Icon / Logo / Short text
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 28, 14, 16),
                                child: SizedBox(
                                  width: 130,
                                  height: 100,
                                  child: ch.iconUrl != null && ch.iconUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: ch.iconUrl!,
                                          cacheManager: AppImageCache.manager,
                                          // Logo box is 130x100; bound to ~3x.
                                          memCacheWidth: 390,
                                          fit: BoxFit.contain,
                                          placeholder: (_, _) => Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white.withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, _, _) => _buildShortBadge(ch))
                                      : _buildShortBadge(ch),
                                ),
                              ),
                            ),

                            // Live Indicator Top-Left
                            if (IptvSettings.showHdBadge.value)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFF3B30).withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF3B30),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFFFF3B30),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Category Tag Top-Right
                            if (IptvSettings.showCategoryTag.value)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ch.category,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                            // Gloss overlay on hover
                            if (_hovered)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.12),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Title
                  const SizedBox(height: 8),
                  Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),

                  // Category & Stream tag
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (IptvSettings.showCategoryTag.value) ...[
                        Text(
                          ch.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.52),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        'HD Live',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortBadge(HardcodedChannel ch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            ch.short,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
