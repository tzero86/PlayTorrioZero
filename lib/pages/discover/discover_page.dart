import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/content/content_settings.dart';
import '../../services/metadata/metadata_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/dock_settings.dart';
import '../../widgets/common/app_liquid_dock.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/movie/movie_card.dart';

class DiscoverPage extends StatefulWidget {
  final String? query;
  final bool isGenre;
  final AddonCatalog? initialCatalog;
  final InstalledAddon? initialAddon;

  const DiscoverPage({
    super.key,
    this.query,
    this.isGenre = false,
    this.initialCatalog,
    this.initialAddon,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  // Legacy query mode (when query is passed)
  bool get _isLegacyMode => widget.query != null && widget.query!.isNotEmpty;

  // Legacy state
  bool _legacyLoading = true;
  String? _legacyError;
  List<MovieSection> _legacySections = [];

  // Full Discover state
  List<({InstalledAddon addon, AddonCatalog catalog})> _allCatalogs = [];
  List<String> _availableTypes = [];
  String _selectedType = 'movie';

  /// Pseudo-type that narrows the catalog list to adult addons. Only offered
  /// while the global Adult Content switch is on and such an addon exists.
  static const String _adultType = '18+';

  ({InstalledAddon addon, AddonCatalog catalog})? _selectedCatalogEntry;
  final Map<String, String> _selectedExtras = {};

  final List<Movie> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final ScrollController _filtersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ContentSettings.adultEnabled.addListener(_onAdultContentChanged);

    if (_isLegacyMode) {
      _fetchLegacyData();
    } else {
      _initDiscoverCatalogs();
    }
  }

  @override
  void dispose() {
    ContentSettings.adultEnabled.removeListener(_onAdultContentChanged);
    _scrollController.dispose();
    _filtersScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// The catalog list is adult-filtered at query time, so rebuild it under the
  /// new switch value and reload. The previous type/entry is preserved when it
  /// still exists (see [_initDiscoverCatalogs]).
  void _onAdultContentChanged() {
    if (!mounted) return;
    MetadataService.clearCatalogCache();
    if (_isLegacyMode) {
      _fetchLegacyData();
      return;
    }
    _initDiscoverCatalogs();
  }

  // ── Legacy Search / Genre Mode ──
  Future<void> _fetchLegacyData() async {
    setState(() {
      _legacyLoading = true;
      _legacyError = null;
    });

    try {
      final manager = AddonManager.instance;
      List<MovieSection> sections;

      if (widget.isGenre) {
        sections = await manager.fetchByGenre(widget.query!);
      } else {
        sections = await manager.searchAll(widget.query!);
      }

      if (!mounted) return;
      setState(() {
        _legacySections = sections;
        _legacyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _legacyError = e.toString();
        _legacyLoading = false;
      });
    }
  }

  // ── Full Discover Mode ──
  void _initDiscoverCatalogs() {
    final catalogs = AddonManager.instance.getAvailableDiscoverCatalogs();
    final types = <String>{};
    for (final entry in catalogs) {
      types.add(entry.catalog.type);
    }

    final sortedTypes = types.toList();
    const priority = ['movie', 'series', 'anime', 'collections', 'collection'];
    sortedTypes.sort((a, b) {
      final idxA = priority.indexOf(a);
      final idxB = priority.indexOf(b);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.compareTo(b);
    });

    // The 18+ entry is a view of the app's adult sources, so it is offered
    // whenever the global switch is on — even before any adult addon exists,
    // otherwise the filter silently looks missing. The empty view explains how
    // to add one.
    if (ContentSettings.adultEnabled.value &&
        !sortedTypes.contains(_adultType)) {
      sortedTypes.add(_adultType);
    }

    // Preserve the user's current type/entry across re-inits (e.g. the 18+
    // switch flipping the available catalog list). Falls back to the initial
    // catalog when the prior selection no longer exists.
    final hasPriorSelection =
        _availableTypes.isNotEmpty || _selectedCatalogEntry != null;
    final priorType = _selectedType;
    final priorEntry = _selectedCatalogEntry;

    String initialType;
    if (hasPriorSelection && sortedTypes.contains(priorType)) {
      initialType = priorType;
    } else {
      initialType =
          widget.initialCatalog?.type ??
          (sortedTypes.isNotEmpty ? sortedTypes.first : 'movie');
      if (!sortedTypes.contains(initialType) && sortedTypes.isNotEmpty) {
        initialType = sortedTypes.first;
      }
    }

    ({InstalledAddon addon, AddonCatalog catalog})? initialEntry;
    if (priorEntry != null) {
      for (final entry in catalogs) {
        if (entry.catalog.id == priorEntry.catalog.id &&
            entry.addon.manifest.id == priorEntry.addon.manifest.id) {
          initialEntry = entry;
          break;
        }
      }
    }
    if (initialEntry == null && widget.initialCatalog != null) {
      for (final entry in catalogs) {
        if (entry.catalog.id == widget.initialCatalog!.id &&
            (widget.initialAddon == null || entry.addon.manifest.id == widget.initialAddon!.manifest.id)) {
          initialEntry = entry;
          break;
        }
      }
    }

    initialEntry ??= catalogs.where((c) => c.catalog.type == initialType).firstOrNull ?? catalogs.firstOrNull;

    setState(() {
      _allCatalogs = catalogs;
      _availableTypes = sortedTypes;
      _selectedType = initialType;
      _selectedCatalogEntry = initialEntry;
    });

    _checkAndLoadCatalog();
  }

  List<({InstalledAddon addon, AddonCatalog catalog})> get _currentTypeCatalogs {
    if (_selectedType == _adultType) {
      return _allCatalogs.where((c) => c.addon.isAdultCapable).toList();
    }
    return _allCatalogs.where((c) => c.catalog.type == _selectedType).toList();
  }

  bool get _hasVisibleExtras {
    if (_selectedCatalogEntry == null) return false;
    return _selectedCatalogEntry!.catalog.extra.any((e) =>
        e.name != 'skip' && (e.name != 'search' || e.isRequired));
  }

  List<CatalogExtra> get _missingRequiredExtras {
    if (_selectedCatalogEntry == null) return const [];
    final catalog = _selectedCatalogEntry!.catalog;
    return catalog.requiredExtras.where((req) {
      final val = _selectedExtras[req.name];
      return val == null || val.trim().isEmpty;
    }).toList();
  }

  bool get _areRequiredExtrasSatisfied => _missingRequiredExtras.isEmpty;

  void _onTypeChanged(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      // The 18+ entry is a cross-addon filter, so resolve the first catalog
      // through the same getter the chip row uses.
      _selectedCatalogEntry = _currentTypeCatalogs.firstOrNull;
      _selectedExtras.clear();
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onCatalogChanged(({InstalledAddon addon, AddonCatalog catalog}) entry) {
    if (_selectedCatalogEntry == entry) return;
    setState(() {
      _selectedCatalogEntry = entry;
      _selectedExtras.clear();
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onExtraOptionSelected(String extraName, String? value) {
    if (_selectedExtras[extraName] == value) return;
    setState(() {
      if (value == null || value.trim().isEmpty) {
        _selectedExtras.remove(extraName);
      } else {
        _selectedExtras[extraName] = value.trim();
      }
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onCustomExtraSubmitted(String extraName, String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _selectedExtras.remove(extraName);
      });
    } else {
      setState(() {
        _selectedExtras[extraName] = value.trim();
      });
    }
    _checkAndLoadCatalog();
  }

  void _checkAndLoadCatalog() {
    if (_selectedCatalogEntry == null) {
      setState(() {
        _items.clear();
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    if (!_areRequiredExtrasSatisfied) {
      // Gating: DO NOT fire network requests until required extras are selected!
      setState(() {
        _items.clear();
        _isLoading = false;
        _hasMore = false;
        _error = null;
      });
      return;
    }

    _loadItems(refresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && _hasMore) {
        _loadItems();
      }
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (_selectedCatalogEntry == null) return;
    final entry = _selectedCatalogEntry!;

    if (refresh) {
      setState(() {
        _items.clear();
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore) return;
    if (!_areRequiredExtrasSatisfied) return;

    setState(() => _isLoading = true);

    try {
      List<Movie> newItems = [];

      final params = Map<String, String>.from(_selectedExtras);
      if (_searchQuery.isNotEmpty) {
        params['search'] = _searchQuery;
      }

      if (_isSearching && _searchQuery.isNotEmpty && !entry.catalog.supportsSkip) {
        newItems = await MetadataService.search(
          baseUrl: entry.addon.baseUrl,
          type: entry.catalog.type,
          catalogId: entry.catalog.id,
          query: _searchQuery,
        );
        _hasMore = false;
      } else {
        newItems = await MetadataService.fetchCatalog(
          baseUrl: entry.addon.baseUrl,
          type: entry.catalog.type,
          catalogId: entry.catalog.id,
          extraParams: params.isNotEmpty ? params : null,
          skip: entry.catalog.supportsSkip ? _items.length : 0,
        );

        if (!entry.catalog.supportsSkip) {
          _hasMore = false;
        }
      }

      if (!mounted) return;

      setState(() {
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(newItems);
          if (newItems.length < 10) {
            _hasMore = false;
          }
        }
        _isLoading = false;
      });

      // Auto load more if screen not filled yet
      if (_hasMore && !_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          if (_scrollController.position.maxScrollExtent <= 0) {
            _loadItems();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
      });
      _checkAndLoadCatalog();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query.trim();
    });
    _checkAndLoadCatalog();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _checkAndLoadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLegacyMode) {
      return _buildLegacyScaffold();
    }
    return _buildDiscoverScaffold();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Full Discover UI
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDiscoverScaffold() {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomInset = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isCompactScreen = screenHeight < 520;

    final sizing = MovieCardSizing.fromWidth(screenWidth);

    final hasExtras = _hasVisibleExtras;
    final toolbarH = isCompactScreen ? 46.0 : kToolbarHeight;
    final selectorH = isCompactScreen ? 44.0 : 50.0;
    final extrasH = isCompactScreen ? 42.0 : 48.0;

    final headerHeight = topPadding + toolbarH + selectorH + (hasExtras ? extrasH : 0);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // ── Main Content Grid ──
          Positioned.fill(
            child: _buildDiscoverContent(headerHeight, sizing, bottomInset),
          ),

          // ── Glass App Bar & Filters ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(
              topPadding,
              hasExtras,
              isCompactScreen: isCompactScreen,
              toolbarH: toolbarH,
              selectorH: selectorH,
              extrasH: extrasH,
            ),
          ),

          // ── Liquid Dock Navbar ──
          Positioned(
            bottom: 12.0 + bottomInset,
            left: 0,
            right: 0,
            child: const Center(
              child: AppLiquidDock(
                currentDestination: DockItemKey.discover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverContent(double topOffset, MovieCardSizing sizing, double bottomInset) {
    if (_selectedCatalogEntry == null) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topOffset + 30, 20, 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                _selectedType == _adultType
                    ? 'No 18+ sources yet.\nMark an addon as 18+ in Settings → Addons, or install one.'
                    : 'No catalogs available for "$_selectedType"',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Required extra gating prompt
    if (!_areRequiredExtrasSatisfied) {
      return _buildRequiredExtraGatingPrompt(topOffset);
    }

    if (_items.isEmpty && _isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
      );
    }

    if (_items.isEmpty && _error != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topOffset + 30, 20, 100),
          child: ErrorView(
            error: _error,
            onRetry: () => _loadItems(refresh: true),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topOffset + 30, 20, 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              const Text(
                'No titles found in this catalog',
                style: TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = ((screenWidth - sizing.sidePadding * 2 + sizing.spacing) /
            (sizing.cardWidth + sizing.spacing))
        .floor()
        .clamp(2, 10);
    final double cardAspectRatio = sizing.cardWidth / sizing.totalHeight;

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        sizing.sidePadding,
        topOffset + 14,
        sizing.sidePadding,
        110 + bottomInset,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: sizing.spacing,
        mainAxisSpacing: sizing.spacing,
      ),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(
            child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
          );
        }
        return MovieCard(movie: _items[index]);
      },
    );
  }

  Widget _buildRequiredExtraGatingPrompt(double topOffset) {
    final missing = _missingRequiredExtras;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isNarrow ? 16 : 24,
          topOffset + 20,
          isNarrow ? 16 : 24,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 18 : 28,
            vertical: isNarrow ? 20 : 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF131622).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF9D85FF), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Required Filter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isNarrow ? 17 : 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This catalog requires selecting ${missing.map((e) => e.name).join(' & ')} before loading titles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: isNarrow ? 13 : 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Quick selection chips for missing extras
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: missing.map((extra) {
                  if (extra.options.isNotEmpty) {
                    return PopupMenuButton<String>(
                      tooltip: extra.name,
                      constraints: const BoxConstraints(maxHeight: 360),
                      color: const Color(0xFF15171F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      onSelected: (val) => _onExtraOptionSelected(extra.name, val),
                      itemBuilder: (context) => extra.options
                          .map(
                            (opt) => PopupMenuItem<String>(
                              value: opt,
                              child: Text(opt, style: const TextStyle(color: Colors.white)),
                            ),
                          )
                          .toList(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 14 : 16,
                          vertical: isNarrow ? 7 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeService.currentPalette.value.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Select ${extra.name[0].toUpperCase()}${extra.name.substring(1)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isNarrow ? 12.5 : 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return ElevatedButton.icon(
                      onPressed: () => _showCustomExtraDialog(extra.name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 14 : 18,
                          vertical: isNarrow ? 8 : 10,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(
                        'Enter ${extra.name}',
                        style: TextStyle(fontSize: isNarrow ? 12.5 : 14),
                      ),
                    );
                  }
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomExtraDialog(String extraName) {
    final controller = TextEditingController(text: _selectedExtras[extraName] ?? '');
    final screenWidth = MediaQuery.sizeOf(context).width;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15171F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          'Enter $extraName',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: (screenWidth - 64).clamp(260.0, 420.0),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type $extraName here...',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppThemeService.currentPalette.value.primaryColor),
              ),
            ),
            onSubmitted: (val) {
              Navigator.pop(ctx);
              _onCustomExtraSubmitted(extraName, val);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeService.currentPalette.value.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _onCustomExtraSubmitted(extraName, controller.text);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    double topPadding,
    bool hasExtras, {
    bool isCompactScreen = false,
    double toolbarH = kToolbarHeight,
    double selectorH = 50.0,
    double extrasH = 48.0,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;
    final isNarrow = screenWidth < 400;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: EdgeInsets.only(top: topPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF080A0F).withValues(alpha: 0.95),
                const Color(0xFF080A0F).withValues(alpha: 0.80),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Title Row ──
              SizedBox(
                height: toolbarH,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 19, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 2),
                    if (!_isSearching) ...[
                      Icon(Icons.explore_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 21),
                      const SizedBox(width: 8),
                      Text(
                        'Discover',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 20 : (isNarrow ? 17 : 18),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    if (_isSearching)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _onSearchSubmitted,
                            decoration: InputDecoration(
                              hintText: isNarrow
                                  ? 'Search...'
                                  : 'Search within ${_selectedCatalogEntry?.catalog.name ?? 'catalog'}...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                                onPressed: _clearSearch,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    // Search toggle button
                    if (!_isSearching && (_selectedCatalogEntry?.catalog.supportsSearch ?? false))
                      IconButton(
                        icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                        tooltip: 'Search catalog',
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // ── Type and Catalog Selector Row ──
              Container(
                height: selectorH,
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 16),
                child: Row(
                  children: [
                    // Type selector popup/dropdown
                    if (_availableTypes.isNotEmpty) ...[
                      PopupMenuButton<String>(
                        tooltip: 'Content Type',
                        constraints: const BoxConstraints(maxHeight: 360),
                        color: const Color(0xFF15171F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        onSelected: _onTypeChanged,
                        itemBuilder: (context) => _availableTypes
                            .map(
                              (t) => PopupMenuItem<String>(
                                value: t,
                                child: Text(
                                  '${t[0].toUpperCase()}${t.substring(1)}',
                                  style: TextStyle(
                                    color: t == _selectedType ? AppThemeService.currentPalette.value.primaryColor : Colors.white,
                                    fontWeight: t == _selectedType ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 10 : 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_selectedType[0].toUpperCase()}${_selectedType.substring(1)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 12 : 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: isNarrow ? 6 : 10),
                    ],

                    // Catalog selector horizontal scroll
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _currentTypeCatalogs.map((entry) {
                            final isSelected = _selectedCatalogEntry == entry;
                            // The 18+ view mixes addons, so name the source.
                            final name =
                                '${AddonManager.instance.catalogDisplayName(entry.catalog)}'
                                '${_selectedType == _adultType ? ' · ${entry.addon.manifest.name}' : ''}';
                            final hasReq = entry.catalog.hasRequiredExtra;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FocusableCard(
                                onTap: () => _onCatalogChanged(entry),
                                builder: (context, state) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 11 : 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppThemeService.currentPalette.value.primaryColor
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppThemeService.currentPalette.value.primaryColor
                                          : Colors.white.withValues(alpha: 0.12),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: isNarrow ? 12 : 13,
                                        ),
                                      ),
                                      if (hasReq) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white24 : Colors.amber.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Custom',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : Colors.amber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Extra Selectors Row (Genre, Tag, Sort, Performer, etc.) ──
              if (hasExtras) ...[
                SizedBox(
                  height: extrasH,
                  child: ListView(
                    controller: _filtersScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 16, vertical: 6),
                    physics: const BouncingScrollPhysics(),
                    children: _selectedCatalogEntry!.catalog.extra.map((extra) {
                      if (extra.name == 'skip' || (extra.name == 'search' && !extra.isRequired)) {
                        return const SizedBox.shrink();
                      }

                      final currentVal = _selectedExtras[extra.name];
                      final isReq = extra.isRequired;
                      final isSelected = currentVal != null && currentVal.isNotEmpty;

                      // Dropdown for extras with predefined options
                      if (extra.options.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: PopupMenuButton<String?>(
                            tooltip: extra.name,
                            constraints: const BoxConstraints(maxHeight: 360),
                            color: const Color(0xFF15171F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            onSelected: (val) => _onExtraOptionSelected(extra.name, val),
                            itemBuilder: (context) => [
                              if (!isReq)
                                PopupMenuItem<String?>(
                                  value: null,
                                  child: Text('All ${extra.name}', style: const TextStyle(color: Colors.white)),
                                ),
                              ...extra.options.map(
                                (opt) => PopupMenuItem<String?>(
                                  value: opt,
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: opt == currentVal ? AppThemeService.currentPalette.value.primaryColor : Colors.white,
                                      fontWeight: opt == currentVal ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isNarrow ? 10 : 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeService.currentPalette.value.primaryColor
                                    : (isReq ? Colors.amber.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppThemeService.currentPalette.value.primaryColor
                                      : (isReq ? Colors.amber.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${extra.name.toUpperCase()}: ${currentVal ?? (isReq ? "Required *" : "All")}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isReq ? Colors.amber : Colors.white.withValues(alpha: 0.8)),
                                      fontWeight: FontWeight.w600,
                                      fontSize: isNarrow ? 11.5 : 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : (isReq ? Colors.amber : Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Text input chip for freeform extras (or search if isRequired)
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FocusableCard(
                          onTap: () => _showCustomExtraDialog(extra.name),
                          builder: (context, state) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 10 : 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppThemeService.currentPalette.value.primaryColor
                                  : (isReq ? Colors.amber.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppThemeService.currentPalette.value.primaryColor
                                    : (isReq ? Colors.amber.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${extra.name.toUpperCase()}: ${currentVal ?? (isReq ? "Required *" : "Enter")}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isReq ? Colors.amber : Colors.white.withValues(alpha: 0.8)),
                                    fontWeight: FontWeight.w600,
                                    fontSize: isNarrow ? 11.5 : 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : (isReq ? Colors.amber : Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Legacy Search/Genre Scaffold (Backwards compatibility)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLegacyScaffold() {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          if (_legacyLoading)
            Center(child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor))
          else if (_legacyError != null)
            ErrorView(error: _legacyError, onRetry: _fetchLegacyData)
          else if (_legacySections.isEmpty)
            Center(
              child: Text(
                'No results found for "${widget.query}"',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          else
            _buildLegacySectionsList(topPadding + kToolbarHeight + 20),

          // Glass App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: kToolbarHeight + topPadding,
                  padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C16).withValues(alpha: 0.6),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isGenre ? 'Genre: ${widget.query}' : 'Search: ${widget.query}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 22 : 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacySectionsList(double topPadding) {
    final allMoviesMap = <String, Movie>{};
    for (var section in _legacySections) {
      for (var movie in section.movies) {
        if (!allMoviesMap.containsKey(movie.id)) {
          allMoviesMap[movie.id] = movie;
        }
      }
    }
    final allMovies = allMoviesMap.values.toList();
    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);
    final double cardAspectRatio = sizing.cardWidth / sizing.totalHeight;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        sizing.sidePadding,
        topPadding,
        sizing.sidePadding,
        110 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ((MediaQuery.sizeOf(context).width - sizing.sidePadding * 2 + sizing.spacing) /
                (sizing.cardWidth + sizing.spacing))
            .floor()
            .clamp(2, 10),
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: sizing.spacing,
        mainAxisSpacing: sizing.spacing,
      ),
      itemCount: allMovies.length,
      itemBuilder: (context, index) {
        return MovieCard(movie: allMovies[index]);
      },
    );
  }
}
