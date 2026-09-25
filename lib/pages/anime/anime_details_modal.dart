import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/anime/anime_media.dart';
import '../../services/anime/anilist_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/anime/extractors/anidb_extractor.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/performance_liquid_lens.dart';
import '../../services/storage/app_image_cache.dart';

class AnimeDetailsModal extends StatefulWidget {
  final AnimeMedia initialAnime;
  final Function(AnimeMedia anime, int episodeNumber, bool isDub) onPlayEpisode;
  final Function(AnimeMedia) onNavigateToAnime;
  final VoidCallback onClose;

  const AnimeDetailsModal({
    super.key,
    required this.initialAnime,
    required this.onPlayEpisode,
    required this.onNavigateToAnime,
    required this.onClose,
  });

  @override
  State<AnimeDetailsModal> createState() => _AnimeDetailsModalState();
}

class _AnimeDetailsModalState extends State<AnimeDetailsModal> {
  late AnimeMedia _anime;
  bool _isLoadingDetails = true;
  bool _isDub = false;
  int _selectedEpisodeBatch = 0; // 50 episodes per batch
  int? _highlightedEpisode;
  List<AniDbEpisode>? _aniDbEpisodes;

  final TextEditingController _jumpEpController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  static const int _chunkSize = 50;

  @override
  void initState() {
    super.initState();
    _anime = widget.initialAnime;
    _fetchFullDetails();
    _resolveAniDbEpisodes();
  }

