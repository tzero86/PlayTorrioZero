import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/anime/anime_media.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';
import '../../models/stream/stream_model.dart';
import '../content/content_settings.dart';
import 'extractors/anidb_extractor.dart';
import 'extractors/megaplay_extractor.dart';
import 'extractors/recloud_extractor.dart';
import 'extractors/tryembed_extractor.dart';
import 'extractors/watchhentai_extractor.dart';
import 'extractors/hentaini_extractor.dart';
import 'extractors/dulo_extractor.dart';
import 'extractors/luna_extractor.dart';
import 'extractors/anineko_extractor.dart';
import 'extractors/one_two_three_anime_extractor.dart';
import 'extractors/anihq_extractor.dart';
import 'extractors/anipm_extractor.dart';
import 'extractors/vidnest_extractor.dart';
import '../cloudstream/cloudstream_manager.dart';

class AnimeScraperService {
  static final AnimeScraperService instance = AnimeScraperService._internal();
  AnimeScraperService._internal();

  final MegaPlayExtractor _megaPlay = MegaPlayExtractor.instance;
  final ReCloudExtractor _reCloud = ReCloudExtractor.instance;
  final TryEmbedExtractor _tryEmbed = TryEmbedExtractor.instance;
  final AniDbExtractor _aniDb = AniDbExtractor.instance;
  final DuloExtractor _dulo = DuloExtractor.instance;
  final LunaExtractor _luna = LunaExtractor.instance;
  final AniNekoExtractor _aniNeko = AniNekoExtractor.instance;
  final OneTwoThreeAnimeExtractor _oneTwoThreeAnime = OneTwoThreeAnimeExtractor.instance;
  final AniHQExtractor _aniHQ = AniHQExtractor.instance;
  final AniPMExtractor _aniPM = AniPMExtractor.instance;
  final VidNestExtractor _vidNest = VidNestExtractor.instance;
  final WatchHentaiExtractor _watchHentai = WatchHentaiExtractor();
  final HentainiExtractor _hentaini = HentainiExtractor();

