import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_service.dart';

/// Enum representing the kind of active media / status
enum DiscordActivityKind {
  idle,
  movie,
  series,
  anime,
  liveTv,
  audiobook,
  book,
  manga,
  music,
}

/// Service managing Discord Rich Presence (RPC) across desktop platforms.
class DiscordRpcService {
  static final DiscordRpcService instance = DiscordRpcService._internal();
  DiscordRpcService._internal();

  static const String _prefKey = 'discord_rpc_enabled';
  static const String _defaultAssetKey = 'logo';

  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(true);

  DiscordRPC? _rpc;
  bool _isInitialized = false;
  final DateTime _sessionStartTime = DateTime.now();

  // Cache last active activity to restore when re-enabled
  DiscordPresence? _lastPresence;
  DiscordActivityKind _currentKind = DiscordActivityKind.idle;

  DiscordActivityKind get currentKind => _currentKind;

  /// Initialize Discord RPC connection and load user preference.
  Future<void> initialize() async {
    if (!DiscordRPC.isAvailable) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefKey) ?? true;
      isEnabled.value = enabled;

      if (enabled) {
        await _connect();
        await setIdle();
      }
    } catch (e) {
      debugPrint('[DiscordRPC] Initialization error: $e');
    }
  }

  /// Toggle Discord RPC on or off and persist preference.
  Future<void> setEnabled(bool enabled) async {
    if (!DiscordRPC.isAvailable) return;
    isEnabled.value = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);

      if (enabled) {
        await _connect();
        if (_lastPresence != null) {
          await _updatePresence(_lastPresence!);
        } else {
          await setIdle();
        }
      } else {
        await _disconnect();
      }
    } catch (e) {
      debugPrint('[DiscordRPC] setEnabled error: $e');
    }
  }

  Future<void> _connect() async {
    if (!DiscordRPC.isAvailable) return;
    if (_isInitialized && _rpc != null && _rpc!.isConnected) return;

    try {
      await _disposeRpc();
      final appId = EnvService.discordAppId;
      if (appId.isEmpty) return;

      final rpc = DiscordRPC();
      _rpc = rpc;
      await rpc.initialize(appId);
      _isInitialized = true;
      debugPrint('[DiscordRPC] Connected to Discord successfully.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[DiscordRPC] Failed to connect to Discord IPC: $e');
    }
  }

  Future<void> _disconnect() async {
    if (!DiscordRPC.isAvailable) return;
    try {
      if (_rpc != null) {
        try {
          await _rpc!.clearPresence();
        } catch (_) {}
        await _disposeRpc();
      }
    } catch (e) {
      debugPrint('[DiscordRPC] Disconnect error: $e');
    } finally {
      _isInitialized = false;
    }
  }

  Future<void> _disposeRpc() async {
    if (_rpc != null) {
      try {
        await _rpc!.dispose();
      } catch (_) {}
      _rpc = null;
    }
  }

  Future<void> _updatePresence(DiscordPresence presence) async {
    if (!DiscordRPC.isAvailable || !isEnabled.value) return;

    _lastPresence = presence;

    if (_rpc == null || !_isInitialized || !_rpc!.isConnected) {
      await _connect();
    }

    if (_rpc != null && _isInitialized) {
      try {
        await _rpc!.setPresence(presence);
      } catch (e) {
        debugPrint('[DiscordRPC] setPresence error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Status Helpers
  // ---------------------------------------------------------------------------

  /// Set Idle / Browsing status: "browsing ZPlay"
  Future<void> setIdle() async {
    _currentKind = DiscordActivityKind.idle;
    final presence = DiscordPresence(
      type: DiscordActivityType.playing,
      details: 'Browsing ZPlay',
      largeAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: DiscordTimestamps.started(_sessionStartTime),
    );
    await _updatePresence(presence);
  }

  /// Set Watching Movie status: "watching {movie name}"
  Future<void> setWatchingMovie({
    required String title,
    String? year,
    String? posterUrl,
    Duration? position,
    Duration? duration,
    bool isPaused = false,
  }) async {
    _currentKind = DiscordActivityKind.movie;
    final cleanTitle = title.trim();

    DiscordTimestamps? timestamps;
    if (!isPaused) {
      if (duration != null && duration > Duration.zero && position != null) {
        final remaining = duration - position;
        timestamps = DiscordTimestamps.ending(DateTime.now().add(remaining));
      } else if (position != null) {
        timestamps = DiscordTimestamps.started(DateTime.now().subtract(position));
      }
    }

    final hasValidPoster = posterUrl != null && posterUrl.trim().isNotEmpty && posterUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.watching,
      details: 'Watching $cleanTitle',
      state: isPaused
          ? 'Paused'
          : (year != null && year.trim().isNotEmpty ? '($year)' : 'In ZPlay'),
      largeAsset: hasValidPoster
          ? DiscordAsset.fromUrl(posterUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: timestamps,
    );

    await _updatePresence(presence);
  }

  /// Set Watching Show / Series status: "watching {show name}" + season/episode
  Future<void> setWatchingSeries({
    required String title,
    int? season,
    int? episode,
    String? episodeTitle,
    String? posterUrl,
    Duration? position,
    Duration? duration,
    bool isPaused = false,
  }) async {
    _currentKind = DiscordActivityKind.series;
    final cleanTitle = title.trim();

    String stateText;
    final s = season ?? 1;
    final e = episode ?? 1;
    if (episodeTitle != null && episodeTitle.trim().isNotEmpty) {
      stateText = 'S${s}E$e: ${episodeTitle.trim()}';
    } else {
      stateText = 'Season $s Episode $e';
    }
    if (isPaused) stateText = '$stateText (Paused)';

    DiscordTimestamps? timestamps;
    if (!isPaused) {
      if (duration != null && duration > Duration.zero && position != null) {
        final remaining = duration - position;
        timestamps = DiscordTimestamps.ending(DateTime.now().add(remaining));
      } else if (position != null) {
        timestamps = DiscordTimestamps.started(DateTime.now().subtract(position));
      }
    }

    final hasValidPoster = posterUrl != null && posterUrl.trim().isNotEmpty && posterUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.watching,
      details: 'Watching $cleanTitle',
      state: stateText,
      largeAsset: hasValidPoster
          ? DiscordAsset.fromUrl(posterUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: timestamps,
    );

    await _updatePresence(presence);
  }

  /// Set Watching Anime status (English & Arabic Anime): "watching {anime name}" and episode
  Future<void> setWatchingAnime({
    required String title,
    int? season,
    int? episode,
    String? episodeTitle,
    String? posterUrl,
    Duration? position,
    Duration? duration,
    bool isPaused = false,
  }) async {
    _currentKind = DiscordActivityKind.anime;
    final cleanTitle = title.trim();

    String stateText;
    if (episode != null) {
      if (season != null && season > 1) {
        stateText = 'Season $season Episode $episode';
      } else {
        stateText = 'Episode $episode';
      }
      if (episodeTitle != null && episodeTitle.trim().isNotEmpty) {
        stateText = '$stateText - ${episodeTitle.trim()}';
      }
    } else {
      stateText = 'Anime in ZPlay';
    }
    if (isPaused) stateText = '$stateText (Paused)';

    DiscordTimestamps? timestamps;
    if (!isPaused) {
      if (duration != null && duration > Duration.zero && position != null) {
        final remaining = duration - position;
        timestamps = DiscordTimestamps.ending(DateTime.now().add(remaining));
      } else if (position != null) {
        timestamps = DiscordTimestamps.started(DateTime.now().subtract(position));
      }
    }

    final hasValidPoster = posterUrl != null && posterUrl.trim().isNotEmpty && posterUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.watching,
      details: 'Watching $cleanTitle',
      state: stateText,
      largeAsset: hasValidPoster
          ? DiscordAsset.fromUrl(posterUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: timestamps,
    );

    await _updatePresence(presence);
  }

  /// Set Watching Live TV status: "watching live tv"
  Future<void> setWatchingLiveTv({
    String? channelName,
    String? logoUrl,
  }) async {
    _currentKind = DiscordActivityKind.liveTv;
    final stateText = (channelName != null && channelName.trim().isNotEmpty)
        ? channelName.trim()
        : 'Live Streams';

    final hasValidLogo = logoUrl != null && logoUrl.trim().isNotEmpty && logoUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.watching,
      details: 'Watching Live TV',
      state: stateText,
      largeAsset: hasValidLogo
          ? DiscordAsset.fromUrl(logoUrl.trim(), text: stateText)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: DiscordTimestamps.started(DateTime.now()),
    );

    await _updatePresence(presence);
  }

  /// Set Listening to Audiobook status: "listening to {book name}"
  Future<void> setListeningAudiobook({
    required String title,
    String? author,
    String? chapter,
    String? coverUrl,
    Duration? position,
    Duration? duration,
    bool isPaused = false,
  }) async {
    _currentKind = DiscordActivityKind.audiobook;
    final cleanTitle = title.trim();

    String stateText;
    if (author != null && author.trim().isNotEmpty) {
      stateText = 'by ${author.trim()}';
    } else if (chapter != null && chapter.trim().isNotEmpty) {
      stateText = chapter.trim();
    } else {
      stateText = 'Audiobook in ZPlay';
    }
    if (isPaused) stateText = '$stateText (Paused)';

    DiscordTimestamps? timestamps;
    if (!isPaused) {
      if (duration != null && duration > Duration.zero && position != null) {
        final remaining = duration - position;
        timestamps = DiscordTimestamps.ending(DateTime.now().add(remaining));
      } else if (position != null) {
        timestamps = DiscordTimestamps.started(DateTime.now().subtract(position));
      }
    }

    final hasValidCover = coverUrl != null && coverUrl.trim().isNotEmpty && coverUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.listening,
      details: 'Listening to "$cleanTitle"',
      state: stateText,
      largeAsset: hasValidCover
          ? DiscordAsset.fromUrl(coverUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: timestamps,
    );

    await _updatePresence(presence);
  }

  /// Set Reading Book status: "Reading {Book}"
  Future<void> setReadingBook({
    required String title,
    String? author,
    String? coverUrl,
    int? page,
    int? totalPages,
  }) async {
    _currentKind = DiscordActivityKind.book;
    final cleanTitle = title.trim();

    String stateText;
    if (page != null && totalPages != null && totalPages > 0) {
      stateText = 'Page $page of $totalPages';
      if (author != null && author.trim().isNotEmpty) {
        stateText = '$stateText • ${author.trim()}';
      }
    } else if (author != null && author.trim().isNotEmpty) {
      stateText = 'by ${author.trim()}';
    } else {
      stateText = 'eBook in ZPlay';
    }

    final hasValidCover = coverUrl != null && coverUrl.trim().isNotEmpty && coverUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.playing,
      details: 'Reading "$cleanTitle"',
      state: stateText,
      largeAsset: hasValidCover
          ? DiscordAsset.fromUrl(coverUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
    );

    await _updatePresence(presence);
  }

  /// Set Reading Manga status: "reading {manga name}"
  Future<void> setReadingManga({
    required String title,
    String? chapter,
    String? coverUrl,
  }) async {
    _currentKind = DiscordActivityKind.manga;
    final cleanTitle = title.trim();

    final stateText = (chapter != null && chapter.trim().isNotEmpty)
        ? (chapter.trim().toLowerCase().startsWith('chapter') ? chapter.trim() : 'Chapter ${chapter.trim()}')
        : 'Manga in ZPlay';

    final hasValidCover = coverUrl != null && coverUrl.trim().isNotEmpty && coverUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.playing,
      details: 'Reading "$cleanTitle"',
      state: stateText,
      largeAsset: hasValidCover
          ? DiscordAsset.fromUrl(coverUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
    );

    await _updatePresence(presence);
  }

  /// Set Listening Music status: "Listening {music name}"
  Future<void> setListeningMusic({
    required String title,
    required String artist,
    String? album,
    String? coverUrl,
    Duration? position,
    Duration? duration,
    bool isPlaying = true,
  }) async {
    _currentKind = DiscordActivityKind.music;
    final cleanTitle = title.trim();
    final cleanArtist = artist.trim();

    String stateText = cleanArtist.isNotEmpty ? 'by $cleanArtist' : 'Music in ZPlay';
    if (!isPlaying) stateText = '$stateText (Paused)';

    DiscordTimestamps? timestamps;
    if (isPlaying) {
      if (duration != null && duration > Duration.zero && position != null) {
        final remaining = duration - position;
        timestamps = DiscordTimestamps.ending(DateTime.now().add(remaining));
      } else if (position != null) {
        timestamps = DiscordTimestamps.started(DateTime.now().subtract(position));
      }
    }

    final hasValidCover = coverUrl != null && coverUrl.trim().isNotEmpty && coverUrl.startsWith('http');

    final presence = DiscordPresence(
      type: DiscordActivityType.listening,
      details: 'Listening "$cleanTitle"',
      state: stateText,
      largeAsset: hasValidCover
          ? DiscordAsset.fromUrl(coverUrl.trim(), text: cleanTitle)
          : const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      smallAsset: const DiscordAsset.fromKey(_defaultAssetKey, text: 'ZPlay'),
      timestamps: timestamps,
    );

    await _updatePresence(presence);
  }

  /// Return back to idle state if leaving a media player
  Future<void> clearToIdle() async {
    if (_currentKind != DiscordActivityKind.idle) {
      await setIdle();
    }
  }

  /// Clears presence completely
  Future<void> clearPresence() async {
    _lastPresence = null;
    _currentKind = DiscordActivityKind.idle;
    if (_rpc != null && _isInitialized) {
      try {
        await _rpc!.clearPresence();
      } catch (_) {}
    }
  }
}
