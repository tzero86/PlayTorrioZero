import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../pages/details/details_page.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/home/home_page_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../common/focusable_card.dart';
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
      spacing: ZplaySpacing.s16,
      sidePadding: ZplaySpacing.s16,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie Card
// ─────────────────────────────────────────────────────────────────────────────

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.movie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return FocusableCard(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              LiquidRevealRoute(
                page: DetailsPage(movie: movie),
                tapPosition: null, // Let it center if tapPosition not easily available
              ),
            );
          },
      builder: (_, state) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          scale: state.pressed ? 0.97 : (state.highlighted ? HomePageSettings.cardHoverZoom.value : 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, state.highlighted ? -6 : 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Poster ──────────────────────────────────────────────
                Expanded(
                  child: CardFocusRing(
                    focused: state.focused,
                    radius: ZplayRadius.mdAll,
                    child: _PosterFrame(
                      posterUrl: movie.poster,
                      highlighted: state.highlighted,
                      contentType: movie.type,
                      imdbRating: movie.imdbRating,
                    ),
                  ),
                ),

                // ── Title ───────────────────────────────────────────────
                const SizedBox(height: ZplaySpacing.s8),
                Text(
                  movie.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
                ),

                // ── Year / type ─────────────────────────────────────────
                const SizedBox(height: ZplaySpacing.s4),
                Row(
                  children: [
                    if (movie.year != null && movie.year!.isNotEmpty)
                      Text(
                        movie.year!,
                        style: ZplayType.label.toStyle(
                          color: tokens.textSecondary,
                        ),
                      ),
                    if (movie.year != null && movie.year!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZplaySpacing.s8,
                        ),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: tokens.textDisabled,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Text(
                      movie.type == 'series' ? 'Series' : (movie.type == 'anime' ? 'Anime' : 'Movie'),
                      style: ZplayType.label.toStyle(color: tokens.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Poster Frame — the image container with overlays, shadows, and hover FX.
// ─────────────────────────────────────────────────────────────────────────────

class _PosterFrame extends StatelessWidget {
  final String? posterUrl;
  final bool highlighted;
  final String contentType;
  final String? imdbRating;

  const _PosterFrame({
    required this.posterUrl,
    required this.highlighted,
    required this.contentType,
    this.imdbRating,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;
    final tokens = context.tokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: ZplayRadius.mdAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlighted ? 0.60 : 0.34),
            blurRadius: highlighted ? 32 : 20,
            offset: Offset(0, highlighted ? 18 : 10),
          ),
          if (highlighted)
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.35),
              blurRadius: 34,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ZplayRadius.mdAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background fill
            ColoredBox(
              color: tokens.surface,
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
                      Colors.transparent,
                      Colors.transparent,
                      tokens.bg.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),

            // Hover highlight gradient
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: highlighted ? 1 : 0,
                duration: const Duration(milliseconds: 170),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.textPrimary.withValues(alpha: 0.11),
                        Colors.transparent,
                        tokens.bg.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content type badge (top-left)
            Positioned(
              left: ZplaySpacing.s8,
              top: ZplaySpacing.s8,
              child: AnimatedOpacity(
                opacity: highlighted ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 170),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZplaySpacing.s8,
                    vertical: ZplaySpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: (contentType == 'series' || contentType == 'anime')
                        ? tokens.info.withValues(alpha: 0.90)
                        : tokens.accent.withValues(alpha: 0.90),
                    borderRadius: ZplayRadius.smAll,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    contentType == 'series' ? 'SERIES' : (contentType == 'anime' ? 'ANIME' : 'MOVIE'),
                    style: ZplayType.overline.toStyle(
                      color: tokens.textPrimary,
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
                    right: ZplaySpacing.s8,
                    top: ZplaySpacing.s8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZplaySpacing.s8,
                        vertical: ZplaySpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.bg.withValues(alpha: 0.90),
                        borderRadius: ZplayRadius.xsAll,
                        border: Border.all(color: tokens.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: tokens.warning, size: 12),
                          const SizedBox(width: ZplaySpacing.s4),
                          Text(
                            displayRating,
                            style: ZplayType.caption.toStyle(
                              color: tokens.textPrimary,
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
                    borderRadius: ZplayRadius.mdAll,
                    border: Border.all(
                      color: highlighted
                          ? tokens.borderStrong
                          : tokens.borderDefault,
                      width: highlighted ? 1.35 : 1,
                    ),
                  ),
                ),
              ),
            ),

            // Play button (bottom-right, hover reveal)
            Positioned(
              right: ZplaySpacing.s8,
              bottom: ZplaySpacing.s8,
              child: AnimatedOpacity(
                opacity: highlighted ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedScale(
                  scale: highlighted ? 1 : 0.82,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.textPrimary.withValues(alpha: 0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: tokens.bg,
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
