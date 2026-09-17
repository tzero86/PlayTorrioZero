import 'dart:convert';

/// Represents a CloudStream extension source (plugin).
class CloudStreamSource {
  final String id;
  final String name;
  String? internalName;
  final String? version;
  final String? versionLast;
  final String? lang;
  final bool isNsfw;
  final String? baseUrl;
  final String? iconUrl;
  final String? repo;
  final String? pluginUrl; // .cs3 URL
  final String? jarUrl;    // .jar URL (if provided)
  final String? description;
  List<String>? tvTypes;
  bool enabled;

  CloudStreamSource({
    required this.id,
    required this.name,
    this.internalName,
    this.version,
    this.versionLast,
    this.lang,
    this.isNsfw = false,
    this.baseUrl,
    this.iconUrl,
    this.repo,
    this.pluginUrl,
    this.jarUrl,
    this.description,
    this.tvTypes,
    this.enabled = true,
  });

  CloudStreamSource copyWith({
    String? id,
    String? name,
    String? internalName,
    String? version,
    String? versionLast,
    String? lang,
    bool? isNsfw,
    String? baseUrl,
    String? iconUrl,
    String? repo,
    String? pluginUrl,
    String? jarUrl,
    String? description,
    List<String>? tvTypes,
    bool? enabled,
  }) {
    return CloudStreamSource(
      id: id ?? this.id,
      name: name ?? this.name,
      internalName: internalName ?? this.internalName,
      version: version ?? this.version,
      versionLast: versionLast ?? this.versionLast,
      lang: lang ?? this.lang,
      isNsfw: isNsfw ?? this.isNsfw,
      baseUrl: baseUrl ?? this.baseUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      repo: repo ?? this.repo,
      pluginUrl: pluginUrl ?? this.pluginUrl,
      jarUrl: jarUrl ?? this.jarUrl,
      description: description ?? this.description,
      tvTypes: tvTypes ?? this.tvTypes,
      enabled: enabled ?? this.enabled,
    );
  }

  String get effectiveLanguage => (lang == null || lang!.trim().isEmpty) ? 'ALL' : lang!;

  /// Official CloudStream TvType tag checkers (zero name-based guessing)
  bool get hasDeclaredTvTypes => tvTypes != null && tvTypes!.isNotEmpty;

  bool get supportsAnime {
    if (!hasDeclaredTvTypes) return true;
    return tvTypes!.any((t) {
      final tl = t.toLowerCase();
      return tl.startsWith('anime') || tl == 'ova' || tl == 'all';
    });
  }

  bool get supportsCartoon {
    if (!hasDeclaredTvTypes) return true;
    return tvTypes!.any((t) {
      final tl = t.toLowerCase();
      return tl.startsWith('cartoon') || tl == 'all';
    });
  }

  bool get supportsMovie {
    if (!hasDeclaredTvTypes) return true;
    return tvTypes!.any((t) {
      final tl = t.toLowerCase();
      return tl.startsWith('movie') ||
          tl.startsWith('animemovie') ||
          tl == 'torrent' ||
          tl == 'others' ||
          tl == 'all';
    });
  }

  bool get supportsSeries {
    if (!hasDeclaredTvTypes) return true;
    return tvTypes!.any((t) {
      final tl = t.toLowerCase();
      return tl.contains('series') ||
          tl == 'tv' ||
          tl.startsWith('tv') ||
          tl.contains('tv') ||
          tl == 'asiandrama' ||
          tl == 'ova' ||
          tl == 'anime' ||
          tl.startsWith('anime') ||
          tl == 'torrent' ||
          tl == 'others' ||
          tl == 'all';
    });
  }

  bool get isLiveOnly {
    if (!hasDeclaredTvTypes) return false;
    return tvTypes!.every((t) {
      final tl = t.toLowerCase();
      return tl == 'live' || tl == 'livetv';
    });
  }

  bool get isAudioOnly {
    if (!hasDeclaredTvTypes) return false;
    return tvTypes!.every((t) {
      final tl = t.toLowerCase();
      return tl == 'audiobook' || tl == 'podcast' || tl == 'audio' || tl == 'music';
    });
  }

  bool get isAnimationOnly {
    if (!hasDeclaredTvTypes) return false;
    return tvTypes!.every((t) {
      final tl = t.toLowerCase();
      return tl.startsWith('anime') || tl.startsWith('cartoon') || tl == 'ova';
    });
  }

