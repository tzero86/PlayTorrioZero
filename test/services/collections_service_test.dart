import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/services/collections/collections_service.dart';
import 'package:zplay/services/collections/curated_collection.dart';
import 'package:zplay/services/collections/curated_collections.dart';
import 'package:zplay/services/collections/curated_sagas.dart';

final RegExp _imdbId = RegExp(r'^tt\d{7,}$');

const List<String> _sagaIds = [
  'saga_godfather',
  'saga_rocky',
  'saga_back_to_the_future',
  'saga_alien',
  'saga_die_hard',
  'saga_lethal_weapon',
  'saga_terminator',
  'saga_predator',
  'saga_jurassic_park',
  'saga_rambo',
  'saga_indiana_jones',
  'saga_marx_brothers',
];

/// Curated data is bundled, so every rule below is a static invariant.
void main() {
  group('curatedCollections', () {
    test('ids are unique', () {
      final ids = curatedCollections.map((c) => c.id).toSet();
      expect(ids.length, curatedCollections.length);
    });

    test('sagas ship the verified packs', () {
      expect(curatedSagas.map((c) => c.id).toList(), _sagaIds);
      for (final collection in curatedSagas) {
        expect(collection.kind, CuratedKind.saga);
      }
    });

    test('every collection has at least two items', () {
      for (final collection in curatedCollections) {
        expect(
          collection.count,
          greaterThanOrEqualTo(2),
          reason: collection.id,
        );
      }
    });

    test('every item has an imdb id, a title and a plausible year', () {
      for (final collection in curatedCollections) {
        for (final item in collection.items) {
          expect(_imdbId.hasMatch(item.imdbId), isTrue, reason: item.imdbId);
          expect(item.title.trim(), isNotEmpty, reason: item.imdbId);
          expect(item.year, inInclusiveRange(1900, 2026), reason: item.imdbId);
        }
      }
    });

    test('item ids are unique within a collection', () {
      for (final collection in curatedCollections) {
        final ids = collection.items.map((i) => i.imdbId).toSet();
        expect(ids.length, collection.count, reason: collection.id);
      }
    });

    test('saga items run in release order', () {
      for (final collection in curatedSagas) {
        for (var i = 1; i < collection.items.length; i++) {
          expect(
            collection.items[i].year,
            greaterThanOrEqualTo(collection.items[i - 1].year),
            reason: collection.id,
          );
        }
      }
    });

    test('1990s rails hold only 1990s films', () {
      final nineties =
          curatedCollections.where((c) => c.id.startsWith('era_90s_'));
      expect(nineties, isNotEmpty);
      for (final collection in nineties) {
        for (final item in collection.items) {
          expect(item.year, inInclusiveRange(1990, 1999), reason: item.imdbId);
        }
      }
    });
  });

  group('CollectionsService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CollectionsService.initialize();
    });

    test('shows curated rails on Home by default', () {
      expect(CollectionsService.showOnHome.value, isTrue);
    });

    test('persists the Home visibility toggle', () async {
      CollectionsService.showOnHome.value = false;
      await pumpEventQueue();
      expect(CollectionsService.showOnHome.value, isFalse);

      await CollectionsService.initialize();
      expect(CollectionsService.showOnHome.value, isFalse);
    });

    test('movieFor builds an offline cinemeta movie', () {
      final item = curatedCollections.first.items.first;
      final movie = CollectionsService.movieFor(item);

      expect(movie.id, item.imdbId);
      expect(movie.name, item.title);
      expect(movie.year, item.year.toString());
      expect(movie.type, 'movie');
      expect(movie.addonBaseUrl, 'https://v3-cinemeta.strem.io');
      expect(
        movie.poster,
        'https://images.metahub.space/poster/medium/${item.imdbId}/img',
      );
    });

    test('sectionFor builds a movie catalog section', () {
      final collection = curatedCollections.first;
      final section = CollectionsService.sectionFor(collection);

      expect(section.title, collection.title);
      expect(section.subtitle, collection.subtitle);
      expect(section.contentType, 'movie');
      expect(section.addonBaseUrl, 'https://v3-cinemeta.strem.io');
      expect(section.catalog.type, 'movie');
      expect(section.catalog.id, 'curated_${collection.id}');
      expect(section.catalog.name, collection.title);
      expect(section.movies.length, collection.count);
    });

    test('homeSections has one section per collection', () {
      final sections = CollectionsService.homeSections();

      expect(sections.length, curatedCollections.length);
      expect(
        sections.map((s) => s.title).toList(),
        curatedCollections.map((c) => c.title).toList(),
      );
    });
  });
}
