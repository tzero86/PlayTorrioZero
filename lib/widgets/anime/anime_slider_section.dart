import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/anime/anime_media.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/slider_arrow.dart';
import '../../widgets/movie/movie_card.dart';
import 'anime_card.dart';

class AnimeSliderSection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<AnimeMedia> animeList;
  final Function(AnimeMedia) onAnimeTap;
  final VoidCallback? onSeeAll;

  const AnimeSliderSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.animeList,
    required this.onAnimeTap,
    this.onSeeAll,
  });

  @override
  State<AnimeSliderSection> createState() => _AnimeSliderSectionState();
}

class _AnimeSliderSectionState extends State<AnimeSliderSection> {
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
    final canRight = _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 10;
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
    if (widget.animeList.isEmpty) return const SizedBox.shrink();

    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);
    final isDesktop = _isDesktop();

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header matching Home Page exactly
          SectionHeader(
            title: widget.title,
            count: widget.animeList.length,
            subtitle: widget.subtitle,
            onSeeAll: widget.onSeeAll,
          ),
          const SizedBox(height: 12),

          // Slider with Desktop Navigation Arrows
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
                    padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding),
                    itemCount: widget.animeList.length,
                    separatorBuilder: (_, __) => SizedBox(width: sizing.spacing),
                    itemBuilder: (context, index) {
                      final anime = widget.animeList[index];
                      return SizedBox(
                        width: sizing.cardWidth,
                        child: AnimeCard(
                          anime: anime,
                          width: sizing.cardWidth,
                          onTap: () => widget.onAnimeTap(anime),
                        ),
                      );
                    },
                  ),

                  // Desktop Floating Scroll Arrows (Matching Home Page)
                  if (isDesktop) ...[
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: _canScrollLeft && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => _scroll(-1),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      right: _canScrollRight && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
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
