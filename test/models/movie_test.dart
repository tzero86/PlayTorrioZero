import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/movie/movie.dart';

void main() {
  group('Movie', () {
    test('parses basic movie fields', () {
      final json = {'id': 'tt1375666', 'name': 'Inception', 'poster': 'https://example.com/poster.jpg', 'year': '2010', 'type': 'movie'};
      final movie = Movie.fromJson(json, 'https://cinemeta.example.com');
      expect(movie.id, 'tt1375666');
      expect(movie.name, 'Inception');
      expect(movie.poster, 'https://example.com/poster.jpg');
      expect(movie.year, '2010');
      expect(movie.type, 'movie');
      expect(movie.addonBaseUrl, 'https://cinemeta.example.com');
    });
    test('handles missing fields gracefully', () {
      final json = {'id': 'tt123', 'name': 'Unknown Movie'};
      final movie = Movie.fromJson(json, '');
      expect(movie.id, 'tt123');
      expect(movie.poster, isNull);
      expect(movie.year, isNull);
      expect(movie.type, 'movie');
    });
    test('uses releaseInfo over year', () {
      final json = {'id': 'tt1', 'name': 'Test', 'releaseInfo': '2020-2024', 'year': '2019'};
      final movie = Movie.fromJson(json, '');
      expect(movie.year, '2020-2024');
    });
  });
}
