import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/manga/manga_service.dart';
import '../../widgets/common/focusable_card.dart';
import 'manga_reader_page.dart';
import '../../services/storage/app_image_cache.dart';
import '../../services/theme/design_tokens.dart';

class MangaDetailsPage extends StatefulWidget {
  final Manga manga;

  const MangaDetailsPage({super.key, required this.manga});

  @override
  State<MangaDetailsPage> createState() => _MangaDetailsPageState();
}

class _MangaDetailsPageState extends State<MangaDetailsPage> {
  final MangaService _mangaService = MangaService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Manga? _fullDetails;
  List<MangaChapter>? _chapters;
  Map<String, dynamic>? _historyEntry;
  bool _isLoading = true;

  // Chapter Pagination & Search
  String _chapterSearchQuery = '';
  int _currentChapterPage = 0;
  final int _chaptersPerPage = 50;

  @override
  void initState() {
    super.initState();
    AppThemeService.currentPalette.addListener(_onThemeChanged);
    _loadDetails();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    AppThemeService.currentPalette.removeListener(_onThemeChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final results = await Future.wait([
      _mangaService.getSeriesDetail(widget.manga.id),
      _mangaService.getChapters(widget.manga.id),
      _mangaService.getReadingHistory(),
    ]);

    final historyList = results[2] as List<Map<String, dynamic>>;
    Map<String, dynamic>? matchingHistory;
    try {
      matchingHistory = historyList.firstWhere((h) => h['manga']['id'] == widget.manga.id);
    } catch (_) {
      // No history found
    }

    if (mounted) {
      setState(() {
        _fullDetails = results[0] as Manga;
        _chapters = results[1] as List<MangaChapter>;
        _historyEntry = matchingHistory;
        _isLoading = false;
      });
    }
  }

  void _startReading(int chapterIndex, {int pageIndex = 0}) {
    if (_chapters == null || _chapters!.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MangaReaderPage(
          manga: _fullDetails ?? widget.manga,
          chapters: _chapters!,
          currentChapterIndex: chapterIndex,
          resumePageIndex: pageIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      _loadDetails();
    });
  }

  List<MangaChapter> get _filteredChapters {
    if (_chapters == null) return [];
    if (_chapterSearchQuery.isEmpty) return _chapters!;

    final query = _chapterSearchQuery.toLowerCase();
    return _chapters!.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.number.toString().contains(query)).toList();
  }

