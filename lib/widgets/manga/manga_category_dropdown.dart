import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../common/focusable_card.dart';

class MangaCategoryDropdown extends StatefulWidget {
  final String selectedGenre;
  final List<String> genres;
  final ValueChanged<String> onGenreSelected;

  const MangaCategoryDropdown({
    super.key,
    required this.selectedGenre,
    required this.genres,
    required this.onGenreSelected,
  });

  @override
  State<MangaCategoryDropdown> createState() => _MangaCategoryDropdownState();
}

class _MangaCategoryDropdownState extends State<MangaCategoryDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<double> _expandAnim;
  late Animation<double> _fadeAnim;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _hideDropdown(instant: true);
    _animController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_isOpen) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);

    setState(() => _isOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return _DropdownOverlayContent(
          layerLink: _layerLink,
          buttonSize: size,
          buttonOffset: buttonOffset,
          screenSize: screenSize,
          genres: widget.genres,
          selectedGenre: widget.selectedGenre,
          anim: _expandAnim,
          fadeAnim: _fadeAnim,
          onClose: _hideDropdown,
          onSelect: (genre) {
            _hideDropdown();
            widget.onGenreSelected(genre);
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _animController.forward();
  }

  void _hideDropdown({bool instant = false}) {
    if (!_isOpen && _overlayEntry == null) return;

    if (instant) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) setState(() => _isOpen = false);
      return;
    }

    _animController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) {
        setState(() => _isOpen = false);
      }
    });
  }

  IconData _getGenreIcon(String genre) {
    switch (genre.toLowerCase()) {
      case 'all':
        return Icons.auto_stories_rounded;
      case 'action':
        return Icons.flash_on_rounded;
      case 'adventure':
        return Icons.explore_rounded;
      case 'comedy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'drama':
        return Icons.theater_comedy_rounded;
      case 'ecchi':
        return Icons.favorite_border_rounded;
      case 'fantasy':
        return Icons.auto_fix_high_rounded;
      case 'harem':
        return Icons.groups_rounded;
      case 'historical':
        return Icons.account_balance_rounded;
      case 'horror':
        return Icons.nights_stay_rounded;
      case 'isekai':
        return Icons.cyclone_rounded;
      case 'martial arts':
        return Icons.sports_martial_arts_rounded;
      case 'mature':
        return Icons.explicit_rounded;
      case 'mystery':
        return Icons.search_rounded;
      case 'psychological':
        return Icons.psychology_rounded;
      case 'romance':
        return Icons.favorite_rounded;
      case 'school life':
        return Icons.school_rounded;
      case 'sci-fi':
        return Icons.rocket_launch_rounded;
      case 'seinen':
        return Icons.person_rounded;
      case 'shounen':
        return Icons.local_fire_department_rounded;
      case 'slice of life':
        return Icons.coffee_rounded;
      case 'sports':
        return Icons.sports_baseball_rounded;
      case 'supernatural':
        return Icons.bolt_rounded;
      case 'tragedy':
        return Icons.heart_broken_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final isSelectedGenre = widget.selectedGenre != 'All';
    final genreIcon = _getGenreIcon(widget.selectedGenre);

    return CompositedTransformTarget(
      link: _layerLink,
      child: FocusableCard(
        onTap: _toggleDropdown,
        builder: (context, state) {
          final isHovered = state.highlighted;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _isOpen || isHovered
                  ? palette.primaryColor.withValues(alpha: 0.16)
                  : (isSelectedGenre
                      ? palette.primaryColor.withValues(alpha: 0.10)
                      : const Color(0xFF121520).withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOpen
                    ? palette.primaryColor
                    : (isHovered || isSelectedGenre
                        ? palette.primaryColor.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.12)),
                width: _isOpen || isSelectedGenre ? 1.5 : 1.0,
              ),
              boxShadow: [
                if (_isOpen || isSelectedGenre)
                  BoxShadow(
                    color: palette.primaryColor.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  )
                else if (isHovered)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Icon Badge
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSelectedGenre
                        ? palette.primaryColor.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    genreIcon,
                    size: 15,
                    color: isSelectedGenre ? palette.primaryColor : Colors.white70,
                  ),
                ),
                const SizedBox(width: 9),

                // Selected Category Text
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    widget.selectedGenre,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelectedGenre ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.5,
                      fontWeight: isSelectedGenre ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Animated Rotating Chevron
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 19,
                    color: _isOpen || isSelectedGenre
                        ? palette.primaryColor
                        : Colors.white54,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DropdownOverlayContent extends StatefulWidget {
  final LayerLink layerLink;
  final Size buttonSize;
  final Offset buttonOffset;
  final Size screenSize;
  final List<String> genres;
  final String selectedGenre;
  final Animation<double> anim;
  final Animation<double> fadeAnim;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;

  const _DropdownOverlayContent({
    required this.layerLink,
    required this.buttonSize,
    required this.buttonOffset,
    required this.screenSize,
    required this.genres,
    required this.selectedGenre,
    required this.anim,
    required this.fadeAnim,
    required this.onClose,
    required this.onSelect,
  });

  @override
  State<_DropdownOverlayContent> createState() => _DropdownOverlayContentState();
}

class _DropdownOverlayContentState extends State<_DropdownOverlayContent> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  IconData _getGenreIcon(String genre) {
    switch (genre.toLowerCase()) {
      case 'all':
        return Icons.auto_stories_rounded;
      case 'action':
        return Icons.flash_on_rounded;
      case 'adventure':
        return Icons.explore_rounded;
      case 'comedy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'drama':
        return Icons.theater_comedy_rounded;
      case 'ecchi':
        return Icons.favorite_border_rounded;
      case 'fantasy':
        return Icons.auto_fix_high_rounded;
      case 'harem':
        return Icons.groups_rounded;
      case 'historical':
        return Icons.account_balance_rounded;
      case 'horror':
        return Icons.nights_stay_rounded;
      case 'isekai':
        return Icons.cyclone_rounded;
      case 'martial arts':
        return Icons.sports_martial_arts_rounded;
      case 'mature':
        return Icons.explicit_rounded;
      case 'mystery':
        return Icons.search_rounded;
      case 'psychological':
        return Icons.psychology_rounded;
      case 'romance':
        return Icons.favorite_rounded;
      case 'school life':
        return Icons.school_rounded;
      case 'sci-fi':
        return Icons.rocket_launch_rounded;
      case 'seinen':
        return Icons.person_rounded;
      case 'shounen':
        return Icons.local_fire_department_rounded;
      case 'slice of life':
        return Icons.coffee_rounded;
      case 'sports':
        return Icons.sports_baseball_rounded;
      case 'supernatural':
        return Icons.bolt_rounded;
      case 'tragedy':
        return Icons.heart_broken_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final isMobile = widget.screenSize.width < 500;
    
    // Calculate dropdown dimensions
    final menuWidth = isMobile
        ? (widget.screenSize.width - 32).clamp(280.0, 360.0)
        : 380.0;
    const menuMaxHeight = 440.0;

    // Determine horizontal alignment relative to button
    final bool alignRight = (widget.buttonOffset.dx + menuWidth) > widget.screenSize.width - 16;
    final double leftOffset = alignRight
        ? -(menuWidth - widget.buttonSize.width)
        : 0.0;

    // Filtered genre list
    final filteredGenres = widget.genres.where((g) {
      if (_filterQuery.isEmpty) return true;
      return g.toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();

    return Stack(
      children: [
        // Full screen invisible barrier to dismiss dropdown on tap.
        //
        // Deliberately NOT a FocusableCard: it is a modal scrim, and making it a
        // focus stop adds an invisible screen-sized target to traversal. The
        // remote's dismiss path is the trigger button above (itself a
        // FocusableCard) which toggles this closed — the same reasoning that
        // left the player's three panel scrims as plain detectors.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: const SizedBox.expand(),
          ),
        ),

        // Animated Dropdown Menu
        Positioned(
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: Offset(leftOffset, widget.buttonSize.height + 8),
            child: FadeTransition(
              opacity: widget.fadeAnim,
              child: ScaleTransition(
                scale: widget.anim,
                alignment: alignRight ? Alignment.topRight : Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: menuWidth,
                        constraints: const BoxConstraints(maxHeight: menuMaxHeight),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF121624).withValues(alpha: 0.95),
                              const Color(0xFF0A0D15).withValues(alpha: 0.98),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: palette.primaryColor.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 28,
                              spreadRadius: 4,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: palette.primaryColor.withValues(alpha: 0.18),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Header / Filter Search ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                        color: palette.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Manga Categories',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${widget.genres.length} Tags',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Quick Search / Filter Input
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _filterController,
                                      onChanged: (val) => setState(() => _filterQuery = val),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Filter categories...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          fontSize: 12.5,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color: palette.primaryColor.withValues(alpha: 0.8),
                                        ),
                                        suffixIcon: _filterQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                                                onPressed: () {
                                                  _filterController.clear();
                                                  setState(() => _filterQuery = '');
                                                },
                                              )
                                            : null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),

                            // ── Categories List / Grid ──
                            Flexible(
                              child: filteredGenres.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_off_rounded,
                                            size: 32,
                                            color: Colors.white.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No matching categories',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : RawScrollbar(
                                      thumbColor: palette.primaryColor.withValues(alpha: 0.35),
                                      radius: const Radius.circular(8),
                                      thickness: 4,
                                      padding: const EdgeInsets.only(right: 4),
                                      child: GridView.builder(
                                        padding: const EdgeInsets.all(12),
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                          mainAxisExtent: 44,
                                        ),
                                        itemCount: filteredGenres.length,
                                        itemBuilder: (context, index) {
                                          final genre = filteredGenres[index];
                                          final isSelected = genre == widget.selectedGenre;
                                          final icon = _getGenreIcon(genre);

                                          return _CategoryItemTile(
                                            genre: genre,
                                            icon: icon,
                                            isSelected: isSelected,
                                            palette: palette,
                                            onTap: () => widget.onSelect(genre),
                                          );
                                        },
                                      ),
                                    ),
                            ),

                            // ── Footer / Reset to All ──
                            if (widget.selectedGenre != 'All') ...[
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: InkWell(
                                  onTap: () => widget.onSelect('All'),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: palette.primaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: palette.primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            size: 15,
                                            color: palette.primaryColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Reset to All Categories',
                                            style: TextStyle(
                                              color: palette.primaryColor,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryItemTile extends StatelessWidget {
  final String genre;
  final IconData icon;
  final bool isSelected;
  final AppThemePalette palette;
  final VoidCallback onTap;

  const _CategoryItemTile({
    required this.genre,
    required this.icon,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) {
        final isHovered = state.highlighted;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primaryColor.withValues(alpha: 0.24)
                : (isHovered
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? palette.primaryColor.withValues(alpha: 0.8)
                  : (isHovered
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.06)),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: palette.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? palette.primaryColor
                    : (isHovered ? Colors.white : Colors.white60),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  genre,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isHovered ? Colors.white : Colors.white70),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.primaryColor,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
