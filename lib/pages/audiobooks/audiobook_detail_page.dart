import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/audiobook/audiobook_scraper_service.dart';
import 'audiobook_player_screen.dart';
import 'audiobook_route_transitions.dart';
import '../../services/storage/app_image_cache.dart';

class AudiobookDetailPage extends StatefulWidget {
  final Audiobook audiobook;
  final String? heroTag;

  const AudiobookDetailPage({
    super.key,
    required this.audiobook,
    this.heroTag,
  });

  @override
  State<AudiobookDetailPage> createState() => _AudiobookDetailPageState();
}

class _AudiobookDetailPageState extends State<AudiobookDetailPage> {
  List<AudiobookChapter>? _chapters;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppThemeService.currentPalette.addListener(_onThemeChanged);
    _fetchChapters();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppThemeService.currentPalette.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _fetchChapters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chapters = await AudiobookScraperService.instance.getChapters(widget.audiobook);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load chapters: $e';
        });
      }
    }
  }

  void _playChapter(AudiobookChapter chapter) {
    if (_chapters == null || _chapters!.isEmpty) return;
    final initialIndex = _chapters!.indexOf(chapter).clamp(0, _chapters!.length - 1);

    Navigator.push(
      context,
      AudiobookPageRoute(
        page: AudiobookPlayerScreen(
          audiobook: widget.audiobook,
          chapters: _chapters!,
          initialChapterIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.audiobook;
    final hasCover = book.coverImage.isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 700;
    final palette = AppThemeService.currentPalette.value;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // Background ambient cover blur
          if (hasCover && book.coverImage.trim().isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.25,
                child: CachedNetworkImage(
                  imageUrl: book.coverImage.trim(),
                  cacheManager: AppImageCache.manager,
                  httpHeaders: const {
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  },
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          // Main Scroll View
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
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Audiobook Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Hero Cover & Info Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: 16,
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildCoverImage(book, 180, 260),
                            const SizedBox(height: 20),
                            _buildDetails(book, isMobile, palette),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCoverImage(book, 200, 290),
                            const SizedBox(width: 32),
                            Expanded(child: _buildDetails(book, isMobile, palette)),
                          ],
                        ),
                ),
              ),

              // Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, color: palette.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Chapters & Audio Files',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Chapters List
              if (_loading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: palette.primaryColor),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              else if (_chapters == null || _chapters!.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No playable chapters found.',
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
                    24 + bottomInset,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chapter = _chapters![index];
                        return _ChapterTile(
                          chapter: chapter,
                          palette: palette,
                          onTap: () => _playChapter(chapter),
                        );
                      },
                      childCount: _chapters!.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(Audiobook book, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: book.coverImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: book.coverImage,
                cacheManager: AppImageCache.manager,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF161A26)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF161A26),
                  child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white38),
                ))
            : Container(
                color: const Color(0xFF161A26),
                child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white38),
              ),
      ),
    );
  }

  Widget _buildDetails(Audiobook book, bool isMobile, AppThemePalette palette) {
    final isTorrent = book.source.toLowerCase().contains('audiobookbay');

    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isTorrent
                ? const Color(0xFFFF9800).withValues(alpha: 0.25)
                : palette.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: isTorrent
                ? Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4), width: 0.8)
                : null,
          ),
          child: Text(
            isTorrent ? 'AUDIOBOOKBAY (TORRENT)' : book.source.toUpperCase(),
            style: TextStyle(
              color: isTorrent ? const Color(0xFFFFB74D) : palette.primaryColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          book.title,
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 18 : 24,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (_chapters != null && _chapters!.isNotEmpty)
          _PlayFirstChapterButton(
            palette: palette,
            onPressed: () => _playChapter(_chapters!.first),
          ),
      ],
    );
  }
}

class _PlayFirstChapterButton extends StatefulWidget {
  final AppThemePalette palette;
  final VoidCallback onPressed;

  const _PlayFirstChapterButton({
    required this.palette,
    required this.onPressed,
  });

  @override
  State<_PlayFirstChapterButton> createState() => _PlayFirstChapterButtonState();
}

class _PlayFirstChapterButtonState extends State<_PlayFirstChapterButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.94 : (_isHovered ? 1.05 : 1.0);
    final palette = widget.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered
                    ? [palette.primaryColor, palette.accentColor]
                    : [palette.primaryColor.withValues(alpha: 0.9), palette.accentColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: palette.primaryColor.withValues(alpha: _isHovered ? 0.6 : 0.35),
                  blurRadius: _isHovered ? 18 : 10,
                  spreadRadius: _isHovered ? 2 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Play First Chapter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterTile extends StatefulWidget {
  final AudiobookChapter chapter;
  final AppThemePalette palette;
  final VoidCallback onTap;

  const _ChapterTile({
    required this.chapter,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_ChapterTile> createState() => _ChapterTileState();
}

class _ChapterTileState extends State<_ChapterTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final palette = widget.palette;
    final scale = _isPressed ? 0.98 : (_isHovered ? 1.015 : 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xFF1B2030)
                    : const Color(0xFF12151E).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isHovered
                      ? palette.primaryColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                  width: _isHovered ? 1.5 : 1.0,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: palette.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? palette.primaryColor
                            : palette.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(
                                  color: palette.primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: _isHovered ? Colors.white : palette.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: TextStyle(
                          color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
