import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../stream_scraper.dart';
import '../../../models/stream/stream_model.dart';
import '../../../utils/torrent/parse_torrent_title.dart';

class KnabenScraper extends StreamScraper {
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
    final url = 'https://knaben.org/search/$encodedQuery/0/1/seeders';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      });

      if (response.statusCode != 200) return sources;

      final document = parser.parse(response.body);
      final rows = document.querySelectorAll('table tbody tr');
      
      final titleParser = ParseTorrentTitle();
      final searchTitleLower = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      for (final row in rows) {
        final tdList = row.querySelectorAll('td');
        if (tdList.length < 6) continue;

        // Extract title
        final titleNode = row.querySelector('.text-wrap.w-100 > a');
        final torrentName = titleNode?.text.trim() ?? '';
        
        // Extract magnet
        final magnetNode = row.querySelector('a[href^="magnet:"]');
        final magnetUrl = magnetNode?.attributes['href'] ?? '';
        
        if (torrentName.isEmpty || magnetUrl.isEmpty) continue;
        
        // Extract size
        final sizeNode = tdList[2];
        final size = sizeNode.text.trim();
        
        // Extract seeders
        final seedersNode = tdList[4];
        final seedersText = seedersNode.text.trim().replaceAll(',', '');
        final seeders = int.tryParse(seedersText) ?? 0;

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
          // Only include if it's the specific episode OR a season pack (no episode specified)
          if (episode != null && parsedEpisode != null && parsedEpisode != episode) {
            continue;
          }
        }
        

        // Extract infoHash from magnet
        final match = RegExp(r'urn:btih:([a-zA-Z0-9]+)').firstMatch(magnetUrl);
        final infoHash = match?.group(1);
        
        if (infoHash == null) continue;

        // Extract trackers
        final trMatches = RegExp(r'&tr=([^&]+)').allMatches(magnetUrl);
        final trackers = trMatches
            .map((m) => 'tracker:${Uri.decodeComponent(m.group(1)!)}')
            .toList();

        sources.add(StreamSource(
          name: 'ZPlay',
          addonName: 'ZPlay',
          title: '$torrentName\n$size 👥 $seeders',
          infoHash: infoHash,
          sources: trackers.isNotEmpty ? trackers : null,
        ));
      }
    } catch (e) {
      print('Knaben scrape error: $e');
    }
    
    return sources;
  }
}
