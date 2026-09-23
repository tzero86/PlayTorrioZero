import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../utils/search/relevance_scorer.dart';
import '../metadata/metadata_service.dart';
import '../p2p/p2p_settings_service.dart';
import '../content/content_settings.dart';

/// Manages installed Stremio metadata addons.
///
/// - Persists addon list + enabled state to SharedPreferences.
/// - On first launch, installs Cinemeta as default.
/// - Provides [fetchAllHomeSections] to aggregate catalogs across all active addons.
class AddonManager {
  AddonManager._();
  static final AddonManager instance = AddonManager._();

  static const String _storageKey = 'installed_addons_v4';

  List<InstalledAddon> _addons = [];
  bool _initialized = false;

  void _ensureBuiltInsExist() {
    bool changed = false;
    if (!_addons.any((a) => a.manifest.id == 'builtin.playtorrio' || a.baseUrl == 'builtin:playtorrio')) {
      _addons.add(playTorrioBuiltin);
      changed = true;
    }
    if (!_addons.any((a) => a.manifest.id == 'builtin.playtorriohttp' || a.baseUrl == 'builtin:playtorriohttp')) {
      _addons.add(playTorrioHttpBuiltin);
      changed = true;
    }
    if (changed && _initialized) {
      _save();
    }
  }

  /// Rewrites the manifest of persisted built-in addons when it still carries
  /// the pre-rebrand display name, preserving every user-controlled flag.
  ///
  /// `_ensureBuiltInsExist` only checks the id, so an install that installed the
  /// built-ins before the rename would otherwise keep the stale name forever.
  bool _refreshBuiltInNames() {
    var changed = false;
    for (final builtIn in [playTorrioBuiltin, playTorrioHttpBuiltin]) {
      final index = _addons.indexWhere(
        (a) => a.manifest.id == builtIn.manifest.id || a.baseUrl == builtIn.baseUrl,
      );
      if (index == -1) continue;
      final stored = _addons[index];
      if (stored.manifest.name == builtIn.manifest.name) continue;
      _addons[index] = InstalledAddon(
        baseUrl: builtIn.baseUrl,
        manifest: builtIn.manifest,
        enabled: stored.enabled,
        enableCatalogs: stored.enableCatalogs,
        enableSearch: stored.enableSearch,
        enableSubtitles: stored.enableSubtitles,
        enableStreams: stored.enableStreams,
        adultRating: stored.adultRating,
      );
      changed = true;
    }
    return changed;
  }

  List<InstalledAddon> get addons {
    _ensureBuiltInsExist();
    return List.unmodifiable(_addons);
  }

  /// NSFW-only addons (declared adult, or rated that way by the user) only
  /// contribute content while the global Adult Content switch is on. Hybrid and
  /// SFW addons stay active either way.
  bool _adultAllowed(InstalledAddon addon) =>
      ContentSettings.adultEnabled.value || !addon.isNsfwOnly;

  List<InstalledAddon> get activeAddons {
    _ensureBuiltInsExist();
    return _addons.where((a) => a.enabled && _adultAllowed(a)).toList();
  }

  List<InstalledAddon> get activeCatalogAddons {
    _ensureBuiltInsExist();
    return _addons.where((a) => a.isCatalogsActive && _adultAllowed(a)).toList();
  }

  List<InstalledAddon> get activeSearchAddons {
    _ensureBuiltInsExist();
    return _addons.where((a) => a.isSearchActive && _adultAllowed(a)).toList();
  }

  List<InstalledAddon> get activeSubtitleAddons {
    _ensureBuiltInsExist();
    return _addons.where((a) => a.isSubtitlesActive && _adultAllowed(a)).toList();
  }

  List<InstalledAddon> get activeStreamAddons {
    _ensureBuiltInsExist();
    return _addons
        .where((a) =>
            a.isStreamsActive &&
            !a.baseUrl.startsWith('builtin:') &&
            _adultAllowed(a))
        .toList();
  }

  bool get isPlayTorrioActive {
    _ensureBuiltInsExist();
    final p2p = _addons.firstWhere(
      (a) => a.manifest.id == 'builtin.playtorrio' || a.baseUrl == 'builtin:playtorrio',
      orElse: () => playTorrioBuiltin,
    );
    return p2p.isStreamsActive;
  }

