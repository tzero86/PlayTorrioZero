import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/player/skip_segment_model.dart';

void main() {
  group('MediaSkipSegment & MediaSkipData Tests', () {
    test('Parses intro, recap, credits, preview correctly from JSON', () {
      final json = {
        'tmdb_id': 1396,
        'type': 'tv',
        'season': 1,
        'episode': 1,
        'intro': [
          {'start_ms': null, 'end_ms': 23000}
        ],
        'recap': [
          {'start_ms': 25000, 'end_ms': 134000}
        ],
        'credits': [
          {'start_ms': 5801777, 'end_ms': 6371111},
          {'start_ms': 6408000, 'end_ms': null}
        ],
        'preview': [
          {'start_ms': 1680000, 'end_ms': 1740000}
        ]
      };

      final data = MediaSkipData.fromJson(json);
      expect(data.tmdbId, 1396);
      expect(data.type, 'tv');
      expect(data.season, 1);
      expect(data.episode, 1);
      expect(data.segments.length, 5);

      // Intro
      final intro = data.segments.firstWhere((s) => s.type == 'intro');
      expect(intro.start, Duration.zero);
      expect(intro.end, const Duration(milliseconds: 23000));
      expect(intro.label, 'Skip Intro');

      // Recap
      final recap = data.segments.firstWhere((s) => s.type == 'recap');
      expect(recap.start, const Duration(milliseconds: 25000));
      expect(recap.end, const Duration(milliseconds: 134000));
      expect(recap.label, 'Skip Recap');

      // Credits
      final credits = data.segments.where((s) => s.type == 'credits').toList();
      expect(credits.length, 2);
      expect(credits.first.label, 'Skip Credits');
      expect(credits.last.end, isNull);

      // Preview
      final preview = data.segments.firstWhere((s) => s.type == 'preview');
      expect(preview.start, const Duration(milliseconds: 1680000));
      expect(preview.end, const Duration(milliseconds: 1740000));
      expect(preview.label, 'Skip Preview');
    });

    test('Contains method checks position intervals accurately', () {
      const seg = MediaSkipSegment(
        type: 'intro',
        startMs: 15000,
        endMs: 85000,
      );

      expect(seg.contains(const Duration(seconds: 10)), isFalse);
      expect(seg.contains(const Duration(seconds: 15)), isTrue);
      expect(seg.contains(const Duration(seconds: 45)), isTrue);
      expect(seg.contains(const Duration(seconds: 84)), isTrue);
      expect(seg.contains(const Duration(seconds: 85)), isFalse);
      expect(seg.contains(const Duration(seconds: 90)), isFalse);
    });

    test('Credits segment with null endMs extends to total duration', () {
      const seg = MediaSkipSegment(
        type: 'credits',
        startMs: 5000000,
        endMs: null,
      );

      const totalDur = Duration(milliseconds: 5500000);
      expect(seg.contains(const Duration(milliseconds: 4999999), totalDur), isFalse);
      expect(seg.contains(const Duration(milliseconds: 5000000), totalDur), isTrue);
      expect(seg.contains(const Duration(milliseconds: 5499999), totalDur), isTrue);
    });

    test('Unique keys differentiate segments cleanly', () {
      const seg1 = MediaSkipSegment(type: 'intro', startMs: 0, endMs: 20000);
      const seg2 = MediaSkipSegment(type: 'intro', startMs: 0, endMs: 20000);
      const seg3 = MediaSkipSegment(type: 'credits', startMs: 50000, endMs: null);

      expect(seg1.uniqueKey, seg2.uniqueKey);
      expect(seg1.uniqueKey, isNot(seg3.uniqueKey));
    });
  });
}