  @override
  void didUpdateWidget(AnimeDetailsModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAnime.id != widget.initialAnime.id) {
      setState(() {
        _anime = widget.initialAnime;
        _isLoadingDetails = true;
        _selectedEpisodeBatch = 0;
        _highlightedEpisode = null;
        _aniDbEpisodes = null;
      });
      _jumpEpController.clear();
      _fetchFullDetails();
      _resolveAniDbEpisodes();
    }
  }

  @override
  void dispose() {
    _jumpEpController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    final full = await AnilistService.instance.fetchAnimeDetails(_anime.id);
    if (full != null && mounted) {
      setState(() {
        _anime = full;
        _isLoadingDetails = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingDetails = false);
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
          setState(() {
            _aniDbEpisodes = episodes;
          });
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

  @override
  Widget build(BuildContext context) {
    final library = AnimeLibraryService.instance;
    final watchItem = library.getWatchlistItem(_anime.id);
    final size = MediaQuery.sizeOf(context);
    final tokens = ZplayTokens.of(context);
    final isMobile = size.width < 750;

    final modalWidth = isMobile ? size.width - 16 : math.min(size.width * 0.94, 980.0);
    final modalHeight = isMobile ? size.height * 0.94 : math.min(size.height * 0.94, 820.0);

    final totalEps = _computedTotalEpisodes;
    final totalBatches = (totalEps / _chunkSize).ceil().clamp(1, 9999);
    final currentBatchSafe = _selectedEpisodeBatch.clamp(0, totalBatches - 1);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside modal content
              child: PerformanceLiquidLens(
                style: PerformanceGlassStyles.sheet,
                child: Container(
                  width: modalWidth,
                  height: modalHeight,
                  decoration: BoxDecoration(
                    color: tokens.surfaceOverlay,
                    borderRadius: ZplayRadius.sheetTop,
                    border: Border.all(color: tokens.borderStrong),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 40,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: ZplayRadius.sheetTop,
                    child: Column(
                      children: [
                        // Top Backdrop Header
                        Stack(
                          children: [
                            SizedBox(
                              height: isMobile ? 190 : 250,
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: _anime.backdropUrl,
                                cacheManager: AppImageCache.manager,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (_, __, ___) => Container(
                                  color: tokens.surface,
                                )),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.25),
                                      tokens.surfaceOverlay.withValues(
                                        alpha: 0.75,
                                      ),
                                      tokens.surfaceOverlay,
                                    ],
                                    stops: const [0.0, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            if (_isLoadingDetails)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  color: AppThemeService.currentPalette.value.primaryColor,
                                  backgroundColor: Colors.transparent,
                                  minHeight: 2.5,
                                ),
                              ),

                            // Top Back and Close Buttons (Always visible on any window size)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: _buildHeaderIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: widget.onClose,
                              ),
                            ),
                            Positioned(
                              top: 14,
                              right: 14,
                              child: _buildHeaderIconButton(
                                icon: Icons.close_rounded,
                                onTap: widget.onClose,
                              ),
                            ),

                            // Title & Badges in Header
                            Positioned(
                              left: isMobile ? 16 : 24,
                              right: isMobile ? 60 : 80,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (_anime.averageScore > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                tokens.warning,
                                                Color.lerp(
                                                      tokens.warning,
                                                      Colors.black,
                                                      0.15,
                                                    ) ??
                                                    tokens.warning,
                                              ],
                                            ),
                                            borderRadius: ZplayRadius.smAll,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded, color: Colors.black, size: 13),
                                              const SizedBox(width: 3),
                                              Text(
                                                _anime.formattedScore,
                                                style: ZplayType.caption
                                                    .copyWith(
                                                      weight: FontWeight.w900,
                                                    )
                                                    .toStyle(
                                                      color: Colors.black,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppThemeService.currentPalette.value.primaryColor,
                                          borderRadius: ZplayRadius.smAll,
                                        ),
                                        child: Text(
                                          _anime.formattedFormat.toUpperCase(),
                                          style: ZplayType.overline.copyWith(weight: FontWeight.w900).toStyle(color: tokens.onAccent),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: tokens.borderStrong,
                                          borderRadius: ZplayRadius.smAll,
                                        ),
                                        child: Text(
                                          _anime.formattedStatus,
                                          style: ZplayType.overline.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                                        ),
                                      ),
                                      if (_anime.seasonYear > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: tokens.borderDefault,
                                            borderRadius: ZplayRadius.smAll,
                                          ),
                                          child: Text(
                                            '${_anime.seasonYear}',
                                            style: ZplayType.overline.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textEmphasis),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: ZplaySpacing.s8),
                                  Text(
                                    _anime.displayTitle,
                                    style: ZplayType.display
                                        .copyWith(
                                          size: isMobile ? 20 : 26,
                                          weight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        )
                                        .toStyle(color: tokens.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_anime.titleNative.isNotEmpty)
                                    Text(
                                      _anime.titleNative,
                                      style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Scrollable Content Body
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile
                                  ? ZplaySpacing.s16
                                  : ZplaySpacing.s24,
                              vertical: ZplaySpacing.s12,
                            ),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // Action Row: Play + Add to List + SUB/DUB toggle
                              Row(
                                children: [
                                  _HoverScale(
                                    onTap: () {
                                      final epToPlay = watchItem?.lastWatchedEpisode ?? 1;
                                      widget.onPlayEpisode(_anime, epToPlay, _isDub);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s20, vertical: ZplaySpacing.s12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppThemeService.currentPalette.value.primaryColor,
                                            Color.lerp(
                                              AppThemeService.currentPalette.value.primaryColor,
                                              Colors.black,
                                              0.33,
                                            )!,
                                          ],
                                        ),
                                        borderRadius: ZplayRadius.mdAll,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, color: tokens.onAccent, size: 22),
                                          const SizedBox(width: 6),
                                          Text(
                                            watchItem != null && watchItem.lastWatchedEpisode > 0
                                                ? 'Resume Ep ${watchItem.lastWatchedEpisode}'
                                                : 'Play Ep 1',
                                            style: ZplayType.body.copyWith(weight: FontWeight.w800).toStyle(color: tokens.onAccent),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: ZplaySpacing.s12),

                                  // Watchlist Status Popup
                                  PopupMenuButton<AnimeWatchStatus>(
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
                                        child: Text(
                                          'Watching',
                                          style: ZplayType.body.toStyle(
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: AnimeWatchStatus.planToWatch,
                                        child: Text(
                                          'Plan to Watch',
                                          style: ZplayType.body.toStyle(
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: AnimeWatchStatus.completed,
                                        child: Text(
                                          'Completed',
                                          style: ZplayType.body.toStyle(
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: AnimeWatchStatus.dropped,
                                        child: Text(
                                          'Dropped',
                                          style: ZplayType.body.toStyle(
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    child: _HoverScale(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        decoration: BoxDecoration(
                                          color: tokens.borderDefault,
                                          borderRadius: ZplayRadius.mdAll,
                                          border: Border.all(
                                            color: watchItem != null
                                                ? tokens.success
                                                : tokens.borderStrong,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              watchItem != null
                                                  ? Icons.check_circle_rounded
                                                  : Icons.bookmark_outline_rounded,
                                              color: watchItem != null
                                                  ? tokens.success
                                                  : tokens.textEmphasis,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              watchItem != null
                                                  ? watchItem.status.name.toUpperCase()
                                                  : 'ADD TO LIST',
                                              style: ZplayType.caption
                                                  .copyWith(
                                                    weight: FontWeight.w800,
                                                  )
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
                                  ),

                                  const Spacer(),

                                  // SUB / DUB Toggle
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
                                          builder: (_, state) => AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: !_isDub ? AppThemeService.currentPalette.value.primaryColor : Colors.transparent,
                                              borderRadius: ZplayRadius.smAll,
                                            ),
                                            child: Text(
                                              'SUB',
                                              style: ZplayType.caption
                                                  .copyWith(
                                                    weight: FontWeight.w900,
                                                  )
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
                                          builder: (_, state) => AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _isDub ? AppThemeService.currentPalette.value.primaryColor : Colors.transparent,
                                              borderRadius: ZplayRadius.smAll,
                                            ),
                                            child: Text(
                                              'DUB',
                                              style: ZplayType.caption
                                                  .copyWith(
                                                    weight: FontWeight.w900,
                                                  )
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
                                ],
                              ),

                              // Synopsis
                              if (_anime.description.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Text(
                                  _anime.description,
                                  style: ZplayType.body.copyWith(height: 1.5).toStyle(color: tokens.textEmphasis),
                                ),
                              ],

                              // Genres Chips
                              if (_anime.genres.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _anime.genres
                                      .map(
                                        (g) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s4),
                                          decoration: BoxDecoration(
                                            color: tokens.borderSubtle,
                                            borderRadius: ZplayRadius.mdAll,
                                            border: Border.all(color: tokens.borderStrong),
                                          ),
                                          child: Text(
                                            g,
                                            style: ZplayType.caption.toStyle(color: tokens.textEmphasis),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],

                              const SizedBox(height: ZplaySpacing.s24),
                              Divider(color: tokens.borderDefault),
                              const SizedBox(height: 14),

                              // ─── EPISODES HEADER & 50-CHUNK PAGINATION + JUMP FIELD ───
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Episodes',
                                        style: ZplayType.title
                                            .copyWith(weight: FontWeight.w900)
                                            .toStyle(color: tokens.textPrimary),
                                      ),
                                      const SizedBox(width: ZplaySpacing.s8),
                                      Text(
                                        '($totalEps total)',
                                        style: ZplayType.label.toStyle(color: tokens.textSecondary),
                                      ),
                                    ],
                                  ),

                                  // Jump to episode + Page selector
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Jump input field
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
                                            contentPadding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: 10),
                                            suffixIcon: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(Icons.arrow_forward_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 16),
                                              onPressed: () => _jumpToEpisode(_jumpEpController.text),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // Prev Batch Arrow
                                      IconButton(
                                        icon: Icon(Icons.chevron_left_rounded, color: tokens.textEmphasis, size: 20),
                                        onPressed: currentBatchSafe > 0
                                            ? () => setState(() => _selectedEpisodeBatch = currentBatchSafe - 1)
                                            : null,
                                      ),

                                      // 50-Episode Chunk Dropdown
                                      if (totalBatches > 1)
                                        Container(
                                          height: 34,
                                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8),
                                          decoration: BoxDecoration(
                                            color: tokens.surface,
                                            borderRadius: ZplayRadius.smAll,
                                            border: Border.all(color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4)),
                                          ),
                                          child: DropdownButton<int>(
                                            value: currentBatchSafe,
                                            underline: const SizedBox.shrink(),
                                            dropdownColor: tokens.surfaceOverlay,
                                            style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                                            icon: Icon(Icons.expand_more_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 16),
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

                                      // Next Batch Arrow
                                      IconButton(
                                        icon: Icon(Icons.chevron_right_rounded, color: tokens.textEmphasis, size: 20),
                                        onPressed: currentBatchSafe < totalBatches - 1
                                            ? () => setState(() => _selectedEpisodeBatch = currentBatchSafe + 1)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Episode Grid with Hover Effects
                              _buildEpisodeGrid(
                                totalEps,
                                currentBatchSafe * _chunkSize,
                                math.min((currentBatchSafe + 1) * _chunkSize, totalEps),
                                watchItem?.lastWatchedEpisode,
                              ),

                              // Characters & Voice Cast
                              if (_anime.characters.isNotEmpty) ...[
                                const SizedBox(height: ZplaySpacing.s32),
                                Text(
                                  'Characters & Voice Cast',
                                  style: ZplayType.title
                                      .copyWith(weight: FontWeight.w900)
                                      .toStyle(color: tokens.textPrimary),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 145,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _anime.characters.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      final char = _anime.characters[index];
                                      return _HoverScale(
                                        child: SizedBox(
                                          width: 90,
                                          child: Column(
                                            children: [
                                              ClipRRect(
                                                borderRadius: ZplayRadius.smAll,
                                                child: CachedNetworkImage(
                                                  imageUrl: char.imageLarge,
                                                  cacheManager: AppImageCache.manager,
                                                  memCacheWidth: 255,
                                                  width: 85,
                                                  height: 85,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: tokens.surfaceRaised,
                                                    child: Icon(Icons.person_rounded, color: tokens.textDisabled),
                                                  )),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                char.nameFull,
                                                style: ZplayType.caption.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                char.role,
                                                style: ZplayType.overline.toStyle(color: tokens.textMuted),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                              // Franchise & Relations (Clickable with Hover Scale)
                              if (_anime.relations.isNotEmpty) ...[
                                const SizedBox(height: ZplaySpacing.s32),
                                Text(
                                  'Franchise & Relations',
                                  style: ZplayType.title
                                      .copyWith(weight: FontWeight.w900)
                                      .toStyle(color: tokens.textPrimary),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _anime.relations.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      final rel = _anime.relations[index];
                                      return _HoverScale(
                                        onTap: () async {
                                          final media = await AnilistService.instance.fetchAnimeDetails(rel.id);
                                          if (media != null) {
                                            widget.onNavigateToAnime(media);
                                          }
                                        },
                                        child: SizedBox(
                                          width: 105,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: ZplayRadius.smAll,
                                                child: CachedNetworkImage(
                                                  imageUrl: rel.coverUrl,
                                                  cacheManager: AppImageCache.manager,
                                                  memCacheWidth: 315,
                                                  width: 105,
                                                  height: 125,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: tokens.surfaceRaised,
                                                    child: Icon(Icons.movie_creation_outlined, color: tokens.textDisabled),
                                                  )),
                                              ),
                                              const SizedBox(height: ZplaySpacing.s4),
                                              Text(
                                                rel.relationType.replaceAll('_', ' '),
                                                style: ZplayType.overline
                                                    .copyWith(
                                                      weight: FontWeight.w900,
                                                    )
                                                    .toStyle(
                                                      color: AppThemeService
                                                          .currentPalette
                                                          .value
                                                          .primaryColor,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                rel.title,
                                                style: ZplayType.caption.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                              // Recommendations / You May Also Like (Clickable with Hover Scale)
                              if (_anime.recommendations.isNotEmpty) ...[
                                const SizedBox(height: ZplaySpacing.s32),
                                Text(
                                  'You May Also Like',
                                  style: ZplayType.title
                                      .copyWith(weight: FontWeight.w900)
                                      .toStyle(color: tokens.textPrimary),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 185,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _anime.recommendations.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      final rec = _anime.recommendations[index];
                                      return _HoverScale(
                                        onTap: () => widget.onNavigateToAnime(rec),
                                        child: SizedBox(
                                          width: 115,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: ZplayRadius.smAll,
                                                child: CachedNetworkImage(
                                                  imageUrl: rec.coverUrl,
                                                  cacheManager: AppImageCache.manager,
                                                  memCacheWidth: 345,
                                                  width: 115,
                                                  height: 140,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: tokens.surfaceRaised,
                                                    child: Icon(Icons.movie_creation_outlined, color: tokens.textDisabled),
                                                  )),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                rec.displayTitle,
                                                style: ZplayType.caption.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: ZplaySpacing.s24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap}) {
    final tokens = ZplayTokens.of(context);
    return _HoverScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: ZplayRadius.lgAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(ZplaySpacing.s8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: tokens.textDisabled),
            ),
            child: Icon(icon, color: tokens.textPrimary, size: 20),
          ),
        ),
      ),
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
        maxCrossAxisExtent: 75,
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
          onTap: () => widget.onPlayEpisode(_anime, epNum, _isDub),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? tokens.danger.withValues(alpha: 0.30)
                  : isCurrent
                      ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.35)
                      : (isWatched
                          ? tokens.borderDefault
                          : tokens.surface),
              borderRadius: ZplayRadius.smAll,
              border: Border.all(
                color: isHighlighted
                    ? tokens.danger
                    : isCurrent
                        ? AppThemeService.currentPalette.value.primaryColor
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
                              ? AppThemeService
                                    .currentPalette
                                    .value
                                    .primaryColor
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
