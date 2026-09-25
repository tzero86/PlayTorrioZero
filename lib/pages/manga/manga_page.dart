import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/manga/manga_service.dart';
import '../../services/manga/manga_settings.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/segmented_tabs.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/slider_arrow.dart';
import '../../widgets/manga/manga_card.dart';
import '../../widgets/manga/manga_category_dropdown.dart';
import '../settings/appearance/manga_settings_page.dart';
import 'manga_reader_page.dart';
import '../../services/storage/app_image_cache.dart';

class MangaPage extends StatefulWidget {
  const MangaPage({super.key});

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  // Static cache to preserve state across navigations
  static List<Manga>? _cachedMangaList;
  static List<Map<String, dynamic>>? _cachedReadingHistory;
  static int _cachedCurrentPage = 1;
  static String _cachedSearchQuery = '';
  static String _cachedSelectedGenre = 'All';
  static double _cachedScrollOffset = 0.0;

  final MangaService _mangaService = MangaService();
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Manga> _mangaList = [];
  List<Map<String, dynamic>> _readingHistory = [];
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String _searchQuery = '';
  String _selectedGenre = 'All';
  
  // Track grid layout dimensions
  late double _screenWidth;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _cachedScrollOffset);
    _searchController.text = _cachedSearchQuery;
    _selectedGenre = _cachedSelectedGenre;
    
    MangaSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);

    if (_cachedMangaList != null && _cachedReadingHistory != null) {
      _mangaList = _cachedMangaList!;
      _readingHistory = _cachedReadingHistory!;
      _currentPage = _cachedCurrentPage;
      _searchQuery = _cachedSearchQuery;
      _selectedGenre = _cachedSelectedGenre;
      // Refresh reading history in background silently
      _mangaService.getReadingHistory().then((history) {
        if (mounted) {
          setState(() {
            _readingHistory = history;
            _cachedReadingHistory = history;
          });
        }
      });
    } else {
      _isLoading = true;
      _loadInitialData();
    }
    
    MangaService.readingHistoryRevision.addListener(_loadHistory);
    _scrollController.addListener(_onScroll);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    MangaSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    MangaService.readingHistoryRevision.removeListener(_loadHistory);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _cachedScrollOffset = _scrollController.offset;
    }
    if (_isLoading || _isLoadingMore) return;
    
    // If we're within 800 pixels of the bottom, load more
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    final history = await _mangaService.getReadingHistory();
    if (mounted) {
      setState(() {
        _readingHistory = history;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _mangaList.clear();
    });
    
    final results = await Future.wait([
      _searchQuery.isEmpty 
          ? _mangaService.getManga(page: _currentPage, tag: _selectedGenre == 'All' ? null : _selectedGenre)
          : _mangaService.searchManga(_searchQuery, page: _currentPage),
      _mangaService.getReadingHistory(),
    ]);

    if (mounted) {
      setState(() {
        _mangaList = results[0] as List<Manga>;
        _readingHistory = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
        
        _cachedMangaList = _mangaList;
        _cachedReadingHistory = _readingHistory;
        _cachedCurrentPage = _currentPage;
        _cachedSearchQuery = _searchQuery;
        _cachedSelectedGenre = _selectedGenre;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    
    _currentPage++;
    final newManga = _searchQuery.isEmpty 
        ? await _mangaService.getManga(page: _currentPage, tag: _selectedGenre == 'All' ? null : _selectedGenre)
        : await _mangaService.searchManga(_searchQuery, page: _currentPage);
        
    if (mounted) {
      setState(() {
        _mangaList.addAll(newManga);
        _isLoadingMore = false;
        
        _cachedMangaList = _mangaList;
        _cachedCurrentPage = _currentPage;
      });
    }
  }
  
  void _onSearchChanged(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _loadInitialData();
  }

  void _onGenreSelected(String genre) {
    if (_selectedGenre == genre && _searchQuery.isEmpty) return;
    setState(() {
      _selectedGenre = genre;
      _cachedSelectedGenre = genre;
      _searchQuery = '';
      _searchController.clear();
      _cachedSearchQuery = '';
    });
    _loadInitialData();
  }

  void _resumeReading(Map<String, dynamic> historyEntry) {
    final mangaJson = historyEntry['manga'];
    final manga = Manga.fromJson(mangaJson);
    final chapterIndex = historyEntry['chapterIndex'] as int;
    final pageIndex = historyEntry['pageIndex'] as int;
    final chaptersList = (historyEntry['chapters'] as List).map((c) => MangaChapter.fromJson(c)).toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MangaReaderPage(
          manga: manga,
          chapters: chaptersList,
          currentChapterIndex: chapterIndex,
          resumePageIndex: pageIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onRemoveHistory(String mangaId) {
    _mangaService.removeHistory(mangaId).then((_) {
      _loadHistory();
    });
  }

  void _showMangaCustomizer(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: tokens.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: ZplayRadius.lgAll,
            side: tokens.hairlineStrong,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(ZplaySpacing.s20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: palette.primaryColor, size: 20),
                      const SizedBox(width: ZplaySpacing.s12),
                      Text(
                        'Customize Manga Section',
                        style: ZplayType.title.toStyle(color: tokens.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: tokens.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZplaySpacing.s16),
                  Divider(color: tokens.borderDefault),
                  const SizedBox(height: ZplaySpacing.s12),

                  Text(
                    'Poster Card Density',
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  ValueListenableBuilder<MangaCardDensity>(
                    valueListenable: MangaSettings.cardDensity,
                    builder: (context, density, _) {
                      return SegmentedTabs<MangaCardDensity>(
                        semanticsLabel: 'Manga poster card density',
                        selected: density,
                        onSelected: MangaSettings.setCardDensity,
                        options: [
                          for (final option in MangaCardDensity.values)
                            SegmentedTabOption(
                              value: option,
                              label: option.label,
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: ZplaySpacing.s16),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.enableAmbientLights,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Moving Ambient Background Glow', style: ZplayType.label.toStyle(color: tokens.textPrimary)),
                        value: enabled,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setEnableAmbientLights(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.showContinueReading,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Show "Continue Reading" Slider', style: ZplayType.label.toStyle(color: tokens.textPrimary)),
                        value: show,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setShowContinueReading(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.showContentTypeBadge,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Show Content Type Badge on Posters', style: ZplayType.label.toStyle(color: tokens.textPrimary)),
                        value: show,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setShowContentTypeBadge(val),
                      );
                    },
                  ),

                  const SizedBox(height: ZplaySpacing.s12),
                  Divider(color: tokens.borderDefault),
                  const SizedBox(height: ZplaySpacing.s12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryColor.withValues(alpha: 0.15),
                        foregroundColor: palette.primaryColor,
                        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                        shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                        padding: const EdgeInsets.symmetric(vertical: ZplaySpacing.s12),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: Text('More Appearance & Reader Settings', style: ZplayType.label.toStyle()),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MangaSettingsPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.sizeOf(context).width;
    final palette = AppThemeService.currentPalette.value;
    final ambientEnabled = MangaSettings.enableAmbientLights.value;
    final showScrollTrack = MangaSettings.showScrollTrack.value;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // ── Moving Ambient Background ──
          if (ambientEnabled)
            const Positioned.fill(child: AnimatedAmbientBackground())
          else
            Positioned.fill(
              child: Container(color: palette.scaffoldBackgroundColor),
            ),

          LiquidGlassView(
            pixelRatio: 0.25,
            refreshRate: LiquidGlassRefreshRate.low,
            backgroundWidget: _buildScrollableContent(),
            child: Stack(
              children: [
                // Top App Bar / Search / Customize
                _buildAppBar(),
                
                // Custom Scroll Track (Desktop only)
                if (_screenWidth > 800 && showScrollTrack)
                  Positioned(
                    right: 24,
                    bottom: 40,
                    child: CustomScrollTrack(controller: _scrollController),
                  ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent() {
    final palette = AppThemeService.currentPalette.value;
    final density = MangaSettings.cardDensity.value;
    final sizing = MangaCardSizing.fromWidth(_screenWidth, density: density);
    final showContinue = MangaSettings.showContinueReading.value;
    final isMobile = _screenWidth < 600;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tokens = context.tokens;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: 76.0 + topInset), // Spacer for top app bar
        ),
        
        // ── Continue Reading ──
        if (showContinue && _readingHistory.isNotEmpty && _searchQuery.isEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 32.0,
                vertical: isMobile ? 12.0 : 16.0,
              ),
              child: Text(
                'Continue Reading',
                style: (isMobile ? ZplayType.titleLarge : ZplayType.display)
                    .toStyle(color: tokens.textPrimary),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContinueReadingSlider(
              readingHistory: _readingHistory,
              onResume: _resumeReading,
              onRemove: _onRemoveHistory,
              screenWidth: _screenWidth,
              isMobile: isMobile,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: isMobile ? ZplaySpacing.s24 : ZplaySpacing.s40),
          ),
        ],

        // ── Discovery / Search Results & Category Dropdown ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s32,
              vertical: isMobile ? ZplaySpacing.s12 : ZplaySpacing.s16,
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Search Results'
                            : (_selectedGenre == 'All' ? 'Discover Manga' : '$_selectedGenre Manga'),
                        style: ZplayType.titleLarge.toStyle(
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: ZplaySpacing.s12),
                        Row(
                          children: [
                            MangaCategoryDropdown(
                              selectedGenre: _selectedGenre,
                              genres: MangaService.popularGenres,
                              onGenreSelected: _onGenreSelected,
                            ),
                            if (_selectedGenre != 'All') ...[
                              const SizedBox(width: ZplaySpacing.s8),
                              InkWell(
                                onTap: () => _onGenreSelected('All'),
                                borderRadius: ZplayRadius.smAll,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: ZplaySpacing.s8,
                                    vertical: ZplaySpacing.s8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.borderSubtle,
                                    borderRadius: ZplayRadius.smAll,
                                    border: Border.all(
                                      color: tokens.borderDefault,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.close_rounded, size: 14, color: tokens.textEmphasis),
                                      const SizedBox(width: ZplaySpacing.s4),
                                      Text(
                                        'Clear',
                                        style: ZplayType.bodySmall.toStyle(
                                          color: tokens.textEmphasis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Search Results'
                                : (_selectedGenre == 'All' ? 'Discover Manga' : '$_selectedGenre Manga'),
                            style: ZplayType.display.toStyle(
                              color: tokens.textPrimary,
                            ),
                          ),
                          if (_searchQuery.isEmpty && _selectedGenre != 'All')
                            Padding(
                              padding: const EdgeInsets.only(top: ZplaySpacing.s4),
                              child: Text(
                                'Filtered by category • $_selectedGenre',
                                style: ZplayType.bodySmall.toStyle(
                                  color: palette.primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_searchQuery.isEmpty)
                        Row(
                          children: [
                            MangaCategoryDropdown(
                              selectedGenre: _selectedGenre,
                              genres: MangaService.popularGenres,
                              onGenreSelected: _onGenreSelected,
                            ),
                            if (_selectedGenre != 'All') ...[
                              const SizedBox(width: ZplaySpacing.s8),
                              Tooltip(
                                message: 'Reset to All Categories',
                                child: InkWell(
                                  onTap: () => _onGenreSelected('All'),
                                  borderRadius: ZplayRadius.mdAll,
                                  child: Container(
                                    padding: const EdgeInsets.all(ZplaySpacing.s8),
                                    decoration: BoxDecoration(
                                      color: tokens.borderSubtle,
                                      borderRadius: ZplayRadius.mdAll,
                                      border: Border.all(
                                        color: tokens.borderDefault,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: tokens.textEmphasis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
          ),
        ),
        
        if (_isLoading && _mangaList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: tokens.textPrimary),
            ),
          )
        else if (_mangaList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No manga found',
                style: ZplayType.title.toStyle(color: tokens.textEmphasis),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding, vertical: ZplaySpacing.s8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: sizing.cardWidth + sizing.spacing * 2,
                mainAxisSpacing: ZplaySpacing.s32,
                crossAxisSpacing: sizing.spacing,
                mainAxisExtent: sizing.totalHeight,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return MangaCard(manga: _mangaList[index]);
                },
                childCount: _mangaList.length,
              ),
            ),
          ),
          
        if (_isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(ZplaySpacing.s32),
              child: Center(child: CircularProgressIndicator(color: tokens.textPrimary)),
            ),
          ),
        
        SliverToBoxAdapter(
          child: SizedBox(height: ZplaySpacing.s24 + bottomInset), // Trailing gap only; the dock needed 110 px here
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    final topInset = MediaQuery.paddingOf(context).top;
    final isMobile = _screenWidth < 600;
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;

    return Positioned(
      top: ZplaySpacing.s12 + topInset,
      left: isMobile ? ZplaySpacing.s12 : ZplaySpacing.s24,
      right: isMobile ? ZplaySpacing.s12 : ZplaySpacing.s24,
      child: Row(
        children: [
          
          // Search Bar
          Expanded(
            child: ClipRRect(
              borderRadius: ZplayRadius.lgAll,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  // Opaque, where this was a 5%-white wash behind a sigma-16
                  // blur. Nothing needs the blur: the field floats over the
                  // poster grid, so the fill only let artwork smear through the
                  // text it is supposed to frame.
                  color: tokens.surface,
                  border: Border.all(
                    color: _searchQuery.isNotEmpty ? palette.primaryColor : tokens.borderDefault,
                    width: 1.5,
                  ),
                  borderRadius: ZplayRadius.lgAll,
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _onSearchChanged,
                  style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search Manga, Manhwa, Manhua...',
                    hintStyle: ZplayType.subtitle.toStyle(color: tokens.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, color: palette.primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ZplaySpacing.s20,
                      vertical: ZplaySpacing.s12,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: ZplaySpacing.s12),

          // Quick Customize Button
          ClipRRect(
            borderRadius: ZplayRadius.lgAll,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(
                  color: tokens.borderDefault,
                  width: 1.5,
                ),
                borderRadius: ZplayRadius.lgAll,
              ),
              child: IconButton(
                icon: Icon(Icons.tune_rounded, color: tokens.textEmphasis),
                tooltip: 'Customize Manga Section',
                onPressed: () => _showMangaCustomizer(context),
                splashRadius: ZplayRadius.lg,
              ),
            ),
          ),
          
          // Spacer so search bar doesn't touch the right edge on wide desktop screens
          if (_screenWidth > 800) const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _ContinueReadingSlider extends StatefulWidget {
  final List<Map<String, dynamic>> readingHistory;
  final void Function(Map<String, dynamic>) onResume;
  final void Function(String mangaId) onRemove;
  final double screenWidth;
  final bool isMobile;

  const _ContinueReadingSlider({
    required this.readingHistory,
    required this.onResume,
    required this.onRemove,
    required this.screenWidth,
    required this.isMobile,
  });

  @override
  State<_ContinueReadingSlider> createState() => _ContinueReadingSliderState();
}

class _ContinueReadingSliderState extends State<_ContinueReadingSlider> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final canLeft = _scrollController.position.pixels > 10;
    final canRight = _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double directionMultiplier) {
    if (!_scrollController.hasClients) return;
    final viewportWidth = _scrollController.position.viewportDimension;
    final scrollAmount = (viewportWidth * 0.75) * directionMultiplier;
    final target = (_scrollController.position.pixels + scrollAmount).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !widget.isMobile;

    return MouseRegion(
      onEnter: (_) {
        if (isDesktop) setState(() => _isHovering = true);
      },
      onExit: (_) {
        if (isDesktop) setState(() => _isHovering = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: widget.isMobile ? 200 : 240,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? ZplaySpacing.s12 : ZplaySpacing.s24,
              ),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.readingHistory.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(widget.readingHistory[index]);
              },
            ),
          ),
          if (isDesktop) ...[
            // Left Arrow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: _canScrollLeft && _isHovering ? ZplaySpacing.s12 : -60,
              top: 0,
              bottom: 0,
              child: Center(
                child: SliderArrow(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => _scroll(-1),
                ),
              ),
            ),
            // Right Arrow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              right: _canScrollRight && _isHovering ? ZplaySpacing.s12 : -60,
              top: 0,
              bottom: 0,
              child: Center(
                child: SliderArrow(
                  icon: Icons.arrow_forward_ios_rounded,
                  onTap: () => _scroll(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;
    final mangaJson = entry['manga'];
    final mangaId = (mangaJson['id'] ?? '').toString();
    final title = mangaJson['title'] ?? 'Unknown';
    final coverUrl = mangaJson['cover_normal'] ?? mangaJson['cover_small'] ?? '';
    final chapterIndex = entry['chapterIndex'] as int;
    final chaptersList = entry['chapters'] as List;
    final chapterTitle = chaptersList.isNotEmpty && chapterIndex < chaptersList.length
        ? chaptersList[chapterIndex]['name'] ?? 'Chapter ${chaptersList[chapterIndex]['number']}'
        : 'Resume';

    return FocusableCard(
      onTap: () => widget.onResume(entry),
      builder: (context, _) {
        return Container(
          width: widget.isMobile ? math.min(320.0, widget.screenWidth * 0.82) : 380,
          margin: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8),
          decoration: BoxDecoration(
            borderRadius: ZplayRadius.lgAll,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: ZplayRadius.lgAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                if (coverUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    cacheManager: AppImageCache.manager,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter),
                // Legibility scrim over the cover art: the same transparent →
                // opaque gradient, sourced from the palette instead of flat black.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        tokens.bg.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
                // Frosted Info Panel
                Positioned(
                  bottom: ZplaySpacing.s16,
                  left: ZplaySpacing.s16,
                  right: ZplaySpacing.s16,
                  child: ClipRRect(
                    borderRadius: ZplayRadius.mdAll,
                    child: BackdropFilter(
                      // Kept: this blur frosts the cover art the panel sits on,
                      // so it still depicts content rather than chrome.
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(ZplaySpacing.s12),
                        decoration: BoxDecoration(
                          color: tokens.bg.withValues(alpha: 0.50),
                          border: Border.all(color: tokens.borderStrong),
                          borderRadius: ZplayRadius.mdAll,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZplayType.title.toStyle(
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: ZplaySpacing.s4),
                            Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: palette.primaryColor, size: 16),
                                const SizedBox(width: ZplaySpacing.s8),
                                Expanded(
                                  child: Text(
                                    chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZplayType.body.toStyle(
                                      color: tokens.textEmphasis,
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
                ),
                // Remove from Continue Reading Button
                Positioned(
                  top: ZplaySpacing.s16,
                  left: ZplaySpacing.s16,
                  child: Tooltip(
                    message: 'Remove from Continue Reading',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => widget.onRemove(mangaId),
                        borderRadius: ZplayRadius.lgAll,
                        child: Container(
                          padding: const EdgeInsets.all(ZplaySpacing.s8),
                          decoration: BoxDecoration(
                            color: tokens.bg.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.borderStrong,
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: tokens.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Play/Resume Overlay Icon
                Positioned(
                  top: ZplaySpacing.s16,
                  right: ZplaySpacing.s16,
                  child: Container(
                    padding: const EdgeInsets.all(ZplaySpacing.s12),
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: tokens.textPrimary, size: 24),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
