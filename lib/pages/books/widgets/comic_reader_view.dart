import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/books/reader_settings.dart';
import '../../../widgets/common/focusable_card.dart';

class ComicReaderView extends StatefulWidget {
  final Uint8List imageBytes;
  final String pageTitle;
  final VoidCallback? onNextPage;
  final VoidCallback? onPrevPage;
  final VoidCallback? onToggleControls;
  final bool showControls;

  const ComicReaderView({
    super.key,
    required this.imageBytes,
    required this.pageTitle,
    this.onNextPage,
    this.onPrevPage,
    this.onToggleControls,
    this.showControls = true,
  });

  @override
  State<ComicReaderView> createState() => _ComicReaderViewState();
}

class _ComicReaderViewState extends State<ComicReaderView> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;

  double _currentScale = 1.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant ComicReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _resetZoom(animate: false);
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() => _currentScale = scale);
    }
  }

  void _resetZoom({bool animate = true}) {
    if (!animate) {
      _transformController.value = Matrix4.identity();
      setState(() => _currentScale = 1.0);
      return;
    }

    _animateToMatrix(Matrix4.identity());
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    final targetScale = (_currentScale * factor).clamp(0.5, 6.0);

    // Scale from center or focal point
    final size = MediaQuery.of(context).size;
    final center = focalPoint ?? Offset(size.width / 2, size.height / 2);

    final currentMatrix = _transformController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double scaleRatio = targetScale / currentScale;

    final translation = currentMatrix.getTranslation();

    final newMatrix = Matrix4.identity()
      ..translate(
        center.dx - (center.dx - translation.x) * scaleRatio,
        center.dy - (center.dy - translation.y) * scaleRatio,
      )
      ..scale(targetScale);

    _animateToMatrix(newMatrix);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_currentScale > 1.2) {
      _resetZoom();
    } else {
      // Zoom into 2.5x at tap location
      final pos = details.localPosition;
      final size = MediaQuery.of(context).size;
      const targetScale = 2.5;

      final newMatrix = Matrix4.identity()
        ..translate(
          size.width / 2 - pos.dx * targetScale,
          size.height / 2 - pos.dy * targetScale,
        )
        ..scale(targetScale);

      _animateToMatrix(newMatrix);
    }
  }

  void _animateToMatrix(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.reset();
    _zoomAnimation!.addListener(() {
      _transformController.value = _zoomAnimation!.value;
    });
    _animController.forward();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Ctrl + scroll or trackpad pinch/scroll
      final scrollDelta = event.scrollDelta.dy;
      if (scrollDelta == 0) return;

      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isCtrlPressed || scrollDelta.abs() < 50) {
        final factor = scrollDelta < 0 ? 1.15 : 0.85;
        _zoomBy(factor, focalPoint: event.position);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettingsData>(
      valueListenable: ReaderSettings.settingsNotifier,
      builder: (context, settings, _) {
        return Stack(
          children: [
            // ── Interactive Image Canvas ──
            Positioned.fill(
              child: Listener(
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggleControls,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: () {},
                  child: MouseRegion(
                    cursor: _isDragging
                        ? SystemMouseCursors.grabbing
                        : (_currentScale > 1.05 ? SystemMouseCursors.grab : SystemMouseCursors.basic),
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.5,
                      maxScale: 6.0,
                      boundaryMargin: const EdgeInsets.all(300),
                      panEnabled: true,
                      scaleEnabled: true,
                      onInteractionStart: (_) => setState(() => _isDragging = true),
                      onInteractionEnd: (_) => setState(() => _isDragging = false),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 1400,
                          ),
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating Zoom Controls Bar ──
            Positioned(
              right: 24,
              bottom: widget.showControls ? 100 : 32,
              child: AnimatedOpacity(
                opacity: widget.showControls || _currentScale > 1.05 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141419).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom Out Button
                      _buildToolbarButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom Out (Ctrl -)',
                        onPressed: () => _zoomBy(0.8),
                      ),

                      // Zoom Percentage
                      FocusableCard(
                        onTap: () => _resetZoom(),
                        builder: (context, _) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            '${(_currentScale * 100).round()}%',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Zoom In Button
                      _buildToolbarButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom In (Ctrl +)',
                        onPressed: () => _zoomBy(1.25),
                      ),

                      const SizedBox(width: 4),
                      Container(height: 18, width: 1, color: Colors.white12),
                      const SizedBox(width: 4),

                      // Reset / Fit
                      _buildToolbarButton(
                        icon: Icons.fit_screen_rounded,
                        tooltip: 'Reset Zoom (100%)',
                        onPressed: () => _resetZoom(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }
}
