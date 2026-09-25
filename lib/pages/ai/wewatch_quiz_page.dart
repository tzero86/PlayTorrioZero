import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/ai/wewatch_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../details/details_page.dart';
import '../../services/storage/app_image_cache.dart';

class WeWatchQuizPage extends StatefulWidget {
  const WeWatchQuizPage({super.key});

  @override
  State<WeWatchQuizPage> createState() => _WeWatchQuizPageState();
}

class _WeWatchQuizPageState extends State<WeWatchQuizPage> {
  final List<WeWatchUserPick> _picks = [
    WeWatchUserPick(id: 'pick_1'),
    WeWatchUserPick(id: 'pick_2'),
    WeWatchUserPick(id: 'pick_3'),
  ];

  final Map<String, List<String>> _reasonPillsCache = {};
  final Map<String, bool> _loadingPills = {};
  final Map<int, bool> _showStarterPicks = {};
  final Map<int, TextEditingController> _searchControllers = {};
  final Map<int, List<WeWatchMediaItem>> _searchResults = {};
  final Map<int, bool> _isSearching = {};
  final Map<int, Timer?> _searchDebouncers = {};

  bool _isGenerating = false;
  String _generationStep = 'Analyzing your favorite storylines & themes...';
  List<WeWatchRecommendation>? _recommendations;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppThemeService.currentPalette.addListener(_onThemeChanged);
    for (int i = 0; i < _picks.length; i++) {
      _searchControllers[i] = TextEditingController();
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppThemeService.currentPalette.removeListener(_onThemeChanged);
    for (final c in _searchControllers.values) {
      c.dispose();
    }
    for (final d in _searchDebouncers.values) {
      d?.cancel();
    }
    super.dispose();
  }

  int get _ratedCount => _picks.where((p) => p.isValid).length;
  bool get _canSubmit => _ratedCount >= 3;

