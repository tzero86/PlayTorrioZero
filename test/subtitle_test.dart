import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/subtitles/subtitle_parser.dart';
import 'package:archive/archive.dart';

void main() {
  group('SubtitleParser & Encoding Tests', () {
    test('Decodes UTF-8 and parses SRT cues accurately', () {
      const rawSrt = '''1
00:00:01,000 --> 00:00:04,000
Hello World!

2
00:00:05,500 --> 00:00:08,250
This is a test subtitle.
''';
      final bytes = utf8.encode(rawSrt);
      final decoded = SubtitleParser.decodeBytesWithFallback(bytes);
      final result = SubtitleParser.parse(decoded);

      expect(result.format, SubFormat.srt);
      expect(result.cues.length, 2);
      expect(result.cues[0].start, 1.0);
      expect(result.cues[0].end, 4.0);
      expect(result.cues[0].text, 'Hello World!');
    });

    test('Decodes Latin-1 / Windows-1256 fallback without throwing', () {
      final latin1Bytes = [0xC7, 0xE1, 0xD3, 0xE1, 0xC7, 0xE3];
      final decoded = SubtitleParser.decodeBytesWithFallback(latin1Bytes);
      expect(decoded.isNotEmpty, isTrue);
    });

    test('Decodes and extracts subtitle from in-memory ZIP archive', () {
      const srtText = '''1
00:00:02,000 --> 00:00:05,000
Extracted from zip!
''';
      final archive = Archive();
      final srtBytes = utf8.encode(srtText);
      archive.addFile(ArchiveFile('subtitles/movie.srt', srtBytes.length, srtBytes));
      archive.addFile(ArchiveFile('__MACOSX/._movie.srt', 20, [1, 2, 3]));

      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);

      final decodedArchive = ZipDecoder().decodeBytes(zipData);
      ArchiveFile? bestFile;
      for (final f in decodedArchive) {
        if (!f.isFile) continue;
        final name = f.name.toLowerCase();
        if (name.contains('__macosx')) continue;
        if (name.endsWith('.srt')) {
          bestFile = f;
        }
      }

      expect(bestFile, isNotNull);
      expect(bestFile!.name, 'subtitles/movie.srt');
      final content = utf8.decode(bestFile.content as List<int>);
      final result = SubtitleParser.parse(content);
      expect(result.cues.length, 1);
      expect(result.cues[0].text, 'Extracted from zip!');
    });
  });
}
