import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/anime/anime_media.dart';
import '../../models/stream/stream_model.dart';
import '../../services/anime/anime_scraper_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/segmented_tabs.dart';
import '../../widgets/common/zplay_sheet.dart';
import '../player/player_screen.dart';

import '../../services/anime/extractors/anidb_extractor.dart';

class AnimeStreamSheet extends StatefulWidget {
  final AnimeMedia anime;
  final int episodeNumber;
  final bool autoPlay;
  final List<AniDbEpisode>? aniDbEpisodes;
  final int? totalEpisodes;

  const AnimeStreamSheet({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.autoPlay = false,
    this.aniDbEpisodes,
    this.totalEpisodes,
  });

  @override
  State<AnimeStreamSheet> createState() => _AnimeStreamSheetState();
}

class _AnimeStreamSheetState extends State<AnimeStreamSheet> {
  final AnimeScraperService _scraper = AnimeScraperService.instance;
  final AnimeLibraryService _library = AnimeLibraryService.instance;

  final List<StreamSource> _allSources = [];
  String _selectedCategory = 'all'; // 'all', 'sub', 'dub'
  bool _isScraping = true;
  String? _error;
  StreamSubscription<StreamSource>? _streamSub;

  @override
  void initState() {
    super.initState();
    _startScraping();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _startScraping() {
    setState(() {
      _allSources.clear();
      _isScraping = true;
      _error = null;
    });

    _streamSub?.cancel();
    _streamSub = _scraper
        .scrapeStreamsStream(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
    )
        .listen(
      (source) {
        if (mounted) {
          setState(() {
            _allSources.add(source);
          });

          if (widget.autoPlay && _allSources.length == 1) {
            _playSource(source);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isScraping = false;
            _error = e.toString();
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScraping = false;
            if (_allSources.isEmpty) {
              _error =
                  'No playable streams found for Episode ${widget.episodeNumber}.';
            }
          });
        }
      },
    );
  }

  List<StreamSource> get _filteredSources {
    if (_selectedCategory == 'sub') {
      return _allSources
          .where((s) =>
              !(s.description?.toLowerCase().contains('dub') ?? false) &&
              !(s.name?.toLowerCase().contains('dub') ?? false))
          .toList();
    } else if (_selectedCategory == 'dub') {
      return _allSources
          .where((s) =>
              (s.description?.toLowerCase().contains('dub') ?? false) ||
              (s.name?.toLowerCase().contains('dub') ?? false))
          .toList();
    }
    return _allSources;
  }

  void _playSource(StreamSource source) {
    _library.updateProgress(
      anime: widget.anime,
      episodeNumber: widget.episodeNumber,
      positionSeconds: 1,
      durationSeconds: 1440,
    );

    final detail = AnimeScraperService.toMovieDetail(
      widget.anime,
      aniDbEpisodes: widget.aniDbEpisodes,
      customEpisodeCount: widget.totalEpisodes,
    );
    final video =
        AnimeScraperService.toVideo(widget.anime, widget.episodeNumber);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: source,
          title: '${widget.anime.displayTitle} - Episode ${widget.episodeNumber}',
          backdropUrl: widget.anime.backdropUrl,
          detail: detail,
          episode: video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSources;
    final tokens = ZplayTokens.of(context);

    return ZplaySheet(
      title: '${widget.anime.displayTitle} • Ep ${widget.episodeNumber}',
      subtitle: _isScraping
          ? 'Cascading native anime extractors…'
          : '${_allSources.length} sources found',
      status: IconButton(
        icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
        onPressed: () => Navigator.pop(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sub / Dub — the shared segmented control rather than three
          // GestureDetector chips. Those were pointer-only (no key, remote or
          // D-pad event could reach them), about 26px tall, and painted pure
          // white on the accent fill, which is 1.9:1 on Signal Teal.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZplaySpacing.s20,
              vertical: ZplaySpacing.s4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedTabs<String>(
                semanticsLabel: 'Subtitle or dub',
                selected: _selectedCategory,
                onSelected: (category) =>
                    setState(() => _selectedCategory = category),
                options: [
                  SegmentedTabOption(
                    value: 'all',
                    label: 'All',
                    count: _allSources.length,
                  ),
                  const SegmentedTabOption(value: 'sub', label: 'Sub'),
                  const SegmentedTabOption(value: 'dub', label: 'Dub'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          Divider(color: tokens.borderDefault, height: 1),

          // Stream list
          Flexible(
            child: _allSources.isEmpty && _isScraping
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ZplaySpacing.s40,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppThemeService.currentPalette.value.primaryColor,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Extracting MegaPlay, VidWish, AllAnime & Miruro streams...',
                          style: ZplayType.body.toStyle(
                            color: tokens.textEmphasis,
                          ),
                        ),
                      ],
                    ),
                  )
                : _allSources.isEmpty && _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: tokens.danger,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: ZplayType.body.toStyle(
                                color: tokens.textEmphasis,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                              ),
                              onPressed: _startScraping,
                              child: const Text('Retry Scraping'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(ZplaySpacing.s32),
                            child: Text(
                              'No ${_selectedCategory.toUpperCase()} sources found.',
                              style: ZplayType.body.toStyle(
                                color: tokens.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(ZplaySpacing.s16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final s = filtered[index];
                              final isDub =
                                  (s.description?.toLowerCase().contains('dub') ??
                                          false) ||
                                      (s.name?.toLowerCase().contains('dub') ??
                                          false);

                              return RepaintBoundary(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _playSource(s),
                                    borderRadius: ZplayRadius.mdAll,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: ZplaySpacing.s16,
                                        vertical: ZplaySpacing.s12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.surface,
                                        borderRadius: ZplayRadius.mdAll,
                                        border: Border.fromBorderSide(
                                          tokens.hairline,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(
                                              ZplaySpacing.s8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppThemeService.currentPalette.value.primaryColor
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  ZplayRadius.smAll,
                                            ),
                                            child: Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: AppThemeService.currentPalette.value.primaryColor,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.name ?? 'Stream Source',
                                                  style: ZplayType.subtitle
                                                      .toStyle(
                                                        color: tokens
                                                            .textPrimary,
                                                      ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  s.description ?? s.addonName,
                                                  style: ZplayType.caption
                                                      .toStyle(
                                                        color: tokens
                                                            .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: ZplaySpacing.s8,
                                              vertical: ZplaySpacing.s4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDub
                                                  ? tokens.warning
                                                      .withValues(alpha: 0.2)
                                                  : tokens.info
                                                      .withValues(alpha: 0.2),
                                              borderRadius:
                                                  ZplayRadius.xsAll,
                                            ),
                                            child: Text(
                                              isDub ? 'DUB' : 'SUB',
                                              style: ZplayType.overline
                                                  .copyWith(
                                                    weight: FontWeight.w900,
                                                  )
                                                  .toStyle(
                                                    color: isDub
                                                        ? tokens.warning
                                                        : tokens.info,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
