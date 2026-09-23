import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/my_list/my_list_item.dart';

void main() {
  group('MyListItem', () {
    group('uniqueKey', () {
      test('uses traktId when available', () {
        final item = MyListItem(
          traktId: 123,
          imdbId: 'tt456',
          tmdbId: 789,
          title: 'Test Movie',
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'trakt:123');
      });

      test('falls back to imdbId when no traktId', () {
        final item = MyListItem(
          imdbId: 'tt456',
          tmdbId: 789,
          title: 'Test Movie',
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'imdb:tt456');
      });

      test('falls back to tmdbId when no traktId or imdbId', () {
        final item = MyListItem(
          tmdbId: 789,
          title: 'Test Movie',
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'tmdb:789');
      });

      test('falls back to title+year when no IDs', () {
        final item = MyListItem(
          title: 'Test Movie',
          year: 2024,
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'title:test movie:2024');
      });

      test('title is lowercased and trimmed in fallback key', () {
        final item = MyListItem(
          title: '  THE MATRIX  ',
          year: 1999,
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'title:the matrix:1999');
      });

      test('year defaults to 0 when null in fallback key', () {
        final item = MyListItem(
          title: 'Unknown',
          type: 'movie',
          addedAt: DateTime(2026),
        );
        expect(item.uniqueKey, 'title:unknown:0');
      });
    });

    group('equality', () {
      test('same uniqueKey means equal', () {
        final a = MyListItem(traktId: 1, title: 'A', type: 'movie', addedAt: DateTime(2026));
        final b = MyListItem(traktId: 1, title: 'B', type: 'series', addedAt: DateTime(2025));
        expect(a, equals(b));
      });

      test('different uniqueKey means not equal', () {
        final a = MyListItem(traktId: 1, title: 'A', type: 'movie', addedAt: DateTime(2026));
        final b = MyListItem(traktId: 2, title: 'A', type: 'movie', addedAt: DateTime(2026));
        expect(a, isNot(equals(b)));
      });
    });

    group('fromJson / toJson roundtrip', () {
      test('full item survives roundtrip', () {
        final original = MyListItem(
          traktId: 100,
          imdbId: 'tt1234567',
          tmdbId: 500,
          title: 'Inception',
          year: 2010,
          type: 'movie',
          poster: 'https://example.com/poster.jpg',
          addedAt: DateTime(2026, 8, 11, 12, 0, 0),
          source: MyListSource.trakt,
        );

        final json = original.toJson();
        final restored = MyListItem.fromJson(json);

        expect(restored.traktId, original.traktId);
        expect(restored.imdbId, original.imdbId);
        expect(restored.tmdbId, original.tmdbId);
        expect(restored.title, original.title);
        expect(restored.year, original.year);
        expect(restored.type, original.type);
        expect(restored.poster, original.poster);
        expect(restored.source, original.source);
      });

      test('minimal item survives roundtrip', () {
        final original = MyListItem(
          title: 'Minimal',
          type: 'movie',
          addedAt: DateTime(2026),
        );

        final json = original.toJson();
        final restored = MyListItem.fromJson(json);

        expect(restored.title, 'Minimal');
        expect(restored.type, 'movie');
        expect(restored.source, MyListSource.local);
        expect(restored.traktId, isNull);
        expect(restored.imdbId, isNull);
        expect(restored.tmdbId, isNull);
        expect(restored.poster, isNull);
      });

      test('source serializes as string', () {
        final local = MyListItem(title: 'L', type: 'movie', addedAt: DateTime(2026), source: MyListSource.local);
        final trakt = MyListItem(title: 'T', type: 'movie', addedAt: DateTime(2026), source: MyListSource.trakt);

        expect(local.toJson()['source'], 'local');
        expect(trakt.toJson()['source'], 'trakt');
      });

      test('unknown source string defaults to local', () {
        final json = {'title': 'X', 'type': 'movie', 'addedAt': '2026-01-01T00:00:00.000', 'source': 'unknown'};
        final item = MyListItem.fromJson(json);
        expect(item.source, MyListSource.local);
      });
    });

    group('fromMovieDetail factory', () {
      test('detects IMDb ID from tt-prefixed id', () {
        final item = MyListItem.fromMovieDetail(
          id: 'tt1375666',
          name: 'Inception',
          type: 'movie',
        );
        expect(item.imdbId, 'tt1375666');
        expect(item.tmdbId, isNull);
      });

      test('detects TMDB ID from numeric id', () {
        final item = MyListItem.fromMovieDetail(
          id: '27205',
          name: 'Inception',
          type: 'movie',
        );
        expect(item.tmdbId, 27205);
        expect(item.imdbId, isNull);
      });

      test('maps series and anime types to series', () {
        final series = MyListItem.fromMovieDetail(id: '1', name: 'Show', type: 'series');
        final anime = MyListItem.fromMovieDetail(id: '2', name: 'Anime', type: 'anime');
        final movie = MyListItem.fromMovieDetail(id: '3', name: 'Movie', type: 'movie');

        expect(series.type, 'series');
        expect(anime.type, 'series');
        expect(movie.type, 'movie');
      });

      test('parses year from string', () {
        final item = MyListItem.fromMovieDetail(
          id: '1', name: 'Test', type: 'movie', year: '2024',
        );
        expect(item.year, 2024);
      });

      test('handles non-numeric year gracefully', () {
        final item = MyListItem.fromMovieDetail(
          id: '1', name: 'Test', type: 'movie', year: '2024-present',
        );
        expect(item.year, 2024);
      });

      test('sets source to local', () {
        final item = MyListItem.fromMovieDetail(id: '1', name: 'T', type: 'movie');
        expect(item.source, MyListSource.local);
      });
    });

    group('fromTraktJson factory', () {
      test('parses movie watchlist item', () {
        final json = {
          'listed_at': '2026-08-11T12:00:00.000Z',
          'movie': {
            'title': 'Inception',
            'year': 2010,
            'ids': {'trakt': 100, 'imdb': 'tt1375666', 'tmdb': 27205},
          },
        };
        final item = MyListItem.fromTraktJson(json);
        expect(item.traktId, 100);
        expect(item.imdbId, 'tt1375666');
        expect(item.tmdbId, 27205);
        expect(item.title, 'Inception');
        expect(item.year, 2010);
        expect(item.type, 'movie');
        expect(item.source, MyListSource.trakt);
      });

      test('parses show watchlist item', () {
        final json = {
          'listed_at': '2026-01-01T00:00:00.000Z',
          'show': {
            'title': 'Breaking Bad',
            'year': 2008,
            'ids': {'trakt': 200, 'imdb': 'tt0903747', 'tmdb': 1396},
          },
        };
        final item = MyListItem.fromTraktJson(json);
        expect(item.traktId, 200);
        expect(item.type, 'series');
      });

      test('handles missing listed_at', () {
        final json = {
          'movie': {
            'title': 'No Date',
            'year': 2025,
            'ids': {'trakt': 300},
          },
        };
        final item = MyListItem.fromTraktJson(json);
        expect(item.title, 'No Date');
        expect(item.addedAt, isNotNull);
      });

      test('handles missing ids gracefully', () {
        final json = {
          'movie': {'title': 'No IDs', 'year': 2020},
        };
        final item = MyListItem.fromTraktJson(json);
        expect(item.title, 'No IDs');
        expect(item.traktId, isNull);
        expect(item.imdbId, isNull);
        expect(item.tmdbId, isNull);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = MyListItem(
          traktId: 1, title: 'Original', type: 'movie',
          addedAt: DateTime(2026), source: MyListSource.trakt,
        );
        final copy = original.copyWith(title: 'Updated');
        expect(copy.title, 'Updated');
        expect(copy.traktId, 1);
        expect(copy.type, 'movie');
        expect(copy.source, MyListSource.trakt);
      });

      test('does not mutate original', () {
        final original = MyListItem(
          title: 'Original', type: 'movie', addedAt: DateTime(2026),
        );
        original.copyWith(title: 'New');
        expect(original.title, 'Original');
      });
    });

    group('edge cases', () {
      test('imdbId passed explicitly is used', () {
        final item = MyListItem.fromMovieDetail(
          id: 'generic123', name: 'Test', type: 'movie', imdbId: 'tt9999999',
        );
        expect(item.imdbId, 'tt9999999');
        expect(item.tmdbId, isNull); // generic123 is not a valid integer
      });

      test('tmdbId passed explicitly overrides numeric id parse', () {
        final item = MyListItem.fromMovieDetail(
          id: '999', name: 'Test', type: 'movie', tmdbId: 500,
        );
        expect(item.tmdbId, 500);
      });
    });
  });
}
