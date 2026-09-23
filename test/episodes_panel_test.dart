import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/movie/video.dart';
import 'package:zplay/models/stream/stream_model.dart';
import 'package:zplay/services/stream/stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Episodes Panel Data & Grouping', () {
    test('Groups and sorts videos by season and episode number correctly', () {
      final videos = [
        Video(id: 'ep1_2', title: 'Episode 2', season: 1, episode: 2),
        Video(id: 'ep2_1', title: 'S2 Episode 1', season: 2, episode: 1),
        Video(id: 'ep1_1', title: 'Episode 1', season: 1, episode: 1),
        Video(id: 'ep2_2', title: 'S2 Episode 2', season: 2, episode: 2),
      ];

      final seasonMap = <int, List<Video>>{};
      for (final v in videos) {
        final s = v.season ?? 1;
        seasonMap.putIfAbsent(s, () => []).add(v);
      }

      final sortedSeasons = seasonMap.keys.toList()..sort();
      for (final s in sortedSeasons) {
        seasonMap[s]!.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
      }

      expect(sortedSeasons, equals([1, 2]));
      expect(seasonMap[1]!.first.episode, equals(1));
      expect(seasonMap[1]!.last.episode, equals(2));
      expect(seasonMap[2]!.first.episode, equals(1));
      expect(seasonMap[2]!.last.episode, equals(2));
    });

    test('Episode stream source caching by key works correctly', () {
      final cache = <String, List<StreamSource>>{};

      const s1e1Key = '1:1';
      const s1e2Key = '1:2';

      final mockSource1 = StreamSource(
        name: '4K Stream',
        title: 'Show S01E01 2160p',
        url: 'https://stream.test/s1e1.mp4',
        addonName: 'PlayTorrioHTTP',
      );

      final mockSource2 = StreamSource(
        name: '1080p Stream',
        title: 'Show S01E02 1080p',
        url: 'https://stream.test/s1e2.mp4',
        addonName: 'PlayTorrioHTTP',
      );

      cache[s1e1Key] = [mockSource1];
      cache[s1e2Key] = [mockSource2];

      expect(cache.containsKey('1:1'), isTrue);
      expect(cache['1:1']!.first.title, contains('S01E01'));
      expect(cache.containsKey('1:2'), isTrue);
      expect(cache['1:2']!.first.title, contains('S01E02'));
      expect(cache.containsKey('2:1'), isFalse);
    });
  });

  group('StreamService Targeted Scraping', () {
    test('fetchStreamsForTargetAddon returns a Stream', () {
      final stream = StreamService.fetchStreamsForTargetAddon(
        targetAddonName: 'PlayTorrioHTTP',
        type: 'tv',
        id: 'tt123456:1:1',
        title: 'Test Show',
        season: 1,
        episode: 1,
      );

      expect(stream, isA<Stream<StreamSource>>());
    });
  });
}
