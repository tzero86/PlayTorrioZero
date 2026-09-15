import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/book/book_result.dart';
import '../../services/books/book_download_service.dart';
import '../../services/books/continue_reading_service.dart';
import '../audiobooks/generate_audiobook_screen.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';
import '../../services/storage/app_image_cache.dart';

class BookDetailSheet extends StatefulWidget {
  final BookResult book;

  const BookDetailSheet({
    super.key,
    required this.book,
  });

  static Future<void> show(BuildContext context, BookResult book) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookDetailSheet(book: book),
    );
  }

  @override
  State<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<BookDetailSheet> {
  bool _isDownloaded = false;
  File? _downloadedFile;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    final downloaded = await BookDownloadService.instance.getDownloadedBook(
      widget.book.md5,
      widget.book.bookFiletype,
    );
    if (!mounted) return;
    setState(() {
      _isDownloaded = downloaded != null;
      _downloadedFile = downloaded;
      _checkingStatus = false;
    });
  }

  Future<void> _startReadOrDownload() async {
    if (_isDownloaded && _downloadedFile != null) {
      _openReader(_downloadedFile!);
      return;
    }

    // Start download and open upon completion
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.01;
    });

    try {
      final file = await BookDownloadService.instance.downloadBook(
        widget.book,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress = p);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isDownloaded = file != null;
        _downloadedFile = file;
      });

      if (file != null) {
        _openReader(file);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download book: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openReader(File file) {
    Navigator.of(context).pop(); // Close sheet

    final progress = ContinueReadingService.getProgress(widget.book.md5);

    if (widget.book.isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PdfReaderPage(
            file: file,
            book: widget.book,
            initialPage: progress?.currentPage ?? 1,
          ),
        ),
      );
    } else {
      // EPUB, FB2, MOBI, AZW3, TXT, CBZ, LIT, LRF all open in universal reader
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EpubReaderPage(
            file: file,
            book: widget.book,
            initialChapterIndex: progress?.chapterIndex ?? 0,
            initialScrollOffset: progress?.scrollOffset ?? 0.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final progress = ContinueReadingService.getProgress(book.md5);
    final hasProgress = progress != null && progress.progressPercent > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 36,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Cover + Metadata info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book Cover Card
                      Hero(
                        tag: 'book_cover_${book.md5}',
                        child: Container(
                          width: 124,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: book.coverUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: book.coverUrl,
                                    cacheManager: AppImageCache.manager,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: const Color(0xFF22232E),
                                      child: const Center(
                                        child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF22232E),
                                      child: const Center(
                                        child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                      ),
                                    ))
                                : Container(
                                    color: const Color(0xFF22232E),
                                    child: const Center(
                                      child: Icon(Icons.menu_book_rounded, color: Colors.white24, size: 36),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Title & Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.displayTitle,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.25,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.displayAuthor,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Color(0xFF9E9EA8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),

                            // Badges (Format, Size, Year, Language)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildBadge(
                                  book.bookFiletype.toUpperCase(),
                                  bgColor: book.isEpub
                                      ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                                      : book.isPdf
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                                          : Colors.white10,
                                  textColor: book.isEpub
                                      ? const Color(0xFFA78BFA)
                                      : book.isPdf
                                          ? const Color(0xFFFCA5A5)
                                          : Colors.white70,
                                ),
                                if (book.bookSize.isNotEmpty)
                                  _buildBadge(book.bookSize, textColor: Colors.white70),
                                if (book.year.isNotEmpty)
                                  _buildBadge(book.year, textColor: Colors.white70),
                                if (book.bookLang.isNotEmpty)
                                  _buildBadge(book.bookLang, textColor: const Color(0xFF60A5FA)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reading Progress indicator if ongoing
                  if (hasProgress) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20212C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progress.fileType == 'pdf'
                                    ? 'Page ${progress.currentPage} of ${progress.totalPages}'
                                    : 'Chapter ${progress.chapterIndex + 1} of ${progress.totalChapters}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                '${(progress.progressPercent * 100).round()}% Completed',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA78BFA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.progressPercent,
                              backgroundColor: Colors.white12,
                              color: const Color(0xFF7C3AED),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      // Read / Resume Button
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: _checkingStatus || _isDownloading ? null : _startReadOrDownload,
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    value: _downloadProgress > 0.05 ? _downloadProgress : null,
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  hasProgress ? Icons.play_arrow_rounded : Icons.auto_stories_rounded,
                                  size: 22,
                                ),
                          label: Text(
                            _isDownloading
                                ? 'Downloading ${(_downloadProgress * 100).round()}%...'
                                : hasProgress
                                    ? 'Resume Reading'
                                    : 'Read Now',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                      if (book.isEpub) ...[
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFA78BFA)),
                          tooltip: 'Generate AI Audiobook (TTS)',
                          onPressed: () async {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GenerateAudiobookScreen()),
                            );
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],

                      if (_isDownloaded) ...[
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          tooltip: 'Delete downloaded file',
                          onPressed: () async {
                            await BookDownloadService.instance.deleteBook(
                              book.md5,
                              book.bookFiletype,
                            );
                            _checkDownloadStatus();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white10,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Metadata Details List
                  if (book.publisher.isNotEmpty || book.isbn.isNotEmpty || book.series.isNotEmpty) ...[
                    const Text(
                      'Information',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20212C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          if (book.publisher.isNotEmpty)
                            _buildInfoRow('Publisher', book.publisher),
                          if (book.series.isNotEmpty)
                            _buildInfoRow('Series', book.series),
                          if (book.isbn.isNotEmpty)
                            _buildInfoRow('ISBN', book.isbn),
                          if (book.bookLang.isNotEmpty)
                            _buildInfoRow('Language', book.bookLang),
                          _buildInfoRow('File Format', book.bookFiletype.toUpperCase()),
                          if (book.bookSize.isNotEmpty)
                            _buildInfoRow('Size', book.bookSize),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description
                  if (book.description.isNotEmpty) ...[
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.description,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
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

  Widget _buildBadge(String text, {Color? bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
