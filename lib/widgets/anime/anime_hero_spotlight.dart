import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/anime/anime_media.dart';
import '../../services/theme/app_theme_service.dart';
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = screenWidth < 650;
    final bannerHeight = isMobile ? 320.0 : (screenHeight * 0.60).clamp(440.0, 680.0);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      height: bannerHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
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
                          color: const Color(0xFF131522),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF131522),
                          child: const Icon(
                            Icons.animation_rounded,
                            color: Colors.white24,
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
                              Colors.black.withValues(alpha: 0.94),
                              Colors.black.withValues(alpha: 0.70),
                              Colors.black.withValues(alpha: 0.20),
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
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Anime Information Overlay
                    Positioned(
                      left: isMobile ? 18 : 36,
                      right: isMobile ? 18 : 36,
                      bottom: isMobile ? 20 : 36,
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
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemeService.currentPalette.value.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'FEATURED ANIME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              if (anime.averageScore > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFB800)
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFFFB800),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${anime.formattedScore} / 10',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (anime.formattedSeasonYear.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    anime.formattedSeasonYear,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            anime.displayTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 22 : 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Genres & Studio
                          if (anime.genres.isNotEmpty ||
                              anime.studioName.isNotEmpty)
                            Text(
                              [
                                if (anime.studioName.isNotEmpty)
                                  anime.studioName,
                                ...anime.genres.take(3),
                              ].join(' • '),
                              style: TextStyle(
                                color: AppThemeService.currentPalette.value.primaryColor
                                    .withValues(alpha: 0.95),
                                fontSize: isMobile ? 12 : 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),

                          // Synopsis snippet
                          if (!isMobile && anime.description.isNotEmpty) ...[
                            Text(
                              anime.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Action Buttons Row
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 22,
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                  shadowColor: AppThemeService.currentPalette.value.primaryColor
                                      .withValues(alpha: 0.5),
                                  elevation: 8,
                                ),
                                onPressed: () =>
                                    widget.onPlayEpisode(anime, 1),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Play Ep 1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.15),
                                ),
                                icon: Icon(
                                  widget.isInWatchlist(anime.id)
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: widget.isInWatchlist(anime.id)
                                      ? const Color(0xFF00D294)
                                      : Colors.white,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    widget.onToggleWatchlist(anime),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.15),
                                ),
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
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
                right: 24,
                bottom: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.featuredAnime.length,
                    (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppThemeService.currentPalette.value.primaryColor
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
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
