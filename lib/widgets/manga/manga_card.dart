import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/manga/manga.dart';
import '../../pages/manga/manga_details_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/manga/manga_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../common/poster_skeleton.dart';
import '../../services/storage/app_image_cache.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card sizing — responsive breakpoints that scale with MangaCardDensity.
// ─────────────────────────────────────────────────────────────────────────────

class MangaCardSizing {
  final double cardWidth;
  final double posterHeight;
  final double totalHeight;
  final double spacing;
  final double sidePadding;

  MangaCardSizing({
    required this.cardWidth,
    required this.posterHeight,
    required this.totalHeight,
    required this.spacing,
    required this.sidePadding,
  });

  factory MangaCardSizing.fromWidth(double screenWidth, {MangaCardDensity density = MangaCardDensity.standard}) {
    double baseWidth;

    if (screenWidth < 360) {
      baseWidth = 138;
    } else if (screenWidth < 430) {
      baseWidth = 152;
    } else if (screenWidth < 700) {
      baseWidth = 162;
    } else if (screenWidth < 1000) {
      baseWidth = 176;
    } else if (screenWidth < 1400) {
      baseWidth = 190;
    } else {
      baseWidth = 205;
    }

    // Apply density scaling only when not standard (compact shrinks, cinematic grows)
    if (density == MangaCardDensity.compact) {
      baseWidth *= 0.85;
    } else if (density == MangaCardDensity.spacious) {
      baseWidth *= 1.20;
    }

    final cardWidth = baseWidth;
    final posterHeight = cardWidth * 1.48;
    final totalHeight = posterHeight + 66;

    return MangaCardSizing(
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      totalHeight: totalHeight,
      spacing: 16,
      sidePadding: 18,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manga Card
// ─────────────────────────────────────────────────────────────────────────────

class MangaCard extends StatefulWidget {
  final Manga manga;
  final VoidCallback? onTap;

  const MangaCard({
    super.key,
    required this.manga,
    this.onTap,
  });

  @override
  State<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<MangaCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final manga = widget.manga;
    final palette = AppThemeService.currentPalette.value;
    final showYear = MangaSettings.showMangaYear.value;
    final showBadge = MangaSettings.showContentTypeBadge.value;
    final ambientGlow = MangaSettings.ambientCardGlow.value;

    final genreText = manga.tags.isNotEmpty ? manga.tags.first : (manga.type.isNotEmpty ? manga.type : '');
    final metaText = [
      if (showYear && manga.year.isNotEmpty) manga.year,
      if (genreText.isNotEmpty) genreText,
    ].join(' • ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap ??
            () {
              Navigator.push(
                context,
                LiquidRevealRoute(
                  page: MangaDetailsPage(manga: manga),
                  tapPosition: null,
                ),
              );
            },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.97 : (_hovered ? 1.045 : 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster ──────────────────────────────────────────────
                Expanded(
                  child: _PosterFrame(
                    posterUrl: manga.coverNormal.isNotEmpty ? manga.coverNormal : manga.coverSmall,
                    hovered: _hovered,
                    contentType: manga.type.isNotEmpty ? manga.type : 'MANGA',
                    palette: palette,
                    showBadge: showBadge,
                    ambientGlow: ambientGlow,
                  ),
                ),
                
                // ── Title & Info ─────────────────────────────────────────
                const SizedBox(height: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 170),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    height: 1.25,
                    color: _hovered ? Colors.white : Colors.white.withOpacity(0.92),
                  ),
                  child: Text(
                    manga.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (metaText.isNotEmpty || showYear) ...[
                  const SizedBox(height: 3),
                  Text(
                    metaText.isNotEmpty ? metaText : 'Unknown Year',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterFrame extends StatelessWidget {
  final String? posterUrl;
  final bool hovered;
  final String contentType;
  final AppThemePalette palette;
  final bool showBadge;
  final bool ambientGlow;

  const _PosterFrame({
    required this.posterUrl,
    required this.hovered,
    required this.contentType,
    required this.palette,
    required this.showBadge,
    required this.ambientGlow,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(hovered ? 0.60 : 0.34),
            blurRadius: hovered ? 32 : 20,
            offset: Offset(0, hovered ? 18 : 10),
          ),
          if (hovered && ambientGlow)
            BoxShadow(
              color: palette.primaryColor.withOpacity(0.30),
              blurRadius: 34,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background fill
            const ColoredBox(
              color: Color(0xFF171A23),
            ),

            // Poster image (cached, decode bounded to ~3x display width)
            if (hasPoster)
              LayoutBuilder(
                builder: (context, constraints) {
                  final posterWidth = constraints.maxWidth;
                  final cacheWidth = posterWidth.isFinite && posterWidth > 0
                      ? (posterWidth * 3).round().clamp(96, 1280).toInt()
                      : 615;
                  return CachedNetworkImage(
                    imageUrl: posterUrl!,
                    cacheManager: AppImageCache.manager,
                    memCacheWidth: cacheWidth,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    placeholder: (context, url) => const PosterSkeleton(),
                    errorWidget: (context, url, error) => const MissingPoster());
                },
              )
            else
              const MissingPoster(),

            // Bottom vignette gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.00),
                      Colors.black.withOpacity(0.00),
                      Colors.black.withOpacity(0.20),
                    ],
                  ),
                ),
              ),
            ),

            // Hover highlight gradient
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0,
                duration: const Duration(milliseconds: 170),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.11),
                        Colors.transparent,
                        Colors.black.withOpacity(0.40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content type badge (top-left)
            if (showBadge)
              Positioned(
                left: 9,
                top: 9,
                child: AnimatedOpacity(
                  opacity: hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 170),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.40),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      contentType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Border glow on hover
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hovered
                          ? palette.primaryColor.withOpacity(0.50)
                          : Colors.white.withOpacity(0.08),
                      width: hovered ? 1.4 : 1,
                    ),
                  ),
                ),
              ),
            ),

            // Play button (bottom-right, hover reveal)
            Positioned(
              right: 10,
              bottom: 10,
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedScale(
                  scale: hovered ? 1 : 0.82,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF11131B),
                      size: 29,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MissingPoster extends StatelessWidget {
  const MissingPoster({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF232533),
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white.withOpacity(0.2),
          size: 40,
        ),
      ),
    );
  }
}