  List<MangaChapter> get _paginatedChapters {
    final filtered = _filteredChapters;
    final startIndex = _currentChapterPage * _chaptersPerPage;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + _chaptersPerPage).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final displayManga = _fullDetails ?? widget.manga;
    final coverUrl = displayManga.coverNormal.isNotEmpty
        ? displayManga.coverNormal
        : displayManga.coverSmall;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Background Hero Cover with ambient blur
          Positioned.fill(
            child: Hero(
              tag: 'manga_cover_${displayManga.id}',
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                cacheManager: AppImageCache.manager,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorWidget: (_, __, ___) => ColoredBox(color: tokens.bg)),
            ),
          ),

          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tokens.bg.withValues(alpha: 0.65),
                    tokens.bg.withValues(alpha: 0.96),
                    tokens.bg,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          LiquidGlassView(
            pixelRatio: 0.25,
            refreshRate: LiquidGlassRefreshRate.low,
            backgroundWidget: _buildScrollableContent(displayManga),
            child: Stack(
              children: [
                _buildAppBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(Manga manga) {
    final screen = MediaQuery.sizeOf(context);
    final isDesktop = screen.width >= 720;
    final horizontalPad = isDesktop ? 40.0 : 18.0;

    final tokens = context.tokens;
    final paginatedList = _paginatedChapters;
    final totalFiltered = _filteredChapters.length;
    final totalPages = (totalFiltered / _chaptersPerPage).ceil();

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).top + 60),
        ),

        // Responsive Metadata Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: isDesktop
                ? _buildDesktopHeader(manga)
                : _buildMobileHeader(manga),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 36 : 24)),

        // Synopsis Section
        if (manga.synopsis.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Synopsis',
                    style: ZplayType.titleLarge
                        .copyWith(size: isDesktop ? 22 : 18)
                        .toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 18 : 14),
                    decoration: BoxDecoration(
                      color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.borderDefault),
                    ),
                    child: Text(
                      manga.synopsis,
                      style: ZplayType.body
                          .copyWith(size: isDesktop ? 15 : 13.5, height: 1.55)
                          .toStyle(color: tokens.textEmphasis),
                    ),
                  ),
                ],
              ),
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 36 : 24)),

        // Chapters Header & Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Chapters',
                            style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
                          ),
                          if (_chapters != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accentSubtle,
                                borderRadius: ZplayRadius.smAll,
                              ),
                              child: Text(
                                '${_chapters!.length}',
                                style: ZplayType.bodySmall
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(
                        width: 250,
                        height: 40,
                        child: _buildSearchTextField(),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Chapters',
                            style: ZplayType.title.toStyle(color: tokens.textPrimary),
                          ),
                          if (_chapters != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accentSubtle,
                                borderRadius: ZplayRadius.smAll,
                              ),
                              child: Text(
                                '${_chapters!.length}',
                                style: ZplayType.caption
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(color: tokens.accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: _buildSearchTextField(),
                      ),
                    ],
                  ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        if (_isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(color: tokens.accent),
              ),
            ),
          )
        else if (paginatedList.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  _chapterSearchQuery.isNotEmpty
                      ? 'No chapters matching "$_chapterSearchQuery"'
                      : 'No chapters found.',
                  style: ZplayType.body.toStyle(color: tokens.textEmphasis),
                ),
              ),
            ),
          )
        else ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chapter = paginatedList[index];
                final originalIndex = _chapters!.indexOf(chapter);

                final isRead = _historyEntry != null &&
                    _historyEntry!['chapterIndex'] < originalIndex;
                final isCurrent = _historyEntry != null &&
                    _historyEntry!['chapterIndex'] == originalIndex;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: 3.5,
                  ),
                  child: ListTile(
                    onTap: () => _startReading(originalIndex),
                    shape: RoundedRectangleBorder(
                      borderRadius: ZplayRadius.smAll,
                      side: BorderSide(
                        color: isCurrent ? tokens.accent : tokens.borderSubtle,
                      ),
                    ),
                    tileColor: isCurrent
                        ? tokens.accentSubtle
                        : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isCurrent ? tokens.accentSubtle : tokens.borderDefault,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          chapter.number > 0
                              ? chapter.number.toStringAsFixed(
                                  chapter.number.truncateToDouble() == chapter.number ? 0 : 1)
                              : '#',
                          style: ZplayType.caption
                              .copyWith(weight: FontWeight.w700)
                              .toStyle(color: tokens.textPrimary),
                        ),
                      ),
                    ),
                    title: Text(
                      (chapter.name.isNotEmpty && chapter.name.toLowerCase() != 'last read')
                          ? chapter.name
                          : (chapter.number > 0
                              ? 'Chapter ${chapter.number.toStringAsFixed(chapter.number.truncateToDouble() == chapter.number ? 0 : 1)}'
                              : 'Chapter'),
                      style: ZplayType.label
                          .copyWith(
                            size: isDesktop ? 14.5 : 13.5,
                            weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          )
                          .toStyle(color: isRead ? tokens.textSecondary : tokens.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: tokens.textMuted,
                      size: 20,
                    ),
                  ),
                );
              },
              childCount: paginatedList.length,
            ),
          ),

          // Pagination Controls
          if (totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: 24.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, color: tokens.textPrimary),
                      onPressed: _currentChapterPage > 0
                          ? () => setState(() => _currentChapterPage--)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Page ${_currentChapterPage + 1} of $totalPages',
                      style: ZplayType.body
                          .copyWith(size: 14.5)
                          .toStyle(color: tokens.textEmphasis),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: tokens.textPrimary),
                      onPressed: _currentChapterPage < totalPages - 1
                          ? () => setState(() => _currentChapterPage++)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSearchTextField() {
    final tokens = context.tokens;

    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _chapterSearchQuery = val;
          _currentChapterPage = 0;
        });
      },
      style: ZplayType.label.copyWith(size: 13.5).toStyle(color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search chapters...',
        hintStyle: ZplayType.label.copyWith(size: 13.5).toStyle(color: tokens.textMuted),
        prefixIcon: Icon(Icons.search_rounded, color: tokens.accent, size: 18),
        suffixIcon: _chapterSearchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: tokens.textSecondary, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _chapterSearchQuery = '';
                    _currentChapterPage = 0;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: ZplayRadius.mdAll,
          borderSide: tokens.hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZplayRadius.mdAll,
          borderSide: tokens.hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZplayRadius.mdAll,
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Desktop Header (Side-by-side Cover + Details)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopHeader(Manga manga) {
    final tokens = context.tokens;
    final coverUrl = manga.coverNormal.isNotEmpty ? manga.coverNormal : manga.coverSmall;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image with Drop Shadow
        Container(
          decoration: BoxDecoration(
            borderRadius: ZplayRadius.mdAll,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: ZplayRadius.mdAll,
            child: CachedNetworkImage(
              imageUrl: coverUrl,
              cacheManager: AppImageCache.manager,

              memCacheWidth: 600,
              width: 200,
              height: 290,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 200,
                height: 290,
                color: tokens.surfaceRaised,
                child: Icon(Icons.book_rounded, color: tokens.textMuted, size: 48),
              )),
          ),
        ),
        const SizedBox(width: 32),

        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                manga.title,
                style: ZplayType.display
                    .copyWith(size: 36, height: 1.15)
                    .toStyle(color: tokens.textPrimary),
              ),
              const SizedBox(height: 12),
              if (manga.author.isNotEmpty || manga.year.isNotEmpty)
                Text(
                  '${manga.author}${manga.author.isNotEmpty && manga.year.isNotEmpty ? ' • ' : ''}${manga.year}',
                  style: ZplayType.subtitle
                      .copyWith(size: 16, weight: FontWeight.w500)
                      .toStyle(color: tokens.textEmphasis),
                ),
              const SizedBox(height: 18),

              // Tags
              if (manga.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: manga.tags.take(6).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderDefault),
                        borderRadius: ZplayRadius.smAll,
                        border: Border.all(color: tokens.borderStrong),
                      ),
                      child: Text(
                        tag,
                        style: ZplayType.caption
                            .copyWith(size: 11.5)
                            .toStyle(color: tokens.textPrimary),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              // Action Buttons
              if (!_isLoading) _buildHeaderActionButtons(isFullWidth: false),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mobile / Android Header (Stacked Poster + Full-width Title & Details)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMobileHeader(Manga manga) {
    final tokens = context.tokens;
    final coverUrl = manga.coverNormal.isNotEmpty ? manga.coverNormal : manga.coverSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Centered Poster
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: ZplayRadius.mdAll,
              border: Border.all(
                color: tokens.borderStrong,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.18),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: ZplayRadius.mdAll,
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                cacheManager: AppImageCache.manager,

                memCacheWidth: 495,
                width: 165,
                height: 240,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 165,
                  height: 240,
                  color: tokens.surfaceRaised,
                  child: Icon(Icons.book_rounded, color: tokens.textMuted, size: 40),
                )),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Full-width Title (Horizontal, beautifully centered)
        Text(
          manga.title,
          textAlign: TextAlign.center,
          style: ZplayType.titleLarge
              .copyWith(letterSpacing: -0.3, height: 1.25)
              .toStyle(color: tokens.textPrimary),
        ),
        const SizedBox(height: 8),

        // Author & Year
        if (manga.author.isNotEmpty || manga.year.isNotEmpty)
          Text(
            '${manga.author}${manga.author.isNotEmpty && manga.year.isNotEmpty ? ' • ' : ''}${manga.year}',
            textAlign: TextAlign.center,
            style: ZplayType.label
                .copyWith(size: 13.5, weight: FontWeight.w500)
                .toStyle(color: tokens.textEmphasis),
          ),
        const SizedBox(height: 14),

        // Tags Wrap
        if (manga.tags.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: manga.tags.take(5).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderDefault),
                  borderRadius: ZplayRadius.smAll,
                  border: Border.all(color: tokens.borderStrong),
                ),
                child: Text(
                  tag,
                  style: ZplayType.caption.toStyle(color: tokens.textEmphasis),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 18),

        // Action Button
        if (!_isLoading) _buildHeaderActionButtons(isFullWidth: true),
      ],
    );
  }

  Widget _buildHeaderActionButtons({required bool isFullWidth}) {
    if (_historyEntry != null) {
      final chNum = (_chapters != null && _historyEntry!['chapterIndex'] < _chapters!.length)
          ? _chapters![_historyEntry!['chapterIndex']].number
          : '';
      final label = 'Resume Chapter ${chNum.toString().isNotEmpty ? chNum : ''}';

      return _buildActionButton(
        icon: Icons.play_arrow_rounded,
        label: label,
        isFullWidth: isFullWidth,
        onTap: () => _startReading(
          _historyEntry!['chapterIndex'],
          pageIndex: _historyEntry!['pageIndex'],
        ),
      );
    } else if (_chapters != null && _chapters!.isNotEmpty) {
      return _buildActionButton(
        icon: Icons.menu_book_rounded,
        label: 'Start Reading',
        isFullWidth: isFullWidth,
        onTap: () => _startReading(_chapters!.length - 1),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isFullWidth,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: FocusableCard(
        onTap: onTap,
        builder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: tokens.accent,
            borderRadius: ZplayRadius.mdAll,
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tokens.onAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: ZplayType.subtitle
                    .copyWith(weight: FontWeight.w700)
                    .toStyle(color: tokens.onAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final tokens = context.tokens;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      child: ClipRRect(
        borderRadius: ZplayRadius.lgAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surfaceOverlay.withValues(alpha: 0.75),
              border: Border.all(
                color: tokens.borderStrong,
                width: 1.2,
              ),
              borderRadius: ZplayRadius.lgAll,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: tokens.textPrimary, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
            ),
          ),
        ),
      ),
    );
  }
}
