import 'dart:io';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:playtorrio/models/subtitle/subtitle_model.dart';
import './providers/subdl_provider.dart';
import './providers/subtitlecat_provider.dart';
import './providers/wyzie_provider.dart';
import './providers/opensubtitles_provider.dart';
import './providers/stremio_subtitle_provider.dart';
import './subtitle_provider.dart';
import './subtitle_extractor.dart';

class SubtitleService {
  static final SubtitleService _instance = SubtitleService._internal();
  factory SubtitleService() => _instance;
  SubtitleService._internal();

  final List<SubtitleProvider> _providers = [
    WyzieProvider(),
    SubtitleCatProvider(),
    OpenSubtitlesProvider(),
    SubdlProvider(),
    StremioSubtitleProvider(),
  ];

  /// Streams subtitle batches progressively as each provider finishes.
  Stream<List<SubtitleVariant>> streamSubtitles(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) {
    final controller = StreamController<List<SubtitleVariant>>();
    int pending = _providers.length;

    for (final p in _providers) {
      p.search(
        movieName,
        imdbId: imdbId,
        season: season,
        episode: episode,
        year: year,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[SubtitleService] ${p.name} search timed out (5s)');
        return <SubtitleVariant>[];
      }).then((variants) {
        if (variants.isNotEmpty && !controller.isClosed) {
          controller.add(variants);
        }
      }).catchError((e) {
        debugPrint('[SubtitleService] ${p.name} search error: $e');
      }).whenComplete(() {
        pending--;
        if (pending <= 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    return controller.stream;
  }

  /// Groups variants by language and deduplicates identical download URLs.
  static List<SubtitleLanguageGroup> groupVariantsByLanguage(List<SubtitleVariant> variants) {
    if (variants.isEmpty) return [];
    final Map<String, List<SubtitleVariant>> grouped = {};
    final Set<String> seenUrls = {};
    for (final variant in variants) {
      if (!seenUrls.add(variant.downloadUrl.toLowerCase())) continue;
      grouped.putIfAbsent(variant.language, () => []).add(variant);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    return sortedKeys.map((lang) => SubtitleLanguageGroup(language: lang, variants: grouped[lang]!)).toList();
  }

  /// Fetches subtitles from all registered providers concurrently.
  /// Groups the results by language.
  Future<List<SubtitleLanguageGroup>> fetchAllSubtitles(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) async {
    final allVariants = <SubtitleVariant>[];
    await for (final batch in streamSubtitles(
      movieName,
      imdbId: imdbId,
      season: season,
      episode: episode,
      year: year,
    )) {
      allVariants.addAll(batch);
    }
    return groupVariantsByLanguage(allVariants);
  }

  /// Downloads and extracts the specific subtitle variant.
  Future<String?> downloadSubtitle(SubtitleVariant variant) async {
    // Extract any custom headers / referer provided by CloudStream or direct stream
    Map<String, String>? customHeaders;
    if (variant.extraData['headers'] is Map) {
      customHeaders = (variant.extraData['headers'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    final referer = variant.extraData['referer']?.toString();
    if (referer != null && referer.isNotEmpty) {
      customHeaders ??= {};
      customHeaders.putIfAbsent('Referer', () => referer.endsWith('/') ? referer : '$referer/');
    }

    // Check if it's one of the dedicated online subtitle search providers
    for (final provider in _providers) {
      if (provider is! StremioSubtitleProvider && provider.name == variant.providerName) {
        return provider.download(variant);
      }
    }

    // Direct / CloudStream / Stremio subtitle download
    return SubtitleExtractor.downloadAndExtract(
      variant.downloadUrl,
      headers: customHeaders,
      providerName: variant.providerName,
    );
  }

  /// Best-effort delete of a downloaded subtitle temp file (including synced
  /// copies). Called by the player slice on switch/dispose; never throws.
  Future<void> deleteSubtitleFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
