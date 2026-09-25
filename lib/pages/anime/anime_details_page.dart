import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/anime/extractors/anidb_extractor.dart';
import '../../services/theme/design_tokens.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/slider_arrow.dart';
import 'anime_stream_sheet.dart';
import '../../services/storage/app_image_cache.dart';

class AnimeDetailsPage extends StatefulWidget {
  final AnimeMedia anime;

  const AnimeDetailsPage({
    super.key,
    required this.anime,
  });

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimeMedia _anime;
  bool _isDub = false;
  bool _isSynopsisExpanded = false;

  int _selectedEpisodeBatch = 0; // 50 episodes per chunk
  int? _highlightedEpisode;
  List<AniDbEpisode>? _aniDbEpisodes;

  static const int _chunkSize = 50;

  final TextEditingController _jumpEpController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _castScrollController = ScrollController();
  final ScrollController _relationsScrollController = ScrollController();
  final ScrollController _recsScrollController = ScrollController();

  bool _canScrollCastLeft = false;
  bool _canScrollCastRight = true;
  bool _isHoveringCast = false;

  bool _canScrollRelationsLeft = false;
  bool _canScrollRelationsRight = true;
  bool _isHoveringRelations = false;

  bool _canScrollRecsLeft = false;
  bool _canScrollRecsRight = true;
  bool _isHoveringRecs = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.anime;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
    _loadDetails();
    _resolveAniDbEpisodes();

