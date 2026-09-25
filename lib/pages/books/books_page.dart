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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
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
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _searchController.text.trim().isNotEmpty
                              ? 'Results for "${_searchController.text.trim()}"'
                              : 'Discover Books',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        if (!_loading && _books.isNotEmpty)
                          Text(
                            '${_books.length} Books',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white38,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Grid / Loading / Error
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadBooks(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_books.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, color: Colors.white38, size: 56),
                          SizedBox(height: 14),
                          Text(
                            'No books found',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Try searching for another title, author, or language',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF7C3AED),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFA78BFA), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Books',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Search Bar
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1C26).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Search millions of books & authors...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Format Filter Chips
            _buildFormatChip('All Formats', null),
            const SizedBox(width: 8),
            _buildFormatChip('EPUB', 'epub', accentColor: const Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            _buildFormatChip('PDF', 'pdf', accentColor: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            _buildFormatChip('MOBI', 'mobi', accentColor: const Color(0xFF0EA5E9)),
            const SizedBox(width: 8),
            _buildFormatChip('AZW3', 'azw3', accentColor: const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _buildFormatChip('FB2', 'fb2', accentColor: const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _buildFormatChip('TXT', 'txt', accentColor: const Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            _buildFormatChip('CBZ', 'cbz', accentColor: const Color(0xFFEC4899)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, String? format, {Color? accentColor}) {
    final isSelected = _selectedFormat == format;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFormat = format);
        _loadBooks();
      },
      selectedColor: accentColor ?? const Color(0xFF7C3AED),
      backgroundColor: const Color(0xFF1B1C26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.white12,
        ),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : Colors.white70,
      ),
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
                      color: state.highlighted ? const Color(0xFF7C3AED) : Colors.white.withValues(alpha: 0.08),
                      width: state.highlighted ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      state.highlighted
                          ? BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            )
                          : ReaderTokens.shadowMd,
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: book.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: book.coverUrl,
                                  cacheManager: AppImageCache.manager,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: const Color(0xFF1E202B),
                                    child: const Center(
                                      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF1E202B),
                                    child: const Center(
                                      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                    ),
                                  ))
                              : Container(
                                  color: const Color(0xFF1E202B),
                                  child: const Center(
                                    child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                  ),
                                ),
                        ),

                        // Subtle inner border (6% white)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.9)
                                  : book.isPdf
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.9)
                                      : Colors.black87,
                              borderRadius: ReaderTokens.rounded4,
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              book.bookFiletype.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: ReaderTokens.uiFont,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                book.year,
                                style: const TextStyle(
                                  fontFamily: ReaderTokens.uiFont,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
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
                style: const TextStyle(
                  fontFamily: ReaderTokens.uiFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Author
              Text(
                book.displayAuthor,
                style: TextStyle(
                  fontFamily: ReaderTokens.uiFont,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
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
