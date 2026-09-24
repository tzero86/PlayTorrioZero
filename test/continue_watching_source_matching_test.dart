import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/continue_watching/continue_watching_item.dart';
import 'package:zplay/models/stream/stream_model.dart';
import 'package:zplay/services/continue_watching/continue_watching_service.dart';

void main() {
  group('Continue Watching Source Matching Tests', () {
    test('Matches exact source card name, title and comments (FSOnline example)', () {
      final savedItem = ContinueWatchingItem(
        id: 'tt0137523',
        title: 'Fight Club',
        type: 'movie',
        positionSeconds: 1200,
        totalDurationSeconds: 8400,
        lastWatchedAt: DateTime.now(),
        isTorrent: false,
        addonName: 'ZPlayHTTP',
        streamName: 'ZPlayHTTP',
        streamTitle: 'FSOnline · FileSuN · 1080p',
        streamDescription: 'FSOnline HLS Stream',
        quality: '1080p',
      );

      final exactMatch = StreamSource(
        name: 'ZPlayHTTP',
        addonName: 'ZPlayHTTP',
        title: 'FSOnline · FileSuN · 1080p',
        description: 'FSOnline HLS Stream',
        url: 'https://example.com/fsonline/master.m3u8',
      );

      final variantPunctuationMatch = StreamSource(
        name: 'ZPlayHTTP',
        addonName: 'ZPlayHTTP',
        title: 'FSOnline . FileSuN . 1080P',
        description: 'FSOnline HLS Stream',
        url: 'https://example.com/fsonline/master2.m3u8',
      );

      final differentScraper = StreamSource(
        name: 'ZPlayHTTP',
        addonName: 'ZPlayHTTP',
        title: 'VidFast · vRapid · 1080p',
        description: 'VidFast Direct Stream',
        url: 'https://example.com/vidfast/video.mp4',
      );

      final exactScore = ContinueWatchingService.calculateSourceMatchScore(exactMatch, savedItem);
      final variantScore = ContinueWatchingService.calculateSourceMatchScore(variantPunctuationMatch, savedItem);
      final diffScore = ContinueWatchingService.calculateSourceMatchScore(differentScraper, savedItem);

      print('Exact match score: $exactScore');
      print('Variant punctuation score: $variantScore');
      print('Different scraper score: $diffScore');

      // Exact and variant should both score > 1400 (exceeding early completion threshold of 950)
      expect(exactScore, greaterThan(1400.0));
      expect(variantScore, greaterThan(1400.0));

      // Different scraper should score much lower (under 500, well below 950)
      expect(diffScore, lessThan(500.0));
      expect(exactScore, greaterThan(diffScore + 1000.0));
    });
  });
}
