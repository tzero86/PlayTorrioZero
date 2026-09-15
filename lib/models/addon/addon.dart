/// Models for Stremio addon manifest parsing and storage.

class AddonManifest {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? logo;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<AddonCatalog> catalogs;

  /// Declared by the addon itself (`behaviorHints.adult`, legacy `adult`).
  /// Addons that serve NSFW catalogs are expected to set this.
  final bool isAdult;

  AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.logo,
    required this.resources,
    required this.types,
    required this.idPrefixes,
    required this.catalogs,
    this.isAdult = false,
  });

  bool get supportsMeta => resources.contains('meta');
  bool get supportsCatalog => resources.contains('catalog');
  bool get supportsStream => resources.contains('stream');
  bool get supportsSubtitles => resources.contains('subtitles');

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final prefixes = _parseStringList(json['idPrefixes']);
    if (json['resources'] is List) {
      for (final r in json['resources']) {
        if (r is Map && r['idPrefixes'] != null) {
          final resPrefixes = _parseStringList(r['idPrefixes']);
          for (final p in resPrefixes) {
            if (!prefixes.contains(p)) {
              prefixes.add(p);
            }
          }
        }
      }
    }

    return AddonManifest(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Addon',
      version: json['version']?.toString() ?? '0.0.0',
      description: json['description']?.toString(),
      logo: json['logo']?.toString(),
      resources: _parseResourceList(json['resources']),
      types: _parseStringList(json['types']),
      idPrefixes: prefixes,
      catalogs: (json['catalogs'] as List<dynamic>?)
              ?.map((e) => AddonCatalog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isAdult: _parseAdultFlag(json),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
        'resources': resources,
        'types': types,
        'idPrefixes': idPrefixes,
        'catalogs': catalogs.map((c) => c.toJson()).toList(),
        if (isAdult) 'behaviorHints': {'adult': true},
      };
}

/// Represents a single extra parameter definition in a Stremio catalog manifest.
class CatalogExtra {
  final String name;
  final bool isRequired;
  final List<String> options;
  final int? optionsLimit;

  const CatalogExtra({
    required this.name,
    this.isRequired = false,
    this.options = const [],
    this.optionsLimit,
  });

  factory CatalogExtra.fromJson(dynamic json) {
    if (json is String) {
      return CatalogExtra(name: json);
    }
    if (json is Map) {
      return CatalogExtra(
        name: json['name']?.toString() ?? '',
        isRequired: json['isRequired'] == true,
        options: _parseStringList(json['options']),
        optionsLimit: json['optionsLimit'] is int
            ? json['optionsLimit'] as int
            : int.tryParse(json['optionsLimit']?.toString() ?? ''),
      );
    }
    return CatalogExtra(name: json?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isRequired': isRequired,
        'options': options,
        if (optionsLimit != null) 'optionsLimit': optionsLimit,
      };
}

class AddonCatalog {
  final String type;
  final String id;
  final String? name;
  final int? pageSize;
  final List<CatalogExtra> extra;

  AddonCatalog({
    required this.type,
    required this.id,
    this.name,
    this.pageSize,
    List<CatalogExtra>? extra,
    List<String>? genres,
    bool? supportsSearch,
    bool? supportsSkip,
  }) : extra = extra ?? [
          if (genres != null && genres.isNotEmpty)
            CatalogExtra(name: 'genre', options: genres),
          if (supportsSearch == true)
            const CatalogExtra(name: 'search'),
          if (supportsSkip == true)
            const CatalogExtra(name: 'skip'),
        ];

  /// Backward-compatible list of genres defined on this catalog.
  List<String> get genres =>
      extra.firstWhere((e) => e.name == 'genre', orElse: () => const CatalogExtra(name: 'genre')).options;

  /// Whether this catalog represents a collection of movies/franchise sagas.
  bool get isCollection => type == 'collections' || type == 'collection';

  /// Whether this catalog supports freeform search query.
  bool get supportsSearch => extra.any((e) => e.name == 'search');

  /// Whether this catalog supports pagination via skip.
  bool get supportsSkip => extra.any((e) => e.name == 'skip');

  /// Whether this catalog has any extra marked isRequired: true.
  bool get hasRequiredExtra => extra.any((e) => e.isRequired);

  /// Whether this catalog requires search to be provided.
  bool get isSearchRequired => extra.any((e) => e.name == 'search' && e.isRequired);

  /// Catalogs that can be safely loaded as a row on the Home page.
  /// Strictly requires that NO extra is marked with isRequired: true.
  bool get canAutoLoadOnHome => !hasRequiredExtra;

