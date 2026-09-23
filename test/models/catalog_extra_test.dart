import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/addon/addon.dart';
import 'package:zplay/services/metadata/metadata_service.dart';

void main() {
  group('CatalogExtra Model & Manifest Parsing', () {
    test('parses rich extra objects with isRequired, options, optionsLimit', () {
      final catalogJson = {
        'type': 'movie',
        'id': 'custom_catalog',
        'name': 'Custom Catalog',
        'extra': [
          {
            'name': 'tag',
            'isRequired': true,
            'options': ['action', 'comedy', 'drama'],
            'optionsLimit': 1,
          },
          {
            'name': 'performer',
            'isRequired': true,
            'optionsLimit': 2,
          },
          {
            'name': 'skip',
            'isRequired': false,
          },
        ],
      };

      final catalog = AddonCatalog.fromJson(catalogJson);

      expect(catalog.extra.length, 3);
      expect(catalog.hasRequiredExtra, isTrue);
      expect(catalog.canAutoLoadOnHome, isFalse);
      expect(catalog.supportsSkip, isTrue);
      expect(catalog.supportsSearch, isFalse);

      final tagExtra = catalog.getExtra('tag');
      expect(tagExtra, isNotNull);
      expect(tagExtra!.isRequired, isTrue);
      expect(tagExtra.options, ['action', 'comedy', 'drama']);
      expect(tagExtra.optionsLimit, 1);

      final performerExtra = catalog.getExtra('performer');
      expect(performerExtra, isNotNull);
      expect(performerExtra!.isRequired, isTrue);
      expect(performerExtra.optionsLimit, 2);

      expect(catalog.requiredExtras.map((e) => e.name), ['tag', 'performer']);
      expect(catalog.selectableExtras.map((e) => e.name), ['tag']);
    });

    test('User reproduction scenario: Recent vs Tag vs Performer', () {
      final manifestJson = {
        'id': 'org.example.customsource',
        'name': 'Custom Source',
        'version': '1.0.0',
        'resources': ['catalog', 'meta', 'stream'],
        'types': ['movie'],
        'catalogs': [
          {
            'type': 'movie',
            'id': 'recent',
            'name': 'Recent',
            'extra': [
              {'name': 'skip', 'isRequired': false}
            ],
          },
          {
            'type': 'movie',
            'id': 'tag',
            'name': 'Tag',
            'extra': [
              {
                'name': 'tag',
                'isRequired': true,
                'options': ['action', 'comedy', 'drama']
              },
              {'name': 'skip', 'isRequired': false}
            ],
          },
          {
            'type': 'movie',
            'id': 'performer',
            'name': 'Performer',
            'extra': [
              {
                'name': 'performer',
                'isRequired': true,
              },
              {'name': 'skip', 'isRequired': false}
            ],
          },
          {
            'type': 'movie',
            'id': 'required_search',
            'name': 'Search Only',
            'extra': [
              {'name': 'search', 'isRequired': true}
            ],
          }
        ],
      };

      final manifest = AddonManifest.fromJson(manifestJson);

      final recent = manifest.catalogs[0];
      final tag = manifest.catalogs[1];
      final performer = manifest.catalogs[2];
      final requiredSearch = manifest.catalogs[3];

      // Recent: No required extras -> can appear on Home/Board
      expect(recent.hasRequiredExtra, isFalse);
      expect(recent.canAutoLoadOnHome, isTrue);

      // Tag: Required extra -> cannot auto-load on Home, must be gated in Discover
      expect(tag.hasRequiredExtra, isTrue);
      expect(tag.canAutoLoadOnHome, isFalse);
      expect(tag.requiredExtras.first.name, 'tag');
      expect(tag.selectableExtras.first.options, contains('comedy'));

      // Performer: Required extra -> cannot auto-load on Home
      expect(performer.hasRequiredExtra, isTrue);
      expect(performer.canAutoLoadOnHome, isFalse);
      expect(performer.requiredExtras.first.name, 'performer');

      // Required Search: Cannot auto-load on Home, supports search
      expect(requiredSearch.hasRequiredExtra, isTrue);
      expect(requiredSearch.isSearchRequired, isTrue);
      expect(requiredSearch.canAutoLoadOnHome, isFalse);
      expect(requiredSearch.supportsSearch, isTrue);
    });

    test('parses legacy string-based extra list and extraRequired', () {
      final legacyJson = {
        'type': 'movie',
        'id': 'legacy_cat',
        'name': 'Legacy Catalog',
        'extra': ['search', 'genre', 'skip'],
        'extraRequired': ['search'],
        'genres': ['Horror', 'Sci-Fi'],
      };

      final catalog = AddonCatalog.fromJson(legacyJson);

      expect(catalog.supportsSearch, isTrue);
      expect(catalog.isSearchRequired, isTrue);
      expect(catalog.hasRequiredExtra, isTrue);
      expect(catalog.canAutoLoadOnHome, isFalse);
      expect(catalog.supportsSkip, isTrue);
      expect(catalog.genres, ['Horror', 'Sci-Fi']);
    });

    test('toJson preserves all custom extra properties', () {
      final catalog = AddonCatalog(
        type: 'movie',
        id: 'test_cat',
        name: 'Test Cat',
        extra: [
          const CatalogExtra(
            name: 'custom_sort',
            isRequired: true,
            options: ['votes', 'rating', 'date'],
            optionsLimit: 1,
          ),
          const CatalogExtra(
            name: 'skip',
            isRequired: false,
          ),
        ],
      );

      final json = catalog.toJson();
      final restored = AddonCatalog.fromJson(json);

      expect(restored.extra.length, 2);
      expect(restored.hasRequiredExtra, isTrue);
      final customSort = restored.getExtra('custom_sort');
      expect(customSort, isNotNull);
      expect(customSort!.isRequired, isTrue);
      expect(customSort.options, ['votes', 'rating', 'date']);
      expect(customSort.optionsLimit, 1);
    });
  });

  group('MetadataService.buildCatalogUrl', () {
    const baseUrl = 'https://addon.example.com';

    test('builds URL with no extras without trailing slash before .json', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: baseUrl,
        type: 'movie',
        catalogId: 'top',
      );
      expect(url, 'https://addon.example.com/catalog/movie/top.json');
    });

    test('builds URL with single extra parameter', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: baseUrl,
        type: 'movie',
        catalogId: 'tag',
        extraParams: {'tag': 'action'},
      );
      expect(url, 'https://addon.example.com/catalog/movie/tag/tag=action.json');
    });

    test('builds URL with multiple extra parameters', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: baseUrl,
        type: 'movie',
        catalogId: 'tag',
        extraParams: {'tag': 'action', 'skip': '20'},
      );
      expect(url, 'https://addon.example.com/catalog/movie/tag/tag=action&skip=20.json');
    });

    test('builds URL with search parameter', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: baseUrl,
        type: 'movie',
        catalogId: 'search_cat',
        extraParams: {'search': 'The Dark Knight'},
      );
      expect(url, 'https://addon.example.com/catalog/movie/search_cat/search=The%20Dark%20Knight.json');
    });

    test('builds URL encoding special characters properly', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: baseUrl,
        type: 'movie',
        catalogId: 'by_genre',
        extraParams: {'genre': 'Sci-Fi & Fantasy'},
      );
      expect(url, 'https://addon.example.com/catalog/movie/by_genre/genre=Sci-Fi%20%26%20Fantasy.json');
    });
  });
}