  bool get isAnimeOnly {
    if (!hasDeclaredTvTypes) return false;
    return tvTypes!.every((t) {
      final tl = t.toLowerCase();
      return tl.startsWith('anime') || tl == 'ova';
    });
  }

  bool get isCartoonOnly {
    if (!hasDeclaredTvTypes) return false;
    return tvTypes!.every((t) => t.toLowerCase().startsWith('cartoon'));
  }

  /// Determines whether this extension supports the given media request based strictly on
  /// declared [tvTypes] tags and content metadata ([mediaType], [genres]).
  bool supportsType(String mediaType, {List<String>? genres}) {
    // 1. Exclude non-video providers (Live TV and Audiobooks) from VOD video scraping
    if (isLiveOnly || isAudioOnly) return false;

    // Fallback if provider didn't declare tvTypes in manifest
    if (!hasDeclaredTvTypes) return true;

    final reqType = mediaType.toLowerCase();

    // 2. Dedicated Anime Tab request
    if (reqType == 'anime') {
      return supportsAnime;
    }

    final lowerGenres = genres?.map((g) => g.toLowerCase()).toSet() ?? {};
    final isReqAnime = lowerGenres.any((g) => g.contains('anime') || g.contains('japanese'));
    final isReqCartoon = lowerGenres.any((g) => g.contains('cartoon'));
    final isReqAnimated = isReqAnime || isReqCartoon || lowerGenres.any((g) => g.contains('animation'));

    // 3. Non-animated / Live-Action content (e.g. "Obsession", "Breaking Bad")
    if (!isReqAnimated) {
      // Animation-only providers must not run on live-action titles
      if (isAnimationOnly) return false;

      if (reqType == 'movie') {
        return supportsMovie;
      }
      if (reqType == 'series' || reqType == 'tv' || reqType == 'show') {
        return supportsSeries;
      }
      return supportsMovie || supportsSeries;
    }

    // 4. Anime content from Cinemeta (e.g. "Spirited Away", "Attack on Titan")
    if (isReqAnime) {
      // Cartoon-only providers must not run on anime
      if (isCartoonOnly) return false;
      if (supportsAnime) return true;
      if (reqType == 'movie') return supportsMovie;
      if (reqType == 'series' || reqType == 'tv' || reqType == 'show') return supportsSeries;
      return supportsMovie || supportsSeries;
    }

    // 5. Western animation / Cartoon (e.g. "Rick and Morty", "Shrek", "Toy Story")
    // Anime-only providers must not run on western cartoons
    if (isAnimeOnly) return false;
    if (supportsCartoon) return true;
    if (reqType == 'movie') return supportsMovie;
    if (reqType == 'series' || reqType == 'tv' || reqType == 'show') return supportsSeries;
    return supportsMovie || supportsSeries;
  }

  factory CloudStreamSource.fromJson(Map<String, dynamic> json) {
    return CloudStreamSource(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Plugin',
      internalName: json['internalName']?.toString() ?? json['name']?.toString(),
      version: json['version']?.toString() ?? '1.0.0',
      versionLast: json['versionLast']?.toString(),
      lang: json['lang']?.toString() ?? json['language']?.toString() ?? 'ALL',
      isNsfw: json['isNsfw'] == true || json['status'] == 'NSFW',
      baseUrl: json['baseUrl']?.toString(),
      iconUrl: json['iconUrl']?.toString() ??
          'https://raw.githubusercontent.com/recloudstream/cloudstream/master/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      repo: json['repo']?.toString(),
      pluginUrl: json['url']?.toString() ?? json['pluginUrl']?.toString(),
      jarUrl: json['jarUrl']?.toString(),
      description: json['description']?.toString(),
      tvTypes: (json['tvTypes'] as List?)
          ?.expand((e) => e.toString().split(','))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (internalName != null) 'internalName': internalName,
        if (version != null) 'version': version,
        if (versionLast != null) 'versionLast': versionLast,
        if (lang != null) 'lang': lang,
        'isNsfw': isNsfw,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (repo != null) 'repo': repo,
        if (pluginUrl != null) 'pluginUrl': pluginUrl,
        if (jarUrl != null) 'jarUrl': jarUrl,
        if (description != null) 'description': description,
        if (tvTypes != null) 'tvTypes': tvTypes,
        'enabled': enabled,
      };

  String encode() => jsonEncode(toJson());

  static CloudStreamSource decode(String str) =>
      CloudStreamSource.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
