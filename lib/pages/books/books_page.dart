import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/book/book_result.dart';
import '../../services/books/bookracy_service.dart';
import '../../services/books/continue_reading_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/focusable_card.dart';
import 'book_detail_sheet.dart';
import 'widgets/continue_reading_slider.dart';
import 'widgets/reader_design_tokens.dart';
import '../../services/storage/app_image_cache.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BookResult> _books = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  String _currentQuery = 'fantasy';
  String? _selectedFormat; // 'epub', 'pdf', or null for all
  int _currentPage = 1;
  bool _hasMore = true;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_loadingMore && !_loading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadBooks({bool resetPage = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMore = true;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await BookracyService.instance.searchBooks(
        query: _currentQuery,
        page: _currentPage,
        limit: 80,
        formatFilter: _selectedFormat,
      );

      if (!mounted) return;
      setState(() {
        _books = results;
        _loading = false;
        _hasMore = results.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load books: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      _currentPage++;
      final more = await BookracyService.instance.searchBooks(
        query: _currentQuery,
        page: _currentPage,
        limit: 80,
        formatFilter: _selectedFormat,
      );

      if (!mounted) return;
      setState(() {
        _books.addAll(more);
        _loadingMore = false;
        if (more.isEmpty) _hasMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      final trimmed = query.trim();
      setState(() {
        _currentQuery = trimmed.isNotEmpty ? trimmed : 'fantasy';
      });
      _loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // ── Ambient Animated Background ──
          const Positioned.fill(
            child: AnimatedAmbientBackground(),
          ),

          // ── Main Content ──
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top App Bar & Search Header
                SliverToBoxAdapter(
                  child: _buildHeader(isMobile),
                ),

                // Filters (Language & Formats)
                SliverToBoxAdapter(
                  child: _buildFilters(),
                ),

                // Continue Reading Horizontal Slider
                const SliverToBoxAdapter(
                  child: ContinueReadingSlider(),
                ),

                // Catalog Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZplaySpacing.s24,
                      ZplaySpacing.s8,
                      ZplaySpacing.s24,
                      ZplaySpacing.s16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: ZplayRadius.xsAll,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _searchController.text.trim().isNotEmpty
                              ? 'Results for "${_searchController.text.trim()}"'
                              : 'Discover Books',
                          style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
                        ),
                        const Spacer(),
                        if (!_loading && _books.isNotEmpty)
                          Text(
                            '${_books.length} Books',
                            style: ZplayType.label.toStyle(color: tokens.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),

                // Grid / Loading / Error
                if (_loading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: tokens.accent),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, color: tokens.danger, size: 48),
                          const SizedBox(height: ZplaySpacing.s12),
                          Text(_error!, style: ZplayType.body.toStyle(color: tokens.textEmphasis)),
                          const SizedBox(height: ZplaySpacing.s16),
                          ElevatedButton(
                            onPressed: () => _loadBooks(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, color: tokens.textMuted, size: 56),
                          const SizedBox(height: 14),
                          Text(
                            'No books found',
                            style: ZplayType.subtitle.toStyle(color: tokens.textEmphasis),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try searching for another title, author, or language',
                            style: ZplayType.label.toStyle(color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile ? 160 : 190,
                        mainAxisSpacing: 22,
                        crossAxisSpacing: 18,
                        childAspectRatio: 0.56,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = _books[index];
                          return _BookCard(
                            book: book,
                            onTap: () => BookDetailSheet.show(context, book),
                          );
                        },
                        childCount: _books.length,
                      ),
                    ),
                  ),

                // Loading More Indicator
                if (_loadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  // The SafeArea above is bottom:false, so the trailing gap carries the gesture inset.
                  child: SizedBox(height: ZplaySpacing.s24 + MediaQuery.paddingOf(context).bottom),
                ),
              ],
            ),
          ),
          // ── Custom Scroll Track (Desktop Only) ──
          if (MediaQuery.sizeOf(context).width > 800)
            Positioned(
              right: 24,
              bottom: 40,
              child: CustomScrollTrack(controller: _scrollController),
            ),

        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZplaySpacing.s20,
        ZplaySpacing.s16,
        ZplaySpacing.s20,
        ZplaySpacing.s12,
      ),
      child: Row(
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZplaySpacing.s8),
                decoration: BoxDecoration(
                  // The violet identity was the fork's, not the brand's: the
                  // monogram now follows the active palette's accent.
                  color: tokens.accentSubtle,
                  borderRadius: ZplayRadius.smAll,
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.menu_book_rounded, color: tokens.accent, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Books',
                style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: ZplaySpacing.s20),

          // Search Bar
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: tokens.surfaceOverlay.withValues(alpha: 0.8),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.borderStrong),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: ZplayType.label.toStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search millions of books & authors...',
                  hintStyle: ZplayType.label.toStyle(color: tokens.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: tokens.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: tokens.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZplaySpacing.s24,
        ZplaySpacing.s4,
        ZplaySpacing.s24,
        ZplaySpacing.s20,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Format Filter Chips
            _buildFormatChip('All Formats', null),
            const SizedBox(width: 8),
            _buildFormatChip('EPUB', 'epub', accentColor: tokens.accent),
            const SizedBox(width: 8),
            _buildFormatChip('PDF', 'pdf', accentColor: tokens.danger),
            const SizedBox(width: 8),
            _buildFormatChip('MOBI', 'mobi', accentColor: tokens.info),
            const SizedBox(width: 8),
            _buildFormatChip('AZW3', 'azw3', accentColor: tokens.warning),
            const SizedBox(width: 8),
            _buildFormatChip('FB2', 'fb2', accentColor: tokens.success),
            const SizedBox(width: 8),
            _buildFormatChip('TXT', 'txt', accentColor: tokens.accentHover),
            const SizedBox(width: 8),
            _buildFormatChip('CBZ', 'cbz', accentColor: tokens.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, String? format, {Color? accentColor}) {
    final tokens = context.tokens;
    final isSelected = _selectedFormat == format;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFormat = format);
        _loadBooks();
      },
      selectedColor: accentColor ?? tokens.accent,
      backgroundColor: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: ZplayRadius.smAll,
        side: BorderSide(
          color: isSelected ? Colors.transparent : tokens.borderStrong,
        ),
      ),
      labelStyle: ZplayType.bodySmall
          .copyWith(weight: isSelected ? FontWeight.w700 : FontWeight.w500)
          .toStyle(color: isSelected ? tokens.textPrimary : tokens.textEmphasis),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookResult book;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = ContinueReadingService.getProgress(book.md5);
    final tokens = context.tokens;

    return FocusableCard(
      onTap: onTap,
      builder: (context, state) {
        return AnimatedContainer(
          duration: ReaderTokens.motionFast,
          curve: ReaderTokens.curveFast,
          transform: Matrix4.translationValues(0, state.highlighted ? -6 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Artwork
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: ReaderTokens.rounded16,
                    border: Border.all(
                      color: state.highlighted ? tokens.accent : tokens.borderDefault,
                      width: state.highlighted ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      state.highlighted
                          ? BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            )
                          : ReaderTokens.shadowMd,
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: ZplayRadius.mdAll,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: book.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: book.coverUrl,
                                  cacheManager: AppImageCache.manager,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: tokens.surface,
                                    child: Center(
                                      child: Icon(Icons.menu_book_rounded, color: tokens.textDisabled, size: 36),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: tokens.surface,
                                    child: Center(
                                      child: Icon(Icons.menu_book_rounded, color: tokens.textDisabled, size: 36),
                                    ),
                                  ))
                              : Container(
                                  color: tokens.surface,
                                  child: Center(
                                    child: Icon(Icons.menu_book_rounded, color: tokens.textDisabled, size: 36),
                                  ),
                                ),
                        ),

                        // Subtle inner border (6% white)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: ZplayRadius.mdAll,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                          ),
                        ),

                        // Format Badge Top-Left
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: book.isEpub
                                  ? tokens.accent.withValues(alpha: 0.9)
                                  : book.isPdf
                                      ? tokens.danger.withValues(alpha: 0.9)
                                      : Colors.black87,
                              borderRadius: ReaderTokens.rounded4,
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              book.bookFiletype.toUpperCase(),
                              style: ZplayType.overline.toStyle(color: tokens.textPrimary),
                            ),
                          ),
                        ),

                        // Year Tag Bottom-Right if available
                        if (book.year.isNotEmpty)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: ZplayRadius.xsAll,
                              ),
                              child: Text(
                                book.year,
                                style: ZplayType.caption.toStyle(color: tokens.textEmphasis),
                              ),
                            ),
                          ),

                        // In-Progress Bar directly on Cover Bottom Edge
                        if (progress != null && progress.progressPercent > 0.01)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                              child: LinearProgressIndicator(
                                value: progress.progressPercent,
                                minHeight: 3.5,
                                backgroundColor: Colors.black38,
                                valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ReaderTokens.space8),

              // Title
              Text(
                book.displayTitle,
                style: ZplayType.bodySmall
                    .copyWith(weight: FontWeight.w600)
                    .toStyle(color: tokens.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Author
              Text(
                book.displayAuthor,
                style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
