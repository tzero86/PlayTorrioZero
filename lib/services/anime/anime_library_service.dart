import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/anime/anime_media.dart';
import '../content/content_settings.dart';

class AnimeLibraryService extends ChangeNotifier {
  static final AnimeLibraryService instance = AnimeLibraryService._internal();
  AnimeLibraryService._internal() {
    ContentSettings.adultEnabled.addListener(notifyListeners);
  }

  static const String _watchlistKey = 'zplay_anime_watchlist_v1';
  static const String _historyKey = 'zplay_anime_history_v1';

  final List<AnimeWatchlistItem> _watchlist = [];
  final Map<int, AnimeWatchlistItem> _progressMap = {};

  bool _isInitialized = false;

  /// While the global Adult Content switch is off, adult entries are hidden from
  /// every list the library exposes. Nothing is removed from storage, so they
  /// come back as soon as the switch is turned on.
  bool _isVisible(AnimeWatchlistItem item) =>
      ContentSettings.adultEnabled.value || !item.anime.isAdult;

  List<AnimeWatchlistItem> get watchlist =>
      List.unmodifiable(_watchlist.where(_isVisible));
  List<AnimeWatchlistItem> get watchingList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.watching && _isVisible(item))
      .toList();
  List<AnimeWatchlistItem> get planToWatchList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.planToWatch && _isVisible(item))
      .toList();
  List<AnimeWatchlistItem> get completedList => _watchlist
      .where((item) => item.status == AnimeWatchStatus.completed && _isVisible(item))
      .toList();
  List<AnimeWatchlistItem> get recentHistory => List.unmodifiable(
        _progressMap.values.where(_isVisible).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

  /// Whether the library holds [title] as adult content, regardless of the
  /// switch state. Lets entries saved elsewhere (My List), which carry no
  /// maturity flag of their own, be classified without new persistence.
  bool isKnownAdultTitle(String title) {
    final key = _normalizedTitle(title);
    if (key.isEmpty) return false;
    bool isAdult(AnimeWatchlistItem entry) =>
        entry.anime.isAdult && _normalizedTitle(entry.anime.displayTitle) == key;
    return _watchlist.any(isAdult) || _progressMap.values.any(isAdult);
  }

  static String _normalizedTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final rawWatchlist = prefs.getStringList(_watchlistKey) ?? [];
      _watchlist.clear();
      for (final str in rawWatchlist) {
        try {
          final json = jsonDecode(str) as Map<String, dynamic>;
          _watchlist.add(AnimeWatchlistItem.fromJson(json));
        } catch (_) {}
      }

      final rawHistory = prefs.getStringList(_historyKey) ?? [];
      _progressMap.clear();
      for (final str in rawHistory) {
        try {
          final json = jsonDecode(str) as Map<String, dynamic>;
          final item = AnimeWatchlistItem.fromJson(json);
          _progressMap[item.anime.id] = item;
        } catch (_) {}
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AnimeLibraryService init error: $e');
    }
  }

  bool isAnimeInWatchlist(int anilistId) {
    return _watchlist.any((i) => i.anime.id == anilistId);
  }

  AnimeWatchlistItem? getWatchlistItem(int anilistId) {
    try {
      return _watchlist.firstWhere((i) => i.anime.id == anilistId);
    } catch (_) {
      return null;
    }
  }

  AnimeWatchlistItem? getProgress(int anilistId) {
    return _progressMap[anilistId];
  }

  Future<void> setWatchlistStatus(
    AnimeMedia anime,
    AnimeWatchStatus status,
  ) async {
    final idx = _watchlist.indexWhere((i) => i.anime.id == anime.id);
    final currentProgress = _progressMap[anime.id];

    final newItem = AnimeWatchlistItem(
      anime: anime,
      status: status,
      lastWatchedEpisode: currentProgress?.lastWatchedEpisode ?? 0,
      lastWatchedPositionSeconds:
          currentProgress?.lastWatchedPositionSeconds ?? 0,
      totalDurationSeconds: currentProgress?.totalDurationSeconds ?? 0,
      updatedAt: DateTime.now(),
    );

    if (idx >= 0) {
      _watchlist[idx] = newItem;
    } else {
      _watchlist.insert(0, newItem);
    }

    notifyListeners();
    await _saveWatchlist();
  }

  Future<void> removeFromWatchlist(int anilistId) async {
    _watchlist.removeWhere((i) => i.anime.id == anilistId);
    notifyListeners();
    await _saveWatchlist();
  }

  Future<void> updateProgress({
    required AnimeMedia anime,
    required int episodeNumber,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final status = _watchlist
            .firstWhere(
              (i) => i.anime.id == anime.id,
              orElse: () => AnimeWatchlistItem(
                anime: anime,
                status: AnimeWatchStatus.watching,
                updatedAt: DateTime.now(),
              ),
            )
            .status;

    final item = AnimeWatchlistItem(
      anime: anime,
      status: status,
      lastWatchedEpisode: episodeNumber,
      lastWatchedPositionSeconds: positionSeconds,
      totalDurationSeconds: durationSeconds,
      updatedAt: DateTime.now(),
    );

    _progressMap[anime.id] = item;

    // Update watchlist item if present
    final wlIdx = _watchlist.indexWhere((i) => i.anime.id == anime.id);
    if (wlIdx >= 0) {
      _watchlist[wlIdx] = item;
    }

    notifyListeners();
    await _saveHistory();
    if (wlIdx >= 0) {
      await _saveWatchlist();
    }
  }

  Future<void> _saveWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _watchlist.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_watchlistKey, list);
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          _progressMap.values.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_historyKey, list);
    } catch (_) {}
  }
}
