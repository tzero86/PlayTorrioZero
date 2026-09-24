import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/books/epub_parser_service.dart';
import '../../../services/books/reader_settings.dart';
import 'reader_design_tokens.dart';

class FocusLineData {
  final int index;
  final int paragraphIndex;
  final bool isFirstInParagraph;
  final bool isLastInParagraph;
  final String text;

  FocusLineData({
    required this.index,
    required this.paragraphIndex,
    required this.isFirstInParagraph,
    required this.isLastInParagraph,
    required this.text,
  });
}

class FocusModeView extends StatefulWidget {
  final EpubBookData book;
  final EpubChapterData chapter;
  final ReaderSettingsData settings;
  final VoidCallback onExit;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPrevChapter;

  const FocusModeView({
    super.key,
    required this.book,
    required this.chapter,
    required this.settings,
    required this.onExit,
    this.onNextChapter,
    this.onPrevChapter,
  });

  @override
  State<FocusModeView> createState() => _FocusModeViewState();
}

class _FocusModeViewState extends State<FocusModeView> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<String> _paragraphs = [];
  List<FocusLineData> _lines = [];
  final Map<int, GlobalKey> _lineKeys = {};
  int _activeLineIndex = 0;
  double _lastCalculatedWidth = 0.0;

  bool _showCoachMark = false;
  Timer? _coachMarkTimer;

  @override
  void initState() {
    super.initState();
    _extractParagraphs();
    _checkCoachMark();
  }

  Future<void> _checkCoachMark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('zplay_seen_focus_coach_v2') ?? false;
      if (!seen && mounted) {
        setState(() => _showCoachMark = true);
        await prefs.setBool('zplay_seen_focus_coach_v2', true);
        _coachMarkTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showCoachMark = false);
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant FocusModeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.id != widget.chapter.id) {
      _extractParagraphs();
      _activeLineIndex = 0;
      _lastCalculatedWidth = 0.0;
    }
  }

  @override
  void dispose() {
    _coachMarkTimer?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _extractParagraphs() {
    final doc = html_parser.parse(widget.chapter.htmlContent);
    final extracted = <String>[];

    final nodes = doc.querySelectorAll('h1, h2, h3, h4, p, blockquote, div, section, article');
    if (nodes.isNotEmpty) {
      for (final node in nodes) {
        final text = node.text.trim();
        if (text.isNotEmpty && !extracted.contains(text)) {
          if (text.length > 2) {
            extracted.add(text);
          }
        }
      }
    }

    if (extracted.isEmpty) {
      final bodyText = doc.body?.text.trim() ?? '';
      final split = bodyText.split(RegExp(r'\n\s*\n'));
      for (final p in split) {
        if (p.trim().isNotEmpty) extracted.add(p.trim());
      }
    }

    setState(() {
      _paragraphs = extracted;
    });
  }

  void _computeLines(double maxWidth) {
    if (_paragraphs.isEmpty || (maxWidth - _lastCalculatedWidth).abs() < 1.0) return;
    _lastCalculatedWidth = maxWidth;

    final computed = <FocusLineData>[];
    _lineKeys.clear();

    final textStyle = TextStyle(
      fontFamily: widget.settings.fontFamily,
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineSpacing,
      letterSpacing: widget.settings.letterSpacing,
      fontWeight: FontWeight.normal,
    );

    for (int pIdx = 0; pIdx < _paragraphs.length; pIdx++) {
      final pText = _paragraphs[pIdx];
      final painter = TextPainter(
        text: TextSpan(text: pText, style: textStyle),
        textAlign: widget.settings.textAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      final lineMetrics = painter.computeLineMetrics();

      if (lineMetrics.isEmpty) {
        final lineIndex = computed.length;
        _lineKeys[lineIndex] = GlobalKey();
        computed.add(FocusLineData(
          index: lineIndex,
          paragraphIndex: pIdx,
          isFirstInParagraph: true,
          isLastInParagraph: true,
          text: pText,
        ));
      } else {
        int charOffset = 0;
        for (int mIdx = 0; mIdx < lineMetrics.length; mIdx++) {
          final isLast = mIdx == lineMetrics.length - 1;
          final metric = lineMetrics[mIdx];
          
          final lineEndOffset = isLast
              ? pText.length
              : painter.getPositionForOffset(Offset(maxWidth, metric.baseline)).offset;

          final lineText = (charOffset < pText.length && lineEndOffset <= pText.length && lineEndOffset > charOffset)
              ? pText.substring(charOffset, lineEndOffset).trim()
              : pText.substring(charOffset).trim();
          charOffset = lineEndOffset;

          if (lineText.isNotEmpty) {
            final lineIndex = computed.length;
            _lineKeys[lineIndex] = GlobalKey();
            computed.add(FocusLineData(
              index: lineIndex,
              paragraphIndex: pIdx,
              isFirstInParagraph: mIdx == 0,
              isLastInParagraph: isLast,
              text: lineText,
            ));
          }
        }
      }
    }

    _lines = computed;
  }

  void _goToLine(int targetIndex) {
    if (_lines.isEmpty) return;

    if (_showCoachMark) {
      setState(() => _showCoachMark = false);
    }

    if (targetIndex < 0) {
      widget.onPrevChapter?.call();
      return;
    }

    if (targetIndex >= _lines.length) {
      if (widget.onNextChapter != null) {
        widget.onNextChapter!();
      }
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _activeLineIndex = targetIndex;
    });

    _scrollToActiveLine();
  }

  void _scrollToActiveLine() {
    if (_lines.isEmpty || _activeLineIndex >= _lines.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _lineKeys[_activeLineIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.35, // Keep active line in the upper 35% reading zone
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleScreenTap(TapUpDetails details, double screenHeight) {
    final tapY = details.localPosition.dy;
    if (tapY < screenHeight * 0.45) {
      // Tap upper screen -> previous line
      _goToLine(_activeLineIndex - 1);
    } else {
      // Tap lower screen -> next line
      _goToLine(_activeLineIndex + 1);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      _goToLine(_activeLineIndex + 1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      _goToLine(_activeLineIndex - 1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onExit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      if (delta > 25) {
        _goToLine(_activeLineIndex + 1);
      } else if (delta < -25) {
        _goToLine(_activeLineIndex - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final textColumnWidth = (screenSize.width - 64).clamp(320.0, 780.0);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _computeLines(textColumnWidth);

            return Stack(
              children: [
                // ── Pure AMOLED Background ──
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                  ),
                ),

                // ── Direct Line-by-Line Content ──
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: _handlePointerSignal,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleScreenTap(details, constraints.maxHeight),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          top: 120,
                          bottom: constraints.maxHeight * 0.55,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: textColumnWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _lines.map((line) {
                                final isActive = line.index == _activeLineIndex;

                                return Padding(
                                  key: _lineKeys[line.index],
                                  padding: EdgeInsets.only(
                                    top: 3,
                                    bottom: line.isLastInParagraph
                                        ? widget.settings.paragraphSpacing + 4
                                        : 3,
                                  ),
                                  child: InkWell(
                                    onTap: () => _goToLine(line.index),
                                    borderRadius: ReaderTokens.rounded12,
                                    child: AnimatedContainer(
                                      duration: reduceMotion ? Duration.zero : ReaderTokens.motionFocusLine,
                                      curve: ReaderTokens.curveFocusLine,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF14141C)
                                            : Colors.transparent,
                                        borderRadius: ReaderTokens.rounded12,
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.65)
                                              : Colors.transparent,
                                          width: 1.4,
                                        ),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                                                  blurRadius: 20,
                                                  spreadRadius: 0,
                                                  offset: Offset.zero,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: AnimatedDefaultTextStyle(
                                        duration: reduceMotion ? Duration.zero : ReaderTokens.motionFocusOpacity,
                                        curve: ReaderTokens.curveFocusOpacity,
                                        style: TextStyle(
                                          fontFamily: widget.settings.fontFamily,
                                          fontSize: widget.settings.fontSize,
                                          height: widget.settings.lineSpacing,
                                          letterSpacing: widget.settings.letterSpacing,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white.withValues(alpha: 0.22),
                                        ),
                                        child: Text(
                                          line.text,
                                          textAlign: widget.settings.textAlign,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Top Header Scrim Overlay ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ReaderTokens.space24,
                      vertical: ReaderTokens.space16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Focus Mode Indicator Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ReaderTokens.space12,
                            vertical: ReaderTokens.space4 + 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111116).withValues(alpha: 0.90),
                            borderRadius: ReaderTokens.rounded24,
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.40)),
                            boxShadow: const [ReaderTokens.shadowSm],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.center_focus_strong_rounded, color: Color(0xFFA78BFA), size: 16),
                              SizedBox(width: ReaderTokens.space8),
                              Text(
                                'Focus Mode Active',
                                style: TextStyle(
                                  fontFamily: ReaderTokens.uiFont,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFA78BFA),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Exit Pill
                        Semantics(
                          label: 'Exit Focus Mode',
                          button: true,
                          child: InkWell(
                            onTap: widget.onExit,
                            borderRadius: ReaderTokens.rounded24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ReaderTokens.space16,
                                vertical: ReaderTokens.space8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14141A).withValues(alpha: 0.95),
                                borderRadius: ReaderTokens.rounded24,
                                border: Border.all(color: Colors.white12),
                                boxShadow: const [ReaderTokens.shadowSm],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: ReaderTokens.space4),
                                  Text(
                                    'Exit (Esc)',
                                    style: TextStyle(
                                      fontFamily: ReaderTokens.uiFont,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── One-Time Coach Mark ──
                if (_showCoachMark)
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _showCoachMark ? 1.0 : 0.0,
                        duration: ReaderTokens.motionFast,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ReaderTokens.space16,
                            vertical: ReaderTokens.space8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121217).withValues(alpha: 0.95),
                            borderRadius: ReaderTokens.rounded24,
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.40)),
                            boxShadow: const [ReaderTokens.shadowMd],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, color: Color(0xFFA78BFA), size: 16),
                              SizedBox(width: ReaderTokens.space8),
                              Text(
                                'Tap above/below to move · ↑ ↓ keys to navigate',
                                style: TextStyle(
                                  fontFamily: ReaderTokens.uiFont,
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Desktop Floating Chevron Controls ──
                Positioned(
                  right: ReaderTokens.space24,
                  top: constraints.maxHeight * 0.44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121217).withValues(alpha: 0.92),
                      borderRadius: ReaderTokens.rounded32,
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [ReaderTokens.shadowMd],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                          tooltip: 'Previous Line (Up Arrow)',
                          onPressed: () => _goToLine(_activeLineIndex - 1),
                        ),
                        Container(height: 1, width: 24, color: Colors.white12),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                          tooltip: 'Next Line (Down Arrow / Space)',
                          onPressed: () => _goToLine(_activeLineIndex + 1),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Ambient Hairline Progress Bar (50% Opacity) ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.50,
                    child: LinearProgressIndicator(
                      value: _lines.isNotEmpty ? (_activeLineIndex + 1) / _lines.length : 0.0,
                      minHeight: 2.0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
