import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/audiobook/audiobook_progress_service.dart';
import '../../services/audiobook/audiobook_scraper_service.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/audiobook/paper2audio_service.dart';
import '../../services/audiobook/custom_audiobook_service.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/segmented_tabs.dart';
import '../settings/appearance/audiobook_settings_page.dart';
import 'audiobook_detail_page.dart';
import 'audiobook_player_screen.dart';
import 'audiobook_route_transitions.dart';
import 'generate_audiobook_screen.dart';
import '../../services/storage/app_image_cache.dart';

class AudiobooksPage extends StatefulWidget {
  const AudiobooksPage({super.key});

  @override
  State<AudiobooksPage> createState() => _AudiobooksPageState();
}

class _AudiobooksPageState extends State<AudiobooksPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _continueScrollController = ScrollController();

  bool _isSearching = false;
  List<Audiobook> _searchResults = [];
  List<AudiobookProgress> _continueListeningList = [];
  String? _errorMessage;
  int _searchSequence = 0;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Fantasy',
    'Sci-Fi',
    'Mystery',
    'Thriller',
    'Non-Fiction',
    'Self-Help',
    'Horror',
    'Romance',
    'Adventure',
    'Classics',
  ];

  @override
  void initState() {
    super.initState();
    AudiobookSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
    Paper2AudioService.instance.jobs.addListener(_onSettingsChanged);
    CustomAudiobookService.instance.audiobooks.addListener(_onSettingsChanged);

    Paper2AudioService.instance.getJobs();
    CustomAudiobookService.instance.ensureLoaded();

    _loadContinueListening();
    _performSearch('Harry Potter');
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    AudiobookSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    Paper2AudioService.instance.jobs.removeListener(_onSettingsChanged);
    CustomAudiobookService.instance.audiobooks.removeListener(_onSettingsChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _continueScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadContinueListening() async {
    final list = await AudiobookProgressService.instance.getAllProgress();
    if (mounted) {
      setState(() {
        _continueListeningList = list;
      });
    }
  }

  void _scrollContinueLeft() {
    if (!_continueScrollController.hasClients) return;
    _continueScrollController.animateTo(
      (_continueScrollController.offset - 280).clamp(0.0, _continueScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollContinueRight() {
    if (!_continueScrollController.hasClients) return;
    _continueScrollController.animateTo(
      (_continueScrollController.offset + 280).clamp(0.0, _continueScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Timer? _searchDebounce;

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && query.trim().isNotEmpty) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchDebounce?.cancel();

    final currentSequence = ++_searchSequence;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await AudiobookScraperService.instance.search(trimmed);
      if (mounted && currentSequence == _searchSequence) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted && currentSequence == _searchSequence) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Failed to fetch audiobooks: $e';
        });
      }
    }
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat);
    if (cat == 'All') {
      _performSearch('Harry Potter');
    } else {
      _searchController.text = cat;
      _performSearch(cat);
    }
  }

  void _showAudiobookCustomizer(BuildContext context) {
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: tokens.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: ZplayRadius.lgAll,
            side: BorderSide(color: tokens.borderStrong),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: tokens.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Customize Audiobook Section',
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
                    style: ZplayType.label
                        .copyWith(weight: FontWeight.w700)
                        .toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<AudiobookCardDensity>(
                    valueListenable: AudiobookSettings.cardDensity,
                    builder: (context, density, _) {
                      return SegmentedTabs<AudiobookCardDensity>(
                        semanticsLabel: 'Audiobook poster card density',
                        selected: density,
                        onSelected: AudiobookSettings.setCardDensity,
                        options: [
                          for (final option in AudiobookCardDensity.values)
                            SegmentedTabOption(
                              value: option,
                              label: option.label,
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  ValueListenableBuilder<bool>(
                    valueListenable: AudiobookSettings.enableSpotlight,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Featured Hero Spotlight Carousel',
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                        ),
                        value: enabled,
                        activeColor: tokens.accent,
                        onChanged: (val) => AudiobookSettings.setEnableSpotlight(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: AudiobookSettings.enableAmbientLights,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Moving Ambient Background Glow',
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                        ),
                        value: enabled,
                        activeColor: tokens.accent,
                        onChanged: (val) => AudiobookSettings.setEnableAmbientLights(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: AudiobookSettings.showContinueListening,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show "Continue Listening" Carousel',
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                        ),
                        value: show,
                        activeColor: tokens.accent,
                        onChanged: (val) => AudiobookSettings.setShowContinueListening(val),
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
                        backgroundColor: tokens.accentSubtle,
                        foregroundColor: tokens.accent,
                        side: BorderSide(color: tokens.accent.withValues(alpha: 0.4)),
                        shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                        padding: const EdgeInsets.symmetric(vertical: ZplaySpacing.s12),
                      ),
                      icon: const Icon(Icons.palette_rounded, size: 18),
                      label: Text(
                        'Open Player Studio & Themes',
                        style: ZplayType.label
                            .copyWith(weight: FontWeight.w700)
                            .toStyle(),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AudiobookSettingsPage()),
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
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;
    final tokens = context.tokens;
    final ambientEnabled = AudiobookSettings.enableAmbientLights.value;
    final showSpotlight = AudiobookSettings.enableSpotlight.value;
    final showContinue = AudiobookSettings.showContinueListening.value;
    final showCategoryPills = AudiobookSettings.showCategoryPills.value;
    final cardDensity = AudiobookSettings.cardDensity.value;

    final spotlightBook = _searchResults.isNotEmpty ? _searchResults.first : null;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // ── Ambient Background Glows ──
          if (ambientEnabled)
            const Positioned.fill(child: AnimatedAmbientBackground())
          else
            Positioned.fill(
              child: Container(color: tokens.bg),
            ),

          // ── Main Content Scroll ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    topInset + ZplaySpacing.s12,
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    ZplaySpacing.s12,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      ClipRRect(
                        borderRadius: ZplayRadius.lgAll,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: tokens.borderDefault,
                              borderRadius: ZplayRadius.lgAll,
                              border: Border.all(color: tokens.borderStrong),
                            ),
                            child: IconButton(
                              // A Browse vertical is never pushed, so there is
                              // normally nothing above this page; the guard keeps
                              // a tap from popping the shell route instead, and
                              // the button goes inert rather than wrong.
                              onPressed: Navigator.of(context).canPop()
                                  ? () => Navigator.pop(context)
                                  : null,
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: tokens.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Glowing Headphones Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // One accent, and only one: this was `primaryColor` to
                          // the palette's *second* accent, which the token layer
                          // deliberately does not carry.
                          gradient: LinearGradient(
                            colors: [tokens.accent, tokens.accentHover],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.headphones_rounded,
                          color: tokens.onAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audiobook Hub',
                              style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
                            ),
                            Text(
                              'Explore, stream & listen to thousands of stories',
                              style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // AI Generator & Studio Button
                      ClipRRect(
                        borderRadius: ZplayRadius.lgAll,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  tokens.accent.withValues(alpha: 0.25),
                                  tokens.accent.withValues(alpha: 0.25),
                                ],
                              ),
                              borderRadius: ZplayRadius.lgAll,
                              border: Border.all(color: tokens.accent.withValues(alpha: 0.35)),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.auto_awesome_rounded,
                                color: tokens.textPrimary,
                                size: 20,
                              ),
                              tooltip: 'Audiobook Generator & Studio',
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
                                );
                                _loadContinueListening();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick Customize Button
                      ClipRRect(
                        borderRadius: ZplayRadius.lgAll,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: tokens.borderDefault,
                              borderRadius: ZplayRadius.lgAll,
                              border: Border.all(color: tokens.borderStrong),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.tune_rounded,
                                color: tokens.textEmphasis,
                                size: 20,
                              ),
                              tooltip: 'Audiobook Customizer',
                              onPressed: () => _showAudiobookCustomizer(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    vertical: 6,
                  ),
                  child: ClipRRect(
                    borderRadius: ZplayRadius.mdAll,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.surface.withValues(alpha: 0.75),
                          borderRadius: ZplayRadius.mdAll,
                          border: Border.all(
                            color: _searchController.text.isNotEmpty
                                ? tokens.accent
                                : tokens.borderDefault,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: ZplayType.body.toStyle(color: tokens.textPrimary),
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            hintText: 'Search audiobooks by title, author, or genre...',
                            hintStyle: ZplayType.body.toStyle(color: tokens.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, color: tokens.accent),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: tokens.textSecondary,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Genre / Category Filter Pills
              if (showCategoryPills)
                SliverToBoxAdapter(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: ZplaySpacing.s8, bottom: 6),
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                      ),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: ZplaySpacing.s8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: tokens.accentSubtle,
                            backgroundColor: tokens.surfaceOverlay.withValues(alpha: 0.8),
                            labelStyle: ZplayType.bodySmall
                                .copyWith(
                                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                )
                                .toStyle(
                                  color: isSelected ? tokens.accent : tokens.textEmphasis,
                                ),
                            side: BorderSide(
                              color: isSelected
                                  ? tokens.accent.withValues(alpha: 0.6)
                                  : tokens.borderDefault,
                            ),
                            onSelected: (selected) {
                              if (selected) _selectCategory(cat);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Hero Spotlight Carousel (Home-style Featured Card)
              if (showSpotlight && spotlightBook != null && !_isSearching)
                SliverToBoxAdapter(
                  child: _buildHeroSpotlight(spotlightBook, isMobile),
                ),

              // Continue Listening Section (If available)
              if (showContinue && _continueListeningList.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildContinueListeningSection(),
                ),

              // Generated & Personal Audiobooks Studio Shelf
              if (!_isSearching)
                SliverToBoxAdapter(
                  child: _buildGeneratedAndUploadedSection(),
                ),

              // Discovery Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    ZplaySpacing.s16,
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    ZplaySpacing.s8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _searchController.text.isNotEmpty ? 'Search Results' : 'Featured Audiobooks',
                        style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
                      ),
                      const SizedBox(width: ZplaySpacing.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZplaySpacing.s8,
                          vertical: ZplaySpacing.s2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accentSubtle,
                          borderRadius: ZplayRadius.xsAll,
                        ),
                        child: Text(
                          '${_searchResults.length} TITLES',
                          style: ZplayType.overline.toStyle(color: tokens.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Status / Loading / Grid
              if (_isSearching)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: tokens.accent),
                        const SizedBox(height: ZplaySpacing.s16),
                        Text(
                          'Scraping high-quality audiobook sources...',
                          style: ZplayType.body.toStyle(color: tokens.textEmphasis),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: ZplayType.subtitle.toStyle(color: tokens.danger),
                    ),
                  ),
                )
              else if (_searchResults.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No audiobooks found. Try another search query.',
                      style: ZplayType.subtitle.toStyle(color: tokens.textSecondary),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    ZplaySpacing.s8,
                    isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
                    ZplaySpacing.s32 + bottomInset,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: (isMobile ? 150 : 180) * cardDensity.scale,
                      childAspectRatio: 0.60,
                      crossAxisSpacing: isMobile ? 12 : 16,
                      mainAxisSpacing: isMobile ? 12 : 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = _searchResults[index];
                        final heroTag = 'audiobook-cover-$index-${book.uuid.isNotEmpty ? book.uuid : book.title}';
                        return _AudiobookCard(
                          key: ValueKey('book-$index-${book.uuid}'),
                          book: book,
                          heroTag: heroTag,
                          onReturn: _loadContinueListening,
                        );
                      },
                      childCount: _searchResults.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Spotlight Section ──
  Widget _buildHeroSpotlight(Audiobook book, bool isMobile) {
    final heroTag = 'spotlight-hero-${book.uuid.isNotEmpty ? book.uuid : book.title}';

    final tokens = context.tokens;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
        vertical: ZplaySpacing.s12,
      ),
      height: isMobile ? 220 : 260,
      decoration: BoxDecoration(
        borderRadius: ZplayRadius.lgAll,
        border: Border.all(color: tokens.borderStrong),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ZplayRadius.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Artwork with Blur
            if (book.coverImage.trim().isNotEmpty)
              CachedNetworkImage(
                imageUrl: book.coverImage.trim(),
                cacheManager: AppImageCache.manager,
                httpHeaders: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink()),
            // Vignette Gradient Fade
            Container(
              decoration: BoxDecoration(
                // Artwork scrim: the wash direction and its stops are untouched,
                // only the colour becomes the page background so the vignette
                // follows the palette instead of pinning ocean-black.
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    tokens.bg.withValues(alpha: 0.94),
                    tokens.bg.withValues(alpha: 0.69),
                    tokens.bg.withValues(alpha: 0.50),
                  ],
                ),
              ),
            ),
            // Spotlight Info Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Cover Image Deck
                  SizedBox(
                    width: isMobile ? 100 : 130,
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: ZplayRadius.mdAll,
                        child: book.coverImage.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: book.coverImage.trim(),
                                cacheManager: AppImageCache.manager,
                                httpHeaders: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                },
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: tokens.surface),
                                errorWidget: (_, __, ___) => Container(
                                  color: tokens.surface,
                                  child: Icon(
                                    Icons.headphones_rounded,
                                    color: tokens.textMuted,
                                  ),
                                ))
                            : Container(color: tokens.surface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Metadata & CTAs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZplaySpacing.s8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accentSubtle,
                            borderRadius: ZplayRadius.xsAll,
                          ),
                          child: Text(
                            'SPOTLIGHT FEATURED',
                            style: ZplayType.overline.toStyle(color: tokens.accent),
                          ),
                        ),
                        const SizedBox(height: ZplaySpacing.s8),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ZplayType.titleLarge
                              .copyWith(size: isMobile ? 17 : 22)
                              .toStyle(color: tokens.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.source.toUpperCase(),
                          style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  AudiobookPageRoute(
                                    page: AudiobookDetailPage(audiobook: book, heroTag: heroTag),
                                  ),
                                );
                                _loadContinueListening();
                              },
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: tokens.onAccent,
                                size: 20,
                              ),
                              label: Text(
                                'Listen Now',
                                style: ZplayType.label
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.onAccent),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.accent,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: ZplayRadius.smAll,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ZplaySpacing.s16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Continue Listening Carousel ──
  Widget _buildContinueListeningSection() {
    final tokens = context.tokens;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
        ZplaySpacing.s12,
        isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
        ZplaySpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: tokens.accent, size: 20),
                  const SizedBox(width: ZplaySpacing.s8),
                  Text(
                    'Continue Listening',
                    style: ZplayType.title.toStyle(color: tokens.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  _ScrollArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: _scrollContinueLeft,
                  ),
                  const SizedBox(width: 8),
                  _ScrollArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _scrollContinueRight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZplaySpacing.s12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              controller: _continueScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _continueListeningList.length,
              itemBuilder: (context, index) {
                final item = _continueListeningList[index];
                return _ContinueListeningCard(
                  progress: item,
                  onDelete: () async {
                    await AudiobookProgressService.instance.removeProgress(item.key);
                    _loadContinueListening();
                  },
                  onTap: () async {
                    await Navigator.push(
                      context,
                      AudiobookPageRoute(
                        page: AudiobookPlayerScreen(
                          audiobook: item.audiobook,
                          chapters: item.chapters,
                          initialChapterIndex: item.chapterIndex,
                          initialPosition: Duration(milliseconds: item.positionMs),
                        ),
                      ),
                    );
                    _loadContinueListening();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Generated & Uploaded Audiobooks Shelf ──
  Widget _buildGeneratedAndUploadedSection() {
    final tokens = context.tokens;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;

    final jobs = Paper2AudioService.instance.jobs.value;
    final uploaded = CustomAudiobookService.instance.audiobooks.value;
    final hasItems = jobs.isNotEmpty || uploaded.isNotEmpty;

    if (!hasItems) {
      // Sleek quick studio banner
      return Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
          ZplaySpacing.s8,
          isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
          ZplaySpacing.s16,
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
            );
            _loadContinueListening();
          },
          borderRadius: ZplayRadius.mdAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tokens.accent.withValues(alpha: 0.15),
                  tokens.accent.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: ZplayRadius.mdAll,
              border: Border.all(color: tokens.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.accentSubtle,
                    borderRadius: ZplayRadius.smAll,
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: tokens.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Audiobook Studio & EPUB Generator',
                        style: ZplayType.label
                            .copyWith(weight: FontWeight.w700)
                            .toStyle(color: tokens.textPrimary),
                      ),
                      Text(
                        'Generate audiobooks from EPUBs or import your own MP3/M4B audiobooks.',
                        style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: ZplaySpacing.s8,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ZplayRadius.smAll,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
                    );
                    _loadContinueListening();
                  },
                  child: Text(
                    'Open Studio',
                    style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
        ZplaySpacing.s8,
        isMobile ? ZplaySpacing.s16 : ZplaySpacing.s24,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: tokens.accent, size: 20),
                  const SizedBox(width: ZplaySpacing.s8),
                  Text(
                    'My Generated & Uploaded Audiobooks',
                    style: ZplayType.title.toStyle(color: tokens.textPrimary),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: Text(
                  'Studio',
                  style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(),
                ),
                style: TextButton.styleFrom(foregroundColor: tokens.accent),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
                  );
                  _loadContinueListening();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                // Render Generated Jobs
                ...jobs.map((job) {
                  final cleanTitle = job.fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
                  final isDone = job.isDone;
                  final isFailed = job.isFailed;

                  return Container(
                    width: 270,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.85),
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 100,
                          decoration: BoxDecoration(
                            color: tokens.borderDefault,
                            borderRadius: ZplayRadius.smAll,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: job.coverPath != null && File(job.coverPath!).existsSync()
                              ? Image.file(File(job.coverPath!), fit: BoxFit.cover)
                              : Icon(
                                  Icons.headphones_rounded,
                                  color: tokens.textDisabled,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cleanTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZplayType.label
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isDone ? 'Voice: ${job.voiceId}' : (isFailed ? 'Failed' : 'Generating ${(job.progress * 100).round()}%'),
                                style: ZplayType.caption
                                    .copyWith(weight: FontWeight.w600)
                                    .toStyle(
                                      color: isDone
                                          ? tokens.success
                                          : (isFailed ? tokens.danger : tokens.warning),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (isDone)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                  label: Text(
                                    'Play',
                                    style: ZplayType.caption
                                        .copyWith(weight: FontWeight.w700)
                                        .toStyle(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.accent,
                                    foregroundColor: tokens.onAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: ZplayRadius.xsAll,
                                    ),
                                  ),
                                  onPressed: () {
                                    final streamOrLocalPath = job.localAudioPath ?? job.downloadUrl!;
                                    final book = Audiobook(
                                      uuid: 'p2a_${job.runId}',
                                      audioBookId: 'p2a_${job.runId}',
                                      dynamicSlugId: job.runId,
                                      title: cleanTitle,
                                      author: 'AI Generated',
                                      coverImage: job.coverPath ?? '',
                                      source: 'Paper2Audio AI',
                                      pageUrl: streamOrLocalPath,
                                    );
                                    Navigator.push(
                                      context,
                                      AudiobookPageRoute(
                                        page: AudiobookPlayerScreen(
                                          audiobook: book,
                                          chapters: [AudiobookChapter(title: cleanTitle, url: streamOrLocalPath)],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else if (!isFailed)
                                ClipRRect(
                                  borderRadius: ZplayRadius.xsAll,
                                  child: LinearProgressIndicator(
                                    value: job.progress > 0 ? job.progress : null,
                                    backgroundColor: tokens.borderDefault,
                                    color: tokens.accent,
                                    minHeight: 4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Render Uploaded Audiobooks
                ...uploaded.map((b) {
                  return Container(
                    width: 270,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.85),
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 100,
                          decoration: BoxDecoration(
                            color: tokens.borderDefault,
                            borderRadius: ZplayRadius.smAll,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: b.coverPath != null && File(b.coverPath!).existsSync()
                              ? Image.file(File(b.coverPath!), fit: BoxFit.cover)
                              : Icon(
                                  Icons.library_music_rounded,
                                  color: tokens.textDisabled,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZplayType.label
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${b.author} • Local',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                label: Text(
                                  'Play',
                                  style: ZplayType.caption
                                      .copyWith(weight: FontWeight.w700)
                                      .toStyle(),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.accent,
                                  foregroundColor: tokens.onAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: ZplayRadius.xsAll,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    AudiobookPageRoute(
                                      page: AudiobookPlayerScreen(
                                        audiobook: b.toAudiobookModel(),
                                        chapters: b.toChapters(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  final AudiobookProgress progress;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ContinueListeningCard({
    required this.progress,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final item = progress;
    final book = item.audiobook;
    final hasCover = book.coverImage.isNotEmpty;
    final heroTag = 'continue-cover-${book.uuid.isNotEmpty ? book.uuid : book.title}';

    final percent = item.durationMs > 0
        ? (item.positionMs / item.durationMs).clamp(0.0, 1.0)
        : 0.0;

    final currentChapterTitle = item.chapters.isNotEmpty && item.chapterIndex < item.chapters.length
        ? item.chapters[item.chapterIndex].title
        : 'Chapter ${item.chapterIndex + 1}';

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FocusableCard(
            onTap: onTap,
            builder: (context, state) {
              final scale = state.pressed ? 0.96 : (state.highlighted ? 1.03 : 1.0);

              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 285,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: state.highlighted
                        ? tokens.surfaceOverlay
                        : tokens.surface.withValues(alpha: 0.85),
                    borderRadius: ZplayRadius.mdAll,
                    border: Border.all(
                      color: state.highlighted
                          ? tokens.accent.withValues(alpha: 0.6)
                          : tokens.borderDefault,
                      width: state.highlighted ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: state.highlighted
                            ? tokens.accent.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: state.highlighted ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Book Cover Art
                      SizedBox(
                        width: 60,
                        height: 90,
                        child: Hero(
                          tag: heroTag,
                          child: ClipRRect(
                            borderRadius: ZplayRadius.smAll,
                            child: hasCover
                                ? CachedNetworkImage(
                                    imageUrl: book.coverImage,
                                    cacheManager: AppImageCache.manager,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: tokens.surface),
                                    errorWidget: (_, __, ___) => Container(
                                      color: tokens.surface,
                                      child: Icon(
                                        Icons.headphones_rounded,
                                        color: tokens.textMuted,
                                      ),
                                    ))
                                : Container(
                                    color: tokens.surface,
                                    child: Icon(
                                      Icons.headphones_rounded,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Info & Progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZplayType.label
                                  .copyWith(weight: FontWeight.w700)
                                  .toStyle(color: tokens.textPrimary),
                            ),
                            const SizedBox(height: ZplaySpacing.s4),
                            Text(
                              currentChapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                            ),
                            const SizedBox(height: ZplaySpacing.s8),
                            // Progress bar
                            ClipRRect(
                              borderRadius: ZplayRadius.xsAll,
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 4,
                                backgroundColor: tokens.borderDefault,
                                valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                              ),
                            ),
                            const SizedBox(height: ZplaySpacing.s4),
                            Text(
                              '${(percent * 100).toInt()}% completed',
                              style: ZplayType.caption
                                  .copyWith(weight: FontWeight.w600)
                                  .toStyle(color: tokens.accent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Play Button Icon
                      Container(
                        padding: const EdgeInsets.all(ZplaySpacing.s8),
                        decoration: BoxDecoration(
                          color: state.highlighted
                              ? tokens.accent
                              : tokens.accentSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: state.highlighted ? tokens.onAccent : tokens.accent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // X Delete Button
          Positioned(
            top: -4,
            right: -4,
            child: FocusableCard(
              onTap: onDelete,
              builder: (context, state) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: state.highlighted ? tokens.danger : tokens.surfaceOverlay,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.highlighted ? tokens.danger : tokens.borderStrong,
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: tokens.textPrimary,
                    size: 14,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: state.highlighted ? tokens.borderStrong : tokens.borderDefault,
            shape: BoxShape.circle,
            border: Border.all(
              color: state.highlighted ? tokens.borderStrong : tokens.borderDefault,
            ),
          ),
          child: Icon(
            icon,
            color: state.highlighted ? tokens.textPrimary : tokens.textEmphasis,
            size: 18,
          ),
        );
      },
    );
  }
}

class _AudiobookCard extends StatelessWidget {
  final Audiobook book;
  final String heroTag;
  final VoidCallback? onReturn;

  const _AudiobookCard({
    super.key,
    required this.book,
    required this.heroTag,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasCover = book.coverImage.isNotEmpty;
    final cardHoverGlow = AudiobookSettings.cardHoverGlow.value;

    return FocusableCard(
      onTap: () async {
        await Navigator.push(
          context,
          AudiobookPageRoute(
            page: AudiobookDetailPage(
              audiobook: book,
              heroTag: heroTag,
            ),
          ),
        );
        onReturn?.call();
      },
      builder: (context, state) {
        final scale = state.pressed ? 0.95 : (state.highlighted ? 1.04 : 1.0);

        return AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: state.highlighted ? tokens.surfaceOverlay : tokens.surface,
              borderRadius: ZplayRadius.mdAll,
              border: Border.all(
                color: state.highlighted
                    ? tokens.accent.withValues(alpha: 0.6)
                    : tokens.borderDefault,
                width: state.highlighted ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: state.highlighted && cardHoverGlow
                      ? tokens.accent.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: state.highlighted ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image with Hero Transition
                Expanded(
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ZplayRadius.md),
                      ),
                      child: hasCover
                          ? CachedNetworkImage(
                              imageUrl: book.coverImage,
                              cacheManager: AppImageCache.manager,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: tokens.surface),
                              errorWidget: (_, __, ___) => Container(
                                color: tokens.surface,
                                child: Icon(
                                  Icons.headphones_rounded,
                                  size: 40,
                                  color: tokens.textMuted,
                                ),
                              ))
                          : Container(
                              color: tokens.surface,
                              child: Center(
                                child: Icon(
                                  Icons.headphones_rounded,
                                  size: 40,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                // Information
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZplayType.label
                            .copyWith(weight: FontWeight.w700)
                            .toStyle(color: tokens.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final isTorrent = book.source.toLowerCase().contains('audiobookbay');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTorrent
                                  ? tokens.warning.withValues(alpha: 0.25)
                                  : (state.highlighted
                                      ? tokens.accentSubtle
                                      : tokens.accent.withValues(alpha: 0.2)),
                              borderRadius: ZplayRadius.xsAll,
                              border: isTorrent
                                  ? Border.all(
                                      color: tokens.warning.withValues(alpha: 0.4),
                                      width: 0.8,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isTorrent) ...[
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: tokens.warning,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Flexible(
                                  child: Text(
                                    isTorrent ? 'AUDIOBOOKBAY' : book.source.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZplayType.overline
                                        .copyWith(size: 9)
                                        .toStyle(
                                          color: isTorrent ? tokens.warning : tokens.accent,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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
