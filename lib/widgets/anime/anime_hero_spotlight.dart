import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/anime/anime_media.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/storage/app_image_cache.dart';

class AnimeHeroSpotlight extends StatefulWidget {
  final List<AnimeMedia> featuredAnime;
  final Function(AnimeMedia, int episodeNumber) onPlayEpisode;
  final Function(AnimeMedia) onDetailsTap;
  final Function(AnimeMedia) onToggleWatchlist;
  final bool Function(int anilistId) isInWatchlist;

  const AnimeHeroSpotlight({
    super.key,
    required this.featuredAnime,
    required this.onPlayEpisode,
    required this.onDetailsTap,
    required this.onToggleWatchlist,
    required this.isInWatchlist,
  });

  @override
  State<AnimeHeroSpotlight> createState() => _AnimeHeroSpotlightState();
}

class _AnimeHeroSpotlightState extends State<AnimeHeroSpotlight> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    if (widget.featuredAnime.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.featuredAnime.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredAnime.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = screenWidth < 650;
    final bannerHeight = isMobile ? 320.0 : (screenHeight * 0.60).clamp(440.0, 680.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
      ),
      height: bannerHeight,
      child: ClipRRect(
        borderRadius: ZplayRadius.xlAll,
        child: Stack(
          children: [
            // Slide Page View
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.featuredAnime.length,
              itemBuilder: (context, index) {
                final anime = widget.featuredAnime[index];
                return Stack(
                  children: [
                    // Backdrop Image (fullscreen banner; bound, blur scrims need no more)
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: anime.backdropUrl,
                        cacheManager: AppImageCache.manager,
                        memCacheWidth: 1280,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.15),
                        placeholder: (_, __) => Container(
                          color: tokens.surface,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: tokens.surface,
                          child: Icon(
                            Icons.animation_rounded,
                            color: tokens.textDisabled,
                            size: 64,
                          ),
                        )),
                    ),

                    // Multi-stop Vignette Gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              tokens.bg.withValues(alpha: 0.94),
                              tokens.bg.withValues(alpha: 0.70),
                              tokens.bg.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              tokens.bg.withValues(alpha: 0.85),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Anime Information Overlay
                    Positioned(
                      left: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s32,
                      right: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s32,
                      bottom: isMobile ? ZplaySpacing.s20 : ZplaySpacing.s32,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 640.0,
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Pills Row
                          Wrap(
                            spacing: ZplaySpacing.s8,
                            runSpacing: ZplaySpacing.s8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ZplaySpacing.s8,
                                  vertical: ZplaySpacing.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.accent,
                                  borderRadius: ZplayRadius.smAll,
                                ),
                                child: Text(
                                  'FEATURED ANIME',
                                  style: ZplayType.overline.toStyle(
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              if (anime.averageScore > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: ZplaySpacing.s8,
                                    vertical: ZplaySpacing.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.bg.withValues(alpha: 0.65),
                                    borderRadius: ZplayRadius.smAll,
                                    border: Border.all(
                                      color: tokens.warning.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: tokens.warning,
                                        size: 14,
                                      ),
                                      const SizedBox(width: ZplaySpacing.s4),
                                      Text(
                                        '${anime.formattedScore} / 10',
                                        style: ZplayType.caption.toStyle(
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (anime.formattedSeasonYear.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: ZplaySpacing.s8,
                                    vertical: ZplaySpacing.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.textPrimary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: ZplayRadius.smAll,
                                  ),
                                  child: Text(
                                    anime.formattedSeasonYear,
                                    style: ZplayType.caption.toStyle(
                                      color: tokens.textEmphasis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: ZplaySpacing.s12),

                          // Title
                          Text(
                            anime.displayTitle,
                            style: ZplayType.display
                                .copyWith(size: isMobile ? 22 : 32)
                                .toStyle(color: tokens.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: ZplaySpacing.s8),

                          // Genres & Studio
                          if (anime.genres.isNotEmpty ||
                              anime.studioName.isNotEmpty)
                            Text(
                              [
                                if (anime.studioName.isNotEmpty)
                                  anime.studioName,
                                ...anime.genres.take(3),
                              ].join(' • '),
                              style: ZplayType.label
                                  .copyWith(size: isMobile ? 12 : 13)
                                  .toStyle(color: tokens.accent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: ZplaySpacing.s8),

                          // Synopsis snippet
                          if (!isMobile && anime.description.isNotEmpty) ...[
                            Text(
                              anime.description,
                              style: ZplayType.body.toStyle(
                                color: tokens.textEmphasis,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: ZplaySpacing.s16),
                          ],

                          // Action Buttons Row
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.accent,
                                  foregroundColor: tokens.onAccent,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: ZplayRadius.lgAll,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile
                                        ? ZplaySpacing.s16
                                        : ZplaySpacing.s24,
                                    vertical: isMobile
                                        ? ZplaySpacing.s8
                                        : ZplaySpacing.s12,
                                  ),
                                  shadowColor: tokens.accent.withValues(
                                    alpha: 0.5,
                                  ),
                                  elevation: 8,
                                ),
                                onPressed: () =>
                                    widget.onPlayEpisode(anime, 1),
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: tokens.onAccent,
                                  size: 20,
                                ),
                                label: Text(
                                  'Play Ep 1',
                                  style: ZplayType.label.toStyle(
                                    color: tokens.onAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: ZplaySpacing.s12),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: tokens.textPrimary
                                      .withValues(
                                        alpha: ZplayOpacity.overlayHover,
                                      ),
                                ),
                                icon: Icon(
                                  widget.isInWatchlist(anime.id)
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: widget.isInWatchlist(anime.id)
                                      ? tokens.success
                                      : tokens.textPrimary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    widget.onToggleWatchlist(anime),
                              ),
                              const SizedBox(width: ZplaySpacing.s8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: tokens.textPrimary
                                      .withValues(
                                        alpha: ZplayOpacity.overlayHover,
                                      ),
                                ),
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  color: tokens.textPrimary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    widget.onDetailsTap(anime),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

            // Bottom Right Page Indicator Dots
            if (widget.featuredAnime.length > 1)
              Positioned(
                right: ZplaySpacing.s24,
                bottom: ZplaySpacing.s20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.featuredAnime.length,
                    (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(
                          horizontal: ZplaySpacing.s4,
                        ),
                        width: isActive ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? tokens.accent : tokens.textDisabled,
                          borderRadius: ZplayRadius.xsAll,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
