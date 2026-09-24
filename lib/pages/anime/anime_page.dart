import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/anime_arabic/anime_arabic_service.dart';
import '../../services/content/content_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/dock_settings.dart';
import '../../services/theme/glass_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/anime/anime_slider_section.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/app_liquid_dock.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../settings/settings_page.dart';
import 'anime_details_page.dart';
import 'anime_stream_sheet.dart';
import 'anime_search_page.dart';
import '../anime_arabic/anime_arabic_details_page.dart';
import '../anime_arabic/anime_arabic_stream_sheet.dart';
import '../../services/storage/app_image_cache.dart';

class AnimePage extends StatefulWidget {
  const AnimePage({super.key});

  @override
  State<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends State<AnimePage> {
  final AnilistService _anilistService = AnilistService.instance;
  final AnimeLibraryService _libraryService = AnimeLibraryService.instance;
  final AnimeArabicService _arabicService = AnimeArabicService.instance;
  final ScrollController _scrollController = ScrollController();

  bool _isArabicMode = false;
  bool _loading = true;
  String? _error;

  // General Anime data
  List<AnimeMedia> _trending = [];
  List<AnimeMedia> _popularSeason = [];
  List<AnimeMedia> _topRated = [];
  List<AnimeMedia> _upcoming = [];
  List<AnimeMedia> _actionAnime = [];
  List<AnimeMedia> _romanceAnime = [];
  List<AnimeMedia> _fantasyAnime = [];
  List<AnimeMedia> _sciFiAnime = [];

  // Arabic Anime data
  HomeFeed? _arabicFeed;
  final Map<int, ArabicAnimeCard> _arabicCards = {};

  @override
  void initState() {
    super.initState();
    _libraryService.addListener(_onLibraryChanged);
    _libraryService.init();
    ContentSettings.adultEnabled.addListener(_onAdultContentChanged);
    _loadAnimeData();
  }

  @override
  void dispose() {
    ContentSettings.adultEnabled.removeListener(_onAdultContentChanged);
    _libraryService.removeListener(_onLibraryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  /// AniList queries embed the 18+ switch, so refetch the rows through the
  /// existing load path when it flips.
  void _onAdultContentChanged() {
    if (!mounted) return;
    _loadAnimeData();
  }

  Future<void> _loadAnimeData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isArabicMode) {
      try {
        final feed = await _arabicService.getHome();
        _arabicCards.clear();
        void registerCards(List<ArabicAnimeCard> list) {
          for (final c in list) {
            _arabicCards[c.slug.hashCode.abs()] = c;
          }
        }
        registerCards(feed.spotlight);
        registerCards(feed.recentEpisodes);
        registerCards(feed.trending);
        registerCards(feed.popularMovies);
        registerCards(feed.topSeasonal);
        registerCards(feed.seasonal);
        registerCards(feed.legendary);
        registerCards(feed.upcoming);

        if (mounted) {
          setState(() {
            _arabicFeed = feed;
            _loading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading Arabic Anime data: $e');
        if (mounted) {
          setState(() {
            _error = 'Failed to load Arabic Anime catalog. Check your internet connection.';
            _loading = false;
          });
        }
      }
      return;
    }

    try {
      final trendingFut = _anilistService.fetchTrendingAnime(perPage: 18);
      final seasonFut = _anilistService.fetchPopularThisSeason(perPage: 18);
      final topRatedFut = _anilistService.fetchTopRated(perPage: 18);
      final upcomingFut = _anilistService.fetchUpcomingNextSeason(perPage: 18);
      final actionFut = _anilistService.fetchByGenre('Action', perPage: 18);
      final romanceFut = _anilistService.fetchByGenre('Romance', perPage: 18);
      final fantasyFut = _anilistService.fetchByGenre('Fantasy', perPage: 18);
      final sciFiFut = _anilistService.fetchByGenre('Sci-Fi', perPage: 18);

      final results = await Future.wait([
        trendingFut,
        seasonFut,
        topRatedFut,
        upcomingFut,
        actionFut,
        romanceFut,
        fantasyFut,
        sciFiFut,
      ]);

      if (mounted) {
        final hasAnyData = results.any((list) => list.isNotEmpty);
        setState(() {
          _trending = results[0];
          _popularSeason = results[1];
          _topRated = results[2];
          _upcoming = results[3];
          _actionAnime = results[4];
          _romanceAnime = results[5];
          _fantasyAnime = results[6];
          _sciFiAnime = results[7];
          _loading = false;
          if (!hasAnyData) {
            _error = 'Failed to load Anime catalog. Please check your internet connection or retry.';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading Anime data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load Anime catalog. Check your internet connection.';
          _loading = false;
        });
      }
    }
  }

  void _onModeChanged(bool arabic) {
    if (_isArabicMode == arabic) return;
    setState(() {
      _isArabicMode = arabic;
    });
    _loadAnimeData();
  }

  void _playEpisode(AnimeMedia anime, int episodeNumber) {
    if (_isArabicMode || anime.isArabic || _arabicCards.containsKey(anime.id)) {
      final card = _arabicCards[anime.id] ??
          ArabicAnimeCard(
            slug: (anime.slug != null && anime.slug!.isNotEmpty)
                ? anime.slug!
                : anime.titleEnglish.toLowerCase().replaceAll(' ', '-'),
            title: anime.displayTitle,
            cover: anime.coverUrl,
          );
      _arabicService.getDetails(card.slug).then((details) {
        if (!mounted) return;
        final ep = details.episodes.firstWhere(
          (e) => e.number == episodeNumber,
          orElse: () => details.episodes.isNotEmpty
              ? details.episodes.first
              : ArabicEpisode(
                  number: episodeNumber,
                  title: 'الحلقة $episodeNumber',
                  encodedHref: '',
                  watchPath: '/e/${card.slug}-$episodeNumber#tok',
                ),
        );
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AnimeArabicStreamSheet(
            details: details,
            episode: ep,
            autoPlay: false,
          ),
        );
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimeStreamSheet(
        anime: anime,
        episodeNumber: episodeNumber,
        autoPlay: false,
      ),
    );
  }

  void _openDetails(AnimeMedia anime, [int? preferredEpisode]) {
    if (_isArabicMode || anime.isArabic || _arabicCards.containsKey(anime.id)) {
      final card = _arabicCards[anime.id] ??
          ArabicAnimeCard(
            slug: (anime.slug != null && anime.slug!.isNotEmpty)
                ? anime.slug!
                : anime.titleEnglish.toLowerCase().replaceAll(' ', '-'),
            title: anime.displayTitle,
            cover: anime.coverUrl,
          );
      final epNum = preferredEpisode ?? (anime.totalEpisodes > 0 ? anime.totalEpisodes : null);
      Navigator.push(
        context,
        CinematicSlideRoute(
          page: AnimeArabicDetailsPage(
            anime: card,
            initialEpisodeNumber: epNum,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      CinematicSlideRoute(
        page: AnimeDetailsPage(anime: anime),
      ),
    );
  }

  void _navigateToSettings(Offset? tapPosition) {
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: const SettingsPage(),
        tapPosition: tapPosition,
      ),
    );
  }

  void _navigateToSearch(Offset? tapPosition) {
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: AnimeSearchPage(initialArabicMode: _isArabicMode),
        tapPosition: tapPosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        final backgroundContent = AnimatedAmbientBackground(
          child: Stack(
            children: [
              // Main scrollable content
              if (_loading && (_isArabicMode ? _arabicFeed == null : _trending.isEmpty))
                Center(
                  child: CircularProgressIndicator(color: palette.primaryColor),
                )
              else if (_error != null && (_isArabicMode ? _arabicFeed == null : _trending.isEmpty))
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primaryColor,
                        ),
                        onPressed: _loadAnimeData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                RefreshIndicator(
                  color: palette.primaryColor,
                  backgroundColor: palette.cardBackgroundColor,
                  onRefresh: _loadAnimeData,
                  child: ListView(
                    controller: _scrollController,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      if (_isArabicMode) ...[
                        // 1. Arabic Hero Carousel (Matching Home Page)
                        if (_arabicFeed != null &&
                            (_arabicFeed!.spotlight.isNotEmpty || _arabicFeed!.trending.isNotEmpty))
                          _AnimeHeroCarousel(
                            animeList: (_arabicFeed!.spotlight.isNotEmpty
                                    ? _arabicFeed!.spotlight
                                    : _arabicFeed!.trending)
                                .take(6)
                                .map((c) => c.toAnimeMedia())
                                .toList(),
                            onWatchNow: (anime) => _playEpisode(anime, 1),
                            onDetailsTap: _openDetails,
                          ),

                        const SizedBox(height: 16),

                        // 2. Anime Continue Watching Slider
                        const ContinueWatchingSlider(
                          typeFilter: 'arabic_anime',
                          title: 'متابعة المشاهدة',
                        ),

                        const SizedBox(height: 8),

                        // 3. Arabic Sliders with Desktop Scroll Arrows
                        if (_arabicFeed != null) ...[
                          if (_arabicFeed!.recentEpisodes.isNotEmpty)
                            AnimeSliderSection(
                              title: '⚡ آخر الحلقات المعروضة',
                              subtitle: 'أحدث الحلقات المضافة المترجمة للعربية',
                              animeList: _arabicFeed!.recentEpisodes.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: (anime) => _openDetails(anime, anime.totalEpisodes > 0 ? anime.totalEpisodes : null),
                            ),
                          if (_arabicFeed!.trending.isNotEmpty)
                            AnimeSliderSection(
                              title: '🔥 الأكثر شهرة وتداولاً',
                              subtitle: 'الأنميات الأكثر مشاهدة حالياً',
                              animeList: _arabicFeed!.trending.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                          if (_arabicFeed!.popularMovies.isNotEmpty)
                            AnimeSliderSection(
                              title: '🎬 الأفلام الأكثر شعبية',
                              subtitle: 'أفلام الأنمي المميزة',
                              animeList: _arabicFeed!.popularMovies.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                          if (_arabicFeed!.topSeasonal.isNotEmpty)
                            AnimeSliderSection(
                              title: '👑 أفضل الأنميات',
                              subtitle: 'أنميات ذات تقييمات استثنائية',
                              animeList: _arabicFeed!.topSeasonal.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                          if (_arabicFeed!.seasonal.isNotEmpty)
                            AnimeSliderSection(
                              title: '🌟 أنميات موسمية',
                              subtitle: 'عروض الموسم الحالي',
                              animeList: _arabicFeed!.seasonal.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                          if (_arabicFeed!.legendary.isNotEmpty)
                            AnimeSliderSection(
                              title: '⚔️ أنميات أسطورية',
                              subtitle: 'أعمال خالدة يجب ألا تفوتك',
                              animeList: _arabicFeed!.legendary.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                          if (_arabicFeed!.upcoming.isNotEmpty)
                            AnimeSliderSection(
                              title: '🚀 المنتظرة قريباً',
                              subtitle: 'أنميات قادمة قريباً',
                              animeList: _arabicFeed!.upcoming.map((c) => c.toAnimeMedia()).toList(),
                              onAnimeTap: _openDetails,
                            ),
                        ],
                      ] else ...[
                        // 1. Full Bleed Hero Carousel (Matching Home Page)
                        if (_trending.isNotEmpty)
                          _AnimeHeroCarousel(
                            animeList: _trending.take(6).toList(),
                            onWatchNow: (anime) => _playEpisode(anime, 1),
                            onDetailsTap: _openDetails,
                          ),

                        const SizedBox(height: 16),

                        // 2. Anime Continue Watching Slider
                        const ContinueWatchingSlider(
                          typeFilter: 'general_anime',
                          title: 'Continue Watching',
                        ),

                        const SizedBox(height: 8),

                        // 3. Sliders with Desktop Scroll Arrows
                        AnimeSliderSection(
                          title: '🔥 Trending Anime',
                          subtitle: 'Top popular and trending series',
                          animeList: _trending,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '🌟 Popular This Season (${AnilistService.currentSeason()})',
                          subtitle: 'Currently airing hits',
                          animeList: _popularSeason,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '⭐ All-Time Masterpieces',
                          subtitle: 'Critically acclaimed top rated anime',
                          animeList: _topRated,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '🚀 Anticipated Next Season',
                          subtitle: 'Upcoming anime you cannot miss',
                          animeList: _upcoming,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '⚔️ Action & Adventure',
                          subtitle: 'High octane battles and epic journeys',
                          animeList: _actionAnime,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '💖 Romance & Drama',
                          subtitle: 'Heartfelt emotional stories',
                          animeList: _romanceAnime,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '🔮 Fantasy & Isekai',
                          subtitle: 'Magical realms and alternate worlds',
                          animeList: _fantasyAnime,
                          onAnimeTap: _openDetails,
                        ),
                        AnimeSliderSection(
                          title: '🤖 Sci-Fi & Cyberpunk',
                          subtitle: 'Futuristic technologies and dystopian worlds',
                          animeList: _sciFiAnime,
                          onAnimeTap: _openDetails,
                        ),
                      ],

                      SizedBox(height: 110.0 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
            ],
          ),
        );

        final overlayChildren = <Widget>[
          // Floating Glass App Bar (Home Page Style)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _AnimeGlassAppBar(
              topPadding: topPadding,
              isArabicMode: _isArabicMode,
              onModeChanged: _onModeChanged,
              onSearchTap: _navigateToSearch,
              onSettingsTap: _navigateToSettings,
            ),
          ),

          // Custom Scroll Track (Matching Home Page)
          if (MediaQuery.sizeOf(context).width > 800)
            Positioned(
              right: 24,
              bottom: 40,
              child: CustomScrollTrack(controller: _scrollController),
            ),

          // Liquid Dock Navbar (Home Page Style)
          Positioned(
            bottom: 12.0 + MediaQuery.paddingOf(context).bottom,
            left: 0,
            right: 0,
            child: Center(
              child: AppLiquidDock(
                currentDestination: DockItemKey.anime,
                onSettingsTap: () => _navigateToSettings(null),
                onSearchTap: () => _navigateToSearch(null),
              ),
            ),
          ),
        ];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ValueListenableBuilder<bool>(
            valueListenable: GlassSettings.enabled,
            builder: (context, enabled, _) {
              final overlays = Stack(children: overlayChildren);
              if (enabled) {
                return LiquidGlassView(
                  realTimeCapture: true,
                  useSync: true,
                  pixelRatio: 0.85,
                  refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
                  regionCapture: true,
                  backgroundWidget: backgroundContent,
                  child: overlays,
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: backgroundContent),
                  ...overlayChildren,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted Glass App Bar for Anime (Matching Home Page GlassAppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimeGlassAppBar extends StatelessWidget {
  final double topPadding;
  final bool isArabicMode;
  final ValueChanged<bool> onModeChanged;
  final void Function(Offset?) onSearchTap;
  final void Function(Offset?) onSettingsTap;

  const _AnimeGlassAppBar({
    required this.topPadding,
    required this.isArabicMode,
    required this.onModeChanged,
    required this.onSearchTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 700;
    final isMobile = MediaQuery.sizeOf(context).width < 430;

    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding + 10,
          bottom: 14,
          left: isMobile ? 8 : 20,
          right: 8,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF5080A0F), Color(0xE6080A0F)],
          ),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 4),

              // Logo
              Image.asset(
                'assets/icon_small.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  text: 'ZPlay ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(
                      text: isArabicMode ? 'Anime • Arabic' : 'Anime',
                      style: TextStyle(
                        color: AppThemeService.currentPalette.value.primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),

            // Mode Switcher (General Anime vs Arabic Anime)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton(
                    label: isDesktop ? '🇯🇵 General' : '🇯🇵',
                    isActive: !isArabicMode,
                    onTap: () => onModeChanged(false),
                  ),
                  _buildModeButton(
                    label: isDesktop ? '🇸🇦 Arabic Anime' : '🇸🇦',
                    isActive: isArabicMode,
                    onTap: () => onModeChanged(true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Search Button
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 25,
                  ),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final offset = box?.localToGlobal(box.size.center(Offset.zero));
                    onSearchTap(offset);
                  },
                );
              },
            ),

            // Settings Button
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 24,
                  ),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final offset = box?.localToGlobal(box.size.center(Offset.zero));
                    onSettingsTap(offset);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return FocusableCard(
      onTap: onTap,
      builder: (_, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppThemeService.currentPalette.value.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-Bleed Anime Hero Carousel (Matching Home Page _HeroCarousel)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimeHeroCarousel extends StatefulWidget {
  final List<AnimeMedia> animeList;
  final Function(AnimeMedia) onWatchNow;
  final Function(AnimeMedia) onDetailsTap;

  const _AnimeHeroCarousel({
    required this.animeList,
    required this.onWatchNow,
    required this.onDetailsTap,
  });

  @override
  State<_AnimeHeroCarousel> createState() => _AnimeHeroCarouselState();
}

class _AnimeHeroCarouselState extends State<_AnimeHeroCarousel> {
  static const _rotateEvery = Duration(seconds: 8);
  final PageController _pageController = PageController();

  Timer? _timer;
  int _index = 0;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.animeList.length < 2) return;
    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % widget.animeList.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseTimer() => _timer?.cancel();

  void _goTo(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  double _heroHeight(double screenWidth, double screenHeight) {
    if (screenWidth < 600) {
      return (screenHeight * 0.68).clamp(460.0, 640.0);
    } else if (screenWidth < 1100) {
      return (screenHeight * 0.70).clamp(520.0, 740.0);
    } else {
      // Maximized / Widescreen Desktop: give generous height
      final targetHeight = screenHeight * 0.82;
      return targetHeight.clamp(620.0, 1050.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = _heroHeight(screenWidth, screenHeight);

    if (widget.animeList.isEmpty) return SizedBox(height: heroHeight);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _pauseTimer();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _startTimer();
      },
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.animeList.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final anime = widget.animeList[i];
                return _AnimeHeroSlide(
                  anime: anime,
                  screenWidth: screenWidth,
                  onWatchNow: () => widget.onWatchNow(anime),
                  onDetailsTap: () => widget.onDetailsTap(anime),
                );
              },
            ),

            // Dot indicators
            if (widget.animeList.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.animeList.length, (i) {
                    final active = i == _index;
                    return FocusableCard(
                      onTap: () => _goTo(i),
                      builder: (_, state) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: active
                              ? AppThemeService.currentPalette.value.primaryColor
                              : Colors.white.withValues(alpha: 0.30),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppThemeService.currentPalette.value.primaryColor
                                        .withValues(alpha: 0.55),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Desktop Hover Arrows
            if (widget.animeList.length > 1 &&
                _isHovering &&
                screenWidth > 600) ...[
              if (_index > 0)
                Positioned(
                  left: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => _goTo(_index - 1),
                    ),
                  ),
                ),
              if (_index < widget.animeList.length - 1)
                Positioned(
                  right: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrow(
                      icon: Icons.arrow_forward_ios_rounded,
                      onTap: () => _goTo(_index + 1),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimeHeroSlide extends StatelessWidget {
  final AnimeMedia anime;
  final double screenWidth;
  final VoidCallback onWatchNow;
  final VoidCallback onDetailsTap;

  const _AnimeHeroSlide({
    required this.anime,
    required this.screenWidth,
    required this.onWatchNow,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = screenWidth < 600;
    final hasBanner = anime.bannerImage.trim().isNotEmpty;
    final bannerUrl = hasBanner ? anime.bannerImage : null;
    final posterUrl = anime.coverUrl.trim().isNotEmpty ? anime.coverUrl : null;
    final effectiveUrl = bannerUrl ?? posterUrl;
    // Layer 1 blur + foreground Layer 2 decode each URL once: same URL +
    // same memCacheWidth hits the shared ResizeImage cache entry.
    final heroCacheWidth = hasBanner ? 1280 : 512;
    Widget heroArtwork({
      required String url,
      required BoxFit fit,
      required Alignment alignment,
      FilterQuality filterQuality = FilterQuality.medium,
      Widget Function(BuildContext, String)? placeholder,
      Widget Function(BuildContext, String, Object)? errorWidget,
    }) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheManager: AppImageCache.manager,
        memCacheWidth: heroCacheWidth,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: placeholder ?? (_, __) => const SizedBox.shrink(),
        errorWidget: errorWidget ?? (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background Layers ──
        if (effectiveUrl != null && effectiveUrl.trim().isNotEmpty)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerWidth = constraints.maxWidth;
                final containerHeight = constraints.maxHeight;
                final containerAspect = containerWidth / containerHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: Ambient blurred background fill (eliminates all black bars)
                    ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 32,
                              sigmaY: 32,
                            ),
                            child: Transform.scale(
                              scale: 1.15,
                              child: heroArtwork(
                                url: effectiveUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.low,
                                placeholder: (_, __) => const ColoredBox(
                                    color: Color(0xFF080A0F)),
                                errorWidget: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFF080A0F)),
                              ),
                            ),
                          ),
                          ColoredBox(
                            color:
                                const Color(0xFF080A0F).withValues(alpha: 0.50),
                          ),
                        ],
                      ),
                    ),

                    // Layer 2: Crisp foreground artwork
                    if (hasBanner) ...[
                      // Landscape 16:9 banner available
                      if (containerAspect <= 1.78)
                        Positioned.fill(
                          child: heroArtwork(
                            url: bannerUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.15),
                          ),
                        )
                      else
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: (containerHeight * (16 / 9))
                              .clamp(0.0, containerWidth),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.0, 0.22],
                                colors: [Colors.transparent, Colors.white],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: heroArtwork(
                              url: bannerUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                    ] else ...[
                      // Portrait poster fallback (when no 16:9 banner is available)
                      if (containerAspect <= 1.2)
                        Positioned.fill(
                          child: heroArtwork(
                            url: effectiveUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        )
                      else
                        Positioned(
                          top: 40,
                          bottom: isCompact ? 70 : 60,
                          right: isCompact ? 24 : 72,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: heroArtwork(
                                  url: effectiveUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          )
        else
          const ColoredBox(color: Color(0xFF080A0F)),

        // Left horizontal wash for cinematic readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.38, 0.85],
                colors: [
                  const Color(0xFF080A0F).withValues(alpha: 0.95),
                  const Color(0xFF080A0F).withValues(alpha: 0.70),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top Gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  const Color(0xFF080A0F).withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom Gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.30, 0.75],
                colors: [
                  const Color(0xFF080A0F),
                  const Color(0xFF080A0F).withValues(alpha: 0.80),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content Overlay
        Positioned(
          left: isCompact ? 20 : 48,
          right: isCompact ? 20 : 48,
          bottom: isCompact ? 36 : 56,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : 680.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rating + Year + Episodes row
                  Row(
                    children: [
                      if (anime.averageScore > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 17,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                anime.formattedScore,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (anime.seasonYear > 0)
                        Text(
                          '${anime.seasonYear}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (anime.totalEpisodes > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          '${anime.totalEpisodes} Episodes',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (anime.studioName.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          anime.studioName,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    anime.displayTitle,
                    style: TextStyle(
                      fontSize: isCompact ? 30 : 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (anime.description.isNotEmpty) ...[
                    SizedBox(height: isCompact ? 12 : 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? double.infinity : 580,
                      ),
                      child: Text(
                        anime.description,
                        maxLines: isCompact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 14.5 : 15.5,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Genre chips
                  if (anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: anime.genres.take(4).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Action buttons (Matching Home Page)
                  SizedBox(height: isCompact ? 22 : 26),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onWatchNow,
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text(
                          'Watch Ep 1',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 18 : 28,
                            vertical: isCompact ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 12,
                          shadowColor: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 12),
                      OutlinedButton.icon(
                        onPressed: onDetailsTap,
                        icon: Icon(
                          Icons.info_outline_rounded,
                          size: isCompact ? 18 : 21,
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                        label: Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 14 : 15.5,
                            color: Colors.white.withValues(alpha: 0.80),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 24,
                            vertical: isCompact ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onTap: onTap,
      builder: (_, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state.highlighted
              ? Colors.black.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: state.highlighted
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: state.highlighted ? Colors.white : Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}
