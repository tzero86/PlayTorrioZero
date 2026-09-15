import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/manga/manga_service.dart';
import 'manga_reader_page.dart';
import '../../services/storage/app_image_cache.dart';

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
    final displayManga = _fullDetails ?? widget.manga;
    final coverUrl = displayManga.coverNormal.isNotEmpty
        ? displayManga.coverNormal
        : displayManga.coverSmall;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
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
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF0F111A))),
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
                    const Color(0xFF0F111A).withValues(alpha: 0.65),
                    const Color(0xFF0F111A).withValues(alpha: 0.96),
                    const Color(0xFF0F111A),
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

    final palette = AppThemeService.currentPalette.value;
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
                ? _buildDesktopHeader(manga, palette)
                : _buildMobileHeader(manga, palette),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 18 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Text(
                      manga.synopsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: isDesktop ? 15 : 13.5,
                        height: 1.55,
                      ),
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
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_chapters != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.primaryColor.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_chapters!.length}',
                                style: TextStyle(
                                  color: palette.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(
                        width: 250,
                        height: 40,
                        child: _buildSearchTextField(palette),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_chapters != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.primaryColor.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_chapters!.length}',
                                style: TextStyle(
                                  color: palette.primaryColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: _buildSearchTextField(palette),
                      ),
                    ],
                  ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
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
                  style: const TextStyle(color: Colors.white70),
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
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent
                            ? palette.primaryColor.withValues(alpha: 0.40)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    tileColor: isCurrent
                        ? palette.primaryColor.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? palette.primaryColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          chapter.number > 0
                              ? chapter.number.toStringAsFixed(
                                  chapter.number.truncateToDouble() == chapter.number ? 0 : 1)
                              : '#',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      (chapter.name.isNotEmpty && chapter.name.toLowerCase() != 'last read')
                          ? chapter.name
                          : (chapter.number > 0
                              ? 'Chapter ${chapter.number.toStringAsFixed(chapter.number.truncateToDouble() == chapter.number ? 0 : 1)}'
                              : 'Chapter'),
                      style: TextStyle(
                        color: isRead ? Colors.white54 : Colors.white,
                        fontSize: isDesktop ? 14.5 : 13.5,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
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
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                      onPressed: _currentChapterPage > 0
                          ? () => setState(() => _currentChapterPage--)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Page ${_currentChapterPage + 1} of $totalPages',
                      style: const TextStyle(color: Colors.white70, fontSize: 14.5),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
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

  Widget _buildSearchTextField(AppThemePalette palette) {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _chapterSearchQuery = val;
          _currentChapterPage = 0;
        });
      },
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Search chapters...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        prefixIcon: Icon(Icons.search_rounded, color: palette.primaryColor, size: 18),
        suffixIcon: _chapterSearchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
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
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primaryColor, width: 1.5),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Desktop Header (Side-by-side Cover + Details)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopHeader(Manga manga, AppThemePalette palette) {
    final coverUrl = manga.coverNormal.isNotEmpty ? manga.coverNormal : manga.coverSmall;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image with Drop Shadow
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
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
                color: const Color(0xFF1E2230),
                child: const Icon(Icons.book_rounded, color: Colors.white38, size: 48),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              if (manga.author.isNotEmpty || manga.year.isNotEmpty)
                Text(
                  '${manga.author}${manga.author.isNotEmpty && manga.year.isNotEmpty ? ' • ' : ''}${manga.year}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              // Action Buttons
              if (!_isLoading) _buildHeaderActionButtons(palette, isFullWidth: false),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mobile / Android Header (Stacked Poster + Full-width Title & Details)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMobileHeader(Manga manga, AppThemePalette palette) {
    final coverUrl = manga.coverNormal.isNotEmpty ? manga.coverNormal : manga.coverSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Centered Poster
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.primaryColor.withValues(alpha: 0.18),
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
              borderRadius: BorderRadius.circular(16),
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
                  color: const Color(0xFF1E2230),
                  child: const Icon(Icons.book_rounded, color: Colors.white38, size: 40),
                )),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Full-width Title (Horizontal, beautifully centered)
        Text(
          manga.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Author & Year
        if (manga.author.isNotEmpty || manga.year.isNotEmpty)
          Text(
            '${manga.author}${manga.author.isNotEmpty && manga.year.isNotEmpty ? ' • ' : ''}${manga.year}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
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
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 18),

        // Action Button
        if (!_isLoading) _buildHeaderActionButtons(palette, isFullWidth: true),
      ],
    );
  }

  Widget _buildHeaderActionButtons(AppThemePalette palette, {required bool isFullWidth}) {
    if (_historyEntry != null) {
      final chNum = (_chapters != null && _historyEntry!['chapterIndex'] < _chapters!.length)
          ? _chapters![_historyEntry!['chapterIndex']].number
          : '';
      final label = 'Resume Chapter ${chNum.toString().isNotEmpty ? chNum : ''}';

      return _buildActionButton(
        icon: Icons.play_arrow_rounded,
        label: label,
        color: palette.primaryColor,
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
        color: palette.primaryColor,
        textColor: Colors.white,
        isFullWidth: isFullWidth,
        onTap: () => _startReading(_chapters!.length - 1),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required bool isFullWidth,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151822).withValues(alpha: 0.75),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
            ),
          ),
        ),
      ),
    );
  }
}
