import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/my_list/my_list_item.dart';
import '../../services/content/content_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../utils/navigation/route_transitions.dart';
import '../details/details_page.dart';
import '../../models/movie/movie.dart';
import '../../services/storage/app_image_cache.dart';
import '../../widgets/common/focusable_card.dart';

class MyListPage extends StatefulWidget {
  const MyListPage({super.key});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  String _filterType = 'all'; // 'all', 'movie', 'series'
  String _sortBy = 'recent'; // 'recent', 'title', 'year'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MyListItem> _getFilteredAndSortedItems(List<MyListItem> allItems) {
    var filtered = allItems.where((item) {
      // 1. Filter by media type
      if (_filterType == 'movie' && item.type != 'movie') return false;
      if (_filterType == 'series' && item.type != 'series' && item.type != 'anime') return false;

      // 2. Filter by search query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final title = item.title.toLowerCase();
        if (!title.contains(query)) return false;
      }
      return true;
    }).toList();

    // 3. Sort items
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case 'title':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'year':
        filtered.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
    }
    return filtered;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  void _navigateToDetail(MyListItem item) {
    final effectiveId = item.imdbId ??
        (item.tmdbId != null ? 'tmdb:${item.tmdbId}' : null) ??
        item.traktId?.toString() ??
        '';

    final movie = Movie(
      id: effectiveId,
      name: item.title,
      poster: item.poster,
      year: item.year?.toString(),
      type: item.type,
      addonBaseUrl: 'https://v3-cinemeta.strem.io',
    );

    Navigator.push(
      context,
      LiquidRevealRoute(
        page: DetailsPage(movie: movie),
        tapPosition: null,
      ),
    );
  }

  Future<void> _confirmRemove(MyListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from My List?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          'Remove "${item.title}" from your list?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        MyListService.remove(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // ── Ambient Background Glows ──
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    blurRadius: 140,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content ──
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                MyListService.items,
                ContentSettings.adultEnabled,
              ]),
              builder: (context, _) {
                final allItems = MyListService.visibleItems;
                final movieCount = allItems.where((i) => i.type == 'movie').length;
                final seriesCount = allItems.where((i) => i.type == 'series' || i.type == 'anime').length;
                final displayedItems = _getFilteredAndSortedItems(allItems);

                return Column(
                  children: [
                    // ── Header Bar ──
                    _buildHeader(context, allItems.length),

                    // ── Filter Pills & Search Bar ──
                    _buildFilterToolbar(allItems.length, movieCount, seriesCount),

                    const SizedBox(height: 12),

                    // ── Grid of Items ──
                    Expanded(
                      child: displayedItems.isEmpty
                          ? _buildEmptyState(allItems.isEmpty)
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                24 + MediaQuery.paddingOf(context).bottom,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _getCrossAxisCount(context),
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: displayedItems.length,
                              itemBuilder: (context, index) {
                                final item = displayedItems[index];
                                return _MyListCard(
                                  item: item,
                                  onTap: () => _navigateToDetail(item),
                                  onRemove: () => _confirmRemove(item),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1017).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // My List is a tab of the library shell slot, not a pushed overlay, so the
          // back button only belongs here when there is genuinely a route underneath.
          if (Navigator.of(context).canPop())
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(8),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '$totalCount saved ${totalCount == 1 ? 'title' : 'titles'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Cloud Sync Status & Refresh Button ──
          ValueListenableBuilder<bool>(
            valueListenable: MyListService.isSyncing,
            builder: (context, isSyncing, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppThemeService.currentPalette.value.primaryColor),
                        ),
                      )
                    else
                      Icon(Icons.cloud_done_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing ? 'Syncing...' : 'Cloud Synced',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      onPressed: isSyncing ? null : () => MyListService.syncAll(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(int totalCount, int movieCount, int seriesCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Filter Tabs
                _buildFilterPill('all', 'All', totalCount),
                const SizedBox(width: 8),
                _buildFilterPill('movie', 'Movies', movieCount),
                const SizedBox(width: 8),
                _buildFilterPill('series', 'TV Shows', seriesCount),
                const SizedBox(width: 16),

                // Sort Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: const Color(0xFF151822),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      icon: Icon(Icons.sort_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 16),
                      items: const [
                        DropdownMenuItem(value: 'recent', child: Text('Recently Added')),
                        DropdownMenuItem(value: 'title', child: Text('Alphabetical')),
                        DropdownMenuItem(value: 'year', child: Text('Release Year')),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search saved titles...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String type, String label, int count) {
    final isSelected = _filterType == type;

    return FocusableCard(
      onTap: () => setState(() => _filterType = type),
      builder: (_, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isListEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.08),
              border: Border.all(color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isListEmpty ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
              size: 54,
              color: AppThemeService.currentPalette.value.primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isListEmpty ? 'Your list is empty' : 'No titles found',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isListEmpty
                ? 'Save your favorite movies and TV shows to watch anytime'
                : 'Try adjusting your search query or filter settings',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
          if (!isListEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _filterType = 'all';
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Hover Card Widget with Home Page Quality & Liquid Effects
// ─────────────────────────────────────────────────────────────────────────────

class _MyListCard extends StatelessWidget {
  const _MyListCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final MyListItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isMovie = item.type == 'movie';

    return FocusableCard(
      onTap: onTap,
      builder: (context, state) => GestureDetector(
        // Pointer-only shortcut: FocusableCard owns tap and activation, not long press.
        onLongPress: onRemove,
        child: AnimatedScale(
          scale: state.highlighted ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: CardFocusRing(
            focused: state.focused,
            radius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state.highlighted
                      ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.08),
                  width: state.highlighted ? 1.8 : 1.0,
                ),
                boxShadow: state.highlighted
                    ? [
                        BoxShadow(
                          color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Poster Image
                    if (item.poster != null && item.poster!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: item.poster!,
                        cacheManager: AppImageCache.manager,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _buildFallbackPoster())
                    else
                      _buildFallbackPoster(),

                    // Bottom Gradient & Title Overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: state.highlighted ? 0.4 : 0.2),
                              Colors.black.withValues(alpha: 0.92),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Badges (Media Type & Trakt Source)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Media Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMovie
                                  ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.85)
                                  : const Color(0xFF00E5FF).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMovie ? 'MOVIE' : 'SERIES',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          // Cloud Sync Badge
                          if (item.source == MyListSource.trakt)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFED1C24).withValues(alpha: 0.5)),
                              ),
                              child: const Icon(Icons.cloud_done_rounded, color: Color(0xFFED1C24), size: 11),
                            )
                          else if (item.source == MyListSource.simkl)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF00ADFF).withValues(alpha: 0.5)),
                              ),
                              child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF00ADFF), size: 11),
                            ),
                        ],
                      ),
                    ),

                    // Title & Metadata
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (item.year != null)
                            Text(
                              '${item.year}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Pointer-only, deliberately. On TV this overlay is
                    // unusable: the quick-delete below is a bare
                    // GestureDetector, so a remote cannot activate it, and the
                    // scrim would cover the poster a D-pad user is looking at.
                    // Gating on hover keeps the focused card clean instead of
                    // promising a control that cannot be used.
                    //
                    // TV is not left without a way to remove an item: the card is
                    // focusable and opens the details page, whose My List toggle
                    // is a FocusableCard and so answers to the centre key. The
                    // alternative — showing this overlay on focus instead — would
                    // cover the poster and would need a focus-holding Focus node,
                    // because the overlay unmounts the button being pressed.
                    // Revisit only if the details-page path goes away.
                    if (state.hovered)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Play/Details Button
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppThemeService.currentPalette.value.primaryColor,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),

                                // Quick Delete Button
                                GestureDetector(
                                  onTap: onRemove,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE50914).withValues(alpha: 0.9),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
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
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: const Color(0xFF151822),
      child: Center(
        child: Icon(
          item.type == 'movie' ? Icons.movie_rounded : Icons.tv_rounded,
          color: Colors.white24,
          size: 38,
        ),
      ),
    );
  }
}
