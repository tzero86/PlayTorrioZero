import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/anime/extractors/luna_extractor.dart';
import 'package:zplay/services/anime/extractors/anineko_extractor.dart';

class _AllowAllHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowAllHttpOverrides();

  group('Chunk 2 Anime Scrapers Tests', () {
    test('Luna extractor resolves streams for One Piece (AniList 21 Ep 1)', () async {
      final extractor = LunaExtractor.instance;
      final results = await extractor.extract(
        anilistId: 21,
        episodeNumber: 1,
        category: 'sub',
      );
      print('[Luna] streams resolved: ${results.length}');
      for (final r in results) {
        print('  -> ${r.server} (${r.quality}): ${r.url}');
      }
      expect(results, isNotEmpty);
      expect(results.first.url, startsWith('http'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('AniNeko extractor resolves streams for Attack on Titan', () async {
      final extractor = AniNekoExtractor.instance;
      final results = await extractor.extract(
        titleCandidates: ['Attack on Titan', 'Shingeki no Kyojin'],
        episodeNumber: 1,
        category: 'sub',
      );
      print('[AniNeko] streams resolved: ${results.length}');
      for (final r in results) {
        print('  -> ${r.server} (${r.quality}): ${r.url}');
      }
      expect(results, isNotEmpty);
      expect(results.first.url, startsWith('http'));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
