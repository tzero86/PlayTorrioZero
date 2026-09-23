import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/anime/extractors/anipm_extractor.dart';
import 'package:zplay/services/anime/extractors/vidnest_extractor.dart';

class _AllowAllHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowAllHttpOverrides();

  group('Chunk 4 Anime Scrapers Tests', () {
    test('AniPM extractor queries for One Piece (AniList 21 Ep 1)', () async {
      final extractor = AniPMExtractor.instance;
      final results = await extractor.extract(
        anilistId: 21,
        episodeNumber: 1,
        category: 'sub',
        title: 'One Piece',
      );
      print('[AniPM] streams resolved: ${results.length}');
      for (final r in results) {
        print('  -> ${r.server} (${r.quality}): ${r.url}');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('VidNest extractor queries for One Piece (AniList 21 Ep 1)', () async {
      final extractor = VidNestExtractor.instance;
      final results = await extractor.extract(
        anilistId: 21,
        episodeNumber: 1,
        category: 'sub',
      );
      print('[VidNest] streams resolved: ${results.length}');
      for (final r in results) {
        print('  -> ${r.server} (${r.quality}): ${r.url}');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
