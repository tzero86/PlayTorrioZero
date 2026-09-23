import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../models/movie/movie.dart';
import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/content/content_settings.dart';
import '../../widgets/anime/anime_slider_section.dart';
import '../anime/anime_details_page.dart';

import '../../models/movie/movie_detail.dart';
import '../../models/movie/movie_section.dart';
import '../details/details_page.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/metadata/metadata_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/home/home_page_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/home/continue_watching_slider.dart';
import '../../widgets/movie/movie_slider_section.dart';
import '../search/search_page.dart';
import '../ai/wewatch_quiz_page.dart';
import '../calendar/tv_calendar_page.dart';
import '../discover/discover_page.dart';
import '../settings/settings_page.dart';
import '../../services/theme/dock_settings.dart';
import '../../widgets/common/app_liquid_dock.dart';
import '../../services/updater/app_updater_service.dart';
import '../../widgets/updater/update_dialog.dart';
import '../../services/p2p/p2p_settings_service.dart';
import '../../widgets/p2p/p2p_warning_dialog.dart';
import 'package:flutter/services.dart';
import '../../services/window/window_service.dart';
import '../../services/storage/app_image_cache.dart';

enum _HomeFilter { all, movies, series, anime }

/// A lazily fetched anime discovery row for the Anime home tab.
class _AnimeRow {
  final String title;
  final String subtitle;
  final List<AnimeMedia> items;

  const _AnimeRow({
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _manager = AddonManager.instance;
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  final List<MovieSection> _sections = [];
  String? _error;

  List<Movie> _featuredMovies = [];
  _HomeFilter _selectedFilter = _HomeFilter.all;

  /// Anime discovery rows for the Anime tab, loaded on first use.
  final List<_AnimeRow> _animeRows = [];
  bool _animeLoading = false;
  bool _animeLoaded = false;

  /// Debounces [_refreshSimilarSections]: my-list / continue-watching /
  /// palette ticks fire on every change, and each refresh is 4 network
  /// fetches. Rapid ticks coalesce into one trailing refresh.
  Timer? _similarDebounce;
  bool _similarRefreshInFlight = false;

  /// Coalesces rapid 18+ switch flips into one trailing [_loadHome], mirroring
  /// [_similarDebounce] so a toggle never fans out into overlapping home loads.
  Timer? _adultReloadDebounce;
  Timer? _animeRefreshDebounce;
  List<MovieSection> get _visibleSections => _sections
      .map(_filterSection)
      .where((section) => section.movies.isNotEmpty)
      .toList();

  MovieSection _filterSection(MovieSection section, {_HomeFilter? filter}) {
    final activeFilter = filter ?? _selectedFilter;
    final movies = section.movies
        .where((movie) => _matchesFilter(movie, activeFilter))
        .toList();
    return MovieSection(
      title: section.title,
      subtitle: section.subtitle,
      contentType: section.contentType,
      addonBaseUrl: section.addonBaseUrl,
      catalog: section.catalog,
      movies: movies,
    );
  }

  /// [movies], [series] and [anime] partition [all]: every non-movie type —
  /// tv, anime, and whatever type a future addon invents — stays visible under
  /// Series, so no catalog entry can fall through both tabs. Anime is split out
  /// of Series so the dedicated tab can surface it the way the Anime page does.
  bool _matchesFilter(Movie movie, _HomeFilter filter) {
    final isAnime = _isAnime(movie);
    switch (filter) {
      case _HomeFilter.all:
        return true;
      case _HomeFilter.movies:
        return !isAnime && movie.type.trim().toLowerCase() == 'movie';
      case _HomeFilter.series:
        return !isAnime && movie.type.trim().toLowerCase() != 'movie';
      case _HomeFilter.anime:
        return isAnime;
    }
  }

  /// Mirrors the `anime` filter in [ContinueWatchingSlider] so both agree on
  /// what counts as anime.
  static bool _isAnime(Movie movie) {
    final id = movie.id;
    return movie.type.trim().toLowerCase() == 'anime' ||
        id.startsWith('anilist:') ||
        id.startsWith('arabic_anime:');
  }

  List<Movie> get _visibleFeaturedMovies => _pickFeatured(_visibleSections);

  void _setFilter(_HomeFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (filter == _HomeFilter.anime || filter == _HomeFilter.all) {
      _ensureAnimeRows();
    }
  }

  /// Pulls the same AniList rows the dedicated Anime page shows. Runs once per
  /// session, only when the Anime tab is opened, so regular home loads are
  /// untouched. A failed load leaves the tab empty and retries on next open.
  Future<void> _ensureAnimeRows() async {
    if (_animeLoaded || _animeLoading) return;
    setState(() => _animeLoading = true);

    final anilist = AnilistService.instance;
    try {
      final results = await Future.wait([
        anilist.fetchTrendingAnime(perPage: 18),
        anilist.fetchPopularThisSeason(perPage: 18),
        anilist.fetchTopRated(perPage: 18),
        anilist.fetchUpcomingNextSeason(perPage: 18),
        anilist.fetchByGenre('Action', perPage: 18),
        anilist.fetchByGenre('Romance', perPage: 18),
        anilist.fetchByGenre('Fantasy', perPage: 18),
        anilist.fetchByGenre('Sci-Fi', perPage: 18),
      ]);

      if (!mounted) return;
      final rows = <_AnimeRow>[
        _AnimeRow(
          title: '🔥 Trending Anime',
          subtitle: 'Top popular and trending series',
          items: results[0],
        ),
        _AnimeRow(
          title:
              '🌟 Popular This Season (${AnilistService.currentSeason()})',
          subtitle: 'Currently airing hits',
          items: results[1],
        ),
        _AnimeRow(
          title: '⭐ All-Time Masterpieces',
          subtitle: 'Critically acclaimed top rated anime',
          items: results[2],
        ),
        _AnimeRow(
          title: '🚀 Anticipated Next Season',
          subtitle: 'Upcoming anime you cannot miss',
          items: results[3],
        ),
        _AnimeRow(
          title: '⚔️ Action & Adventure',
          subtitle: 'High octane battles and epic journeys',
          items: results[4],
        ),
        _AnimeRow(
          title: '💖 Romance & Drama',
          subtitle: 'Heartfelt emotional stories',
          items: results[5],
        ),
        _AnimeRow(
          title: '🔮 Fantasy & Isekai',
          subtitle: 'Magical realms and alternate worlds',
          items: results[6],
        ),
        _AnimeRow(
          title: '🤖 Sci-Fi & Cyberpunk',
          subtitle: 'Futuristic technologies and dystopian worlds',
          items: results[7],
        ),
      ].where((row) => row.items.isNotEmpty).toList();

      setState(() {
        _animeRows
          ..clear()
          ..addAll(rows);
        _animeLoading = false;
        _animeLoaded = true;
      });
    } catch (e) {
      debugPrint('[HomePage] Anime rows failed: $e');
      if (!mounted) return;
      setState(() => _animeLoading = false);
    }
  }

  void _openAnimeDetails(AnimeMedia anime) {
    Navigator.push(
      context,
      CinematicSlideRoute(page: AnimeDetailsPage(anime: anime)),
    );
  }

  /// The anime rows and the catalog/recommendation caches were built under the
  /// old switch value, so invalidate the recommendation cache immediately.
  /// Rows themselves are kept visible (stale-while-refresh); only the affected
  /// rows are refreshed independently so the UI never goes blank.
  void _onAdultContentChanged() {
    if (!mounted) return;
    MetadataService.clearCatalogCache();
    HomePageSettings.clearRecommendationCache();
    _adultReloadDebounce?.cancel();
    _animeRefreshDebounce?.cancel();
    // Do NOT clear _animeRows here; keep stale rows visible. Instead, schedule a
    // per-row refresh so each anime row updates independently on the trailing debounce.
    _animeRefreshDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _ensureAnimeRows();
    });
  }

