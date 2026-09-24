import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie_section.dart';
import '../../pages/calendar/tv_calendar_page.dart';
import '../../pages/catalog/catalog_page.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../utils/navigation/route_transitions.dart';
import './movie_card.dart';
import '../common/section_header.dart';

class MovieSliderSection extends StatefulWidget {
  final MovieSection section;
  final bool showCalendarButton;

  const MovieSliderSection({
    super.key,
    required this.section,
    this.showCalendarButton = false,
  });

  @override
  State<MovieSliderSection> createState() => _MovieSliderSectionState();
}

class _MovieSliderSectionState extends State<MovieSliderSection>
    with SingleTickerProviderStateMixin {
  Offset? _tapPosition;
  late final ScrollController _scrollController;

  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHoveringSlider = false;

  /// Cards that take part in the entry stagger.
  ///
  /// The rail mounts every card at once, so a row used to arrive in one hard
  /// cut. Only the first few animate, and only once on mount: animating a list
  /// that scrolls is the quickest way to lose frames, and the perf notes already
  /// call this screen heavy.
  static const int _staggeredCards = 6;
  static const double _staggerStep = 0.08;

  late final AnimationController _entry;
  final List<Animation<double>> _entryFades = [];
  final List<Animation<Offset>> _entrySlides = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);

    // Built once rather than per build, so a scroll does not allocate.
    _entry = AnimationController(vsync: this, duration: ZplayMotion.slow);
    for (var i = 0; i < _staggeredCards; i++) {
      final fade = _entry.drive(
        CurveTween(
          curve: Interval(
            i * _staggerStep,
            0.45 + i * _staggerStep,
            curve: ZplayMotion.standard,
          ),
        ),
      );
      _entryFades.add(fade);
      _entrySlides.add(
        fade.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ),
        ),
      );
    }
    _entry.forward();

    // Defer the initial check until after first frame so maxScrollExtent is calculated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  /// Wraps a card in its share of the entry animation. Cards past the stagger
  /// window are returned untouched.
  Widget _enter(int index, Widget child) {
    if (index >= _staggeredCards) return child;

    return FadeTransition(
      opacity: _entryFades[index],
      child: SlideTransition(position: _entrySlides[index], child: child),
    );
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;

    final canLeft = _scrollController.position.pixels > 0;
    final canRight =
        _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent;

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
    // Scroll by 80% of the viewport width to leave some context
    final scrollAmount = viewportWidth * 0.8 * directionMultiplier;

    final target = (_scrollController.position.pixels + scrollAmount).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);
    final isDesktop = _isDesktop();

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Listener(
            onPointerDown: (event) => _tapPosition = event.position,
            child: SectionHeader(
              title: widget.section.title,
              count: widget.section.movies.length,
              subtitle: widget.section.subtitle,
              trailing: widget.showCalendarButton
                  ? InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TvCalendarPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: AppThemeService
                                  .currentPalette
                                  .value
                                  .primaryColor,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Calendar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
              onSeeAll: () {
                Navigator.push(
                  context,
                  LiquidRevealRoute(
                    page: CatalogPage(section: widget.section),
                    tapPosition: _tapPosition,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringSlider = true),
            onExit: (_) => setState(() => _isHoveringSlider = false),
            child: SizedBox(
              height: sizing.totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    clipBehavior: Clip.none,
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: sizing.sidePadding,
                    ),
                    itemCount: widget.section.movies.length,
                    separatorBuilder: (context, index) {
                      return SizedBox(width: sizing.spacing);
                    },
                    itemBuilder: (context, index) {
                      return _enter(
                        index,
                        SizedBox(
                          width: sizing.cardWidth,
                          child: MovieCard(movie: widget.section.movies[index]),
                        ),
                      );
                    },
                  ),

                  // Desktop Scroll Arrows
                  if (isDesktop) ...[
                    // Left Arrow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: _canScrollLeft && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderArrow(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => _scroll(-1),
                        ),
                      ),
                    ),

                    // Right Arrow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      right: _canScrollRight && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderArrow(
                          icon: Icons.arrow_forward_ios_rounded,
                          onTap: () => _scroll(1),
                        ),
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
}

class _SliderArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SliderArrow({required this.icon, required this.onTap});

  @override
  State<_SliderArrow> createState() => _SliderArrowState();
}

class _SliderArrowState extends State<_SliderArrow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Dynamic scale based on interaction state
    final scale = _isPressed ? 0.90 : (_isHovered ? 1.08 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFF080A0F).withValues(alpha: 0.5),
                  border: Border.all(
                    color: _isHovered
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.7),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