    _castScrollController.addListener(_updateCastScrollButtons);
    _relationsScrollController.addListener(_updateRelationsScrollButtons);
    _recsScrollController.addListener(_updateRecsScrollButtons);
  }

  @override
  void dispose() {
    _animController.dispose();
    _jumpEpController.dispose();
    _castScrollController.dispose();
    _relationsScrollController.dispose();
    _recsScrollController.dispose();
    super.dispose();
  }

  void _loadDetails() async {
    final full = await AnilistService.instance.fetchAnimeDetails(_anime.id);
    if (mounted) {
      setState(() {
        if (full != null) _anime = full;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateCastScrollButtons();
          _updateRelationsScrollButtons();
          _updateRecsScrollButtons();
        }
      });
    }
  }

  void _resolveAniDbEpisodes() async {
    try {
      final slug = await AniDbExtractor.instance.mapAnime(
        titleCandidates: [
          _anime.titleEnglish,
          _anime.titleRomaji,
          _anime.titleNative,
          _anime.titleUserPreferred,
        ].where((t) => t.isNotEmpty).toList(),
      );
      if (slug != null) {
        final episodes = await AniDbExtractor.instance.getEpisodes(slug);
        if (episodes != null && mounted) {
          setState(() => _aniDbEpisodes = episodes);
        }
      }
    } catch (_) {}
  }

  int get _computedTotalEpisodes {
    if (_aniDbEpisodes != null && _aniDbEpisodes!.isNotEmpty) {
      return _aniDbEpisodes!.length;
    }
    if (_anime.totalEpisodes > 0) return _anime.totalEpisodes;
    if (_anime.nextAiring != null && _anime.nextAiring!.episode > 1) {
      return _anime.nextAiring!.episode - 1;
    }
    if (_anime.format.toUpperCase() == 'MOVIE') return 1;
    return 24;
  }

  void _updateCastScrollButtons() {
    if (!_castScrollController.hasClients) return;
    final canLeft = _castScrollController.position.pixels > 0;
    final canRight = _castScrollController.position.pixels <
        _castScrollController.position.maxScrollExtent;
    if (_canScrollCastLeft != canLeft || _canScrollCastRight != canRight) {
      setState(() {
        _canScrollCastLeft = canLeft;
        _canScrollCastRight = canRight;
      });
    }
  }

  void _updateRelationsScrollButtons() {
    if (!_relationsScrollController.hasClients) return;
    final canLeft = _relationsScrollController.position.pixels > 0;
    final canRight = _relationsScrollController.position.pixels <
        _relationsScrollController.position.maxScrollExtent;
    if (_canScrollRelationsLeft != canLeft ||
        _canScrollRelationsRight != canRight) {
      setState(() {
        _canScrollRelationsLeft = canLeft;
        _canScrollRelationsRight = canRight;
      });
    }
  }

  void _updateRecsScrollButtons() {
    if (!_recsScrollController.hasClients) return;
    final canLeft = _recsScrollController.position.pixels > 0;
    final canRight = _recsScrollController.position.pixels <
        _recsScrollController.position.maxScrollExtent;
    if (_canScrollRecsLeft != canLeft || _canScrollRecsRight != canRight) {
      setState(() {
        _canScrollRecsLeft = canLeft;
        _canScrollRecsRight = canRight;
      });
    }
  }

  void _scrollList(ScrollController controller, double directionMultiplier) {
    if (!controller.hasClients) return;
    final viewportWidth = controller.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.7 * directionMultiplier;
    final target = (controller.position.pixels + scrollAmount)
        .clamp(0.0, controller.position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _playEpisode(int episodeNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnimeStreamSheet(
        anime: _anime,
        episodeNumber: episodeNumber,
        autoPlay: false,
        aniDbEpisodes: _aniDbEpisodes,
        totalEpisodes: _computedTotalEpisodes,
      ),
    );
  }

  void _jumpToEpisode(String value) {
    final ep = int.tryParse(value.trim());
    if (ep == null || ep <= 0) return;

    final totalEps = _computedTotalEpisodes;
    final targetEp = ep.clamp(1, totalEps);
    final targetBatch = ((targetEp - 1) / _chunkSize).floor();

    setState(() {
      _selectedEpisodeBatch = targetBatch;
      _highlightedEpisode = targetEp;
    });
    FocusScope.of(context).unfocus();
  }

  void _navigateToAnime(AnimeMedia target) {
    Navigator.push(
      context,
      CinematicSlideRoute(
        page: AnimeDetailsPage(anime: target),
      ),
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final bgUrl = _anime.backdropUrl;
    final posterUrl = _anime.coverUrl;
    final isDesktop = _isDesktop();
    final screenSize = MediaQuery.sizeOf(context);
    final tokens = ZplayTokens.of(context);

    final heroHeight =
        (screenSize.height * (isDesktop ? 0.46 : 0.4)).clamp(320.0, 520.0);
    final contentMaxWidth = isDesktop ? 1440.0 : double.infinity;
    final overlap = isDesktop ? 120.0 : 70.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedAmbientBackground(
        child: Stack(
          children: [
            if (bgUrl.isNotEmpty) _buildBackdrop(bgUrl, screenSize),

          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? ZplaySpacing.s48 : ZplaySpacing.s24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: heroHeight - overlap),
                            isDesktop
                                ? _buildDesktopLayout(posterUrl)
                                : _buildMobileLayout(posterUrl),
                            const SizedBox(height: ZplaySpacing.s32),

                            // Characters & Voice Cast Row
                            if (_anime.characters.isNotEmpty) ...[
                              _buildCharactersRow(),
                              const SizedBox(height: ZplaySpacing.s32),
                            ],

                            // Episodes Section with 50-Chunking & Jump Input
                            _buildEpisodesSection(),
                            const SizedBox(height: ZplaySpacing.s32),

                            // Franchise & Relations Row
                            if (_anime.relations.isNotEmpty) ...[
                              _buildRelationsRow(),
                              const SizedBox(height: ZplaySpacing.s32),
                            ],

                            // You May Also Like / Recommendations Row
                            if (_anime.recommendations.isNotEmpty) ...[
                              _buildRecommendationsRow(),
                              const SizedBox(height: ZplaySpacing.s32),
                            ],

                            const SizedBox(height: ZplaySpacing.s48),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Frosted Back Button (Top Left)
          Positioned(
            top: ZplaySpacing.s24,
            left: isDesktop ? ZplaySpacing.s48 : ZplaySpacing.s16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: tokens.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.borderDefault,
                    padding: const EdgeInsets.all(ZplaySpacing.s12),
                    side: BorderSide(color: tokens.borderStrong),
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

  // ─── Persistent Cinematic Backdrop ─────────────────────────────
  Widget _buildBackdrop(String bgUrl, Size screenSize) {
    final tokens = ZplayTokens.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: screenSize.height,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: bgUrl,
              cacheManager: AppImageCache.manager,
              memCacheWidth: 1280,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => ColoredBox(color: tokens.surface),
            ),
            // Horizontal wash: darkens where the title sits
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [tokens.bg, tokens.bg.withValues(alpha: 0.6), Colors.transparent],
                  stops: const [0.0, 0.42, 0.82],
                ),
              ),
            ),
            // Slow bottom fade: resolves smoothly to solid background
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, tokens.bg.withValues(alpha: 0.4), tokens.bg],
                  stops: const [0.0, 0.62, 0.94],
                ),
              ),
            ),
            // Top contrast cap for back button
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                  stops: [0.0, 0.22],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Desktop 2-Column Layout ───────────────────────────────────
  Widget _buildDesktopLayout(String posterUrl) {
    final tokens = ZplayTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (posterUrl.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: ZplayRadius.mdAll,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.22),
                        blurRadius: 46,
                        spreadRadius: -6,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: ZplayRadius.mdAll,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        cacheManager: AppImageCache.manager,
                        memCacheWidth: 512,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: tokens.surface),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: ZplaySpacing.s24),
              _buildPlayButton(fullWidth: true),
              const SizedBox(height: ZplaySpacing.s12),
              _buildLibraryButton(fullWidth: true),
            ],
          ),
        ),
        const SizedBox(width: ZplaySpacing.s32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(isDesktop: true),
              const SizedBox(height: ZplaySpacing.s16),
              _buildMetadataRow(),
              if (_anime.description.isNotEmpty) ...[
                const SizedBox(height: ZplaySpacing.s24),
                _buildSynopsis(_anime.description),
              ],
              if (_anime.genres.isNotEmpty) ...[
                const SizedBox(height: ZplaySpacing.s24),
                _buildGenreChips(_anime.genres),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Mobile / Compact Single Column Layout ─────────────────────
  Widget _buildMobileLayout(String posterUrl) {
    final tokens = ZplayTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (posterUrl.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: ZplayRadius.smAll,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.20),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: ZplayRadius.smAll,
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    cacheManager: AppImageCache.manager,
                    memCacheWidth: 330,
                    width: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(width: ZplaySpacing.s16),
            Expanded(child: _buildTitle(isDesktop: false)),
          ],
        ),
        const SizedBox(height: ZplaySpacing.s24),
        _buildMetadataRow(),
        const SizedBox(height: ZplaySpacing.s24),
        Row(
          children: [
            Expanded(child: _buildPlayButton(fullWidth: true)),
            const SizedBox(width: ZplaySpacing.s12),
            _buildLibraryButton(fullWidth: false),
          ],
        ),
        if (_anime.description.isNotEmpty) ...[
          const SizedBox(height: ZplaySpacing.s24),
          _buildSynopsis(_anime.description),
        ],
        if (_anime.genres.isNotEmpty) ...[
          const SizedBox(height: ZplaySpacing.s16),
          _buildGenreChips(_anime.genres),
        ],
      ],
    );
  }

  Widget _buildTitle({required bool isDesktop}) {
    final tokens = ZplayTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _anime.displayTitle,
          style: ZplayType.display
              .copyWith(
                size: isDesktop ? 38 : 26,
                weight: FontWeight.w900,
                letterSpacing: -0.8,
              )
              .toStyle(color: tokens.textPrimary)
              .copyWith(
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
        ),
        if (_anime.titleNative.isNotEmpty &&
            _anime.titleNative != _anime.displayTitle)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _anime.titleNative,
              style: ZplayType.bodySmall
                  .copyWith(
                    size: isDesktop ? 14 : 12,
                    weight: FontWeight.w500,
                  )
                  .toStyle(color: tokens.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataRow() {
    final tokens = ZplayTokens.of(context);
    final List<Widget> items = [];

    if (_anime.seasonYear > 0) {
      items.add(
        Text(
          '${_anime.seasonYear}',
          style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
        ),
      );
    }

    if (_anime.formattedFormat.isNotEmpty) {
      items.add(
        Text(
          _anime.formattedFormat,
          style: ZplayType.body.toStyle(color: tokens.textEmphasis),
        ),
      );
    }

    final totalEps = _computedTotalEpisodes;
    if (totalEps > 0) {
      items.add(
        Text(
          '$totalEps Ep${totalEps > 1 ? "s" : ""}',
          style: ZplayType.body.toStyle(color: tokens.textEmphasis),
        ),
      );
    }

    if (_anime.averageScore > 0) {
      items.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.borderStrong,
            borderRadius: ZplayRadius.xsAll,
            border: Border.all(color: tokens.textDisabled),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: tokens.warning, size: 14),
              const SizedBox(width: ZplaySpacing.s4),
              Text(
                _anime.formattedScore,
                style: ZplayType.bodySmall
                    .copyWith(weight: FontWeight.w700)
                    .toStyle(color: tokens.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    if (_anime.studioName.isNotEmpty) {
      items.add(
        Text(
          _anime.studioName,
          style: ZplayType.body.toStyle(color: tokens.textEmphasis),
        ),
      );
    }

    final List<Widget> spaced = [];
    for (int i = 0; i < items.length; i++) {
      spaced.add(items[i]);
      if (i < items.length - 1) {
        spaced.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s12),
            child: Text(
              '•',
              style: ZplayType.body.toStyle(color: tokens.textDisabled),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: spaced,
    );
  }

  Widget _buildPlayButton({required bool fullWidth}) {
    final library = AnimeLibraryService.instance;
    final watchItem = library.getWatchlistItem(_anime.id);
    final resumeEp = watchItem?.lastWatchedEpisode ?? 1;
    final tokens = ZplayTokens.of(context);

    return _HoverScale(
      onTap: () => _playEpisode(resumeEp),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tokens.accent, tokens.accentPressed],
          ),
          borderRadius: ZplayRadius.smAll,
          boxShadow: [
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: tokens.onAccent, size: 24),
            const SizedBox(width: 6),
            Text(
              watchItem != null && watchItem.lastWatchedEpisode > 0
                  ? 'Resume Ep $resumeEp'
                  : 'Play Ep 1',
              style: ZplayType.subtitle
                  .copyWith(weight: FontWeight.w800, letterSpacing: 0.3)
                  .toStyle(color: tokens.onAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryButton({required bool fullWidth}) {
    final library = AnimeLibraryService.instance;
    final watchItem = library.getWatchlistItem(_anime.id);
    final tokens = ZplayTokens.of(context);

    return PopupMenuButton<AnimeWatchStatus>(
      onSelected: (status) {
        library.setWatchlistStatus(_anime, status);
        setState(() {});
      },
      color: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: ZplayRadius.mdAll,
        side: BorderSide(color: tokens.borderStrong),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AnimeWatchStatus.watching,
          child: Text('Watching', style: ZplayType.body.toStyle(color: tokens.textPrimary)),
        ),
        PopupMenuItem(
          value: AnimeWatchStatus.planToWatch,
          child: Text('Plan to Watch', style: ZplayType.body.toStyle(color: tokens.textPrimary)),
        ),
        PopupMenuItem(
          value: AnimeWatchStatus.completed,
          child: Text('Completed', style: ZplayType.body.toStyle(color: tokens.textPrimary)),
        ),
        PopupMenuItem(
          value: AnimeWatchStatus.dropped,
          child: Text('Dropped', style: ZplayType.body.toStyle(color: tokens.textSecondary)),
        ),
      ],
      child: _HoverScale(
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s20, vertical: 13),
          decoration: BoxDecoration(
            color: tokens.borderDefault,
            borderRadius: ZplayRadius.smAll,
            border: Border.all(
              color: watchItem != null
                  ? tokens.success
                  : tokens.borderStrong,
            ),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                watchItem != null
                    ? Icons.check_circle_rounded
                    : Icons.bookmark_outline_rounded,
                color: watchItem != null
                    ? tokens.success
                    : tokens.textEmphasis,
                size: 18,
              ),
              const SizedBox(width: ZplaySpacing.s8),
              Text(
                watchItem != null
                    ? watchItem.status.name.toUpperCase()
                    : 'ADD TO LIST',
                style: ZplayType.label
                    .copyWith(weight: FontWeight.w800, letterSpacing: 0.3)
                    .toStyle(
                      color: watchItem != null
                          ? tokens.success
                          : tokens.textEmphasis,
                    ),
              ),
              const SizedBox(width: ZplaySpacing.s4),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: tokens.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSynopsis(String description) {
    final tokens = ZplayTokens.of(context);
    return FocusableCard(
      onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
      builder: (_, state) => AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        firstChild: Text(
          description,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: ZplayType.body
              .copyWith(height: 1.55)
              .toStyle(color: tokens.textEmphasis),
        ),
        secondChild: Text(
          description,
          style: ZplayType.body
              .copyWith(height: 1.55)
              .toStyle(color: tokens.textEmphasis),
        ),
        crossFadeState: _isSynopsisExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
      ),
    );
  }

  Widget _buildGenreChips(List<String> genres) {
    final tokens = ZplayTokens.of(context);
    return Wrap(
      spacing: ZplaySpacing.s8,
      runSpacing: ZplaySpacing.s8,
      children: genres
          .map(
            (g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s12, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: ZplayRadius.lgAll,
                border: Border.all(color: tokens.borderStrong),
              ),
              child: Text(
                g,
                style: ZplayType.bodySmall
                    .copyWith(weight: FontWeight.w600)
                    .toStyle(color: tokens.textEmphasis),
              ),
            ),
          )
          .toList(),
    );
  }

  // ─── Characters & Voice Cast Row ───────────────────────────────
  Widget _buildCharactersRow() {
    final tokens = ZplayTokens.of(context);
    final isDesktop = _isDesktop();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Characters & Cast'),
        const SizedBox(height: ZplaySpacing.s16),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringCast = true),
          onExit: (_) => setState(() => _isHoveringCast = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 180,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _castScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _anime.characters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: ZplaySpacing.s16),
                  itemBuilder: (context, index) {
                    final char = _anime.characters[index];
                    return SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HoverScale(
                            child: ClipRRect(
                              borderRadius: ZplayRadius.smAll,
                              child: CachedNetworkImage(
                                imageUrl: char.imageLarge,
                                cacheManager: AppImageCache.manager,
                                memCacheWidth: 300,
                                width: 100,
                                height: 110,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 100,
                                  height: 110,
                                  color: tokens.surface,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: tokens.textDisabled,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            char.nameFull,
                            style: ZplayType.bodySmall
                                .copyWith(weight: FontWeight.w700)
                                .toStyle(color: tokens.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            char.role,
                            style: ZplayType.overline.toStyle(color: tokens.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
              if (isDesktop) ...[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _canScrollCastLeft && _isHoveringCast ? 10 : -60,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SliderArrow(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => _scrollList(_castScrollController, -1),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  right: _canScrollCastRight && _isHoveringCast ? 10 : -60,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SliderArrow(
                      icon: Icons.arrow_forward_ios_rounded,
                      onTap: () => _scrollList(_castScrollController, 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Episodes Section (50-Chunking, Jump Input, SUB/DUB) ────────
  Widget _buildEpisodesSection() {
    final tokens = ZplayTokens.of(context);
    final library = AnimeLibraryService.instance;
    final watchItem = library.getWatchlistItem(_anime.id);
    final totalEps = _computedTotalEpisodes;
    final totalBatches = (totalEps / _chunkSize).ceil().clamp(1, 9999);
    final currentBatchSafe = _selectedEpisodeBatch.clamp(0, totalBatches - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episodes Header & Controls
        Wrap(
          spacing: ZplaySpacing.s12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('Episodes'),
                const SizedBox(width: ZplaySpacing.s8),
                Text(
                  '($totalEps total)',
                  style: ZplayType.body.toStyle(color: tokens.textSecondary),
                ),
              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SUB / DUB Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: ZplayRadius.smAll,
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Row(
                    children: [
                      FocusableCard(
                        onTap: () => setState(() => _isDub = false),
                        builder: (_, state) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: !_isDub ? tokens.accent : Colors.transparent,
                            borderRadius: ZplayRadius.smAll,
                          ),
                          child: Text(
                            'SUB',
                            style: ZplayType.caption
                                .copyWith(weight: FontWeight.w900)
                                .toStyle(
                                  color: !_isDub
                                      ? tokens.onAccent
                                      : tokens.textEmphasis,
                                ),
                          ),
                        ),
                      ),
                      FocusableCard(
                        onTap: () => setState(() => _isDub = true),
                        builder: (_, state) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isDub ? tokens.accent : Colors.transparent,
                            borderRadius: ZplayRadius.smAll,
                          ),
                          child: Text(
                            'DUB',
                            style: ZplayType.caption
                                .copyWith(weight: FontWeight.w900)
                                .toStyle(
                                  color: _isDub
                                      ? tokens.onAccent
                                      : tokens.textEmphasis,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: ZplaySpacing.s12),

                // Jump to Ep Input
                Container(
                  width: 130,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: ZplayRadius.smAll,
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: TextField(
                    controller: _jumpEpController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _jumpToEpisode,
                    style: ZplayType.bodySmall.toStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Jump to ep #',
                      hintStyle: ZplayType.caption.toStyle(color: tokens.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZplaySpacing.s8,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: tokens.accent,
                          size: 16,
                        ),
                        onPressed: () =>
                            _jumpToEpisode(_jumpEpController.text),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: ZplaySpacing.s8),

                // 50-Chunk Dropdown
                if (totalBatches > 1)
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: ZplayRadius.smAll,
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: DropdownButton<int>(
                      value: currentBatchSafe,
                      underline: const SizedBox.shrink(),
                      dropdownColor: tokens.surfaceOverlay,
                      style: ZplayType.bodySmall
                          .copyWith(weight: FontWeight.w700)
                          .toStyle(color: tokens.textPrimary),
                      icon: Icon(
                        Icons.expand_more_rounded,
                        color: tokens.accent,
                        size: 16,
                      ),
                      items: List.generate(
                        totalBatches,
                        (idx) {
                          final start = idx * _chunkSize + 1;
                          final end = math.min((idx + 1) * _chunkSize, totalEps);
                          return DropdownMenuItem(
                            value: idx,
                            child: Text('$start – $end'),
                          );
                        },
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedEpisodeBatch = val);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: ZplaySpacing.s16),

        // Episode Grid
        _buildEpisodeGrid(
          totalEps,
          currentBatchSafe * _chunkSize,
          math.min((currentBatchSafe + 1) * _chunkSize, totalEps),
          watchItem?.lastWatchedEpisode,
        ),
      ],
    );
  }

  Widget _buildEpisodeGrid(
    int total,
    int startIndex,
    int endIndex,
    int? lastWatchedEp,
  ) {
    final count = endIndex - startIndex;

    final tokens = ZplayTokens.of(context);
    if (count <= 0) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 85,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final epNum = startIndex + index + 1;
        final isWatched = lastWatchedEp != null && epNum <= lastWatchedEp;
        final isCurrent = lastWatchedEp == epNum;
        final isHighlighted = _highlightedEpisode == epNum;

        return _HoverScale(
          onTap: () => _playEpisode(epNum),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? tokens.danger.withValues(alpha: 0.30)
                  : isCurrent
                      ? tokens.accent.withValues(alpha: 0.35)
                      : (isWatched
                          ? tokens.borderDefault
                          : tokens.surface),
              borderRadius: ZplayRadius.smAll,
              border: Border.all(
                color: isHighlighted
                    ? tokens.danger
                    : isCurrent
                        ? tokens.accent
                        : (isWatched
                            ? tokens.textDisabled
                            : tokens.borderDefault),
                width: (isCurrent || isHighlighted) ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                '$epNum',
                style: ZplayType.label
                    .copyWith(
                      weight: (isCurrent || isHighlighted)
                          ? FontWeight.w900
                          : FontWeight.w700,
                    )
                    .toStyle(
                      color: isHighlighted
                          ? tokens.danger
                          : isCurrent
                              ? tokens.accent
                              : (isWatched
                                    ? tokens.textEmphasis
                                    : tokens.textPrimary),
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Franchise & Relations Row ─────────────────────────────────
  Widget _buildRelationsRow() {
    final tokens = ZplayTokens.of(context);
    final isDesktop = _isDesktop();
    final cardWidth = isDesktop ? 165.0 : 135.0;
    final cardHeight = cardWidth * 1.5 + 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Franchise & Relations'),
        const SizedBox(height: ZplaySpacing.s16),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringRelations = true),
          onExit: (_) => setState(() => _isHoveringRelations = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _relationsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _anime.relations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: ZplaySpacing.s16),
                  itemBuilder: (context, index) {
                    final rel = _anime.relations[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _HoverScale(
                        onTap: () async {
                          final media = await AnilistService.instance
                              .fetchAnimeDetails(rel.id);
                          if (media != null && mounted) {
                            _navigateToAnime(media);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: ZplayRadius.smAll,
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.accent.withValues(alpha: 0.15),
                                    blurRadius: 18,
                                    spreadRadius: -4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: ZplayRadius.smAll,
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: CachedNetworkImage(
                                    imageUrl: rel.coverUrl,
                                    cacheManager: AppImageCache.manager,
                                    memCacheWidth: 330,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: tokens.surface,
                                      child: Icon(
                                        Icons.movie_creation_outlined,
                                        color: tokens.textDisabled,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: ZplaySpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: ZplaySpacing.s2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.18),
                                borderRadius: ZplayRadius.xsAll,
                              ),
                              child: Text(
                                rel.relationType.replaceAll('_', ' '),
                                style: ZplayType.overline
                                    .copyWith(
                                      weight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    )
                                    .toStyle(color: tokens.accent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: ZplaySpacing.s4),
                            Text(
                              rel.title,
                              style: ZplayType.label
                                  .copyWith(weight: FontWeight.w700)
                                  .toStyle(color: tokens.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
              if (isDesktop) ...[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _canScrollRelationsLeft && _isHoveringRelations ? 10 : -60,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SliderArrow(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => _scrollList(_relationsScrollController, -1),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  right: _canScrollRelationsRight && _isHoveringRelations ? 10 : -60,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SliderArrow(
                      icon: Icons.arrow_forward_ios_rounded,
                      onTap: () => _scrollList(_relationsScrollController, 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Recommendations Row ───────────────────────────────────────
  Widget _buildRecommendationsRow() {
    final tokens = ZplayTokens.of(context);
    final isDesktop = _isDesktop();
    final cardWidth = isDesktop ? 165.0 : 135.0;
    final cardHeight = cardWidth * 1.5 + 68.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZplaySpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('You May Also Like'),
          const SizedBox(height: ZplaySpacing.s16),
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringRecs = true),
            onExit: (_) => setState(() => _isHoveringRecs = false),
            child: SizedBox(
              height: cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    clipBehavior: Clip.none,
                    controller: _recsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _anime.recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: ZplaySpacing.s16),
                    itemBuilder: (context, index) {
                      final rec = _anime.recommendations[index];
                      return SizedBox(
                        width: cardWidth,
                        child: _HoverScale(
                          onTap: () => _navigateToAnime(rec),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: ZplayRadius.smAll,
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.accent.withValues(alpha: 0.15),
                                      blurRadius: 18,
                                      spreadRadius: -4,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: ZplayRadius.smAll,
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: CachedNetworkImage(
                                      imageUrl: rec.coverUrl,
                                      cacheManager: AppImageCache.manager,
                                      memCacheWidth: 330,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: tokens.surface,
                                        child: Icon(
                                          Icons.movie_creation_outlined,
                                          color: tokens.textDisabled,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: ZplaySpacing.s8),
                              Text(
                                rec.displayTitle,
                                style: ZplayType.label
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (rec.formattedFormat.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: ZplaySpacing.s2),
                                  child: Text(
                                    rec.formattedFormat,
                                    style: ZplayType.caption.toStyle(color: tokens.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Desktop Floating Scroll Arrows (Matching Home Page & Anime Slider)
                  if (isDesktop) ...[
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: _canScrollRecsLeft && _isHoveringRecs ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => _scrollList(_recsScrollController, -1),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      right: _canScrollRecsRight && _isHoveringRecs ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
                          icon: Icons.arrow_forward_ios_rounded,
                          onTap: () => _scrollList(_recsScrollController, 1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final tokens = ZplayTokens.of(context);
    return Text(
      title,
      style: ZplayType.titleLarge
          .copyWith(weight: FontWeight.w800)
          .toStyle(color: tokens.textPrimary),
    );
  }
}

class _HoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverScale({required this.child, this.onTap});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hover = false;

  Widget _scaled(bool lifted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..scaleByDouble(
          lifted ? 1.04 : 1.0,
          lifted ? 1.04 : 1.0,
          1.0,
          1.0,
        ),
      transformAlignment: Alignment.center,
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) {
      // Nothing here is actionable, so the scale stays pointer-only: a
      // FocusableCard would install an opaque tap recogniser that swallows the
      // tap of the PopupMenuButton this is used as the child of.
      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: _scaled(_hover),
      );
    }
    return FocusableCard(
      onTap: onTap,
      builder: (_, state) => _scaled(state.highlighted),
    );
  }
}