  static bool _hasShownIntro = false;
  late bool _showIntro;

  @override
  void initState() {
    super.initState();
    _showIntro = !_hasShownIntro;
    _hasShownIntro = true;

    HomePageSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
    MyListService.items.addListener(_onSettingsChanged);
    ContinueWatchingService.activeItems.addListener(_onSettingsChanged);
    ContentSettings.adultEnabled.addListener(_onAdultContentChanged);

    if (_showIntro) {
      _playIntro();
    }

    _loadHome();
    if (!_showIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runStartupDialogs();
      });
    }
  }

  static bool _hasRunStartupDialogs = false;
  static bool _hasAutoCheckedUpdate = false;

  Future<void> _runStartupDialogs() async {
    if (_hasRunStartupDialogs || !mounted) return;
    _hasRunStartupDialogs = true;

    // 1. Check & show Update dialog first
    await _checkAutoUpdate();
    if (!mounted) return;

    // 2. Check & show P2P warning dialog after update dialog
    await _checkP2pWarning();
  }

  Future<void> _checkAutoUpdate() async {
    if (_hasAutoCheckedUpdate) return;
    _hasAutoCheckedUpdate = true;
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdates();
      if (updateInfo != null && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      }
    } catch (e) {
      debugPrint('[HomePage] Auto update check failed: $e');
    }
  }

  Future<void> _checkP2pWarning() async {
    try {
      final shouldShow = await P2pSettingsService.shouldShowWarning();
      if (shouldShow && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => const P2pWarningDialog(),
        );
      }
    } catch (e) {
      debugPrint('[HomePage] P2P warning check failed: $e');
    }
  }

  @override
  void dispose() {
    _similarDebounce?.cancel();
    _adultReloadDebounce?.cancel();
    HomePageSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    MyListService.items.removeListener(_onSettingsChanged);
    ContinueWatchingService.activeItems.removeListener(_onSettingsChanged);
    ContentSettings.adultEnabled.removeListener(_onAdultContentChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    // Coalesce rapid my-list / continue-watching / palette ticks into one
    // trailing refresh; the immediate setState below keeps visuals instant.
    _similarDebounce?.cancel();
    _similarDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _similarRefreshInFlight) return;
      _refreshSimilarSections();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _injectSimilarSections({
    MovieSection? listSection,
    MovieSection? watchingSection,
    MovieSection? traktSection,
    MovieSection? simklSection,
  }) {
    if (!mounted) return;
    setState(() {
      _sections.removeWhere(
        (s) =>
            s.title.toLowerCase().startsWith('because you') ||
            s.catalog.id == 'bestsimilar' ||
            s.catalog.id == 'bestsimilar_list' ||
            s.catalog.id == 'bestsimilar_watching' ||
            s.catalog.id == 'trakt_recommendations' ||
            s.catalog.id == 'simkl_recommendations',
      );

      final toInsert = <MovieSection>[];
      if (watchingSection != null) toInsert.add(watchingSection);
      if (listSection != null) toInsert.add(listSection);
      if (traktSection != null) toInsert.add(traktSection);
      if (simklSection != null) toInsert.add(simklSection);

      if (toInsert.isEmpty) return;

      switch (HomePageSettings.similarPosition.value) {
        case SimilarSectionPosition.top:
          _sections.insertAll(0, toInsert);
          break;
        case SimilarSectionPosition.underCinemeta:
          final insertIdx = _sections.length > 1 ? 1 : _sections.length;
          _sections.insertAll(insertIdx, toInsert);
          break;
        case SimilarSectionPosition.middle:
          final insertIdx = _sections.length ~/ 2;
          _sections.insertAll(insertIdx, toInsert);
          break;
        case SimilarSectionPosition.bottom:
          _sections.addAll(toInsert);
          break;
      }
    });
  }

  Future<void> _refreshSimilarSections() async {
    if (_similarRefreshInFlight) return;
    _similarRefreshInFlight = true;
    try {
      final listFuture = HomePageSettings.fetchBestSimilarSection(
        forceRefresh: true,
      );
      final watchingFuture =
          HomePageSettings.fetchContinueWatchingSimilarSection(
        forceRefresh: true,
      );
      final traktFuture = HomePageSettings.fetchTraktRecommendationsSection(
        forceRefresh: true,
      );
      final simklFuture = HomePageSettings.fetchSimklRecommendationsSection(
        forceRefresh: true,
      );

      final results = await Future.wait([
        listFuture,
        watchingFuture,
        traktFuture,
        simklFuture,
      ]);
      _injectSimilarSections(
        listSection: results[0],
        watchingSection: results[1],
        traktSection: results[2],
        simklSection: results[3],
      );
    } finally {
      _similarRefreshInFlight = false;
    }
  }

  Future<void> _playIntro() async {
    // Show intro for 1.8 seconds so it feels fast and allows full dock shader pre-warming
    await Future.delayed(const Duration(milliseconds: 1800));

    // If still loading critical data, wait a bit longer (up to a timeout or until ready)
    while (_loading && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() => _showIntro = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runStartupDialogs();
      });
    }
  }

  Future<void> _loadHome() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _sections.clear();
      _featuredMovies.clear();
    });

    try {
      final listFuture = HomePageSettings.fetchBestSimilarSection();
      final watchingFuture =
          HomePageSettings.fetchContinueWatchingSimilarSection();
      final traktFuture = HomePageSettings.fetchTraktRecommendationsSection();
      final simklFuture = HomePageSettings.fetchSimklRecommendationsSection();

      await for (final section in _manager.streamHomeSections()) {
        if (!mounted) return;

        setState(() {
          _sections.add(section);

          // Re-pick featured movies with the new section.
          _featuredMovies = _pickFeatured(_sections);

          // Stop full-page loading as soon as we have enough to show the hero.
          if (_loading && _featuredMovies.isNotEmpty) {
            _loading = false;
          }
        });
      }

      // Inject recommendation sections (List, Continue Watching, Trakt, Simkl)
      final results = await Future.wait([
        listFuture,
        watchingFuture,
        traktFuture,
        simklFuture,
      ]);
      if (mounted) {
        _injectSimilarSections(
          listSection: results[0],
          watchingSection: results[1],
          traktSection: results[2],
          simklSection: results[3],
        );
      }

      // If we got through the whole stream and still loading (e.g., no addons worked)
      if (mounted && _loading) {
        setState(() => _loading = false);
      }

      // Anime discovery rows are part of All, but they are fetched in the
      // background so they never delay the usual home content.
      if (mounted && _selectedFilter == _HomeFilter.all) {
        unawaited(_ensureAnimeRows());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Picks a handful of varied movies to rotate through in the hero —
  /// one from each of the first few sections so it isn't just a wall of
  /// the same catalog, deduped by id+type.
  List<Movie> _pickFeatured(List<MovieSection> sections) {
    final featured = <Movie>[];
    final seen = <String>{};

    for (final section in sections) {
      for (final movie in section.movies.take(3)) {
        final key = '${movie.type}:${movie.id}';
        if (seen.add(key)) {
          featured.add(movie);
          break;
        }
      }
      if (featured.length >= 6) break;
    }

    // Fallback: if sections were too sparse to get variety, top up from
    // the first section's list.
    if (featured.length < 2 && sections.isNotEmpty) {
      for (final movie in sections.first.movies) {
        final key = '${movie.type}:${movie.id}';
        if (seen.add(key)) featured.add(movie);
        if (featured.length >= 6) break;
      }
    }

    return featured;
  }

  void _navigateToSettings(Offset? tapPosition) async {
    await Navigator.push(
      context,
      LiquidRevealRoute(page: const SettingsPage(), tapPosition: tapPosition),
    );
    // Reload when returning from settings (addons may have changed)
    _loadHome();
  }

  void _navigateToSearch(Offset? tapPosition) {
    Navigator.push(
      context,
      LiquidRevealRoute(page: const SearchPage(), tapPosition: tapPosition),
    );
  }

  /// Height of the floating glass app bar below `MediaQuery` top padding
  /// (10 top pad + 34 logo + 14 bottom pad).
  static const double _appBarHeight = 58;

  /// Above this width the filter tabs live in the app bar; below it they sit
  /// inline above the hero, where the bar has no room to spare.
  static const double _appBarFilterBreakpoint = 700;

  static bool _filtersInAppBar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _appBarFilterBreakpoint;

  Widget _buildFilterTabs() => _HomeFilterTabs(
    selected: _selectedFilter,
    onSelected: _setFilter,
  );

  /// ListView slot 0: spacing when the tabs moved into the app bar, the tabs
  /// themselves otherwise.
  Widget _buildFilterSlot(BuildContext context, double topPadding) {
    if (_filtersInAppBar(context)) {
      return SizedBox(height: topPadding + _appBarHeight + 8);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + _appBarHeight + 12, 20, 4),
      child: Align(alignment: Alignment.centerLeft, child: _buildFilterTabs()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final palette = AppThemeService.currentPalette.value;
    final visibleSections = _visibleSections;

    final isAnimeTab = _selectedFilter == _HomeFilter.anime;
    final isAllTab = _selectedFilter == _HomeFilter.all;
    // The Anime tab leads with anime rows; All appends them so its usual
    // order stays put. Movies/Series never show them.
    final animeRows = (isAnimeTab || isAllTab)
        ? _animeRows
        : const <_AnimeRow>[];
    final featured = _visibleFeaturedMovies;
    final hasContent =
        visibleSections.isNotEmpty || animeRows.isNotEmpty || _animeLoading;

    final animeRowWidgets = <Widget>[
      for (final row in animeRows)
        AnimeSliderSection(
          title: row.title,
          subtitle: row.subtitle,
          animeList: row.items,
          onAnimeTap: _openAnimeDetails,
        ),
    ];

    final slots = <Widget>[
      _buildFilterSlot(context, topPadding),
      if (!HomePageSettings.enableSpotlight.value)
        SizedBox(height: topPadding + 76)
      else if (isAnimeTab && featured.isEmpty)
        // Nothing to feature yet on the Anime tab: let the rows below start
        // right under the app bar instead of reserving an empty hero band.
        const SizedBox.shrink()
      else
        _HeroCarousel(movies: featured),
      // All keeps unfiltered recents so the row really is everything watched;
      // Movies/Series drop anime recents, the Anime tab keeps only those.
      ContinueWatchingSlider(
        typeFilter: switch (_selectedFilter) {
          _HomeFilter.anime => 'anime',
          _HomeFilter.all => null,
          _ => 'main',
        },
        title: 'Continue Watching',
      ),
      if (isAnimeTab && _animeLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (isAnimeTab) ...animeRowWidgets,
      if (!hasContent)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
          child: Center(
            child: Text(
              isAnimeTab
                  ? 'No anime available right now.'
                  : 'No titles match this filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            ),
          ),
        ),
      for (var i = 0; i < visibleSections.length; i++)
        ValueListenableBuilder<bool>(
          valueListenable: HomePageSettings.enableCalendar,
          builder: (context, calEnabled, _) {
            return MovieSliderSection(
              section: visibleSections[i],
              showCalendarButton:
                  calEnabled && i >= (visibleSections.length - 2),
            );
          },
        ),
      // All is a superset: anime discovery content trails the usual rows.
      if (!isAnimeTab) ...animeRowWidgets,
      SizedBox(height: 110.0 + MediaQuery.paddingOf(context).bottom),
    ];

    final backgroundContent = AnimatedAmbientBackground(
      child: Stack(
        children: [
          // ── Main scrollable content ──
          if (_loading && !_showIntro && _sections.isEmpty)
            Center(
              child: CircularProgressIndicator(color: palette.primaryColor),
            )
          else if (_error != null && _sections.isEmpty)
            ErrorView(error: _error, onRetry: _loadHome)
          else
            RefreshIndicator(
              color: palette.primaryColor,
              backgroundColor: palette.cardBackgroundColor,
              onRefresh: _loadHome,
              child: ListView.builder(
                controller: _scrollController,
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemCount: slots.length,
                itemBuilder: (context, index) => slots[index],
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: palette.scaffoldBackgroundColor,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final primaryFocus = FocusManager.instance.primaryFocus;
            if (primaryFocus != null && primaryFocus.context != null) {
              final focusedWidget = primaryFocus.context!.widget;
              if (focusedWidget is EditableText) {
                return KeyEventResult.ignored;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.keyF ||
                event.logicalKey == LogicalKeyboardKey.f11) {
              if (WindowService.instance.isDesktop) {
                WindowService.instance.toggleFullscreen();
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (WindowService.instance.isDesktop &&
                  WindowService.instance.isFullscreen) {
                WindowService.instance.exitFullscreen();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: _buildBody(backgroundContent, topPadding, context),
      ),
    );
  }

  /// Uses the same shader-free composition on every platform. This avoids
  /// capturing the scrolling page and keeps Skia and Impeller visually equal.
  Widget _buildBody(
    Widget backgroundContent,
    double topPadding,
    BuildContext context,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final overlayChildren = <Widget>[
      // ── Floating glass app bar ──
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _GlassAppBar(
          topPadding: topPadding,
          onSearchTap: _navigateToSearch,
          onSettingsTap: _navigateToSettings,
          filterTabs: _filtersInAppBar(context) ? _buildFilterTabs() : null,
        ),
      ),

      // ── Custom Scroll Track ──
      if (MediaQuery.sizeOf(context).width > 800) // Desktop only
        Positioned(
          right: 24,
          bottom: 40,
          child: _CustomScrollTrack(controller: _scrollController),
        ),

      // ── Liquid Dock Navbar ──
      Positioned(
        bottom: 12.0 + bottomInset,
        left: 0,
        right: 0,
        child: Center(
          child: AppLiquidDock(
            currentDestination: DockItemKey.home,
            onSettingsTap: () => _navigateToSettings(null),
            onSearchTap: () => _navigateToSearch(null),
          ),
        ),
      ),

      // ── Intro Splash Screen ──
      Positioned.fill(child: _buildIntroOverlay(context)),
    ];

    return ValueListenableBuilder<bool>(
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

        return Container(
          color: const Color(0xFF080A0F),
          child: Stack(
            children: [
              RepaintBoundary(child: backgroundContent),
              ...overlayChildren,
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntroOverlay(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleSize = (screenWidth * 0.08).clamp(40.0, 56.0);
    final subtitleSize = (screenWidth * 0.03).clamp(16.0, 20.0);
    final iconSize = (screenWidth * 0.12).clamp(48.0, 72.0);

    return IgnorePointer(
      ignoring: !_showIntro,
      child: AnimatedOpacity(
        opacity: _showIntro ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        child: Container(
          color: const Color(0xFF080A0F),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon_small.png',
                  width: iconSize * 1.5,
                  height: iconSize * 1.5,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'ZPlay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Cinema Universe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 2,
                  ),
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
// All / Movies / Series filter tabs — flat text with an underline indicator,
// sized to sit inside the glass app bar without competing with the hero.
// ─────────────────────────────────────────────────────────────────────────────

class _HomeFilterTabs extends StatelessWidget {
  final _HomeFilter selected;
  final ValueChanged<_HomeFilter> onSelected;

  const _HomeFilterTabs({required this.selected, required this.onSelected});

  static const _filters = <(_HomeFilter, String)>[
    (_HomeFilter.all, 'All'),
    (_HomeFilter.movies, 'Movies'),
    (_HomeFilter.series, 'Series'),
    (_HomeFilter.anime, 'Anime'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeService.currentPalette.value.primaryColor;
    return Semantics(
      container: true,
      label: 'Home content filter',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (filter, label) in _filters)
            _HomeFilterTab(
              label: label,
              selected: selected == filter,
              accent: accent,
              onTap: () => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _HomeFilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _HomeFilterTab({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          focusColor: Colors.white.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 2,
                  width: selected ? 18 : 0,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
// Frosted Glass App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  final double topPadding;
  final void Function(Offset?) onSearchTap;
  final void Function(Offset?) onSettingsTap;
  final Widget? filterTabs;

  const _GlassAppBar({
    required this.topPadding,
    required this.onSearchTap,
    required this.onSettingsTap,
    this.filterTabs,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding + 10,
          bottom: 14,
          left: 20,
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
            // Logo
            Image.asset(
              'assets/icon_small.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'ZPlay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // All / Movies / Series tabs (wide layouts only)
            if (filterTabs != null) ...[
              filterTabs!,
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ],
            // AI Taste Profile Quiz
            ValueListenableBuilder<bool>(
              valueListenable: HomePageSettings.enableAiQuiz,
              builder: (context, aiQuizEnabled, _) {
                if (!aiQuizEnabled) return const SizedBox.shrink();
                final palette = AppThemeService.currentPalette.value;
                return IconButton(
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    color: palette.primaryColor,
                    size: 22,
                  ),
                  tooltip: 'AI Taste Quiz',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WeWatchQuizPage(),
                      ),
                    );
                  },
                );
              },
            ),
            // TV Shows Airing Calendar
            ValueListenableBuilder<bool>(
              valueListenable: HomePageSettings.enableCalendar,
              builder: (context, calEnabled, _) {
                if (!calEnabled) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 22,
                  ),
                  tooltip: 'TV Airing Calendar',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TvCalendarPage()),
                    );
                  },
                );
              },
            ),
            // Discover Catalogs
            IconButton(
              icon: Icon(
                Icons.explore_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 23,
              ),
              tooltip: 'Discover Catalogs',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoverPage()),
                );
              },
            ),
            // Search
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
                    final offset = box?.localToGlobal(
                      box.size.center(Offset.zero),
                    );
                    onSearchTap(offset);
                  },
                );
              },
            ),
            // Settings
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                    size: 24,
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final offset = box?.localToGlobal(
                      box.size.center(Offset.zero),
                    );
                    onSettingsTap(offset);
                  },
                );
              },
            ),
            // Fullscreen Toggle (Desktops only)
            if (WindowService.instance.isDesktop)
              ValueListenableBuilder<bool>(
                valueListenable: WindowService.instance.isFullscreenNotifier,
                builder: (context, isFullscreen, _) {
                  return IconButton(
                    icon: Icon(
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: isFullscreen
                          ? const Color(0xFFFFB300)
                          : Colors.white.withValues(alpha: 0.75),
                      size: 24,
                    ),
                    tooltip: isFullscreen
                        ? 'Exit Fullscreen (F)'
                        : 'Fullscreen (F)',
                    onPressed: () => WindowService.instance.toggleFullscreen(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Carousel — rotates through a handful of featured titles.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCarousel extends StatefulWidget {
  final List<Movie> movies;

  const _HeroCarousel({required this.movies});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pageController = PageController();
  final Map<String, MovieDetail?> _detailsCache = {};

  Timer? _timer;
  int _index = 0;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    HomePageSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);

    if (widget.movies.isNotEmpty) {
      _fetchDetail(widget.movies.first);
      if (widget.movies.length > 1) _fetchDetail(widget.movies[1]);
    }
    _startTimer();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies) {
      _index = 0;
      _detailsCache.clear();
      if (widget.movies.isNotEmpty) _fetchDetail(widget.movies.first);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    HomePageSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int get _totalSlideCount => widget.movies.length;

  void _startTimer() {
    _timer?.cancel();
    if (!HomePageSettings.heroAutoRotate.value) return;
    if (_totalSlideCount < 2) return;
    final interval = Duration(
      seconds: HomePageSettings.heroRotateSeconds.value,
    );
    _timer = Timer.periodic(interval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % _totalSlideCount;
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

  Future<void> _fetchDetail(Movie movie) async {
    if (_detailsCache.containsKey(movie.id)) return;
    _detailsCache[movie.id] = null; // marks as "loading" so we don't refetch
    try {
      final detail = await MetadataService.fetchMeta(
        baseUrl: movie.addonBaseUrl,
        type: movie.type,
        imdbId: movie.id,
      );
      if (mounted) {
        setState(() => _detailsCache[movie.id] = detail);
      }
    } catch (_) {
      // Not critical — falls back to basic Movie data / title text.
    }
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index < widget.movies.length) {
      _fetchDetail(widget.movies[index]);
    }
    final nextSlide = (index + 1) % _totalSlideCount;
    if (nextSlide < widget.movies.length) {
      _fetchDetail(widget.movies[nextSlide]);
    }
  }

  double _heroHeight(double screenWidth, double screenHeight) {
    final style = HomePageSettings.heroStyle.value;
    if (style == HeroStyle.compact) {
      if (screenWidth < 600) {
        return 340.0;
      } else if (screenWidth < 1100) {
        return 400.0;
      } else {
        return 450.0;
      }
    } else if (style == HeroStyle.minimalist) {
      if (screenWidth < 600) {
        return 220.0;
      } else if (screenWidth < 1100) {
        return 260.0;
      } else {
        return 280.0;
      }
    }

    // Default: Immersive
    if (screenWidth < 600) {
      return (screenHeight * 0.68).clamp(460.0, 640.0);
    } else if (screenWidth < 1100) {
      return (screenHeight * 0.70).clamp(520.0, 740.0);
    } else {
      // Maximized / Widescreen Desktop: generous height
      final targetHeight = screenHeight * 0.82;
      return targetHeight.clamp(620.0, 1050.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = _heroHeight(screenWidth, screenHeight);
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;
    final totalSlides = _totalSlideCount;

    if (totalSlides == 0) {
      return SizedBox(height: heroHeight);
    }

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
              itemCount: totalSlides,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) {
                final movie = widget.movies[i];
                final detail = _detailsCache[movie.id];
                return _HeroSlide(
                  movie: movie,
                  detail: detail,
                  screenWidth: screenWidth,
                );
              },
            ),

            // Dot indicators
            if (totalSlides > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalSlides, (i) {
                    final active = i == _index;
                    final dotColor = active
                        ? primaryColor
                        : Colors.white.withValues(alpha: 0.30);
                    return GestureDetector(
                      onTap: () => _goTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: dotColor,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.55),
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

            // Arrows
            if (totalSlides > 1 && _isHovering && screenWidth > 600) ...[
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
              if (_index < totalSlides - 1)
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

class _CarouselArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  State<_CarouselArrow> createState() => _CarouselArrowState();
}

class _CarouselArrowState extends State<_CarouselArrow> {
  bool _isHoveringArrow = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringArrow = true),
      onExit: (_) => setState(() => _isHoveringArrow = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHoveringArrow
                ? Colors.black.withOpacity(0.6)
                : Colors.black.withOpacity(0.3),
            border: Border.all(
              color: _isHoveringArrow
                  ? Colors.white.withOpacity(0.6)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _isHoveringArrow ? Colors.white : Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Slide — a single featured title within the carousel.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSlide extends StatelessWidget {
  final Movie movie;
  final MovieDetail? detail;
  final double screenWidth;

  const _HeroSlide({
    required this.movie,
    required this.detail,
    required this.screenWidth,
  });

  void _openDetails(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final offset = box?.localToGlobal(box.size.center(Offset.zero));
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: movie),
        tapPosition: offset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = screenWidth < 600;
    final palette = AppThemeService.currentPalette.value;
    final heroStyle = HomePageSettings.heroStyle.value;

    final hasBackdrop =
        detail?.background != null && detail!.background!.trim().isNotEmpty;
    final backdropUrl = hasBackdrop ? detail!.background! : null;
    final posterUrl = movie.poster;
    final imageUrl = backdropUrl ?? posterUrl;
    final year = detail?.year ?? movie.year;
    final rating = detail?.imdbRating;
    final description = detail?.description;
    final genres = detail?.genres ?? const <String>[];
    final logo = detail?.logo;
    // Layer 1 blur + foreground Layer 2 + portrait card decode each URL once:
    // same URL + same memCacheWidth hits the shared ResizeImage cache entry.
    final heroCacheWidth = hasBackdrop ? 1280 : 512;
    Widget heroArtwork({
      required String url,
      required BoxFit fit,
      required Alignment alignment,
      FilterQuality filterQuality = FilterQuality.medium,
      Duration fadeIn = const Duration(milliseconds: 300),
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
        fadeInDuration: fadeIn,
        placeholder: placeholder ?? (_, __) => const SizedBox.shrink(),
        errorWidget: errorWidget ?? (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background Layers ──
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
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
                                url: imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.low,
                                placeholder: (_, __) =>
                                    const ColoredBox(color: Color(0xFF151822)),
                                errorWidget: (_, __, ___) =>
                                    const ColoredBox(color: Color(0xFF151822)),
                              ),
                            ),
                          ),
                          ColoredBox(
                            color: palette.scaffoldBackgroundColor.withValues(
                              alpha: 0.50,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Layer 2: Crisp foreground artwork
                    if (hasBackdrop) ...[
                      // Landscape 16:9 backdrop available
                      if (containerAspect <= 1.78)
                        Positioned.fill(
                          child: heroArtwork(
                            url: backdropUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.15),
                          ),
                        )
                      else
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: (containerHeight * (16 / 9)).clamp(
                            0.0,
                            containerWidth,
                          ),
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
                              url: backdropUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                    ] else ...[
                      // Portrait poster fallback (when no 16:9 backdrop is available)
                      if (containerAspect <= 1.2)
                        Positioned.fill(
                          child: heroArtwork(
                            url: imageUrl,
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
                                  url: imageUrl,
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
          const ColoredBox(color: Color(0xFF151822)),

        // Left horizontal wash for cinematic readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.38, 0.85],
                colors: [
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.95),
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.70),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom gradient (fades seamlessly into the body background)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.28, 0.70],
                colors: [
                  palette.scaffoldBackgroundColor,
                  palette.scaffoldBackgroundColor.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Content overlay ──
        Positioned(
          left: isCompact ? 20 : 48,
          right: isCompact ? 20 : 48,
          bottom: isCompact
              ? (heroStyle == HeroStyle.minimalist ? 18 : 32)
              : (heroStyle == HeroStyle.minimalist ? 28 : 50),
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
                  // Rating + year + runtime
                  Row(
                    children: [
                      if (rating != null && rating.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (year != null && year.isNotEmpty)
                        Text(
                          year,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (detail?.runtime != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        Text(
                          detail!.runtime!,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: heroStyle == HeroStyle.minimalist ? 8 : 14),

                  // Title / clearlogo
                  _HeroTitle(
                    title: movie.name,
                    logoUrl: logo,
                    isCompact: isCompact || heroStyle == HeroStyle.minimalist,
                  ),

                  // Description (Hidden in Minimalist, 1-line in Compact, 3-line in Immersive)
                  if (heroStyle != HeroStyle.minimalist &&
                      description != null &&
                      description.isNotEmpty) ...[
                    SizedBox(height: isCompact ? 10 : 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? double.infinity : 560,
                      ),
                      child: Text(
                        description,
                        maxLines: heroStyle == HeroStyle.compact
                            ? 1
                            : (isCompact ? 2 : 3),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 14.0 : 15.0,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],

                  // Genre chips (Immersive only)
                  if (heroStyle == HeroStyle.immersive &&
                      genres.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: genres.take(4).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
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

                  // Action buttons
                  SizedBox(
                    height: heroStyle == HeroStyle.minimalist
                        ? 12
                        : (isCompact ? 18 : 24),
                  ),
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          return ElevatedButton.icon(
                            onPressed: () => _openDetails(context),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'Watch Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 16 : 24,
                                vertical: isCompact ? 10 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.35),
                            ),
                          );
                        },
                      ),
                      if (heroStyle != HeroStyle.minimalist) ...[
                        SizedBox(width: isCompact ? 8 : 12),
                        Builder(
                          builder: (context) {
                            return OutlinedButton.icon(
                              onPressed: () => _openDetails(context),
                              icon: Icon(
                                Icons.info_outline_rounded,
                                size: isCompact ? 18 : 20,
                                color: Colors.white.withValues(alpha: 0.80),
                              ),
                              label: Text(
                                'Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 13.5 : 15,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 14 : 20,
                                  vertical: isCompact ? 10 : 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 1.2,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Hero Title — clearlogo when available, crossfaded text fallback otherwise.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroTitle extends StatelessWidget {
  final String title;
  final String? logoUrl;
  final bool isCompact;

  const _HeroTitle({
    required this.title,
    required this.logoUrl,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = isCompact ? 76.0 : 118.0;
    final textStyle = TextStyle(
      fontSize: isCompact ? 32 : 46,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      height: 1.05,
      color: Colors.white,
    );

    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    if (logoUrl == null || logoUrl!.isEmpty) {
      return titleText;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: CachedNetworkImage(
          imageUrl: logoUrl!,
          cacheManager: AppImageCache.manager,
          memCacheWidth: 512,
          fit: BoxFit.contain,
          alignment: Alignment.bottomLeft,
          filterQuality: FilterQuality.medium,
          fadeInDuration: const Duration(milliseconds: 250),
          placeholder: (_, __) => titleText,
          errorWidget: (_, __, ___) => titleText),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Scroll Track
// ─────────────────────────────────────────────────────────────────────────────

class _CustomScrollTrack extends StatefulWidget {
  final ScrollController controller;

  const _CustomScrollTrack({required this.controller});

  @override
  State<_CustomScrollTrack> createState() => _CustomScrollTrackState();
}

class _CustomScrollTrackState extends State<_CustomScrollTrack> {
  double _thumbFraction = 0.0;
  bool _isHovering = false;
  bool _isDragging = false;
  final double _trackHeight = 300.0;
  final double _thumbHeight = 60.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateThumbFromScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateThumbFromScroll);
    super.dispose();
  }

  void _updateThumbFromScroll() {
    if (!widget.controller.hasClients || _isDragging) return;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return;

    setState(() {
      _thumbFraction = (widget.controller.position.pixels / max).clamp(
        0.0,
        1.0,
      );
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.controller.hasClients) return;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return;

    final usableTrack = _trackHeight - _thumbHeight;
    setState(() {
      _thumbFraction += details.delta.dy / usableTrack;
      _thumbFraction = _thumbFraction.clamp(0.0, 1.0);
    });

    widget.controller.jumpTo(_thumbFraction * max);
  }

  void _scroll(double direction) {
    if (!widget.controller.hasClients) return;
    final target = widget.controller.position.pixels + (direction * 400);
    widget.controller.animateTo(
      target.clamp(0.0, widget.controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbPosition = _thumbFraction * (_trackHeight - _thumbHeight);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedOpacity(
        opacity: _isHovering || _isDragging ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xF01A1D27),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HoverArrow(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => _scroll(-1),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => setState(() => _isDragging = true),
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                onVerticalDragCancel: () => setState(() => _isDragging = false),
                child: Container(
                  height: _trackHeight,
                  width: 24, // Wider hit area for easy grabbing
                  alignment: Alignment.center,
                  child: Container(
                    height: _trackHeight,
                    width: 6, // Visual track
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: thumbPosition,
                          left:
                              -2, // To make the thumb slightly wider than the track
                          right: -2,
                          child: Container(
                            height: _thumbHeight,
                            decoration: BoxDecoration(
                              color: AppThemeService
                                  .currentPalette
                                  .value
                                  .primaryColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemeService
                                      .currentPalette
                                      .value
                                      .primaryColor
                                      .withOpacity(0.6),
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
              ),
              const SizedBox(height: 16),
              _HoverArrow(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => _scroll(1),
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
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;

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
            color: _isHovering
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Icon(
            widget.icon,
            color: _isHovering ? primaryColor : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}
