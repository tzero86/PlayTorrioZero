import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../pages/details/details_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/home/home_page_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../common/poster_skeleton.dart';
import '../../services/storage/app_image_cache.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card sizing — responsive breakpoints that mimic Stremio poster sizes.
//
//   Mobile  : ~138-162 px wide
//   Tablet  : ~176 px
//   Desktop : ~190-205 px
//
// Aspect ratio 1:1.48  (width × 1.48 = poster height).
// Total card height = poster + 66 px for title / year.
// ─────────────────────────────────────────────────────────────────────────────

class MovieCardSizing {
  final double cardWidth;
  final double posterHeight;
  final double totalHeight;
  final double spacing;
  final double sidePadding;

  MovieCardSizing({
    required this.cardWidth,
    required this.posterHeight,
    required this.totalHeight,
    required this.spacing,
    required this.sidePadding,
  });

  factory MovieCardSizing.fromWidth(double screenWidth) {
    double cardWidth;

    if (screenWidth < 360) {
      cardWidth = 138;
    } else if (screenWidth < 430) {
      cardWidth = 152;
    } else if (screenWidth < 700) {
      cardWidth = 162;
    } else if (screenWidth < 1000) {
      cardWidth = 176;
    } else if (screenWidth < 1400) {
      cardWidth = 190;
    } else {
      cardWidth = 205;
    }

    final density = HomePageSettings.cardDensity.value;
    if (density == CardDensity.compact) {
      cardWidth *= 0.85;
    } else if (density == CardDensity.cinematic) {
      cardWidth *= 1.20;
    }

    final posterHeight = cardWidth * 1.48;
    final totalHeight = posterHeight + 66;

    return MovieCardSizing(
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      totalHeight: totalHeight,
      spacing: 16,
      sidePadding: 18,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie Card
// ─────────────────────────────────────────────────────────────────────────────

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

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
                  page: DetailsPage(movie: movie),
                  tapPosition: null, // Let it center if tapPosition not easily available
                ),
              );
            },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.97 : (_hovered ? HomePageSettings.cardHoverZoom.value : 1.0),
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
                    posterUrl: movie.poster,
                    hovered: _hovered,
                    contentType: movie.type,
                    imdbRating: movie.imdbRating,
                  ),
                ),

                // ── Title ───────────────────────────────────────────────
                const SizedBox(height: 9),
                Text(
                  movie.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),

                // ── Year / type ─────────────────────────────────────────
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (movie.year != null && movie.year!.isNotEmpty)
                      Text(
                        movie.year!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.52),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (movie.year != null && movie.year!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.26),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Text(
                      movie.type == 'series' ? 'Series' : (movie.type == 'anime' ? 'Anime' : 'Movie'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.42),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poster Frame — the image container with overlays, shadows, and hover FX.
// ─────────────────────────────────────────────────────────────────────────────

class _PosterFrame extends StatelessWidget {
  final String? posterUrl;
  final bool hovered;
  final String contentType;
  final String? imdbRating;

  const _PosterFrame({
    required this.posterUrl,
    required this.hovered,
    required this.contentType,
    this.imdbRating,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;
    final palette = AppThemeService.currentPalette.value;

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
          if (hovered)
            BoxShadow(
              color: palette.primaryColor.withOpacity(0.35),
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
            Positioned(
              left: 9,
              top: 9,
              child: AnimatedOpacity(
                opacity: hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 170),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (contentType == 'series' || contentType == 'anime')
                        ? palette.accentColor.withOpacity(0.90)
                        : palette.primaryColor.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    contentType == 'series' ? 'SERIES' : (contentType == 'anime' ? 'ANIME' : 'MOVIE'),
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

            // Rating badge (top-right)
            if (imdbRating != null && imdbRating!.isNotEmpty)
              ValueListenableBuilder<bool>(
                valueListenable: HomePageSettings.showRating,
                builder: (context, showRating, _) {
                  if (!showRating) return const SizedBox.shrink();
                  final parsed = double.tryParse(imdbRating!);
                  final displayRating = parsed != null ? (parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(1)) : imdbRating!;
                  return Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xE6080A0F),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            displayRating,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                          ? Colors.white.withOpacity(0.28)
                          : Colors.white.withOpacity(0.08),
                      width: hovered ? 1.35 : 1,
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
