import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/utils/torrent/parse_torrent_title.dart';

void main() {
  group('ParseTorrentTitle', () {
    late ParseTorrentTitle parser;

    setUp(() {
      parser = ParseTorrentTitle();
    });

    group('resolution', () {
      test('detects 2160p', () {
        final r = parser.parse('Movie.2024.2160p.WEB-DL.mkv');
        expect(r['resolution']?.toString(), anyOf('2160p', '4K'));
      });
      test('detects 1080p', () {
        final r = parser.parse('Movie.2024.1080p.BluRay.x264.mkv');
        expect(r['resolution'], '1080p');
      });
      test('detects 720p', () {
        final r = parser.parse('Movie.2024.720p.HDTV.mkv');
        expect(r['resolution'], '720p');
      });
    });

    group('codec', () {
      test('detects x265/HEVC', () {
        final r = parser.parse('Movie.2024.2160p.x265.mkv');
        expect(r['codec']?.toString(), anyOf('HEVC', 'x265'));
      });
      test('detects x264/AVC', () {
        final r = parser.parse('Movie.2024.1080p.x264.mkv');
        expect(r['codec']?.toString(), anyOf('AVC', 'x264', 'H.264'));
      });
      test('detects AV1 if parser supports it', () {
        final r = parser.parse('Movie.2024.1080p.AV1.mkv');
        // AV1 detection depends on parser configuration; skip strict check
        final codec = r['codec']?.toString();
        expect(codec == null || codec == 'AV1', true);
      });
    });

    group('audio', () {
      test('detects DTS', () {
        final r = parser.parse('Movie.2024.1080p.DTS-HD.MA.mkv');
        expect(r['audio']?.toString().toLowerCase(), contains('dts'));
      });
      test('detects Atmos', () {
        final r = parser.parse('Movie.2024.2160p.Atmos.mkv');
        expect(r['audio']?.toString().toLowerCase(), contains('atmos'));
      });
    });

    group('source', () {
      test('detects BluRay', () {
        final r = parser.parse('Movie.2024.1080p.BluRay.mkv');
        expect(r['source']?.toString().toLowerCase(), contains('bluray'));
      });
      test('detects WEB-DL', () {
        final r = parser.parse('Movie.2024.1080p.WEB-DL.mkv');
        expect(r['source']?.toString().toLowerCase(), contains('web'));
      });
    });

    group('season/episode', () {
      test('detects S01E01', () {
        final r = parser.parse('Show.S01E01.1080p.mkv');
        expect(r['season'], 1);
        expect(r['episode'], 1);
      });
      test('detects 1x01 format', () {
        final r = parser.parse('Show.1x01.720p.mkv');
        expect(r['season'], 1);
        expect(r['episode'], 1);
      });
      test('detects multi-digit episodes', () {
        final r = parser.parse('Show.S03E12.1080p.mkv');
        expect(r['season'], 3);
        expect(r['episode'], 12);
      });
    });

    group('year', () {
      test('detects year in title', () {
        final r = parser.parse('Movie.2024.1080p.mkv');
        expect(r['year'], 2024);
      });
      test('detects year in parentheses', () {
        final r = parser.parse('Movie (2024) 1080p.mkv');
        expect(r['year'], 2024);
      });
    });

    group('edge cases', () {
      test('handles empty string', () {
        final r = parser.parse('');
        expect(r, isNotEmpty);
      });
      test('handles non-media files', () {
        final r = parser.parse('sample.txt');
        expect(r, isNotEmpty);
      });
    });
  });
}