  static String cleanAnimeTitle(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'\s*-\s*Episode\s*\d+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*•\s*Ep\s*\d+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*•\s*Episode\s*\d+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\(TV\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\[.*?\]'), '');
    return s.trim();
  }

  /// Scrape all stream sources for an Anime and Episode across all native extractors concurrently.
  Stream<StreamSource> scrapeStreamsStream({
    required AnimeMedia anime,
    required int episodeNumber,
    String? categoryFilter, // 'sub', 'dub', or null for both
  }) {
    final controller = StreamController<StreamSource>();
    final seenUrls = <String>{};

    final titleCandidates = [
      anime.titleEnglish,
      anime.titleRomaji,
      anime.titleUserPreferred,
      anime.titleNative,
    ].where((t) => t.trim().isNotEmpty).toList();

    () async {
      final tasks = <Future>[];
      final cats = categoryFilter != null ? [categoryFilter.toLowerCase()] : ['sub', 'dub'];

      // 1. MegaPlay Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _megaPlay
              .extract(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
          )
              .then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              final catUpper = cat.toUpperCase();
              final subCount = res.tracks.where((t) => t.kind != 'thumbnails').length;
              final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

              controller.add(
                StreamSource(
                  name: '⚡ MegaPlay • $catUpper',
                  title:
                      '${anime.displayTitle} • Ep $episodeNumber [MegaPlay • $catUpper]',
                  description:
                      'MegaPlay • Master HLS • $catUpper$subLabel',
                  url: res.url,
                  addonName: 'MegaPlay',
                  headers: res.headers,
                  behaviorHints: {
                    'notWebReady': false,
                    if (res.intro != null) 'intro': res.intro,
                    if (res.outro != null) 'outro': res.outro,
                    'proxyHeaders': {
                      'request': res.headers,
                    },
                  },
                ),
              );
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] MegaPlay ($cat) error: $e');
          }),
        );
      }

      // 2. ReCloud Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _reCloud
              .extract(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
          )
              .then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              final catUpper = cat.toUpperCase();
              final subCount = res.tracks.where((t) => t.kind != 'thumbnails').length;
              final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

              controller.add(
                StreamSource(
                  name: '⚡ ReCloud • $catUpper',
                  title:
                      '${anime.displayTitle} • Ep $episodeNumber [ReCloud • $catUpper]',
                  description:
                      'ReCloud • Master HLS • $catUpper$subLabel',
                  url: res.url,
                  addonName: 'ReCloud',
                  headers: res.headers,
                  behaviorHints: {
                    'notWebReady': true,
                    if (res.intro != null) 'intro': res.intro,
                    if (res.outro != null) 'outro': res.outro,
                    'proxyHeaders': {
                      'request': res.headers,
                    },
                  },
                ),
              );
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] ReCloud ($cat) error: $e');
          }),
        );
      }

      // 3. TryEmbed Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _tryEmbed
              .extractAll(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                final subCount = res.tracks.length;
                final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

                controller.add(
                  StreamSource(
                    name: '⚡ TryEmbed • ${res.serverName} • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [TryEmbed • ${res.serverName} • $catUpper]',
                    description:
                        'TryEmbed (${res.serverName}) • Master HLS • $catUpper$subLabel',
                    url: res.url,
                    addonName: 'TryEmbed',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      if (res.intro != null) 'intro': res.intro,
                      if (res.outro != null) 'outro': res.outro,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] TryEmbed ($cat) error: $e');
          }),
        );
      }

      // 4. AniDB Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniDb
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                controller.add(
                  StreamSource(
                    name: '⚡ AniDB • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [AniDB • $catUpper]',
                    description:
                        'AniDB • Master HLS • $catUpper',
                    url: res.url,
                    addonName: 'AniDB',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] AniDB ($cat) error: $e');
            }),
          );
        }
      }

      // 5. Dulo Provider (Direct HLS Streams)
      tasks.add(
        _dulo
            .extract(
          anilistId: anime.id,
          episodeNumber: episodeNumber,
        )
            .then((results) {
          for (final res in results) {
            if (res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ Dulo • ${res.title}',
                  title:
                      '${anime.displayTitle} • Ep $episodeNumber [Dulo • ${res.quality}]',
                  description: 'Dulo (${res.quality}) • Master HLS',
                  url: res.url,
                  addonName: 'Dulo',
                  headers: res.headers,
                  behaviorHints: {
                    'notWebReady': false,
                    'proxyHeaders': {
                      'request': res.headers,
                    },
                  },
                ),
              );
            }
          }
        }).catchError((e) {
          if (kDebugMode) debugPrint('[AnimeScraper] Dulo error: $e');
        }),
      );

      // 6. Luna Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _luna
              .extract(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                controller.add(
                  StreamSource(
                    name: '⚡ Luna • ${res.server} • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [Luna • ${res.server} • $catUpper]',
                    description: 'Luna (${res.server}) • Master HLS • $catUpper',
                    url: res.url,
                    addonName: 'Luna',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] Luna ($cat) error: $e');
          }),
        );
      }

      // 7. AniNeko Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniNeko
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ AniNeko • $catUpper',
                      title:
                          '${anime.displayTitle} • Ep $episodeNumber [AniNeko • $catUpper]',
                      description: 'AniNeko • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'AniNeko',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] AniNeko ($cat) error: $e');
            }),
          );
        }
      }

      // 8. 123Anime Provider
      if (titleCandidates.isNotEmpty) {
        tasks.add(
          _oneTwoThreeAnime
              .extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                controller.add(
                  StreamSource(
                    name: '⚡ 123Anime • EchoVideo',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [123Anime]',
                    description: '123Anime • EchoVideo Master HLS',
                    url: res.url,
                    addonName: '123Anime',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] 123Anime error: $e');
          }),
        );
      }

      // 9. AniHQ Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniHQ
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ AniHQ • $catUpper',
                      title:
                          '${anime.displayTitle} • Ep $episodeNumber [AniHQ • $catUpper]',
                      description: 'AniHQ (${res.server}) • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'AniHQ',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] AniHQ ($cat) error: $e');
            }),
          );
        }
      }

      // 10. AniPM Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _aniPM
              .extract(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
            title: anime.displayTitle,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                controller.add(
                  StreamSource(
                    name: '⚡ AniPM • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [AniPM • ${res.server} • $catUpper]',
                    description: 'AniPM (${res.server}) • Master HLS • $catUpper',
                    url: res.url,
                    addonName: 'AniPM',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] AniPM ($cat) error: $e');
          }),
        );
      }

      // 11. VidNest Provider (Sub & Dub)
      for (final cat in cats) {
        tasks.add(
          _vidNest
              .extract(
            anilistId: anime.id,
            episodeNumber: episodeNumber,
            category: cat,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                controller.add(
                  StreamSource(
                    name: '⚡ VidNest • $catUpper',
                    title:
                        '${anime.displayTitle} • Ep $episodeNumber [VidNest • $catUpper]',
                    description: 'VidNest (${res.server}) • Master HLS • $catUpper',
                    url: res.url,
                    addonName: 'VidNest',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] VidNest ($cat) error: $e');
          }),
        );
      }

      // 12. Fallback Hentai extractors for NSFW/Ecchi anime
      final isAdult = anime.genres.any((g) =>
          g.toLowerCase().contains('hentai') ||
          g.toLowerCase().contains('erotica') ||
          g.toLowerCase().contains('ecchi'));

      if (ContentSettings.adultEnabled.value && isAdult && titleCandidates.isNotEmpty) {
        tasks.add(
          _watchHentai.extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          ).then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ WatchHentai',
                  title: '${anime.displayTitle} • Ep $episodeNumber [WatchHentai]',
                  description: 'WatchHentai • Direct MP4',
                  url: res.url,
                  addonName: 'WatchHentai',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );

        tasks.add(
          _hentaini.extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          ).then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ Hentaini',
                  title: '${anime.displayTitle} • Ep $episodeNumber [Hentaini]',
                  description: 'Hentaini • Direct MP4',
                  url: res.url,
                  addonName: 'Hentaini',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );
      }

      // 13. CloudStream Extensions (HiAnime, AnimePahe, etc.)
      if (CloudStreamManager.isSupported && CloudStreamManager.instance.activeExtensions.isNotEmpty) {
        final mainTitle = anime.titleEnglish.isNotEmpty ? anime.titleEnglish : anime.displayTitle;
        final altTitles = titleCandidates.where((t) => t != mainTitle).toList();

        tasks.add(
          () async {
            try {
              await for (final src in CloudStreamManager.instance.scrapeStreams(
                type: 'anime',
                title: mainTitle,
                episode: episodeNumber,
                genres: anime.genres,
                alternativeTitles: altTitles,
              )) {
                if (categoryFilter != null) {
                  final isDub = (src.description?.toLowerCase().contains('dub') ?? false) ||
                      (src.name?.toLowerCase().contains('dub') ?? false);
                  if (categoryFilter.toLowerCase() == 'sub' && isDub) continue;
                  if (categoryFilter.toLowerCase() == 'dub' && !isDub) continue;
                }

                if (src.url != null && seenUrls.add(src.url!) && !controller.isClosed) {
                  controller.add(src);
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('[AnimeScraper] CloudStream anime scrape error: $e');
            }
          }(),
        );
      }

      await Future.wait(tasks);
      if (!controller.isClosed) {
        controller.close();
      }
    }();

    return controller.stream;
  }

  /// Scrapes anime streams when only basic metadata (title, anilistId, episodeNumber) is available,
  /// e.g. from in-player sources panel or continuing playback.
  Stream<StreamSource> scrapeStreamsByDetails({
    required String title,
    int? anilistId,
    required int episodeNumber,
    String? categoryFilter,
  }) {
    final controller = StreamController<StreamSource>();
    final seenUrls = <String>{};

    final cleanTitle = cleanAnimeTitle(title);
    final titleCandidates = [
      cleanTitle,
      title,
    ].where((t) => t.trim().isNotEmpty).toSet().toList();

    () async {
      final tasks = <Future>[];
      final cats = categoryFilter != null ? [categoryFilter.toLowerCase()] : ['sub', 'dub'];

      // 1. MegaPlay (if anilistId is available)
      if (anilistId != null && anilistId > 0) {
        for (final cat in cats) {
          tasks.add(
            _megaPlay
                .extract(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                final subCount = res.tracks.where((t) => t.kind != 'thumbnails').length;
                final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

                controller.add(
                  StreamSource(
                    name: '⚡ MegaPlay • $catUpper',
                    title: '$cleanTitle • Ep $episodeNumber [MegaPlay • $catUpper]',
                    description: 'MegaPlay • Master HLS • $catUpper$subLabel',
                    url: res.url,
                    addonName: 'MegaPlay',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      if (res.intro != null) 'intro': res.intro,
                      if (res.outro != null) 'outro': res.outro,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player MegaPlay error: $e');
            }),
          );
        }

        // 2. ReCloud Provider (Sub & Dub)
        for (final cat in cats) {
          tasks.add(
            _reCloud
                .extract(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                final subCount = res.tracks.where((t) => t.kind != 'thumbnails').length;
                final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

                controller.add(
                  StreamSource(
                    name: '⚡ ReCloud • $catUpper',
                    title: '$cleanTitle • Ep $episodeNumber [ReCloud • $catUpper]',
                    description: 'ReCloud • Master HLS • $catUpper$subLabel',
                    url: res.url,
                    addonName: 'ReCloud',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': true,
                      if (res.intro != null) 'intro': res.intro,
                      if (res.outro != null) 'outro': res.outro,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player ReCloud error: $e');
            }),
          );
        }

        // 3. TryEmbed Provider (Sub & Dub)
        for (final cat in cats) {
          tasks.add(
            _tryEmbed
                .extractAll(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  final subCount = res.tracks.length;
                  final subLabel = subCount > 0 ? ' • $subCount Subtitles' : '';

                  controller.add(
                    StreamSource(
                      name: '⚡ TryEmbed • ${res.serverName} • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [TryEmbed • ${res.serverName} • $catUpper]',
                      description: 'TryEmbed (${res.serverName}) • Master HLS • $catUpper$subLabel',
                      url: res.url,
                      addonName: 'TryEmbed',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        if (res.intro != null) 'intro': res.intro,
                        if (res.outro != null) 'outro': res.outro,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player TryEmbed error: $e');
            }),
          );
        }

        // 4. Dulo Provider (Direct HLS Streams)
        tasks.add(
          _dulo
              .extract(
            anilistId: anilistId,
            episodeNumber: episodeNumber,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                controller.add(
                  StreamSource(
                    name: '⚡ Dulo • ${res.title}',
                    title:
                        '$cleanTitle • Ep $episodeNumber [Dulo • ${res.quality}]',
                    description: 'Dulo (${res.quality}) • Master HLS',
                    url: res.url,
                    addonName: 'Dulo',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] In-player Dulo error: $e');
          }),
        );
      }

      // 5. AniDB Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniDb
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((res) {
              if (res != null &&
                  res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                final catUpper = cat.toUpperCase();
                controller.add(
                  StreamSource(
                    name: '⚡ AniDB • $catUpper',
                    title: '$cleanTitle • Ep $episodeNumber [AniDB • $catUpper]',
                    description: 'AniDB • Master HLS • $catUpper',
                    url: res.url,
                    addonName: 'AniDB',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player AniDB error: $e');
            }),
          );
        }
      }

      // 6. Luna Provider (Sub & Dub)
      if (anilistId != null && anilistId > 0) {
        for (final cat in cats) {
          tasks.add(
            _luna
                .extract(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ Luna • ${res.server} • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [Luna • ${res.server} • $catUpper]',
                      description: 'Luna (${res.server}) • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'Luna',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player Luna ($cat) error: $e');
            }),
          );
        }
      }

      // 7. AniNeko Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniNeko
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ AniNeko • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [AniNeko • $catUpper]',
                      description: 'AniNeko • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'AniNeko',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player AniNeko ($cat) error: $e');
            }),
          );
        }
      }

      // 8. 123Anime Provider
      if (titleCandidates.isNotEmpty) {
        tasks.add(
          _oneTwoThreeAnime
              .extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          )
              .then((results) {
            for (final res in results) {
              if (res.url.isNotEmpty &&
                  seenUrls.add(res.url) &&
                  !controller.isClosed) {
                controller.add(
                  StreamSource(
                    name: '⚡ 123Anime • EchoVideo',
                    title: '$cleanTitle • Ep $episodeNumber [123Anime]',
                    description: '123Anime • EchoVideo Master HLS',
                    url: res.url,
                    addonName: '123Anime',
                    headers: res.headers,
                    behaviorHints: {
                      'notWebReady': false,
                      'proxyHeaders': {
                        'request': res.headers,
                      },
                    },
                  ),
                );
              }
            }
          }).catchError((e) {
            if (kDebugMode) debugPrint('[AnimeScraper] In-player 123Anime error: $e');
          }),
        );
      }

      // 9. AniHQ Provider (Sub & Dub)
      if (titleCandidates.isNotEmpty) {
        for (final cat in cats) {
          tasks.add(
            _aniHQ
                .extract(
              titleCandidates: titleCandidates,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ AniHQ • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [AniHQ • $catUpper]',
                      description: 'AniHQ (${res.server}) • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'AniHQ',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player AniHQ ($cat) error: $e');
            }),
          );
        }
      }

      // 10. AniPM Provider (Sub & Dub)
      if (anilistId != null && anilistId > 0) {
        for (final cat in cats) {
          tasks.add(
            _aniPM
                .extract(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
              title: cleanTitle,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ AniPM • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [AniPM • ${res.server} • $catUpper]',
                      description: 'AniPM (${res.server}) • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'AniPM',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player AniPM ($cat) error: $e');
            }),
          );
        }
      }

      // 11. VidNest Provider (Sub & Dub)
      if (anilistId != null && anilistId > 0) {
        for (final cat in cats) {
          tasks.add(
            _vidNest
                .extract(
              anilistId: anilistId,
              episodeNumber: episodeNumber,
              category: cat,
            )
                .then((results) {
              for (final res in results) {
                if (res.url.isNotEmpty &&
                    seenUrls.add(res.url) &&
                    !controller.isClosed) {
                  final catUpper = cat.toUpperCase();
                  controller.add(
                    StreamSource(
                      name: '⚡ VidNest • $catUpper',
                      title: '$cleanTitle • Ep $episodeNumber [VidNest • $catUpper]',
                      description: 'VidNest (${res.server}) • Master HLS • $catUpper',
                      url: res.url,
                      addonName: 'VidNest',
                      headers: res.headers,
                      behaviorHints: {
                        'notWebReady': false,
                        'proxyHeaders': {
                          'request': res.headers,
                        },
                      },
                    ),
                  );
                }
              }
            }).catchError((e) {
              if (kDebugMode) debugPrint('[AnimeScraper] In-player VidNest ($cat) error: $e');
            }),
          );
        }
      }

      // 12. Fallback Hentai extractors
      if (ContentSettings.adultEnabled.value && titleCandidates.isNotEmpty) {
        tasks.add(
          _watchHentai.extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          ).then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ WatchHentai',
                  title: '$cleanTitle • Ep $episodeNumber [WatchHentai]',
                  description: 'WatchHentai • Direct MP4',
                  url: res.url,
                  addonName: 'WatchHentai',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );

        tasks.add(
          _hentaini.extract(
            titleCandidates: titleCandidates,
            episodeNumber: episodeNumber,
          ).then((res) {
            if (res != null &&
                res.url.isNotEmpty &&
                seenUrls.add(res.url) &&
                !controller.isClosed) {
              controller.add(
                StreamSource(
                  name: '⚡ Hentaini',
                  title: '$cleanTitle • Ep $episodeNumber [Hentaini]',
                  description: 'Hentaini • Direct MP4',
                  url: res.url,
                  addonName: 'Hentaini',
                  headers: {
                    'Referer': res.referer,
                    'Origin': res.origin,
                  },
                ),
              );
            }
          }).catchError((_) {}),
        );
      }

      // 13. CloudStream Extensions (HiAnime, AnimePahe, etc.)
      if (CloudStreamManager.isSupported && CloudStreamManager.instance.activeExtensions.isNotEmpty) {
        final mainTitle = titleCandidates.first;
        final altTitles = titleCandidates.skip(1).toList();

        tasks.add(
          () async {
            try {
              await for (final src in CloudStreamManager.instance.scrapeStreams(
                type: 'anime',
                title: mainTitle,
                episode: episodeNumber,
                genres: const ['Animation', 'Anime'],
                alternativeTitles: altTitles,
              )) {
                if (categoryFilter != null) {
                  final isDub = (src.description?.toLowerCase().contains('dub') ?? false) ||
                      (src.name?.toLowerCase().contains('dub') ?? false);
                  if (categoryFilter.toLowerCase() == 'sub' && isDub) continue;
                  if (categoryFilter.toLowerCase() == 'dub' && !isDub) continue;
                }

                if (src.url != null && seenUrls.add(src.url!) && !controller.isClosed) {
                  controller.add(src);
                }
              }
            } catch (e) {
              if (kDebugMode) debugPrint('[AnimeScraper] CloudStream in-player error: $e');
            }
          }(),
        );
      }

      await Future.wait(tasks);
      if (!controller.isClosed) {
        controller.close();
      }
    }();

    return controller.stream;
  }

  /// Fetch all scraped stream sources as a list
  Future<List<StreamSource>> scrapeAllStreams({
    required AnimeMedia anime,
    required int episodeNumber,
    String? categoryFilter,
  }) async {
    final list = <StreamSource>[];
    await for (final source in scrapeStreamsStream(
      anime: anime,
      episodeNumber: episodeNumber,
      categoryFilter: categoryFilter,
    )) {
      list.add(source);
    }
    return list;
  }

  /// Converts AnimeMedia and Episode to MovieDetail and Video for the PlayerScreen
  static MovieDetail toMovieDetail(
    AnimeMedia anime, {
    List<AniDbEpisode>? aniDbEpisodes,
    int? customEpisodeCount,
  }) {
    int totalCount = (aniDbEpisodes != null && aniDbEpisodes.isNotEmpty)
        ? aniDbEpisodes.length
        : (customEpisodeCount != null && customEpisodeCount > 0)
            ? customEpisodeCount
            : (anime.totalEpisodes > 0)
                ? anime.totalEpisodes
                : (anime.nextAiring != null && anime.nextAiring!.episode > 1)
                    ? anime.nextAiring!.episode - 1
                    : (anime.format.toUpperCase() == 'MOVIE'
                        ? 1
                        : (anime.status.toUpperCase() == 'RELEASING' ? 1200 : 24));

    final List<Video> videos;
    if (aniDbEpisodes != null && aniDbEpisodes.isNotEmpty) {
      videos = List.generate(aniDbEpisodes.length, (i) {
        final ep = aniDbEpisodes[i];
        return Video(
          id: 'anilist:${anime.id}:${ep.number}',
          season: 1,
          episode: ep.number,
          title: 'Episode ${ep.number}',
          thumbnail: anime.backdropUrl,
        );
      });
    } else {
      videos = List.generate(
        totalCount,
        (i) => Video(
          id: 'anilist:${anime.id}:${i + 1}',
          season: 1,
          episode: i + 1,
          title: 'Episode ${i + 1}',
          thumbnail: anime.backdropUrl,
        ),
      );
    }

    return MovieDetail(
      id: 'anilist:${anime.id}',
      type: 'anime',
      name: anime.displayTitle,
      poster: anime.coverUrl,
      background: anime.backdropUrl,
      description: anime.description,
      year: anime.seasonYear > 0 ? '${anime.seasonYear}' : null,
      imdbRating: anime.averageScore > 0 ? anime.formattedScore : null,
      genres: anime.genres,
      videos: videos,
    );
  }

  static Video toVideo(AnimeMedia anime, int episodeNumber, {String? title, String? thumbnail}) {
    return Video(
      id: 'anilist:${anime.id}:$episodeNumber',
      season: 1,
      episode: episodeNumber,
      title: (title != null && title.isNotEmpty) ? title : 'Episode $episodeNumber',
      thumbnail: (thumbnail != null && thumbnail.isNotEmpty) ? thumbnail : anime.backdropUrl,
    );
  }
}
