import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global 18+ content switch.
///
/// Single source of truth for whether adult material may surface anywhere in
/// the app: catalog fetches, addon catalogs/search/streams, the WatchHentai /
/// Hentaini extractors, and saved state (Continue Watching, My List, library).
/// Sources read [adultEnabled] at query time, so flipping the switch only
/// affects the next fetch/rebuild — nothing is retroactively cached.
abstract final class ContentSettings {
  static const _keyAdultEnabled = 'content_adult_enabled';

  /// Off by default: the app never surfaces NSFW content unless asked to.
  static final ValueNotifier<bool> adultEnabled = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      adultEnabled.value = prefs.getBool(_keyAdultEnabled) ?? false;
    } catch (e) {
      debugPrint('[ContentSettings] Error initializing: $e');
    }
  }

  static Future<void> setAdultEnabled(bool value) async {
    adultEnabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAdultEnabled, value);
    } catch (e) {
      debugPrint('[ContentSettings] Error saving adult content state: $e');
    }
  }
}