  bool get isPlayTorrioHttpActive {
    _ensureBuiltInsExist();
    final http = _addons.firstWhere(
      (a) => a.manifest.id == 'builtin.playtorriohttp' || a.baseUrl == 'builtin:playtorriohttp',
      orElse: () => playTorrioHttpBuiltin,
    );
    return http.isStreamsActive;
  }

  /// Returns the logo URL or asset path for a given addon name or id.
  String? getAddonLogo(String addonName) {
    _ensureBuiltInsExist();
    final nameLower = addonName.trim().toLowerCase();
    if (nameLower == 'zplay' ||
        nameLower == 'zplayhttp' ||
        nameLower.startsWith('builtin')) {
      return 'asset:assets/icon_small.png';
    }
    for (final addon in _addons) {
      if (addon.manifest.name.toLowerCase() == nameLower ||
          addon.manifest.id.toLowerCase() == nameLower) {
        if (addon.manifest.logo != null && addon.manifest.logo!.isNotEmpty) {
          return addon.manifest.logo;
        }
      }
    }
    return null;
  }

  static final InstalledAddon playTorrioBuiltin = InstalledAddon(
    baseUrl: 'builtin:playtorrio',
    manifest: AddonManifest(
      id: 'builtin.playtorrio',
      name: 'ZPlay',
      version: '3.0.0',
      description: 'Built-in BitTorrent P2P streaming engine (TorrServer). Plays torrents, magnets, and infohashes directly.',
      resources: ['stream'],
      types: ['movie', 'series', 'anime'],
      idPrefixes: ['tt', 'tmdb:', 'kitsu:', 'mal:'],
      catalogs: [],
    ),
    enabled: true,
    enableCatalogs: false,
    enableSearch: false,
    enableSubtitles: false,
    enableStreams: true,
  );

