import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/anime/anime_media.dart';
import '../../models/stream/stream_model.dart';
import '../../services/anime/anime_scraper_service.dart';
import '../../services/anime/anime_library_service.dart';
import '../../services/theme/app_theme_service.dart';
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

    return ZplaySheet(
      title: '${widget.anime.displayTitle} • Ep ${widget.episodeNumber}',
      subtitle: _isScraping
          ? 'Cascading native anime extractors…'
          : '${_allSources.length} sources found',
      status: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54),
        onPressed: () => Navigator.pop(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sub / Dub — the shared segmented control rather than three
          // GestureDetector chips. Those were pointer-only (no key, remote or
          // D-pad event could reach them), about 26px tall, and painted
          // Colors.white on the accent fill, which is 1.9:1 on Signal Teal.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          const Divider(color: Colors.white10, height: 1),

          // Stream list
          Flexible(
            child: _allSources.isEmpty && _isScraping
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppThemeService.currentPalette.value.primaryColor,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Extracting MegaPlay, VidWish, AllAnime & Miruro streams...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C5CFF),
                              ),
                              onPressed: _startScraping,
                              child: const Text('Retry Scraping'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No ${_selectedCategory.toUpperCase()} sources found.',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
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
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF191C28),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color:
                                              Colors.white.withValues(alpha: 0.08),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7C5CFF)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Color(0xFF7C5CFF),
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
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  s.description ?? s.addonName,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDub
                                                  ? Colors.orange
                                                      .withValues(alpha: 0.2)
                                                  : Colors.blue
                                                      .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isDub ? 'DUB' : 'SUB',
                                              style: TextStyle(
                                                color: isDub
                                                    ? Colors.orangeAccent
                                                    : Colors.lightBlueAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
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
