import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:torrserver_flutter/torrserver_flutter.dart';

import '../../models/download/download_task_model.dart';
import '../download/download_service.dart';
import '../debrid/utils/debrid_media_matcher.dart';

/// Rich torrent statistics object.
class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final int totalPeers;
  final double cachePercent;
  final int loadedBytes;
  final int totalBytes;
  final String hash;
  final bool isConnected;

  const TorrentStats({
    required this.speedMbps,
    required this.activePeers,
    required this.totalPeers,
    required this.cachePercent,
    required this.loadedBytes,
    required this.totalBytes,
    required this.hash,
    required this.isConnected,
  });

  double get speedKbps => speedMbps * 1024;
  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(2)} MB/s'
      : '${speedKbps.toStringAsFixed(0)} KB/s';
  String get peersLabel => '$activePeers / $totalPeers';
  String get cacheLabel => '${cachePercent.toStringAsFixed(1)}%';
}

/// Engine lifecycle states.
enum EngineState { stopped, starting, ready, error }

/// Production-grade TorrentStreamService powered by torrserver_flutter.
///
/// Provides high performance HTTP streaming with automatic free-port allocation,
/// cross-platform subprocess / FFI management, intelligent file selection
/// (via ParseTorrentTitle), and real-time swarm statistics.
class TorrentStreamService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final TorrentStreamService _instance = TorrentStreamService._internal();
  factory TorrentStreamService() => _instance;
  TorrentStreamService._internal();

  // ── Controller & State ─────────────────────────────────────────────────────
  final TorrServerController _controller = createTorrServerController();
  TorrServerController get controller => _controller;

  EngineState _state = EngineState.stopped;
  EngineState get state => _state;

  void Function(EngineState state)? onStateChanged;
  void Function(String line)? onLogLine;

  /// Active torrent hashes tracked by the service.
  final Set<String> _activeTorrents = {};

  /// Latest torrent update snapshots keyed by infohash.
  final Map<String, TorrentInfo> _latestUpdates = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts the TorrServer engine using native defaults. Safe to call multiple times.
  Future<bool> start() async {
    if (_controller.isRunning && _state == EngineState.ready) return true;
    if (_state == EngineState.starting) {
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_controller.isRunning && _state == EngineState.ready) return true;
        if (_state == EngineState.error) return false;
      }
      return false;
    }

    _setState(EngineState.starting);
    try {
      _log('Starting TorrServer engine with native defaults...');
      await _controller.start();
      final version = await _controller.echo();
      _setState(EngineState.ready);
      _log('TorrServer ready at ${_controller.baseUrl} (version: $version, default engine settings)');
      return true;
    } catch (e, st) {
      _log('Failed to start TorrServer: $e\n$st');
      _setState(EngineState.error);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stream a torrent — main entry point
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a magnet, waits for metadata, selects the right file, starts an
  /// HTTP stream, and returns the stream URL.
  Future<String?> streamTorrent(
    String magnetLink, {
    int? season,
    int? episode,
    String? episodeTitle,
    int? fileIdx,
  }) async {
    if (!_controller.isRunning || _state != EngineState.ready) {
      final started = await start();
      if (!started) {
        _log('Cannot stream: TorrServer engine failed to start.');
        return null;
      }
    }

    final rawHash = _extractHash(magnetLink);
    final formattedMagnet = (rawHash != null && !magnetLink.startsWith('magnet:?'))
        ? 'magnet:?xt=urn:btih:$rawHash'
        : magnetLink;

    final displayName = _extractDisplayName(formattedMagnet);

    try {
      _log('Adding torrent to TorrServer...');
      final added = await _controller.addTorrent(
        magnet: formattedMagnet,
        title: displayName.isNotEmpty ? displayName : null,
        saveToDb: false,
      );

      final hash = added.hash.isNotEmpty
          ? added.hash.toLowerCase()
          : (rawHash ?? '').toLowerCase();

      if (hash.isNotEmpty) {
        _activeTorrents.add(hash);
        _latestUpdates[hash] = added;
      }

      _log('Torrent added: $hash ($displayName). Waiting for metadata...');

      // Wait for torrent metadata / file list
      final files = await _waitForMetadata(hash);
      if (files == null || files.isEmpty) {
        _log('No files found in torrent metadata');
        return null;
      }

      // Auto file picker
      final selectedFileId = _selectFile(
        files,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
        preferredIdx: fileIdx,
      );

      if (selectedFileId == null) {
        _log('No suitable media file found in torrent');
        return null;
      }

      final selectedFile = files.firstWhere(
        (f) => f.id == selectedFileId,
        orElse: () => files.first,
      );
      _log('Selected file #${selectedFile.id}: "${selectedFile.path}" (${_formatBytes(selectedFile.length)})');

      final streamUri = _controller.streamUrl(hash, fileIndex: selectedFile.id);
      _log('HTTP Stream URL generated: $streamUri');

      return streamUri.toString();
    } catch (e, st) {
      _log('streamTorrent error: $e\n$st');
      return null;
    }
  }

  /// Adds a magnet, waits for metadata, and returns full TorrentInfo including all files.
  Future<TorrentInfo?> getTorrentMetadata(String magnetLink) async {
    try {
      final started = await start();
      if (!started) return null;

      final rawHash = _extractHash(magnetLink);
      if (rawHash == null) {
        _log('Invalid magnet link / hash: $magnetLink');
        return null;
      }
      final hash = rawHash.toLowerCase();

      final formattedMagnet = !magnetLink.startsWith('magnet:?')
          ? 'magnet:?xt=urn:btih:$rawHash'
          : magnetLink;

      final title = _extractDisplayName(formattedMagnet);
      _log('Adding torrent for file list inspection: $hash ($title)');
      await _controller.addTorrent(
        magnet: formattedMagnet,
        title: title.isNotEmpty ? title : null,
        saveToDb: false,
      );
      _activeTorrents.add(hash);

      final files = await _waitForMetadata(hash);
      if (files == null || files.isEmpty) return null;

      return await _controller.getTorrent(hash);
    } catch (e, st) {
      _log('getTorrentMetadata error: $e\n$st');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata polling
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<TorrentFileStat>?> _waitForMetadata(
    String hash, {
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(milliseconds: 300),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final info = await _controller.getTorrent(hash);
        _latestUpdates[hash] = info;
        if (info.fileStats.isNotEmpty) {
          return info.fileStats;
        }
      } catch (e) {
        _log('Polling metadata error: $e');
      }
      await Future.delayed(pollInterval);
    }

    _log('Metadata timeout after ${timeout.inSeconds}s for hash $hash');
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // File selection — intelligent auto file picker
  // ─────────────────────────────────────────────────────────────────────────
  // File selection — intelligent auto file picker
  // ─────────────────────────────────────────────────────────────────────────

  int? _selectFile(
    List<TorrentFileStat> files, {
    int? season,
    int? episode,
    String? episodeTitle,
    int? preferredIdx,
  }) {
    if (files.isEmpty) return null;

    final picked = DebridMediaMatcher.pickMediaFile<TorrentFileStat>(
      files,
      fileIndex: preferredIdx,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      name: (f) => f.path,
      size: (f) => f.length,
    );

    return picked?.id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Torrent management & Statistics
  // ─────────────────────────────────────────────────────────────────────────

  /// Removes a torrent from TorrServer.
  Future<void> removeTorrent(String magnetOrHash) async {
    final hash = _extractHash(magnetOrHash) ?? magnetOrHash.toLowerCase();
    _activeTorrents.remove(hash);
    _latestUpdates.remove(hash);
    if (_controller.isRunning) {
      try {
        await _controller.removeTorrent(hash);
        _log('Removed torrent $hash from TorrServer');
      } catch (e) {
        _log('Error removing torrent $hash: $e');
      }
    }
  }

  /// Returns latest cached or live stats for a torrent.
  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash) ?? magnetOrHash.toLowerCase();
    final info = _latestUpdates[hash];
    if (info == null) return null;

    final speedMbps = info.downloadSpeed / 1024 / 1024;
    final total = info.torrentSize;
    final loaded = info.loadedSize;
    final percent = total > 0 ? (loaded / total) * 100 : 0.0;

    return TorrentStats(
      speedMbps: speedMbps,
      activePeers: info.activePeers,
      totalPeers: info.totalPeers,
      cachePercent: percent,
      loadedBytes: loaded,
      totalBytes: total,
      hash: hash,
      isConnected: info.activePeers > 0 || info.downloadSpeed > 0,
    );
  }

  /// Streams stats at [interval] for a torrent.
  Stream<TorrentStats> statsStream(
    String magnetOrHash, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final hash = _extractHash(magnetOrHash) ?? magnetOrHash.toLowerCase();
    final streamController = StreamController<TorrentStats>();
    Timer? timer;

    streamController.onListen = () {
      timer = Timer.periodic(interval, (_) async {
        if (!_controller.isRunning || streamController.isClosed) return;
        try {
          final info = await _controller.getTorrent(hash);
          _latestUpdates[hash] = info;
          final stats = getTorrentStats(hash);
          if (stats != null && !streamController.isClosed) {
            streamController.add(stats);
          }
        } catch (_) {}
      });
    };

    streamController.onCancel = () {
      timer?.cancel();
      streamController.close();
    };

    return streamController.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stop / cleanup
  // ─────────────────────────────────────────────────────────────────────────

  /// Drops active torrents from RAM to free resources when closing player.
  Future<void> cleanup() async {
    final downloadingHashes = <String>{};
    for (final task in DownloadService.instance.tasksNotifier.value) {
      if (task.isDownloading || task.status == DownloadStatus.queued) {
        final h1 = task.infoHash != null ? _extractHash(task.infoHash!) : null;
        final h2 = task.magnet != null ? _extractHash(task.magnet!) : null;
        final h3 = task.rawUrl != null ? _extractHash(task.rawUrl!) : null;
        if (h1 != null) downloadingHashes.add(h1);
        if (h2 != null) downloadingHashes.add(h2);
        if (h3 != null) downloadingHashes.add(h3);
      }
    }

    for (final hash in List<String>.from(_activeTorrents)) {
      if (downloadingHashes.contains(hash.toLowerCase())) {
        continue;
      }
      try {
        if (_controller.isRunning) {
          await _controller.dropTorrent(hash);
        }
      } catch (_) {}
    }
    _activeTorrents.removeWhere((h) => !downloadingHashes.contains(h.toLowerCase()));
    _latestUpdates.removeWhere((k, _) => !downloadingHashes.contains(k.toLowerCase()));
  }

  /// Completely stops the TorrServer engine process.
  Future<void> stop() async {
    if (_controller.isRunning) {
      try {
        await _controller.stop();
        _log('TorrServer stopped.');
      } catch (e) {
        _log('Error stopping TorrServer: $e');
      }
    }
    _activeTorrents.clear();
    _latestUpdates.clear();
    _setState(EngineState.stopped);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static final _hashRegExp = RegExp(r'[0-9a-fA-F]{40}');

  String? _extractHash(String magnetOrHash) {
    final match = _hashRegExp.firstMatch(magnetOrHash);
    return match?.group(0)?.toLowerCase();
  }

  String _extractDisplayName(String magnet) {
    try {
      final match = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnet);
      if (match != null && match.group(1) != null) {
        return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
      }
    } catch (_) {}
    return '';
  }

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }

  void _setState(EngineState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
  }

  void _log(String message) {
    debugPrint('[TorrentStream] $message');
    onLogLine?.call(message);
  }
}