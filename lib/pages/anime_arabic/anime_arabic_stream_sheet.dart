import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/stream/stream_model.dart';
import '../../services/anime_arabic/anime_arabic_extractor.dart';
import '../../services/anime_arabic/anime_arabic_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../player/player_screen.dart';
import '../../services/storage/app_image_cache.dart';

class AnimeArabicStreamSheet extends StatefulWidget {
  final ArabicAnimeDetails details;
  final ArabicEpisode episode;
  final bool autoPlay;

  const AnimeArabicStreamSheet({
    super.key,
    required this.details,
    required this.episode,
    this.autoPlay = false,
  });

  @override
  State<AnimeArabicStreamSheet> createState() => _AnimeArabicStreamSheetState();
}

class _AnimeArabicStreamSheetState extends State<AnimeArabicStreamSheet> {
  final AnimeArabicExtractor _extractor = AnimeArabicExtractor.instance;
  final AnimeArabicService _service = AnimeArabicService.instance;

  final List<StreamSource> _allSources = [];
  bool _isScraping = true;
  String? _error;
  String _statusLine = 'Resolving servers…';

  @override
  void initState() {
    super.initState();
    _startScraping();
  }

  void _startScraping() async {
    setState(() {
      _allSources.clear();
      _isScraping = true;
      _error = null;
      _statusLine = 'Cracking Arabic server map…';
    });

    try {
      final hits = await _extractor.resolveEpisode(
        widget.episode,
        onProgress: (phase, detail) {
          if (mounted) {
            setState(() {
              _statusLine = detail;
            });
          }
        },
      );

      if (!mounted) return;

      if (hits.isEmpty) {
        setState(() {
          _isScraping = false;
          _error = 'No playable Arabic streams found for Episode ${widget.episode.number}.';
        });
        return;
      }

      final sources = AnimeArabicExtractor.toSources(
        hits,
        animeTitle: widget.details.title,
        episodeNumber: widget.episode.number,
      );

      setState(() {
        _allSources.addAll(sources);
        _isScraping = false;
      });

      if (widget.autoPlay && _allSources.isNotEmpty) {
        _playSource(_allSources.first);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScraping = false;
          _error = 'Failed to load Arabic streams: $e';
        });
      }
    }
  }

  void _playSource(StreamSource source) {
    _service.recordWatch(
      anime: widget.details.toCard(),
      episodeNumber: widget.episode.number,
      totalEpisodes: widget.details.episodes.isNotEmpty
          ? widget.details.episodes.length
          : widget.episode.number,
    );

    final movieDetail = widget.details.toMovieDetail();
    final video = movieDetail.videos.firstWhere(
      (v) => v.episode == widget.episode.number,
      orElse: () => movieDetail.videos.first,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: source,
          title: '${widget.details.title} - Episode ${widget.episode.number}',
          backdropUrl: widget.details.displayBanner,
          detail: movieDetail,
          episode: video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11141E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.details.displayCover,
                  cacheManager: AppImageCache.manager,

                  memCacheWidth: 132,
                  width: 44,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 44,
                    height: 60,
                    color: Colors.white10,
                    child: const Icon(Icons.movie_rounded, color: Colors.white38),
                  )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.details.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isScraping
                          ? 'جاري فحص السيرفرات...'
                          : '${_allSources.length} سيرفر متاح',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sources list
          if (_isScraping && _allSources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _statusLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (_error != null && _allSources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _startScraping,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _allSources.length,
                itemBuilder: (context, idx) {
                  final source = _allSources[idx];
                  return _buildSourceTile(source);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceTile(StreamSource source) {
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playSource(source),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141824),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name ?? 'سيرفر تشغيل',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.description ?? 'تشغيل مباشر • جودة عالية',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
