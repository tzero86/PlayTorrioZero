import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import 'curated_collection.dart';
import 'curated_collections.dart';

/// Home and Browse rails built from the bundled curated film packs.
///
/// A curated rail is fully offline: every [Movie] carries a metahub poster URL
/// and the Cinemeta base URL, so the card renders (and stays tappable, because
/// the details page re-fetches by imdb id) with no catalog request.
abstract final class CollectionsService {
  static const _keyShowOnHome = 'collections_show_on_home';
  static const _addonBaseUrl = 'https://v3-cinemeta.strem.io';
  static const _posterBaseUrl = 'https://images.metahub.space/poster/medium';

  static SharedPreferences? _prefs;

  /// Whether the curated rails are appended to the Home page feed.
  static final ValueNotifier<bool> showOnHome = _PersistedShowOnHome(true);

  /// True only while a stored value is being applied, so that read is not
  /// written straight back to storage.
  static bool _hydrating = false;

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
  }

  static List<MovieSection> homeSections() => [
        for (final collection in curatedCollections) sectionFor(collection),
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
