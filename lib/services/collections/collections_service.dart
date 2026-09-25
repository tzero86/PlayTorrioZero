import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../metadata/tmdb_service.dart';
import 'curated_collection.dart';
import 'curated_collections.dart';
import 'tmdb_ranked.dart';

/// Home and Browse rails built from the bundled curated film packs.
///
/// A curated rail is fully offline: every [Movie] carries a metahub poster URL
/// and the Cinemeta base URL, so the card renders (and stays tappable, because
/// the details page re-fetches by imdb id) with no catalog request.
///
/// When the user has configured a TMDb key, the six 1990s era rails are shown
/// with TMDb-ranked films instead of the hand-picked ones, in place: same ids,
/// titles and positions. [collections] is what the UI reads; the bundled packs
/// are the baseline it falls back to whenever there is no key, no network or no
/// cache, so a rail is never empty.
abstract final class CollectionsService {
  static const _keyShowOnHome = 'collections_show_on_home';
  static const _addonBaseUrl = 'https://v3-cinemeta.strem.io';
  static const _posterBaseUrl = 'https://images.metahub.space/poster/medium';

  static SharedPreferences? _prefs;

  static final List<CuratedCollection> _bundled =
      List<CuratedCollection>.unmodifiable(curatedCollections);

  /// The curated rails the UI renders: the bundled packs, with the 1990s era
  /// rails swapped for ranked ones once a TMDb key is in play.
  static final ValueNotifier<List<CuratedCollection>> collections =
      ValueNotifier<List<CuratedCollection>>(_bundled);

  /// Whether the curated rails are appended to the Home page feed.
  static final ValueNotifier<bool> showOnHome = _PersistedShowOnHome(true);

  /// True only while a stored value is being applied, so that read is not
  /// written straight back to storage.
  static bool _hydrating = false;

  /// The ranked swap in flight, so a reload or a second event for the same
  /// credential joins the running one instead of starting a parallel fetch.
  static Future<void>? _rankedLoad;
  static String? _rankedFor;

  /// Bumped whenever a load starts and whenever the key is cleared, so a fetch
  /// that lands after the key went away is discarded.
  static int _rankedGeneration = 0;
  static bool _listeningToKey = false;

  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final stored = _prefs?.getBool(_keyShowOnHome) ?? true;
      _hydrating = true;
      showOnHome.value = stored;
      _hydrating = false;
    } catch (e) {
      debugPrint('[CollectionsService] Error initializing: $e');
    }
    _listenToApiKey();
    unawaited(_kickOffRanked());
  }

  static List<MovieSection> homeSections() => [
        for (final collection in collections.value) sectionFor(collection),
      ];

  static MovieSection sectionFor(CuratedCollection c) => MovieSection(
        title: c.title,
        subtitle: c.subtitle,
        contentType: 'movie',
        addonBaseUrl: _addonBaseUrl,
        catalog: AddonCatalog(
          type: 'movie',
          id: 'curated_${c.id}',
          name: c.title,
        ),
        movies: moviesFor(c),
      );

  static List<Movie> moviesFor(CuratedCollection c) => [
        for (final item in c.items) movieFor(item),
      ];

  static Movie movieFor(CuratedItem item) => Movie(
        id: item.imdbId,
        name: item.title,
        poster: '$_posterBaseUrl/${item.imdbId}/img',
        year: item.year.toString(),
        type: 'movie',
        addonBaseUrl: _addonBaseUrl,
      );

  /// Applies the ranked view for the current key: cached lists first, then a
  /// fetch for the rails with no fresh cache. Clearing the key restores the
  /// bundled picks before this returns, with no request made.
  ///
  /// Runs at startup, on every key change, and after a forced refresh.
  static Future<void> applyRanked() {
    final key = TmdbService.apiKey.value.trim();
    if (key.isEmpty) {
      _rankedGeneration++;
      _rankedLoad = null;
      _rankedFor = null;
      collections.value = _bundled;
      return Future<void>.value();
    }
    if (_rankedLoad != null && _rankedFor == key) return _rankedLoad!;

    final load = _loadRanked();
    _rankedLoad = load;
    _rankedFor = key;
    return load.whenComplete(() {
      if (identical(_rankedLoad, load)) {
        _rankedLoad = null;
        _rankedFor = null;
      }
    });
  }

  static Future<void> _kickOffRanked() async {
    try {
      await TmdbService.initialize();
    } catch (e) {
      debugPrint('[CollectionsService] Error initializing TMDb: $e');
    }
    await applyRanked();
  }

  static Future<void> _loadRanked() async {
    final generation = ++_rankedGeneration;
    try {
      final cached = await _rankedFromCache();
      if (generation != _rankedGeneration) return;
      _applyRanked(cached);

      await TmdbRanked.refreshAll();
      if (generation != _rankedGeneration) return;

      final refreshed = await _rankedFromCache();
      if (generation != _rankedGeneration || refreshed.isEmpty) return;
      _applyRanked(refreshed);
    } catch (e) {
      debugPrint('[CollectionsService] Error loading TMDb rails: $e');
    }
  }

  static Future<Map<String, List<CuratedItem>>> _rankedFromCache() async {
    final ranked = <String, List<CuratedItem>>{};
    for (final collectionId in TmdbRanked.ids) {
      final items = await TmdbRanked.cachedItems(collectionId);
      if (items != null && items.isNotEmpty) ranked[collectionId] = items;
    }
    return ranked;
  }

  /// Swaps the cached ranked lists in by id, leaving every other rail and every
  /// rail with nothing cached on the bundled picks.
  static void _applyRanked(Map<String, List<CuratedItem>> ranked) {
    if (ranked.isEmpty) {
      collections.value = _bundled;
      return;
    }
    collections.value = List<CuratedCollection>.unmodifiable([
      for (final collection in _bundled)
        _withRanked(collection, ranked[collection.id]),
    ]);
  }

  static CuratedCollection _withRanked(
    CuratedCollection collection,
    List<CuratedItem>? items,
  ) {
    if (items == null || items.isEmpty) return collection;
    return CuratedCollection(
      id: collection.id,
      title: collection.title,
      subtitle: '${items.length} films, ranked by TMDb',
      kind: collection.kind,
      items: items,
    );
  }

  static void _listenToApiKey() {
    if (_listeningToKey) return;
    _listeningToKey = true;
    TmdbService.apiKey.addListener(() => unawaited(applyRanked()));
  }
}

/// A bool whose plain `value` assignment is persisted, so the settings switch
/// and any other writer do not each have to remember to save.
class _PersistedShowOnHome extends ValueNotifier<bool> {
  _PersistedShowOnHome(super.initialValue);

  @override
  set value(bool next) {
    super.value = next;
    if (!CollectionsService._hydrating) unawaited(_persist(next));
  }

  Future<void> _persist(bool next) async {
    try {
      await CollectionsService._prefs?.setBool(
        CollectionsService._keyShowOnHome,
        next,
      );
    } catch (e) {
      debugPrint('[CollectionsService] Error saving showOnHome: $e');
    }
  }
}
