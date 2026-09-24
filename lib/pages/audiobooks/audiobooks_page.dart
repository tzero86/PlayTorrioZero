import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../../services/theme/app_theme_service.dart';
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
    final palette = AppThemeService.currentPalette.value;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF10131C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
                      Icon(Icons.tune_rounded, color: palette.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Customize Audiobook Section',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  const Text(
                    'Poster Card Density',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
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
                        title: const Text('Featured Hero Spotlight Carousel', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: enabled,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => AudiobookSettings.setEnableSpotlight(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: AudiobookSettings.enableAmbientLights,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Moving Ambient Background Glow', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: enabled,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => AudiobookSettings.setEnableAmbientLights(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: AudiobookSettings.showContinueListening,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show "Continue Listening" Carousel', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: show,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => AudiobookSettings.setShowContinueListening(val),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryColor.withValues(alpha: 0.15),
                        foregroundColor: palette.primaryColor,
                        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.palette_rounded, size: 18),
                      label: const Text('Open Player Studio & Themes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
    final palette = AppThemeService.currentPalette.value;
    final ambientEnabled = AudiobookSettings.enableAmbientLights.value;
    final showSpotlight = AudiobookSettings.enableSpotlight.value;
    final showContinue = AudiobookSettings.showContinueListening.value;
    final showCategoryPills = AudiobookSettings.showCategoryPills.value;
    final cardDensity = AudiobookSettings.cardDensity.value;

    final spotlightBook = _searchResults.isNotEmpty ? _searchResults.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // ── Ambient Background Glows ──
          if (ambientEnabled)
            const Positioned.fill(child: AnimatedAmbientBackground())
          else
            Positioned.fill(
              child: Container(color: palette.scaffoldBackgroundColor),
            ),

          // ── Main Content Scroll ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    topInset + 12,
                    isMobile ? 16 : 24,
                    12,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
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
                          gradient: LinearGradient(
                            colors: [palette.primaryColor, palette.accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryColor.withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audiobook Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Explore, stream & listen to thousands of stories',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // AI Generator & Studio Button
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  palette.primaryColor.withValues(alpha: 0.25),
                                  palette.primaryColor.withValues(alpha: 0.25),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.primaryColor.withValues(alpha: 0.35)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
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
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
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
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12151E).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _searchController.text.isNotEmpty ? palette.primaryColor : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            hintText: 'Search audiobooks by title, author, or genre...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: palette.primaryColor),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
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
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: palette.primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF10131D).withValues(alpha: 0.8),
                            labelStyle: TextStyle(
                              color: isSelected ? palette.primaryColor : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? palette.primaryColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
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
                  child: _buildHeroSpotlight(spotlightBook, isMobile, palette),
                ),

              // Continue Listening Section (If available)
              if (showContinue && _continueListeningList.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildContinueListeningSection(palette),
                ),

              // Generated & Personal Audiobooks Studio Shelf
              if (!_isSearching)
                SliverToBoxAdapter(
                  child: _buildGeneratedAndUploadedSection(palette),
                ),

              // Discovery Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    16,
                    isMobile ? 16 : 24,
                    8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _searchController.text.isNotEmpty ? 'Search Results' : 'Featured Audiobooks',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_searchResults.length} TITLES',
                          style: TextStyle(color: palette.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
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
                        CircularProgressIndicator(color: palette.primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'Scraping high-quality audiobook sources...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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
                      style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                    ),
                  ),
                )
              else if (_searchResults.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No audiobooks found. Try another search query.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    8,
                    isMobile ? 16 : 24,
                    32 + bottomInset,
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
                          palette: palette,
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
  Widget _buildHeroSpotlight(Audiobook book, bool isMobile, AppThemePalette palette) {
    final heroTag = 'spotlight-hero-${book.uuid.isNotEmpty ? book.uuid : book.title}';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      height: isMobile ? 220 : 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF0080A0F),
                    Color(0xB0080A0F),
                    Color(0x80080A0F),
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
                        borderRadius: BorderRadius.circular(16),
                        child: book.coverImage.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: book.coverImage.trim(),
                                cacheManager: AppImageCache.manager,
                                httpHeaders: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                },
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: const Color(0xFF161A24)),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFF161A24),
                                  child: const Icon(Icons.headphones_rounded, color: Colors.white38),
                                ))
                            : Container(color: const Color(0xFF161A24)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SPOTLIGHT FEATURED',
                            style: TextStyle(color: palette.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 17 : 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.source.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
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
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Listen Now',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  Widget _buildContinueListeningSection(AppThemePalette palette) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        12,
        isMobile ? 16 : 24,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: palette.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Continue Listening',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
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
          const SizedBox(height: 12),
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
                  palette: palette,
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
  Widget _buildGeneratedAndUploadedSection(AppThemePalette palette) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;

    final jobs = Paper2AudioService.instance.jobs.value;
    final uploaded = CustomAudiobookService.instance.audiobooks.value;
    final hasItems = jobs.isNotEmpty || uploaded.isNotEmpty;

    if (!hasItems) {
      // Sleek quick studio banner
      return Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          8,
          isMobile ? 16 : 24,
          16,
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
            );
            _loadContinueListening();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.primaryColor.withValues(alpha: 0.15),
                  palette.primaryColor.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: palette.primaryColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Audiobook Studio & EPUB Generator',
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Generate audiobooks from EPUBs or import your own MP3/M4B audiobooks.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
                    );
                    _loadContinueListening();
                  },
                  child: const Text('Open Studio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        8,
        isMobile ? 16 : 24,
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
                  Icon(Icons.record_voice_over_rounded, color: palette.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'My Generated & Uploaded Audiobooks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Studio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: palette.primaryColor),
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
                      color: const Color(0xFF12151E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: job.coverPath != null && File(job.coverPath!).existsSync()
                              ? Image.file(File(job.coverPath!), fit: BoxFit.cover)
                              : const Icon(Icons.headphones_rounded, color: Colors.white30, size: 24),
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
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isDone ? 'Voice: ${job.voiceId}' : (isFailed ? 'Failed' : 'Generating ${(job.progress * 100).round()}%'),
                                style: TextStyle(
                                  color: isDone ? const Color(0xFF10B981) : (isFailed ? Colors.redAccent : const Color(0xFFF59E0B)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isDone)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                  label: const Text('Play', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: job.progress > 0 ? job.progress : null,
                                    backgroundColor: Colors.white10,
                                    color: palette.primaryColor,
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
                      color: const Color(0xFF12151E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: b.coverPath != null && File(b.coverPath!).existsSync()
                              ? Image.file(File(b.coverPath!), fit: BoxFit.cover)
                              : const Icon(Icons.library_music_rounded, color: Colors.white30, size: 24),
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
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${b.author} • Local',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                label: const Text('Play', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
  final AppThemePalette palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ContinueListeningCard({
    required this.progress,
    required this.palette,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                        ? const Color(0xFF1B2030)
                        : const Color(0xFF12151E).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.highlighted
                          ? palette.primaryColor.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: state.highlighted ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: state.highlighted
                            ? palette.primaryColor.withValues(alpha: 0.3)
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
                            borderRadius: BorderRadius.circular(10),
                            child: hasCover
                                ? CachedNetworkImage(
                                    imageUrl: book.coverImage,
                                    cacheManager: AppImageCache.manager,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: const Color(0xFF1A1F2C)),
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF1A1F2C),
                                      child: const Icon(Icons.headphones_rounded, color: Colors.white38),
                                    ))
                                : Container(
                                    color: const Color(0xFF1A1F2C),
                                    child: const Icon(Icons.headphones_rounded, color: Colors.white38),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentChapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 4,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(palette.primaryColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(percent * 100).toInt()}% completed',
                              style: TextStyle(
                                color: palette.primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Play Button Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: state.highlighted
                              ? palette.primaryColor
                              : palette.primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: state.highlighted ? Colors.white : palette.primaryColor,
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
                    color: state.highlighted
                        ? const Color(0xFFFF4D4D)
                        : const Color(0xFF1E2332),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.highlighted
                          ? const Color(0xFFFF4D4D)
                          : Colors.white.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
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
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: state.highlighted
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: state.highlighted
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            color: state.highlighted ? Colors.white : Colors.white70,
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
  final AppThemePalette palette;
  final VoidCallback? onReturn;

  const _AudiobookCard({
    super.key,
    required this.book,
    required this.heroTag,
    required this.palette,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
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
              color: state.highlighted ? const Color(0xFF191E2C) : const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.highlighted
                    ? palette.primaryColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
                width: state.highlighted ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: state.highlighted && cardHoverGlow
                      ? palette.primaryColor.withValues(alpha: 0.35)
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: hasCover
                          ? CachedNetworkImage(
                              imageUrl: book.coverImage,
                              cacheManager: AppImageCache.manager,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF1A1F2C)),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF1A1F2C),
                                child: const Icon(Icons.headphones_rounded, size: 40, color: Colors.white38),
                              ))
                          : Container(
                              color: const Color(0xFF1A1F2C),
                              child: const Center(
                                child: Icon(Icons.headphones_rounded, size: 40, color: Colors.white38),
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
                        style: TextStyle(
                          color: state.highlighted ? Colors.white : Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final isTorrent = book.source.toLowerCase().contains('audiobookbay');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTorrent
                                  ? const Color(0xFFFF9800).withValues(alpha: 0.25)
                                  : (state.highlighted
                                      ? palette.primaryColor.withValues(alpha: 0.35)
                                      : palette.primaryColor.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(6),
                              border: isTorrent
                                  ? Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4), width: 0.8)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isTorrent) ...[
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 10),
                                  const SizedBox(width: 3),
                                ],
                                Flexible(
                                  child: Text(
                                    isTorrent ? 'AUDIOBOOKBAY' : book.source.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isTorrent ? const Color(0xFFFFB74D) : palette.primaryColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
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
