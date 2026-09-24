import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk cache for the artwork/metadata images the UI streams from addons,
/// TMDB and user catalogs.
///
/// The `cached_network_image` default manager evicts aggressively and keeps a
/// short stale window, which makes browsing back into a catalog re-download
/// every poster. A single named manager keeps posters on disk across sessions
/// and bounds the cache so it cannot grow without limit.
class AppImageCache {
  AppImageCache._();

  static const String cacheKey = 'zplayImages';

  static final CacheManager manager = CacheManager(
    Config(
      cacheKey,
      maxNrOfCacheObjects: 800,
      stalePeriod: const Duration(days: 30),
    ),
  );
}