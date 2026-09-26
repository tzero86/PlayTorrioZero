import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/metadata/metadata_service.dart';

String _body(List<dynamic> entries) => jsonEncode({'d': entries});

void main() {
  group('MetadataService.parseSuggestions', () {
    test('drops entries whose id is not a title', () {
      final movies = MetadataService.parseSuggestions(_body([
        {'id': 'nm0000123', 'l': 'Sylvester Stallone', 'q': 'name'},
        {'id': 'in0000001', 'l': 'Metro Goldwyn Mayer', 'q': 'company'},
        {'id': 'tt0075148', 'l': 'Rocky', 'y': 1976, 'q': 'feature'},
      ]));

      expect(movies.map((m) => m.id), ['tt0075148']);
    });

    test('maps feature to movie and series kinds to series', () {
      final movies = MetadataService.parseSuggestions(_body([
        {'id': 'tt0075148', 'l': 'Rocky', 'y': 1976, 'q': 'feature'},
        {'id': 'tt0903747', 'l': 'Breaking Bad', 'y': 2008, 'q': 'TV series'},
      ]));

      expect(movies.map((m) => m.type), ['movie', 'series']);
      expect(movies.map((m) => m.name), ['Rocky', 'Breaking Bad']);
      expect(movies.first.year, '1976');
      expect(movies.first.addonBaseUrl, 'https://v3-cinemeta.strem.io');
    });

    test('tolerates a missing year', () {
      final movies = MetadataService.parseSuggestions(_body([
        {'id': 'tt1234567', 'l': 'No Year', 'q': 'feature'},
      ]));

      expect(movies.single.year, isNull);
      expect(movies.single.type, 'movie');
    });

    test('returns an empty list for an empty result set', () {
      expect(MetadataService.parseSuggestions(_body(const [])), isEmpty);
    });

    test('keeps only the requested type', () {
      final body = _body([
        {'id': 'tt0075148', 'l': 'Rocky', 'y': 1976, 'q': 'feature'},
        {'id': 'tt0903747', 'l': 'Breaking Bad', 'y': 2008, 'q': 'TV series'},
      ]);

      final movies = MetadataService.parseSuggestions(body, type: 'series');
      expect(movies.map((m) => m.id), ['tt0903747']);
    });

    test('applies the limit and survives malformed input', () {
      final body = _body([
        {'id': 'tt1', 'l': 'One', 'q': 'movie'},
        {'id': 'tt2', 'l': 'Two', 'q': 'movie'},
      ]);

      expect(MetadataService.parseSuggestions(body, limit: 1).length, 1);
      expect(MetadataService.parseSuggestions('not json'), isEmpty);
      expect(MetadataService.parseSuggestions('{"d": "nope"}'), isEmpty);
    });

    test('keeps unknown kinds only when no type is requested', () {
      final body = _body([
        {'id': 'tt1', 'l': 'Some Trailer', 'q': 'video'},
      ]);

      expect(MetadataService.parseSuggestions(body, type: 'movie'), isEmpty);
      expect(MetadataService.parseSuggestions(body).single.id, 'tt1');
    });
  });

  group('MetadataService.catalogSearchIsTrustworthy', () {
    test('rejects Cinemeta and accepts real search addons', () {
      expect(
        MetadataService.catalogSearchIsTrustworthy('https://v3-cinemeta.strem.io'),
        isFalse,
      );
      expect(
        MetadataService.catalogSearchIsTrustworthy('https://v3-CINEMETA.strem.io'),
        isFalse,
      );
      expect(
        MetadataService.catalogSearchIsTrustworthy('https://addon.example.com'),
        isTrue,
      );
      expect(MetadataService.catalogSearchIsTrustworthy('builtin:zplay'), isTrue);
    });
  });
}