  /// All required extras for this catalog.
  List<CatalogExtra> get requiredExtras => extra.where((e) => e.isRequired).toList();

  /// All selectable extras (extras that have options, excluding skip and search).
  List<CatalogExtra> get selectableExtras =>
      extra.where((e) => e.name != 'skip' && e.name != 'search' && e.options.isNotEmpty).toList();

  /// Look up an extra by name.
  CatalogExtra? getExtra(String name) {
    try {
      return extra.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    final parsedExtras = <CatalogExtra>[];
    final seenExtraNames = <String>{};

    void addExtra(CatalogExtra e) {
      if (e.name.isEmpty) return;
      final existingIndex = parsedExtras.indexWhere((x) => x.name == e.name);
      if (existingIndex >= 0) {
        final existing = parsedExtras[existingIndex];
        parsedExtras[existingIndex] = CatalogExtra(
          name: existing.name,
          isRequired: existing.isRequired || e.isRequired,
          options: existing.options.isNotEmpty ? existing.options : e.options,
          optionsLimit: existing.optionsLimit ?? e.optionsLimit,
        );
      } else {
        parsedExtras.add(e);
        seenExtraNames.add(e.name);
      }
    }

    // 1. Parse both 'extra' and legacy 'extraSupported'
    for (final key in ['extra', 'extraSupported']) {
      if (json[key] is List) {
        for (final item in json[key] as List) {
          addExtra(CatalogExtra.fromJson(item));
        }
      }
    }

    // 2. Backward compatibility: legacy 'genres' field fallback
    if (json['genres'] is List) {
      final legacyGenres = _parseStringList(json['genres']);
      if (legacyGenres.isNotEmpty) {
        final idx = parsedExtras.indexWhere((x) => x.name.toLowerCase() == 'genre');
        if (idx >= 0) {
          final existing = parsedExtras[idx];
          if (existing.options.isEmpty) {
            parsedExtras[idx] = CatalogExtra(
              name: existing.name,
              isRequired: existing.isRequired,
              options: legacyGenres,
              optionsLimit: existing.optionsLimit,
            );
          }
        } else {
          addExtra(CatalogExtra(
            name: 'genre',
            options: legacyGenres,
          ));
        }
      }
    }

    // 3. Backward compatibility: legacy 'extraRequired' list of strings
    if (json['extraRequired'] is List) {
      for (final item in json['extraRequired'] as List) {
        final name = item.toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          final idx = parsedExtras.indexWhere((x) => x.name.toLowerCase() == name);
          if (idx >= 0) {
            final existing = parsedExtras[idx];
            parsedExtras[idx] = CatalogExtra(
              name: existing.name,
              isRequired: true,
              options: existing.options,
              optionsLimit: existing.optionsLimit,
            );
          } else {
            addExtra(CatalogExtra(name: name, isRequired: true));
          }
        }
      }
    }

    // 4. Backward compatibility: legacy 'supportsSearch' boolean
    if (!seenExtraNames.contains('search') && json['supportsSearch'] == true) {
      addExtra(const CatalogExtra(name: 'search'));
    }

    // 5. Backward compatibility: legacy 'supportsSkip' boolean
    if (!seenExtraNames.contains('skip') && json['supportsSkip'] == true) {
      addExtra(const CatalogExtra(name: 'skip'));
    }

    return AddonCatalog(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      pageSize: json['pageSize'] is int
          ? json['pageSize'] as int
          : int.tryParse(json['pageSize']?.toString() ?? ''),
      extra: parsedExtras,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (name != null) 'name': name,
        if (pageSize != null) 'pageSize': pageSize,
        'extra': extra.map((e) => e.toJson()).toList(),
        // Keep legacy fields for backward compatibility
        'genres': genres,
        'supportsSearch': supportsSearch,
        'supportsSkip': supportsSkip,
      };
}

/// How much adult material an addon serves.
///
/// [sfw] — nothing adult; always active.
/// [hybrid] — serves both; always active, and its catalogs are discoverable
/// under the `18+` view. Item-level adult entries are dropped from it while the
/// global switch is off, wherever the source exposes a maturity flag (anime,
/// manga); live-action catalogs carry no such flag, so they pass through.
/// [nsfw] — adult only; inactive unless the global switch is on.
enum AddonAdultRating {
  sfw('sfw'),
  hybrid('hybrid'),
  nsfw('nsfw');

  final String key;
  const AddonAdultRating(this.key);