  void _onSearchChanged(int index, String query) {
    _searchDebouncers[index]?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults[index] = [];
        _isSearching[index] = false;
      });
      return;
    }

    _searchDebouncers[index] = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearching[index] = true);
      final results = await WeWatchService.searchMedia(trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults[index] = results;
        _isSearching[index] = false;
      });
    });
  }

  void _selectMedia(int index, WeWatchMediaItem item) {
    setState(() {
      final pick = _picks[index];
      pick.title = item.title;
      pick.year = item.year;
      pick.tmdbId = item.tmdbId;
      pick.mediaType = item.mediaType;
      pick.posterUrl = item.posterUrl;
      pick.posterPath = item.posterPath;
      _searchResults[index] = [];
      _showStarterPicks[index] = false;
      _searchControllers[index]?.text = item.title;
    });

    if (_picks[index].sentiment != null) {
      _fetchReasonPills(index);
    }
  }

  void _selectStarterPick(int index, WeWatchStarterPick starter) async {
    setState(() => _isSearching[index] = true);

    final results = await WeWatchService.searchMedia(starter.query);
    if (!mounted) return;

    if (results.isNotEmpty) {
      final match = results.firstWhere(
        (r) => r.mediaType == starter.mediaType,
        orElse: () => results.first,
      );
      _selectMedia(index, match);
    } else {
      setState(() {
        final pick = _picks[index];
        pick.title = starter.label;
        pick.mediaType = starter.mediaType;
        pick.posterUrl = starter.posterUrl;
        pick.posterPath = starter.posterPath;
        _showStarterPicks[index] = false;
        _searchControllers[index]?.text = starter.label;
      });
    }

    setState(() => _isSearching[index] = false);
  }

  void _setSentiment(int index, String sentiment) {
    setState(() {
      _picks[index].sentiment = sentiment;
    });
    _fetchReasonPills(index);
  }

  void _fetchReasonPills(int index) async {
    final pick = _picks[index];
    if (pick.title.isEmpty || pick.sentiment == null) return;

    final cacheKey = '${pick.title}_${pick.year}_${pick.sentiment}';
    if (_reasonPillsCache.containsKey(cacheKey)) {
      setState(() {});
      return;
    }

    setState(() => _loadingPills[cacheKey] = true);
    final pills = await WeWatchService.generateReasonPills(
      title: pick.title,
      year: int.tryParse(pick.year ?? ''),
      sentiment: pick.sentiment!,
      tmdbId: pick.tmdbId,
      mediaType: pick.mediaType,
    );

    if (!mounted) return;
    setState(() {
      _reasonPillsCache[cacheKey] = pills;
      _loadingPills[cacheKey] = false;
    });
  }

  void _togglePill(int index, String pill) {
    setState(() {
      final pick = _picks[index];
      if (pick.selectedPills.contains(pill)) {
        pick.selectedPills.remove(pill);
      } else {
        pick.selectedPills.add(pill);
      }
    });
  }

  void _addAnotherTitle() {
    if (_picks.length >= 8) return;
    setState(() {
      final newIndex = _picks.length;
      _picks.add(WeWatchUserPick(id: 'pick_${newIndex + 1}'));
      _searchControllers[newIndex] = TextEditingController();
    });
  }

  void _removeTitle(int index) {
    if (_picks.length <= 1) {
      setState(() {
        _picks[0] = WeWatchUserPick(id: 'pick_1');
        _searchControllers[0]?.clear();
        _searchResults[0] = [];
      });
      return;
    }
    setState(() {
      _picks.removeAt(index);
      _searchControllers[index]?.dispose();
      _searchControllers.remove(index);
      _searchResults.remove(index);
    });
  }

  void _generateRecommendations() async {
    if (!_canSubmit || _isGenerating) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generationStep = 'Studying your storytelling and mood preferences...';
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _isGenerating) {
        setState(() => _generationStep = 'Finding high-precision cinema matches...');
      }
    });

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _isGenerating) {
        setState(() => _generationStep = 'Polishing your personalized recommendations...');
      }
    });

    try {
      final recs = await WeWatchService.submitAndGetRecommendations(_picks);
      if (!mounted) return;
      setState(() {
        _recommendations = recs;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate recommendations: $e';
        _isGenerating = false;
      });
    }
  }

  void _openDetails(WeWatchRecommendation rec) async {
    try {
      final searchResults = await AddonManager.instance.searchAll('${rec.title} ${rec.year ?? ''}');
      Movie? matchedMovie;

      for (final sec in searchResults) {
        for (final m in sec.movies) {
          if (m.name.toLowerCase() == rec.title.toLowerCase()) {
            matchedMovie = m;
            break;
          }
        }
        if (matchedMovie != null) break;
      }

      matchedMovie ??= (searchResults.isNotEmpty && searchResults.first.movies.isNotEmpty)
          ? searchResults.first.movies.first
          : Movie(
              id: 'tmdb:${rec.tmdbId}',
              name: rec.title,
              type: rec.mediaType == 'movie' ? 'movie' : 'series',
              poster: rec.posterUrl,
              year: rec.year,
              addonBaseUrl: '',
              imdbRating: rec.voteAverage?.toStringAsFixed(1),
            );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsPage(movie: matchedMovie!)),
      );
    } catch (e) {
      debugPrint('[WeWatchQuizPage] openDetails error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Ambient Wallpaper & Animated Glow Layer
          const Positioned.fill(
            child: AnimatedAmbientBackground(),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  children: [
                    _buildAppBar(tokens),
                    Expanded(
                      child: _isGenerating
                          ? _buildCinematicLoadingView(tokens)
                          : (_recommendations != null
                              ? _buildRecommendationsView(tokens, isMobile)
                              : _buildQuizForm(tokens, isMobile)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ZplayTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: tokens.textPrimary, size: 20),
            splashRadius: 20,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.18),
              borderRadius: ZplayRadius.smAll,
              border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: tokens.accent),
                const SizedBox(width: 5),
                Text(
                  'AI TASTE MATCH',
                  style: ZplayType.overline
                      .copyWith(
                        size: 11,
                        weight: FontWeight.w900,
                        letterSpacing: 0.6,
                      )
                      .toStyle(color: tokens.accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Recommendation Quiz',
            style: ZplayType.title
                .copyWith(
                  size: 17,
                  weight: FontWeight.w800,
                  letterSpacing: -0.3,
                )
                .toStyle(color: tokens.textPrimary),
          ),
          const Spacer(),
          if (_recommendations != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: tokens.textEmphasis,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Retake',
                style: ZplayType.label
                    .copyWith(size: 12, weight: FontWeight.bold)
                    .toStyle(),
              ),
              onPressed: () => setState(() => _recommendations = null),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizForm(ZplayTokens tokens, bool isMobile) {
    final rated = _ratedCount;
    final progress = (rated / 3.0).clamp(0.0, 1.0);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 16),
      children: [
        // Taste Profile Header Card
        ClipRRect(
          borderRadius: ZplayRadius.mdAll,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.75),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'What do you like to watch?',
                        style: ZplayType.title
                            .copyWith(
                              weight: FontWeight.w900,
                              letterSpacing: -0.3,
                            )
                            .toStyle(color: tokens.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _canSubmit
                              ? tokens.success.withValues(alpha: 0.18)
                              : tokens.textPrimary.withValues(
                                  alpha: ZplayOpacity.borderSubtle,
                                ),
                          borderRadius: ZplayRadius.lgAll,
                          border: Border.all(
                            color: _canSubmit
                                ? tokens.success.withValues(alpha: 0.4)
                                : tokens.borderStrong,
                          ),
                        ),
                        child: Text(
                          '$rated/3 rated',
                          style: ZplayType.caption
                              .copyWith(size: 11.5, weight: FontWeight.w800)
                              .toStyle(
                                color: _canSubmit
                                    ? tokens.success
                                    : tokens.textEmphasis,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rate 3 or more movies or TV shows. Choose what you liked or disliked, and select key elements to generate pinpoint AI recommendations.',
                    style: ZplayType.body
                        .copyWith(size: 13)
                        .toStyle(color: tokens.textEmphasis),
                  ),
                  const SizedBox(height: 14),

                  // Segmented Progress Bar
                  ClipRRect(
                    borderRadius: ZplayRadius.xsAll,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: tokens.borderDefault,
                      valueColor: AlwaysStoppedAnimation(
                        _canSubmit ? tokens.success : tokens.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: 0.15),
              borderRadius: ZplayRadius.smAll,
              border: Border.all(color: tokens.danger.withValues(alpha: 0.35)),
            ),
            child: Text(
              _errorMessage!,
              style: ZplayType.label
                  .copyWith(weight: FontWeight.w600)
                  .toStyle(color: tokens.danger),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Movie/Show Input Cards
        ..._picks.asMap().entries.map((entry) => _buildPickCard(entry.key, entry.value, tokens, isMobile)),

        const SizedBox(height: 12),

        // Add Another Title Button
        if (_picks.length < 8)
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textEmphasis,
                side: tokens.hairlineStrong,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add Another Title',
                style: ZplayType.label
                    .copyWith(weight: FontWeight.w700)
                    .toStyle(),
              ),
              onPressed: _addAnotherTitle,
            ),
          ),

        const SizedBox(height: 20),

        // Generate Recommendations Action
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canSubmit ? tokens.accent : tokens.borderDefault,
            foregroundColor: _canSubmit ? tokens.onAccent : tokens.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.mdAll),
            elevation: _canSubmit ? 4 : 0,
          ),
          onPressed: _canSubmit ? _generateRecommendations : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: _canSubmit ? tokens.onAccent : tokens.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                _canSubmit ? 'Discover Recommendations ($rated Titles)' : 'Rate 3 Titles to Unlock Recommendations',
                style: ZplayType.body
                    .copyWith(size: 14.5, weight: FontWeight.w800)
                    .toStyle(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildPickCard(int index, WeWatchUserPick pick, ZplayTokens tokens, bool isMobile) {
    final hasSelectedMedia = pick.title.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: ZplayRadius.mdAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.7),
              borderRadius: ZplayRadius.mdAll,
              border: Border.all(
                color: pick.isValid
                    ? tokens.accent.withValues(alpha: 0.4)
                    : tokens.borderDefault,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Number badge + Title + Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: pick.isValid
                                ? tokens.accent
                                : tokens.textPrimary.withValues(
                                    alpha: ZplayOpacity.borderMedium,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: pick.isValid
                                ? Icon(Icons.check_rounded, size: 13, color: tokens.textPrimary)
                                : Text(
                                    '${index + 1}',
                                    style: ZplayType.caption
                                        .copyWith(weight: FontWeight.bold)
                                        .toStyle(color: tokens.textEmphasis),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          hasSelectedMedia ? pick.title : 'Title #${index + 1}',
                          style: ZplayType.subtitle
                              .copyWith(weight: FontWeight.w800)
                              .toStyle(color: tokens.textPrimary),
                        ),
                        if (pick.year != null && pick.year!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${pick.year})',
                            style: ZplayType.body
                                .copyWith(size: 13)
                                .toStyle(color: tokens.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: tokens.textMuted),
                      splashRadius: 18,
                      onPressed: () => _removeTitle(index),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 1. Search Box & Starter Picks
                if (!hasSelectedMedia) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.8),
                      borderRadius: ZplayRadius.smAll,
                      border: Border.all(color: tokens.borderDefault),
                    ),
                    child: TextField(
                      controller: _searchControllers[index],
                      style: ZplayType.body.toStyle(color: tokens.textPrimary),
                      onChanged: (q) => _onSearchChanged(index, q),
                      decoration: InputDecoration(
                        hintText: 'Search movie or TV series...',
                        hintStyle: ZplayType.body
                            .copyWith(size: 13)
                            .toStyle(color: tokens.textMuted),
                        prefixIcon: Icon(Icons.search_rounded, color: tokens.accent, size: 18),
                        suffixIcon: (_isSearching[index] ?? false)
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  // Search Auto-Suggestions Dropdown
                  if ((_searchResults[index] ?? []).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: ZplayRadius.smAll,
                        border: Border.all(color: tokens.borderStrong),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults[index]!.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
                        itemBuilder: (context, rIdx) {
                          final item = _searchResults[index]![rIdx];
                          return ListTile(
                            dense: true,
                            leading: ClipRRect(
                              borderRadius: ZplayRadius.xsAll,
                              child: item.posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: item.posterUrl!,
                                      cacheManager: AppImageCache.manager,
                                      memCacheWidth: 96,
                                      width: 28,
                                      height: 42,
                                      fit: BoxFit.cover)
                                  : Container(width: 28, height: 42, color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
                            ),
                            title: Text(
                              item.title,
                              style: ZplayType.label
                                  .copyWith(weight: FontWeight.bold)
                                  .toStyle(color: tokens.textPrimary),
                            ),
                            subtitle: Text(
                              '${item.year ?? ''} • ${item.mediaType == 'movie' ? 'Movie' : 'TV Series'}',
                              style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                            ),
                            onTap: () => _selectMedia(index, item),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Need Ideas Toggle
                  InkWell(
                    onTap: () => setState(() => _showStarterPicks[index] = !(_showStarterPicks[index] ?? false)),
                    borderRadius: ZplayRadius.lgAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                        borderRadius: ZplayRadius.lgAll,
                        border: Border.all(color: tokens.borderDefault),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 14, color: tokens.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Need ideas?',
                            style: ZplayType.label
                                .copyWith(size: 12, weight: FontWeight.bold)
                                .toStyle(color: tokens.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            (_showStarterPicks[index] ?? false)
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: tokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Popular Starter Picks Drawer
                  if (_showStarterPicks[index] ?? false) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: WeWatchService.starterPicks.length,
                        itemBuilder: (context, sIdx) {
                          final starter = WeWatchService.starterPicks[sIdx];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              onTap: () => _selectStarterPick(index, starter),
                              borderRadius: ZplayRadius.smAll,
                              child: Container(
                                width: 72,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                                  borderRadius: ZplayRadius.smAll,
                                  border: Border.all(color: tokens.borderSubtle),
                                ),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: ZplayRadius.xsAll,
                                      child: CachedNetworkImage(
                                        imageUrl: starter.posterUrl,
                                        cacheManager: AppImageCache.manager,
                                        memCacheWidth: 192,
                                        width: 64,
                                        height: 86,
                                        fit: BoxFit.cover),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      starter.label,
                                      style: ZplayType.caption
                                          .copyWith(
                                            size: 10,
                                            weight: FontWeight.w600,
                                          )
                                          .toStyle(color: tokens.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // 2. Selected Media: Poster + Sentiment Buttons + Dynamic Reason Pills
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pick.posterUrl != null)
                        ClipRRect(
                          borderRadius: ZplayRadius.smAll,
                          child: CachedNetworkImage(
                            imageUrl: pick.posterUrl!,
                            cacheManager: AppImageCache.manager,
                            memCacheWidth: 192,
                            width: 64,
                            height: 96,
                            fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How was your experience with it?',
                              style: ZplayType.label
                                  .copyWith(
                                    size: 12,
                                    weight: FontWeight.w600,
                                  )
                                  .toStyle(color: tokens.textEmphasis),
                            ),
                            const SizedBox(height: 8),

                            // Sentiment Selector
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildSentimentButton(index, 'loved', 'Loved it ❤️', tokens),
                                _buildSentimentButton(index, 'liked', 'Liked it 👍', tokens),
                                _buildSentimentButton(index, 'meh', 'It was okay 😐', tokens),
                                _buildSentimentButton(index, 'hated', 'Disliked 👎', tokens),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Dynamic AI Reason Pills
                  if (pick.sentiment != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'What stood out? (Pick key elements or write a note):',
                      style: ZplayType.label
                          .copyWith(size: 12, weight: FontWeight.w600)
                          .toStyle(color: tokens.textEmphasis),
                    ),
                    const SizedBox(height: 8),

                    Builder(
                      builder: (context) {
                        final cacheKey = '${pick.title}_${pick.year}_${pick.sentiment}';
                        final isLoading = _loadingPills[cacheKey] ?? false;
                        final pills = _reasonPillsCache[cacheKey] ?? [];

                        if (isLoading && pills.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fetching reason tags...',
                                  style: ZplayType.caption.toStyle(
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pills.map((pill) {
                            final isSelected = pick.selectedPills.contains(pill);
                            return ChoiceChip(
                              label: Text(pill),
                              selected: isSelected,
                              selectedColor: tokens.accentSubtle,
                              backgroundColor: tokens.surface.withValues(alpha: 0.6),
                              labelStyle: ZplayType.caption
                                  .copyWith(
                                    size: 11.5,
                                    weight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  )
                                  .toStyle(
                                    color: isSelected
                                        ? tokens.accent
                                        : tokens.textEmphasis,
                                  ),
                              side: BorderSide(
                                color: isSelected
                                    ? tokens.accent.withValues(alpha: 0.6)
                                    : tokens.borderDefault,
                              ),
                              shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                              onSelected: (_) => _togglePill(index, pill),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // User Comment / Note
                    TextField(
                      style: ZplayType.body
                          .copyWith(size: 13)
                          .toStyle(color: tokens.textPrimary),
                      maxLines: 2,
                      onChanged: (val) => pick.reason = val,
                      decoration: InputDecoration(
                        hintText: 'Additional notes or specifics (optional)...',
                        hintStyle: ZplayType.bodySmall.toStyle(color: tokens.textDisabled),
                        filled: true,
                        fillColor: tokens.surface.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: ZplayRadius.smAll,
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: ZplayRadius.smAll,
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: ZplayRadius.smAll,
                          borderSide: BorderSide(color: tokens.accent.withValues(alpha: 0.4)),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentButton(int index, String value, String label, ZplayTokens tokens) {
    final isSelected = _picks[index].sentiment == value;

    return InkWell(
      onTap: () => _setSentiment(index, value),
      borderRadius: ZplayRadius.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accentSubtle
              : tokens.surface.withValues(alpha: 0.6),
          borderRadius: ZplayRadius.smAll,
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.borderStrong,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: ZplayType.caption
              .copyWith(
                size: 11.5,
                weight: isSelected ? FontWeight.w800 : FontWeight.w500,
              )
              .toStyle(
                color: isSelected ? tokens.textPrimary : tokens.textEmphasis,
              ),
        ),
      ),
    );
  }

  Widget _buildCinematicLoadingView(ZplayTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: ZplayRadius.lgAll,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.8),
                borderRadius: ZplayRadius.lgAll,
                border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(tokens.accent),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _generationStep,
                    style: ZplayType.subtitle
                        .copyWith(size: 16, weight: FontWeight.w800)
                        .toStyle(color: tokens.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Synthesizing taste vectors with multi-signal AI...',
                    style: ZplayType.bodySmall
                        .copyWith(size: 12.5)
                        .toStyle(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsView(ZplayTokens tokens, bool isMobile) {
    final recs = _recommendations!;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Personalized Matches',
                  style: ZplayType.titleLarge
                      .copyWith(
                        size: 19,
                        weight: FontWeight.w900,
                        letterSpacing: -0.3,
                      )
                      .toStyle(color: tokens.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${recs.length} cinema picks tailored to your taste profile',
                  style: ZplayType.bodySmall
                      .copyWith(size: 12.5)
                      .toStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Grid / Cards of Recommendations
        ...recs.map((rec) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
              borderRadius: ZplayRadius.mdAll,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surface.withValues(alpha: 0.75),
                    borderRadius: ZplayRadius.mdAll,
                    border: Border.all(color: tokens.borderDefault),
                  ),
                  child: InkWell(
                    onTap: () => _openDetails(rec),
                    borderRadius: ZplayRadius.mdAll,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster
                        ClipRRect(
                          borderRadius: ZplayRadius.smAll,
                          child: rec.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: rec.posterUrl!,
                                  cacheManager: AppImageCache.manager,
                                  width: isMobile ? 80 : 96,
                                  height: isMobile ? 120 : 144,
                                  fit: BoxFit.cover)
                              : Container(
                                  width: isMobile ? 80 : 96,
                                  height: isMobile ? 120 : 144,
                                  color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium),
                                ),
                        ),
                        const SizedBox(width: 14),

                        // Movie Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      rec.title,
                                      style: ZplayType.subtitle
                                          .copyWith(weight: FontWeight.w900)
                                          .toStyle(color: tokens.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: tokens.success.withValues(alpha: 0.18),
                                      borderRadius: ZplayRadius.xsAll,
                                      border: Border.all(color: tokens.success.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '${rec.matchConfidence}% MATCH',
                                      style: ZplayType.overline
                                          .copyWith(
                                            size: 10.5,
                                            weight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          )
                                          .toStyle(color: tokens.success),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (rec.year != null)
                                    Text(
                                      rec.year!,
                                      style: ZplayType.bodySmall.toStyle(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  if (rec.mediaType.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '•  ${rec.mediaType == 'movie' ? 'Movie' : 'TV Series'}',
                                      style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                                    ),
                                  ],
                                  if (rec.voteAverage != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '•  ★ ${rec.voteAverage!.toStringAsFixed(1)}',
                                      style: ZplayType.bodySmall
                                          .copyWith(weight: FontWeight.bold)
                                          .toStyle(color: tokens.warning),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Why it fits
                              Text(
                                rec.reasoning,
                                style: ZplayType.bodySmall
                                    .copyWith(height: 1.35)
                                    .toStyle(color: tokens.textEmphasis),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Match Explanation
                              Text(
                                rec.matchExplanation,
                                style: ZplayType.caption
                                    .copyWith(size: 11.5)
                                    .toStyle(color: tokens.accent)
                                    .copyWith(fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 30),
      ],
    );
  }
}
