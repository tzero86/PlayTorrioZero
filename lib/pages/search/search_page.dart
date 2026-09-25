import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../models/stream/stream_model.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/cloudstream/cloudstream_manager.dart';
import '../../services/home/home_page_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/movie/movie_slider_section.dart';
import '../../widgets/search/magnet_files_view.dart';
import '../ai/wewatch_quiz_page.dart';
import '../player/player_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  Timer? _debounce;
  bool _isLoading = false;
  List<MovieSection> _results = [];
  String _lastQuery = '';

  bool _isMagnetMode = false;
  String _magnetQuery = '';

  List<String> _searchHistory = [];
  List<MovieSection> _suggestedSections = [];
  bool _isLoadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _loadSuggestions();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('search_history', history);
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _removeSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    await prefs.setStringList('search_history', history);
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (mounted) {
      setState(() {
        _searchHistory = [];
      });
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final sections = await AddonManager.instance.fetchAllHomeSections();
      if (mounted) {
        setState(() {
          _suggestedSections = sections.take(4).toList();
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  static bool _isMagnetLink(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('magnet:')) return true;
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(trimmed)) return true;
    if (RegExp(r'^[a-zA-Z2-7]{32}$').hasMatch(trimmed)) return true;
    return false;
  }

  static bool _isStreamLink(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    return true;
  }

  void _playDirectStream(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    String title = 'Direct Stream';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty) {
        title = Uri.decodeComponent(last);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: StreamSource(
            name: 'Direct Stream',
            title: title,
            url: trimmed,
            addonName: 'Direct Stream',
          ),
          title: title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results.clear();
        _isLoading = false;
        _lastQuery = '';
        _isMagnetMode = false;
        _magnetQuery = '';
      });
      return;
    }

    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
      });
      return;
    } else if (_isMagnetMode) {
      setState(() {
        _isMagnetMode = false;
        _magnetQuery = '';
      });
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (trimmed != _lastQuery) {
        _performSearch(trimmed);
      }
    });
  }

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
      });
      return;
    }

    _saveSearchHistory(trimmed);

    setState(() {
      _isLoading = true;
      _lastQuery = trimmed;
      _isMagnetMode = false;
      _results = [];
    });

    final currentQuery = trimmed;

    void addSection(MovieSection section, {bool isCloudStream = false}) {
      if (!mounted || _lastQuery != currentQuery) return;
      if (section.movies.isEmpty) return;

      // Prevent duplicate sections
      final exists = _results.any((s) =>
          s.title == section.title &&
          s.subtitle == section.subtitle &&
          s.addonBaseUrl == section.addonBaseUrl);
      if (exists) return;

      setState(() {
        if (!isCloudStream &&
            (section.addonBaseUrl.contains('cinemeta') ||
                section.subtitle.toLowerCase().contains('cinemeta'))) {
          // Prioritize Cinemeta at the top
          _results.insert(0, section);
        } else {
          _results.add(section);
        }
      });
    }

    try {
      // 1. Search Stremio Addons with dynamic streaming
      final addonSearch = AddonManager.instance.searchAll(
        currentQuery,
        onSectionResult: (section) {
          addSection(section, isCloudStream: false);
        },
      ).catchError((e) {
        debugPrint('[SearchPage] Addon search error: $e');
        return <MovieSection>[];
      });

      // 2. Search CloudStream Extensions with dynamic streaming
      final csSearch = (CloudStreamManager.instance.activeExtensions.isNotEmpty
          ? CloudStreamManager.instance.searchAcrossExtensions(
              currentQuery,
              onProviderResult: (providerName, items) {
                if (!mounted || _lastQuery != currentQuery) return;
                if (items.isEmpty) return;

                final movies = <Movie>[];
                for (final item in items) {
                  final title = item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown';
                  final rawUrl = item['url']?.toString() ?? '';
                  final sourceId = item['_sourceId']?.toString() ??
                      'cs_${providerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
                  final cover = item['cover']?.toString() ??
                      item['poster']?.toString() ??
                      item['image']?.toString();
                  final isSeries = item['type'] == 1 ||
                      item['type']?.toString().toLowerCase().contains('series') == true ||
                      item['type']?.toString().toLowerCase().contains('tv') == true ||
                      (item['extraData'] is Map &&
                          (item['extraData'] as Map)['type']?.toString().toLowerCase().contains('series') == true);

                  movies.add(
                    Movie(
                      id: 'cloudstream:$sourceId:${Uri.encodeComponent(rawUrl)}',
                      name: title,
                      poster: cover,
                      year: item['year']?.toString() ??
                          (item['extraData'] is Map ? (item['extraData'] as Map)['year']?.toString() : null),
                      type: isSeries ? 'series' : 'movie',
                      addonBaseUrl: 'cloudstream',
                    ),
                  );
                }

                if (movies.isNotEmpty) {
                  final section = MovieSection(
                    title: 'CloudStream • $providerName',
                    subtitle: 'CloudStream Extension',
                    contentType: 'movie',
                    addonBaseUrl: 'cloudstream',
                    catalog: AddonCatalog(
                      type: 'movie',
                      id: 'cs_$providerName',
                      name: providerName,
                    ),
                    movies: movies,
                  );
                  addSection(section, isCloudStream: true);
                }
              },
            )
          : Future.value(<String, List<Map<String, dynamic>>>{})
      ).catchError((e) {
        debugPrint('[SearchPage] CloudStream search error: $e');
        return <String, List<Map<String, dynamic>>>{};
      });

      await Future.wait([addonSearch, csSearch]);
    } catch (_) {}

    if (mounted && _lastQuery == currentQuery) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _searchController.text = text;
      _onSearchChanged(text);
      if (!_isMagnetLink(text) && !_isStreamLink(text)) {
        _performSearch(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10),
        // The shell family draws this band as an opaque palette surface with a
        // bottom hairline, not as a blurred wash over the page.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bg,
            border: Border(bottom: tokens.hairline),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topPadding,
              bottom: ZplaySpacing.s8,
            ),
            child: Row(
              children: [
                const SizedBox(width: ZplaySpacing.s8),
                // Search is a shell slot, so it usually has nothing to pop back to
                // and popping would dismiss the shell itself. Keeping the gate means a
                // pushed SearchPage still shows the button and neither state shifts
                // the field, since the inset above is unconditional.
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    color: tokens.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: ZplaySpacing.s16),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: ZplayRadius.smAll,
                        border: Border.fromBorderSide(tokens.hairline),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: ZplayType.subtitle.toStyle(
                          color: tokens.textPrimary,
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: 'Search movies, series, or paste links',
                          hintStyle: ZplayType.body.toStyle(
                            color: tokens.textDisabled,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: tokens.textMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: ZplaySpacing.s12,
                            vertical: ZplaySpacing.s12,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: tokens.textSecondary,
                                  splashRadius: 18,
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              else ...[
                                ValueListenableBuilder<bool>(
                                  valueListenable: HomePageSettings.enableAiQuiz,
                                  builder: (context, aiQuizEnabled, _) {
                                    if (!aiQuizEnabled) {
                                      return const SizedBox.shrink();
                                    }
                                    return IconButton(
                                      icon: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 17,
                                        color: AppThemeService
                                            .currentPalette
                                            .value
                                            .primaryColor,
                                      ),
                                      tooltip: 'AI Taste Quiz',
                                      splashRadius: 18,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const WeWatchQuizPage(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.content_paste_rounded,
                                    size: 17,
                                  ),
                                  tooltip: 'Paste from clipboard',
                                  color: tokens.textSecondary,
                                  splashRadius: 18,
                                  onPressed: _pasteFromClipboard,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_isMagnetMode && _magnetQuery.isNotEmpty)
            MagnetFilesView(
              key: ValueKey(_magnetQuery),
              magnet: _magnetQuery,
            )
          else if (_isLoading && _results.isEmpty)
            Center(
              child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
            )
          else if (!_isLoading && _lastQuery.isNotEmpty && _results.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: tokens.textDisabled,
                  ),
                  const SizedBox(height: ZplaySpacing.s16),
                  Text(
                    'No results for "$_lastQuery"',
                    style: ZplayType.subtitle.toStyle(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (_results.isNotEmpty)
            ListView.builder(
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(
                top: topPadding + kToolbarHeight + ZplaySpacing.s40,
                bottom: ZplaySpacing.s40 + MediaQuery.paddingOf(context).bottom,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: _results.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _results.length) {
                  final sec = _results[index];
                  return MovieSliderSection(
                    key: ValueKey('${sec.addonBaseUrl}_${sec.catalog.id}_${sec.subtitle}'),
                    section: sec,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: ZplaySpacing.s24,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeService.currentPalette.value.primaryColor,
                          ),
                        ),
                        const SizedBox(width: ZplaySpacing.s8),
                        Text(
                          'Searching more sources...',
                          style: ZplayType.bodySmall.toStyle(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            _buildDiscoveryEmptyState(topPadding),

          if (_isLoading && _results.isNotEmpty)
            Positioned(
              top: topPadding + kToolbarHeight + ZplaySpacing.s8,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppThemeService.currentPalette.value.primaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryEmptyState(double topPadding) {
    final tokens = context.tokens;

    return ListView(
      clipBehavior: Clip.none,
      padding: EdgeInsets.only(
        top: topPadding + kToolbarHeight + ZplaySpacing.s12,
        bottom: ZplaySpacing.s40 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent Searches
        if (_searchHistory.isNotEmpty) ...[
          const SizedBox(height: ZplaySpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT SEARCHES',
                  style: ZplayType.overline.toStyle(color: tokens.textMuted),
                ),
                FocusableCard(
                  onTap: _clearSearchHistory,
                  builder: (context, state) => Text(
                    'Clear All',
                    style: ZplayType.caption.toStyle(color: tokens.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZplaySpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16),
            child: Wrap(
              spacing: ZplaySpacing.s8,
              runSpacing: ZplaySpacing.s8,
              children: _searchHistory.map((query) {
                return InputChip(
                  label: Text(query),
                  labelStyle: ZplayType.bodySmall.toStyle(
                    color: tokens.textPrimary,
                  ),
                  backgroundColor: tokens.surface,
                  side: BorderSide(color: tokens.borderStrong),
                  onPressed: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                  onDeleted: () => _removeSearchHistory(query),
                  deleteIconColor: tokens.textMuted,
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ZplayRadius.smAll,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: ZplaySpacing.s12),
        ],

        // Discover / Trending Content
        if (_suggestedSections.isNotEmpty) ...[
          const SizedBox(height: ZplaySpacing.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16),
            child: Text(
              'TRENDING & SUGGESTED',
              style: ZplayType.overline.toStyle(color: tokens.textMuted),
            ),
          ),
          const SizedBox(height: ZplaySpacing.s12),
          ..._suggestedSections.map((sec) => MovieSliderSection(section: sec)),
        ] else if (_isLoadingSuggestions) ...[
          const SizedBox(height: ZplaySpacing.s32),
          Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeService.currentPalette.value.primaryColor)),
        ],
      ],
    );
  }
}