  static AddonAdultRating fromKey(Object? value) {
    final raw = value?.toString().toLowerCase();
    return AddonAdultRating.values.firstWhere(
      (r) => r.key == raw,
      orElse: () => AddonAdultRating.sfw,
    );
  }
}

/// An addon that has been installed by the user.
class InstalledAddon {
  final String baseUrl;
  final AddonManifest manifest;
  bool enabled;
  bool enableCatalogs;
  bool enableSearch;
  bool enableSubtitles;
  bool enableStreams;

  /// User-declared adult rating. Defaults to [AddonAdultRating.sfw]; addons
  /// that declare `behaviorHints.adult` are treated as [AddonAdultRating.nsfw]
  /// regardless.
  AddonAdultRating adultRating;

  InstalledAddon({
    required this.baseUrl,
    required this.manifest,
    this.enabled = true,
    this.enableCatalogs = true,
    this.enableSearch = true,
    this.enableSubtitles = true,
    this.enableStreams = true,
    this.adultRating = AddonAdultRating.sfw,
  });

  /// True when every bit of this addon's content is adult, so it must stay
  /// hidden unless the global Adult Content switch is on.
  bool get isNsfwOnly =>
      adultRating == AddonAdultRating.nsfw || manifest.isAdult;

  /// True when the addon may serve adult content, so its catalogs belong in the
  /// Discover `18+` view. Hybrid addons stay visible with the switch off.
  bool get isAdultCapable =>
      adultRating != AddonAdultRating.sfw || manifest.isAdult;

  bool get isCatalogsActive =>
      enabled && enableCatalogs && (manifest.supportsCatalog || manifest.catalogs.isNotEmpty);

  bool get isSearchActive =>
      enabled && enableSearch && (manifest.catalogs.any((c) => c.supportsSearch) || manifest.supportsCatalog);

  bool get isSubtitlesActive =>
      enabled && enableSubtitles && manifest.supportsSubtitles;

  bool get isStreamsActive =>
      enabled && enableStreams && manifest.supportsStream;

  factory InstalledAddon.fromJson(Map<String, dynamic> json) {
    return InstalledAddon(
      baseUrl: json['baseUrl']?.toString() ?? '',
      manifest:
          AddonManifest.fromJson(json['manifest'] as Map<String, dynamic>),
      enabled: json['enabled'] as bool? ?? true,
      enableCatalogs: json['enableCatalogs'] as bool? ?? true,
      enableSearch: json['enableSearch'] as bool? ?? true,
      enableSubtitles: json['enableSubtitles'] as bool? ?? true,
      enableStreams: json['enableStreams'] as bool? ?? true,
      // Legacy boolean maps to a full NSFW mark.
      adultRating: json['adultRating'] != null
          ? AddonAdultRating.fromKey(json['adultRating'])
          : (json['adultMarked'] == true
                ? AddonAdultRating.nsfw
                : AddonAdultRating.sfw),
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'manifest': manifest.toJson(),
        'enabled': enabled,
        'enableCatalogs': enableCatalogs,
        'enableSearch': enableSearch,
        'enableSubtitles': enableSubtitles,
        'enableStreams': enableStreams,
        'adultRating': adultRating.key,
      };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return [];
}

/// Reads the Stremio adult declaration: `behaviorHints.adult`, or the legacy
/// top-level `adult` flag some addons still send.
bool _parseAdultFlag(Map<String, dynamic> json) {
  final hints = json['behaviorHints'];
  if (hints is Map && hints['adult'] == true) return true;
  return json['adult'] == true;
}

/// Parses the Stremio manifest `resources` field which can be either:
/// - A list of strings: `["catalog", "meta", "stream"]`
/// - A list of objects: `[{"name": "stream", "types": [...], "idPrefixes": [...]}]`
/// - A mix of both
/// Also recovers from previously stored broken toString dumps.
List<String> _parseResourceList(dynamic value) {
  if (value is! List) return [];
  
  return value.map<String>((e) {
    if (e is String) {
      // Check if this is a clean resource name
      if (!e.contains('{') && !e.contains(':')) return e;
      // Try to recover from broken toString dump like "{name: stream, types: [...]}"
      final match = RegExp(r'name:\s*(\w+)').firstMatch(e);
      if (match != null) return match.group(1)!;
      return '';
    }
    if (e is Map<String, dynamic>) return e['name']?.toString() ?? '';
    if (e is Map) return e['name']?.toString() ?? '';
    return e.toString();
  }).where((s) => s.isNotEmpty).toList();
}