  static final InstalledAddon playTorrioHttpBuiltin = InstalledAddon(
    baseUrl: 'builtin:playtorriohttp',
    manifest: AddonManifest(
      id: 'builtin.playtorriohttp',
      name: 'ZPlayHTTP',
      version: '3.0.0',
      description: 'Built-in fast HTTP stream scrapers (111477, Cinejoy, Vuflix, Movy, RiveStream, Vadapav, VidCore, VidSrc, etc.)',
      resources: ['stream'],
      types: ['movie', 'series', 'anime'],
      idPrefixes: ['tt', 'tmdb:', 'kitsu:', 'mal:'],
      catalogs: [],
    ),
    enabled: true,
    enableCatalogs: false,
    enableSearch: false,
    enableSubtitles: false,
    enableStreams: true,
  );

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);

    if (stored != null) {
      try {
        final list = jsonDecode(stored) as List<dynamic>;
        _addons = list
            .map((e) => InstalledAddon.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _addons = [];
      }
    }

    // First launch → install Cinemeta. It is seeded as a hybrid source: its
    // catalogs mix mainstream and adult titles, so it must keep working with
    // the Adult Content switch off while still being discoverable under `18+`.
    if (_addons.isEmpty) {
      try {
        await addAddon('https://v3-cinemeta.strem.io');
        for (final addon in _addons) {
          if (addon.manifest.id == 'com.linvo.cinemeta' ||
              addon.baseUrl.contains('cinemeta')) {
            addon.adultRating = AddonAdultRating.hybrid;
          }
        }
        await _save();
      } catch (_) {
        // Offline — will retry next time
      }
    }

    // Ensure ZPlay P2P engine is registered in the list
    if (!_addons.any((a) => a.manifest.id == 'builtin.playtorrio' || a.baseUrl == 'builtin:playtorrio')) {
      _addons.add(playTorrioBuiltin);
      await _save();
    }

    // Ensure ZPlayHTTP is registered in the list
    if (!_addons.any((a) => a.manifest.id == 'builtin.playtorriohttp' || a.baseUrl == 'builtin:playtorriohttp')) {
      _addons.add(playTorrioHttpBuiltin);
      await _save();
    }

    // Existing installs persisted the built-in addons under their pre-rebrand
    // display name. Refresh the stored manifest so the rename reaches installs
    // that never clear their addon list, keeping user state intact.
    if (_refreshBuiltInNames()) {
      await _save();
    }

    // Sync P2P state
    final p2pAddon = _addons.firstWhere(
      (a) => a.manifest.id == 'builtin.playtorrio' || a.baseUrl == 'builtin:playtorrio',
      orElse: () => playTorrioBuiltin,
    );
    P2pSettingsService.isP2pEnabled.value = p2pAddon.isStreamsActive;

    _initialized = true;
  }

  // ── Add / Remove / Toggle / Reorder ───────────────────────────────────

  /// Reorder addons by index and persist to storage.
  Future<void> reorderAddons(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _addons.length) return;
    if (newIndex < 0 || newIndex > _addons.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _addons.removeAt(oldIndex);
    _addons.insert(newIndex, item);
    MetadataService.clearCache();
    await _save();
  }

  /// Move addon up by 1 position.
  Future<void> moveAddonUp(int index) async {
    if (index <= 0 || index >= _addons.length) return;
    final item = _addons.removeAt(index);
    _addons.insert(index - 1, item);
    MetadataService.clearCache();
    await _save();
  }

  /// Move addon down by 1 position.
  Future<void> moveAddonDown(int index) async {
    if (index < 0 || index >= _addons.length - 1) return;
    final item = _addons.removeAt(index);
    _addons.insert(index + 1, item);
    MetadataService.clearCache();
    await _save();
  }

  /// Install an addon by its base URL or manifest URL.
  Future<InstalledAddon> addAddon(String url) async {
    String baseUrl = url.trim();

    // Convert stremio:// or stremio: URI scheme to https://
    if (baseUrl.startsWith('stremio://')) {
      baseUrl = 'https://${baseUrl.substring('stremio://'.length)}';
    } else if (baseUrl.startsWith('stremio:')) {
      baseUrl = 'https://${baseUrl.substring('stremio:'.length)}';
    } else if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }

    if (baseUrl.endsWith('/manifest.json')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - '/manifest.json'.length);
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Duplicate check by URL
    if (_addons.any((a) => a.baseUrl == baseUrl)) {
      throw Exception('This addon is already installed');
    }

    final manifest = await MetadataService.fetchManifest(baseUrl);

    // Duplicate check by addon ID
    if (_addons.any((a) => a.manifest.id == manifest.id)) {
      throw Exception('An addon with ID "${manifest.id}" is already installed');
    }

    final addon = InstalledAddon(
      baseUrl: baseUrl,
      manifest: manifest,
      enabled: true,
    );

    _addons.add(addon);
    MetadataService.clearCache();
    await _save();
    return addon;
  }

  Future<void> removeAddon(String addonId) async {
    if (addonId == 'builtin.playtorrio' || addonId == 'builtin.playtorriohttp') {
      // For built-in providers, disable instead of deleting
      await toggleAddon(addonId, false);
      return;
    }
    _addons.removeWhere((a) => a.manifest.id == addonId);
    MetadataService.clearCache();
    await _save();
  }

  Future<void> toggleAddon(String addonId, bool enabled) async {
    for (final addon in _addons) {
      if (addon.manifest.id == addonId) {
        addon.enabled = enabled;
        break;
      }
    }
    if (addonId == 'builtin.playtorrio') {
      await P2pSettingsService.setP2pEnabled(enabled);
    }
    MetadataService.clearCache();
    await _save();
  }

  /// Sets how much adult material an addon serves.
  ///
  /// [AddonAdultRating.nsfw] addons are excluded from every active-addon getter
  /// while the global Adult Content switch is off; hybrid addons stay active and
  /// additionally show up in the Discover 18+ view.
  Future<void> setAddonAdultRating(
    String addonId,
    AddonAdultRating rating,
  ) async {
    for (final addon in _addons) {
      if (addon.manifest.id == addonId) {
        addon.adultRating = rating;
        break;
      }
    }
    MetadataService.clearCache();
    await _save();
  }

  Future<void> updateAddonFeature({
    required String addonId,
    bool? enableCatalogs,
    bool? enableSearch,
    bool? enableSubtitles,
    bool? enableStreams,
  }) async {
    for (final addon in _addons) {
      if (addon.manifest.id == addonId) {
        if (enableCatalogs != null) addon.enableCatalogs = enableCatalogs;
        if (enableSearch != null) addon.enableSearch = enableSearch;
        if (enableSubtitles != null) addon.enableSubtitles = enableSubtitles;
        if (enableStreams != null) addon.enableStreams = enableStreams;
        break;
      }
    }
    if (addonId == 'builtin.playtorrio' && enableStreams != null) {
      await P2pSettingsService.setP2pEnabled(enableStreams);
    }
    MetadataService.clearCache();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_addons.map((a) => a.toJson()).toList()),
    );
  }

  // ── Home sections ─────────────────────────────────────────────────────

  /// Fetch all home page sections from every active addon's catalogs.
  /// Each addon's catalogs are fetched concurrently.
  Future<List<MovieSection>> fetchAllHomeSections() async {
    final active = activeCatalogAddons;

    final addonFutures = active.map(_fetchAddonSections);
    final results = await Future.wait(addonFutures);

    final allSections = <MovieSection>[];
    for (final sections in results) {
      allSections.addAll(sections);
    }

    return allSections;
  }

  /// Streams home page sections one by one as they load, so the UI can populate dynamically.
  Stream<MovieSection> streamHomeSections() async* {
    final active = activeCatalogAddons;
    final List<Future<MovieSection?>> sectionFutures = [];

    // 1. Kick off all network requests concurrently
    for (final addon in active) {
      // Only auto-load catalogs where NO extra has isRequired: true
      final catalogsToFetch = addon.manifest.catalogs.where((c) => c.canAutoLoadOnHome).toList();

      for (final catalog in catalogsToFetch) {
        sectionFutures.add(() async {
          try {
            // Bound each catalog so one slow (e.g. adult) source can't
            // head-of-line-block later sections past the timeout. Yield
            // order is unchanged, so UI stability is preserved.
            final movies = await MetadataService.fetchCatalog(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
            ).timeout(const Duration(seconds: 10));
            if (movies.isEmpty) return null;

            return MovieSection(
              title: _catalogDisplayName(catalog),
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: movies,
            );
          } catch (_) {
            return null; // Gracefully handle failure
          }
        }());
      }
    }

    // 2. Yield them in order so the UI stays stable (top addons appear first)
    for (final future in sectionFutures) {
      final section = await future;
      if (section != null) yield section;
    }
  }

  Future<List<MovieSection>> _fetchAddonSections(
    InstalledAddon addon,
  ) async {
    // Only auto-load catalogs where NO extra has isRequired: true
    final catalogsToFetch = addon.manifest.catalogs.where((c) => c.canAutoLoadOnHome).toList();

    final futures = catalogsToFetch.map((catalog) async {
      try {
        // Same bound as the streamed path: one slow source can't stall the
        // whole home list past the timeout.
        final movies = await MetadataService.fetchCatalog(
          baseUrl: addon.baseUrl,
          type: catalog.type,
          catalogId: catalog.id,
        ).timeout(const Duration(seconds: 10));

        return MovieSection(
          title: _catalogDisplayName(catalog),
          subtitle: addon.manifest.name,
          contentType: catalog.type,
          addonBaseUrl: addon.baseUrl,
          catalog: catalog,
          movies: movies,
        );
      } catch (_) {
        return null;
      }
    }).toList();

    final results = await Future.wait(futures);

    return results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();
  }

  /// Returns all available catalogs from active catalog addons.
  /// Includes selector-only catalogs (e.g. Tag, Performer) for Discover.
  List<({InstalledAddon addon, AddonCatalog catalog})> getAvailableDiscoverCatalogs({
    String? type,
  }) {
    final active = activeCatalogAddons;
    final list = <({InstalledAddon addon, AddonCatalog catalog})>[];
    for (final addon in active) {
      for (final catalog in addon.manifest.catalogs) {
        if (type != null && type.isNotEmpty && catalog.type != type) {
          continue;
        }
        list.add((addon: addon, catalog: catalog));
      }
    }
    return list;
  }

  /// Search across all active addons that support search.
  /// Optionally streams each [MovieSection] via [onSectionResult] as soon as it arrives.
  Future<List<MovieSection>> searchAll(
    String query, {
    void Function(MovieSection section)? onSectionResult,
  }) async {
    final active = activeSearchAddons;
    final futures = <Future<MovieSection?>>[];

    for (final addon in active) {
      final searchCatalogs = addon.manifest.catalogs
          .where((c) => c.supportsSearch)
          .toList();

      for (final catalog in searchCatalogs) {
        futures.add(() async {
          try {
            final movies = await MetadataService.search(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
              query: query,
            );

            if (movies.isEmpty) return null;

            // Sort movies within this section by relevance score
            final sortedMovies = List<Movie>.from(movies);
            sortedMovies.sort((a, b) {
              final scoreA = RelevanceScorer.score(title: a.name, query: query);
              final scoreB = RelevanceScorer.score(title: b.name, query: query);
              return scoreB.compareTo(scoreA);
            });

            final section = MovieSection(
              title: _catalogDisplayName(catalog),
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: sortedMovies,
            );

            onSectionResult?.call(section);
            return section;
          } catch (_) {
            return null;
          }
        }());
      }
    }

    final results = await Future.wait(futures);
    final validSections = results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();

    // Sort sections by the relevance score of their top match
    validSections.sort((a, b) {
      final topScoreA = a.movies.isNotEmpty ? RelevanceScorer.score(title: a.movies.first.name, query: query) : 0.0;
      final topScoreB = b.movies.isNotEmpty ? RelevanceScorer.score(title: b.movies.first.name, query: query) : 0.0;
      return topScoreB.compareTo(topScoreA);
    });

    return validSections;
  }

  /// Fetch catalogs filtered by a specific genre across all active addons.
  Future<List<MovieSection>> fetchByGenre(String genre) async {
    final active = activeCatalogAddons;
    final futures = <Future<MovieSection?>>[];

    for (final addon in active) {
      // Find catalogs that explicitly support filtering by genre via their 'extra' properties.
      final genreCatalogs = addon.manifest.catalogs.where((c) {
        final supportsGenre = c.genres.isNotEmpty;
        final isCinemetaTop = addon.manifest.id == 'com.linvo.cinemeta' && c.id == 'top';
        return supportsGenre || isCinemetaTop;
      }).toList();

      for (final catalog in genreCatalogs) {
        futures.add(() async {
          try {
            final movies = await MetadataService.fetchCatalog(
              baseUrl: addon.baseUrl,
              type: catalog.type,
              catalogId: catalog.id,
              genre: genre,
            );

            if (movies.isEmpty) return null;

            return MovieSection(
              title: '${_catalogDisplayName(catalog)} - $genre',
              subtitle: addon.manifest.name,
              contentType: catalog.type,
              addonBaseUrl: addon.baseUrl,
              catalog: catalog,
              movies: movies,
            );
          } catch (_) {
            return null;
          }
        }());
      }
    }

    final results = await Future.wait(futures);
    return results
        .where((s) => s != null && s.movies.isNotEmpty)
        .cast<MovieSection>()
        .toList();
  }

  /// Generate a human-readable name for a catalog.
  String _catalogDisplayName(AddonCatalog catalog) => catalogDisplayName(catalog);

  String catalogDisplayName(AddonCatalog catalog) {
    if (catalog.name != null && catalog.name!.isNotEmpty) {
      return catalog.name!;
    }

    final typeLabel = catalog.type == 'series'
        ? 'Series'
        : (catalog.type == 'anime'
            ? 'Anime'
            : (catalog.type == 'collections' || catalog.type == 'collection'
                ? 'Collections'
                : (catalog.type == 'movie' ? 'Movies' : catalog.type)));

    switch (catalog.id) {
      case 'top':
        return 'Popular $typeLabel';
      case 'year':
        return 'New $typeLabel';
      case 'imdbRating':
        return 'Top Rated $typeLabel';
      default:
        final id = catalog.id;
        final capitalized =
            id.isEmpty ? id : '${id[0].toUpperCase()}${id.substring(1)}';
        return '$capitalized $typeLabel';
    }
  }
}
