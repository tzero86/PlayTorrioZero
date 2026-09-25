import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_settings.dart';
import '../metadata/tmdb_service.dart';
import 'curated_collection.dart';

/// TMDb-ranked stand-ins for the six bundled 1990s era rails.
///
/// A ranked rail is built only from the user's own TMDb credential. With no key
/// configured [rankedItems] returns nothing and issues no request, so the
/// bundled hand-picked packs stay the offline baseline. A successful lookup is
/// cached on disk for a day: a later cold start with no network still paints the
/// ranked list the last run produced, and a failed lookup leaves both that cache
/// and the bundled items untouched.
abstract final class TmdbRanked {
  static const int fromYear = 1990;
  static const int toYear = 1999;
  static const int limit = 20;
  static const double minVotes = 500;
  static const Duration maxAge = Duration(hours: 24);
  static const String _cachePrefix = 'tmdb_ranked_';

  /// The era rails that have a TMDb genre, keyed by collection id.
  static const Map<String, int> genreByCollection = {
    'era_90s_action': 28,
    'era_90s_comedy': 35,
    'era_90s_horror': 27,
    'era_90s_scifi': 878,
    'era_90s_animation': 16,
    'era_90s_thriller': 53,
  };

  static Iterable<String> get ids => genreByCollection.keys;

  /// The top films of [collectionId]'s genre in the 1990s, most voted first.
  ///
  /// Empty when no key is configured or the credential is refused; the caller
  /// keeps whatever it was already showing in that case.
  static Future<List<CuratedItem>> rankedItems(String collectionId) async {
    final genreId = genreByCollection[collectionId];
    if (genreId == null || !TmdbService.isConfigured) return const [];

    try {
      final movies = await TmdbService.discover(
        fromYear: fromYear,
        toYear: toYear,
        genreId: genreId,
        limit: limit,
        minVotes: minVotes,
        includeAdult: ContentSettings.adultEnabled.value,
      );
      final items = <CuratedItem>[];
      for (final movie in movies) {
        final imdbId = movie.imdbId.trim();
        if (imdbId.isEmpty) continue;
        items.add(
          CuratedItem(
            imdbId: imdbId,
            title: movie.title,
            year: movie.year,
          ),
        );
      }
      if (items.isNotEmpty) await _write(collectionId, items);
      return items;
    } catch (e) {
      debugPrint('[TmdbRanked] Error loading $collectionId: $e');
      return const [];
    }
  }

  /// The cached ranked list for [collectionId], or null when there is none, it
  /// is older than [maxAge], or it cannot be read.
  static Future<List<CuratedItem>?> cachedItems(String collectionId) async {
    final entry = await _decodeEntry(collectionId);
    if (entry == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - entry.fetchedAt;
    if (age >= maxAge.inMilliseconds) return null;
    return entry.items;
  }

  /// Fetches and caches every rail whose cache is missing or stale. Fresh
  /// caches are left alone unless [force]. A failed fetch writes nothing, so
  /// the previous cache survives it.
  static Future<void> refreshAll({bool force = false}) async {
    for (final collectionId in ids) {
      if (!force && await cachedItems(collectionId) != null) continue;
      await rankedItems(collectionId);
    }
  }

  static Future<void> _write(
    String collectionId,
    List<CuratedItem> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'fetchedAt': DateTime.now().millisecondsSinceEpoch,
        'items': [
          for (final item in items)
            {'id': item.imdbId, 'title': item.title, 'year': item.year},
        ],
      });
      await prefs.setString('$_cachePrefix$collectionId', payload);
    } catch (e) {
      debugPrint('[TmdbRanked] Error caching $collectionId: $e');
    }
  }

  /// Reads one cache entry. A missing, truncated or otherwise unusable value
  /// reads as null: a corrupt cache must never break a rail.
  static Future<_CacheEntry?> _decodeEntry(String collectionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$collectionId');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fetchedAt = decoded['fetchedAt'];
      final rawItems = decoded['items'];
      if (fetchedAt is! num || rawItems is! List) return null;

      final items = <CuratedItem>[];
      for (final entry in rawItems) {
        if (entry is! Map) continue;
        final imdbId = entry['id'];
        final title = entry['title'];
        final year = entry['year'];
        if (imdbId is! String || title is! String || year is! num) continue;
        if (imdbId.trim().isEmpty || title.trim().isEmpty) continue;
        items.add(
          CuratedItem(imdbId: imdbId, title: title, year: year.toInt()),
        );
      }
      if (items.isEmpty) return null;
      return _CacheEntry(fetchedAt.toInt(), items);
    } catch (e) {
      debugPrint('[TmdbRanked] Ignoring unreadable cache for $collectionId: $e');
      return null;
    }
  }
}

class _CacheEntry {
  final int fetchedAt;
  final List<CuratedItem> items;

  const _CacheEntry(this.fetchedAt, this.items);
}
