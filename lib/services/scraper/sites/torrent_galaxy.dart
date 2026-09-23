import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import '../../../utils/torrent/parse_torrent_title.dart';

class TorrentGalaxyScraper extends StreamScraper {
  @override
  String get name => 'ZPlay';

  @override
  Future<List<StreamSource>> scrape({
    required String type,
    required String title,
    int? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async {
    final sources = <StreamSource>[];
    
    String query = title.trim();
    if (type == 'movie' && year != null) {
      query += ' $year';
    } else if (type == 'series' && season != null) {
      final s = season.toString().padLeft(2, '0');
      query += ' s$s';
    }

    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = 'https://torrentgalaxy.info/get-posts/keywords:$encodedQuery';

    try {
      final response = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      });

      if (response.statusCode != 200) return sources;

      final document = parser.parse(response.body);
      final rows = document.querySelectorAll('.tgxtable .tgxtablerow');
      
      final titleParser = ParseTorrentTitle();
      final searchTitleLower = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      // We will parse the page concurrently or sequentially.
      // Doing it concurrently is faster, but we shouldn't spam the server too much.
      // Since we filter *before* fetching the detail page, it shouldn't be too many requests.
      final detailFutures = <Future<StreamSource?>>[];

      for (final row in rows) {
        // Extract title
        final titleNode = row.querySelector('.tgxtablecell.clickable-row a[title]');
        final torrentName = titleNode?.attributes['title']?.trim() ?? '';
        
        final postUrlPath = titleNode?.attributes['href'] ?? '';
        if (torrentName.isEmpty || postUrlPath.isEmpty) continue;
        
        // Extract size
        final sizeNode = row.querySelector('.badge-secondary');
        final size = sizeNode?.text.trim() ?? 'Unknown Size';
        
        // Extract seeders
        // [ <font color="green"><b>13</b></font> / <font color="#ff0000"><b>25</b></font> ]
        final seedersFonts = row.querySelectorAll('font[color="green"] b');
        int seeders = 0;
        if (seedersFonts.isNotEmpty) {
          seeders = int.tryParse(seedersFonts.first.text.trim()) ?? 0;
        }

        // Filter out bad matches using ParseTorrentTitle
        final parsed = titleParser.parse(torrentName);
        final parsedTitle = (parsed['title'] ?? '').toString().toLowerCase();
        final cleanParsedTitle = parsedTitle.replaceAll(RegExp(r'[^a-z0-9]'), '');

        // 1. Exact show/movie match filter
        if (cleanParsedTitle != searchTitleLower) {
          continue;
        }
        
        // 2. Series specific filtering
        if (type == 'series') {
          final parsedSeason = parsed['season'];
          final parsedEpisode = parsed['episode'];
          
          if (season != null && parsedSeason != null && parsedSeason != season) {
            continue;
          }
          if (episode != null && parsedEpisode != null && parsedEpisode != episode) {
            continue;
          }
        }
        
        // If we passed all filters, queue fetching the detail page for the magnet link
        detailFutures.add(_fetchDetailAndBuildSource(
          postUrl: 'https://torrentgalaxy.info$postUrlPath',
          torrentName: torrentName,
          size: size,
          seeders: seeders,
        ));
      }

      // Wait for all detail pages to be fetched
      final results = await Future.wait(detailFutures);
      for (final s in results) {
        if (s != null) {
          sources.add(s);
        }
      }

    } catch (e) {
      print('TorrentGalaxy scrape error: $e');
    }
    
    return sources;
  }

  Future<StreamSource?> _fetchDetailAndBuildSource({
    required String postUrl,
    required String torrentName,
    required String size,
    required int seeders,
  }) async {
    try {
      final response = await http.get(Uri.parse(postUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });

      if (response.statusCode != 200) return null;

      final document = parser.parse(response.body);
      final magnetNode = document.querySelector('a[href^="magnet:"]');
      final magnetUrl = magnetNode?.attributes['href'];

      if (magnetUrl == null || magnetUrl.isEmpty) return null;

      // Extract infoHash from magnet
      final match = RegExp(r'urn:btih:([a-zA-Z0-9]+)', caseSensitive: false).firstMatch(magnetUrl);
      final infoHash = match?.group(1);
      
      if (infoHash == null) return null;

      // Extract trackers
      final trMatches = RegExp(r'&tr=([^&]+)').allMatches(magnetUrl);
      final trackers = trMatches
          .map((m) => 'tracker:${Uri.decodeComponent(m.group(1)!)}')
          .toList();

      return StreamSource(
        name: 'ZPlay',
        addonName: 'ZPlay',
        title: '$torrentName\n$size 👥 $seeders',
        infoHash: infoHash,
        sources: trackers.isNotEmpty ? trackers : null,
      );
    } catch (e) {
      print('TorrentGalaxy detail fetch error: $e');
      return null;
    }
  }
}
