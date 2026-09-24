import '../../models/stream/stream_model.dart';

/// Represents an active media playback session saved for Continue Watching.
class ContinueWatchingItem {
  final String id; // Movie ID (e.g. tt1234567) or Show ID
  final String title;
  final String type; // 'movie' or 'series'
  final String? posterUrl;
  final String? backdropUrl;
  final String? year;

  // Episode metadata (for series)
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? episodeId; // e.g. tt1234567:1:5

  // Playback timing
  final int positionSeconds;
  final int totalDurationSeconds;
  final DateTime lastWatchedAt;

  // Source fingerprint & resume specs
  final String? addonName; // 'ZPlayHTTP', 'ZPlay', or external addon name
  final bool isTorrent;
  final String? magnetUrl;
  final String? infoHash;
  final int? fileIdx; // Crucial for multi-file torrents & series episodes
  final String? rawUrl;
  final String? streamName;
  final String? streamTitle;
  final String? streamDescription;
  final String? quality;
  final Map<String, String>? headers;

  /// Whether this session originates from adult content. Persisted so the
  /// global Adult Content switch can hide the card without re-classifying.
  final bool isAdult;

  const ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.type,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.season,
    this.episode,
    this.episodeTitle,
    this.episodeId,
    required this.positionSeconds,
    required this.totalDurationSeconds,
    required this.lastWatchedAt,
    this.addonName,
    required this.isTorrent,
    this.magnetUrl,
    this.infoHash,
    this.fileIdx,
    this.rawUrl,
    this.streamName,
    this.streamTitle,
    this.streamDescription,
    this.quality,
    this.headers,
    this.isAdult = false,
  });

  /// Fraction of content watched (0.0 to 1.0)
  double get progressPercent {
    if (totalDurationSeconds <= 0) return 0.0;
    return (positionSeconds / totalDurationSeconds).clamp(0.0, 1.0);
  }

  /// Whether the item is considered finished (>= 90% watched)
  bool get isCompleted => progressPercent >= 0.90;

  /// Remaining duration in minutes
  int get remainingMinutes {
    final remainingSec = totalDurationSeconds - positionSeconds;
    if (remainingSec <= 0) return 0;
    return (remainingSec / 60).ceil();
  }

  /// Score representing episode position (Season * 10000 + Episode)
  int get episodeIndex => ((season ?? 0) * 10000) + (episode ?? 0);

  /// Unique session key: mapped strictly to media ID (1 card per movie/show)
  String get sessionKey => id;

  /// Convert to StreamSource for direct player launch
  StreamSource toStreamSource() {
    return StreamSource(
      name: streamName ?? addonName ?? 'Stream',
      title: streamTitle ?? title,
      description: streamDescription,
      url: isTorrent ? (magnetUrl ?? rawUrl) : rawUrl,
      infoHash: infoHash,
      fileIdx: fileIdx,
      addonName: addonName ?? 'ZPlay',
      headers: headers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'year': year,
      'season': season,
      'episode': episode,
      'episodeTitle': episodeTitle,
      'episodeId': episodeId,
      'positionSeconds': positionSeconds,
      'totalDurationSeconds': totalDurationSeconds,
      'lastWatchedAt': lastWatchedAt.toIso8601String(),
      'addonName': addonName,
      'isTorrent': isTorrent,
      'magnetUrl': magnetUrl,
      'infoHash': infoHash,
      'fileIdx': fileIdx,
      'rawUrl': rawUrl,
      'streamName': streamName,
      'streamTitle': streamTitle,
      'streamDescription': streamDescription,
      'quality': quality,
      'headers': headers,
      'isAdult': isAdult,
    };
  }

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'movie',
      posterUrl: json['posterUrl']?.toString(),
      backdropUrl: json['backdropUrl']?.toString(),
      year: json['year']?.toString(),
      season: json['season'] is int ? json['season'] : int.tryParse(json['season']?.toString() ?? ''),
      episode: json['episode'] is int ? json['episode'] : int.tryParse(json['episode']?.toString() ?? ''),
      episodeTitle: json['episodeTitle']?.toString(),
      episodeId: json['episodeId']?.toString(),
      positionSeconds: json['positionSeconds'] is int ? json['positionSeconds'] : int.tryParse(json['positionSeconds']?.toString() ?? '') ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] is int ? json['totalDurationSeconds'] : int.tryParse(json['totalDurationSeconds']?.toString() ?? '') ?? 0,
      lastWatchedAt: json['lastWatchedAt'] != null ? (DateTime.tryParse(json['lastWatchedAt'].toString()) ?? DateTime.now()) : DateTime.now(),
      addonName: json['addonName']?.toString() ?? 'ZPlay',
      isTorrent: json['isTorrent'] == true,
      magnetUrl: json['magnetUrl']?.toString(),
      infoHash: json['infoHash']?.toString(),
      fileIdx: json['fileIdx'] is int ? json['fileIdx'] : int.tryParse(json['fileIdx']?.toString() ?? ''),
      rawUrl: json['rawUrl']?.toString(),
      streamName: json['streamName']?.toString(),
      streamTitle: json['streamTitle']?.toString(),
      streamDescription: json['streamDescription']?.toString(),
      quality: json['quality']?.toString(),
      headers: json['headers'] is Map ? Map<String, String>.from(json['headers']) : null,
      isAdult: json['isAdult'] == true,
    );
  }

  ContinueWatchingItem copyWith({
    int? positionSeconds,
    int? totalDurationSeconds,
    DateTime? lastWatchedAt,
    String? magnetUrl,
    String? rawUrl,
    int? fileIdx,
    String? streamDescription,
    bool? isAdult,
  }) {
    return ContinueWatchingItem(
      id: id,
      title: title,
      type: type,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      episodeId: episodeId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      addonName: addonName,
      isTorrent: isTorrent,
      magnetUrl: magnetUrl ?? this.magnetUrl,
      infoHash: infoHash,
      fileIdx: fileIdx ?? this.fileIdx,
      rawUrl: rawUrl ?? this.rawUrl,
      streamName: streamName,
      streamTitle: streamTitle,
      streamDescription: streamDescription ?? this.streamDescription,
      quality: quality,
      headers: headers,
      isAdult: isAdult ?? this.isAdult,
    );
  }
}
