import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:photo_view/photo_view.dart';
import '../../../services/books/epub_parser_service.dart';
import '../../../services/books/reader_settings.dart';
import '../../../widgets/common/focusable_card.dart';

class EpubContentView extends StatelessWidget {
  final EpubBookData book;
  final EpubChapterData chapter;
  final ReaderSettingsData settings;

  const EpubContentView({
    super.key,
    required this.book,
    required this.chapter,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.marginHorizontal,
        vertical: 24,
      ),
      child: SelectionArea(
        child: HtmlWidget(
          chapter.htmlContent,
          textStyle: TextStyle(
            fontFamily: settings.fontFamily,
            fontSize: settings.fontSize,
            color: settings.textColor,
            height: settings.lineSpacing,
            letterSpacing: settings.letterSpacing,
          ),
          customStylesBuilder: (element) {
            final tag = element.localName?.toLowerCase();
            if (tag == 'p') {
              return {
                'margin-bottom': '${settings.paragraphSpacing}px',
                'line-height': '${settings.lineSpacing}',
                'text-align': settings.textAlign == TextAlign.justify ? 'justify' : 'left',
                if (settings.firstLineIndent) 'text-indent': '1.8em',
              };
            }
            if (tag == 'h1' || tag == 'h2' || tag == 'h3') {
              return {
                'color': '#${settings.textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                'margin-top': '${settings.paragraphSpacing * 1.6}px',
                'margin-bottom': '${settings.paragraphSpacing}px',
                'font-family': settings.fontFamily,
              };
            }
            return null;
          },
          customWidgetBuilder: (element) {
            final tag = element.localName?.toLowerCase();
            if (tag == 'img' || tag == 'image') {
              final src = element.attributes['src'] ??
                  element.attributes['xlink:href'] ??
                  element.attributes['l:href'] ??
                  element.attributes['href'] ??
                  '';

              if (src.startsWith('data:image')) {
                try {
                  final base64Str = src.split(',').last.trim();
                  final bytes = base64Decode(base64Str);
                  return _buildInteractiveImage(context, bytes);
                } catch (_) {}
              }

              final bytes = book.resolveImage(src, chapter.href);
              if (bytes != null) {
                return _buildInteractiveImage(context, bytes);
              }
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildInteractiveImage(BuildContext context, Uint8List bytes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: FocusableCard(
          onTap: () => _openImageZoom(context, bytes),
          builder: (context, _) => Container(
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openImageZoom(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: MemoryImage(bytes),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
        ),
      ),
    );
  }
}
