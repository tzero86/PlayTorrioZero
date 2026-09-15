import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/book/book_result.dart';
import '../../../models/book/reading_progress.dart';
import '../../../services/books/continue_reading_service.dart';
import '../epub_reader_page.dart';
import '../pdf_reader_page.dart';
import '../../../services/storage/app_image_cache.dart';

class ContinueReadingSlider extends StatefulWidget {
  final String title;

  const ContinueReadingSlider({
    super.key,
    this.title = 'Continue Reading',
  });

  @override
  State<ContinueReadingSlider> createState() => _ContinueReadingSliderState();
}

class _ContinueReadingSliderState extends State<ContinueReadingSlider> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHoveringSlider = false;

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
    final canRight =
        _scrollController.position.pixels < _scrollController.position.maxScrollExtent - 10;

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
    final scrollAmount = viewportWidth * 0.8 * directionMultiplier;
    final target = (_scrollController.position.pixels + scrollAmount)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _openReader(BuildContext context, ReadingProgress item) {
    final file = File(item.filePath);
    final book = BookResult(
      title: item.title,
      author: item.author,
      md5: item.md5,
      link: '',
      bookImage: item.coverUrl,
      bookFiletype: item.fileType,
    );

    if (item.fileType == 'pdf') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PdfReaderPage(
            file: file,
            book: book,
            initialPage: item.currentPage,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EpubReaderPage(
            file: file,
            book: book,
            initialChapterIndex: item.chapterIndex,
            initialScrollOffset: item.scrollOffset,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop();

    return ValueListenableBuilder<List<ReadingProgress>>(
      valueListenable: ContinueReadingService.activeItems,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} ${items.length == 1 ? 'Book' : 'Books'}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              // Slider
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringSlider = true),
                onExit: (_) => setState(() => _isHoveringSlider = false),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ContinueReadingCard(
                            item: item,
                            onTap: () => _openReader(context, item),
                            onRemove: () => ContinueReadingService.removeProgress(item.md5),
                          );
                        },
                      ),
                    ),

                    // Left Arrow
                    if (isDesktop && _canScrollLeft)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _isHoveringSlider ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: _buildArrowButton(
                              Icons.chevron_left_rounded,
                              () => _scroll(-1),
                            ),
                          ),
                        ),
                      ),

                    // Right Arrow
                    if (isDesktop && _canScrollRight)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _isHoveringSlider ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: _buildArrowButton(
                              Icons.chevron_right_rounded,
                              () => _scroll(1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E26).withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 26),
        onPressed: onPressed,
      ),
    );
  }
}

class _ContinueReadingCard extends StatefulWidget {
  final ReadingProgress item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ContinueReadingCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<_ContinueReadingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final percent = (item.progressPercent * 100).round();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 140,
          margin: const EdgeInsets.only(right: 18),
          transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover with progress bar
              Stack(
                children: [
                  Container(
                    height: 180,
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _hovered ? const Color(0xFF7C3AED) : Colors.white12,
                        width: _hovered ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _hovered
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                              : Colors.black54,
                          blurRadius: _hovered ? 18 : 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: item.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.coverUrl,
                              cacheManager: AppImageCache.manager,
                              // Cover box is fixed 140 wide; bound to ~3x.
                              memCacheWidth: 420,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFF20212C),
                                child: const Center(
                                  child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF20212C),
                                child: const Center(
                                  child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                ),
                              ))
                          : Container(
                              color: const Color(0xFF20212C),
                              child: const Center(
                                child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                              ),
                            ),
                    ),
                  ),

                  // Format Tag Top-Left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        item.fileType.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Remove Button Top-Right (always on mobile, hover-only on desktop)
                  if (_hovered || !(defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux))
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: widget.onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),

                  // Progress Bar at Bottom of Cover
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: item.progressPercent.clamp(0.02, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF7C3AED),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                item.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Progress subtext
              Text(
                item.fileType == 'pdf'
                    ? 'Page ${item.currentPage} • $percent%'
                    : 'Ch. ${item.chapterIndex + 1} • $percent%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
