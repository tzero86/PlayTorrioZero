import '../../models/stream/stream_model.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

enum DownloadSourceType {
  p2p,
  debrid,
  http,
}

class DownloadTask {
  final String id;
  final String title;
  final String mediaId;
  final String type; // 'movie', 'series', 'anime'
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? year;

  // Source details
  final DownloadSourceType sourceType;
  final String sourceName;
  final String? addonName;
  final String? rawUrl;
  final String? magnet;
  final String? infoHash;
  final int? fileIdx;
  final Map<String, String>? headers;

  // Filesystem target
  final String targetFilePath;

  // Progress metrics
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final int? etaSeconds;
  final int peers;
  final String? error;

  // Timestamps
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.mediaId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    required this.sourceType,
    required this.sourceName,
    this.addonName,
    this.rawUrl,
    this.magnet,
    this.infoHash,
    this.fileIdx,
    this.headers,
    required this.targetFilePath,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.etaSeconds,
    this.peers = 0,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  double get progressPercent {
    if (totalBytes <= 0) return 0.0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;

  String get speedLabel {
    if (speedBytesPerSec <= 0) return '0 KB/s';
    final mbps = speedBytesPerSec / 1024 / 1024;
    return mbps >= 1.0
        ? '${mbps.toStringAsFixed(2)} MB/s'
        : '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  String get etaLabel {
    if (etaSeconds == null || etaSeconds! <= 0) return '--';
    if (etaSeconds! < 60) return '${etaSeconds}s';
    final mins = (etaSeconds! / 60).floor();
    final secs = etaSeconds! % 60;
    if (mins < 60) return '${mins}m ${secs}s';
    final hours = (mins / 60).floor();
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }

  String get sizeLabel {
    return '${formatBytes(receivedBytes)} / ${formatBytes(totalBytes)}';
  }

  static String formatBytes(int bytes) {
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

  StreamSource toLocalStreamSource() {
    return StreamSource(
      name: 'Downloaded',
      title: title,
      url: targetFilePath,
      addonName: 'ZPlay Offline',
    );
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    int? etaSeconds,
    int? peers,
    String? error,
    DateTime? completedAt,
    String? targetFilePath,
    String? rawUrl,
    String? infoHash,
    String? magnet,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      mediaId: mediaId,
      type: type,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      sourceType: sourceType,
      sourceName: sourceName,
      addonName: addonName,
      rawUrl: rawUrl ?? this.rawUrl,
      magnet: magnet ?? this.magnet,
      infoHash: infoHash ?? this.infoHash,
      fileIdx: fileIdx,
      headers: headers,
      targetFilePath: targetFilePath ?? this.targetFilePath,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      peers: peers ?? this.peers,
      error: error ?? this.error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaId': mediaId,
      'type': type,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'year': year,
      'sourceType': sourceType.name,
      'sourceName': sourceName,
      'addonName': addonName,
      'rawUrl': rawUrl,
      'magnet': magnet,
      'infoHash': infoHash,
      'fileIdx': fileIdx,
      'headers': headers,
      'targetFilePath': targetFilePath,
      'status': status.name,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'error': error,
    };
  }

  /// Pre-rebrand provider sentinels still present in records persisted before
  /// the ZPlay rename. Map them to the current canonical values on read so
  /// existing users keep their resume/watchlist association.
  static String _canonicalAddonName(String? raw) {
    switch (raw) {
      case 'PlayTorrioHTTP':
        return 'ZPlayHTTP';
      case 'PlayTorrio':
        return 'ZPlay';
      case 'PlayTorrio Offline':
        return 'ZPlay Offline';
      default:
        return raw ?? 'ZPlay';
    }
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      mediaId: json['mediaId'] as String? ?? '',
      type: json['type'] as String? ?? 'movie',
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      year: json['year'] as String?,
      sourceType: DownloadSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => DownloadSourceType.http,
      ),
      sourceName: json['sourceName'] as String? ?? 'Stream',
      addonName: json['addonName'] == null ? null : _canonicalAddonName(json['addonName'] as String?),
      rawUrl: json['rawUrl'] as String?,
      magnet: json['magnet'] as String?,
      infoHash: json['infoHash'] as String?,
      fileIdx: json['fileIdx'] as int?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      targetFilePath: json['targetFilePath'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int)
          : null,
      error: json['error'] as String?,
    );
  }
}
