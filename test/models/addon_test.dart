import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/addon/addon.dart';

void main() {
  group('AddonManifest', () {
    test('parses minimal manifest', () {
      final json = {
        'id': 'community.cinemeta',
        'name': 'Cinemeta',
        'version': '1.0.0',
        'resources': ['catalog', 'meta', 'stream'],
        'types': ['movie', 'series'],
        'catalogs': [
          {'type': 'movie', 'id': 'top', 'name': 'Top Movies'}
        ],
      };
      final manifest = AddonManifest.fromJson(json);
      expect(manifest.id, 'community.cinemeta');
      expect(manifest.name, 'Cinemeta');
      expect(manifest.version, '1.0.0');
      expect(manifest.resources, contains('catalog'));
      expect(manifest.types, contains('movie'));
      expect(manifest.catalogs.length, 1);
    });

    test('parses catalog with search support', () {
      final json = {
        'id': 'test.addon',
        'name': 'Test',
        'version': '1.0.0',
        'resources': ['catalog'],
        'types': ['movie'],
        'catalogs': [
          {
            'type': 'movie',
            'id': 'search',
            'name': 'Search',
            'extra': [{'name': 'search', 'isRequired': false}],
          }
        ],
      };
      final manifest = AddonManifest.fromJson(json);
      expect(manifest.catalogs.first.supportsSearch, true);
    });

    test('parses catalog with genres', () {
      final json = {
        'id': 'test.addon',
        'name': 'Test',
        'version': '1.0.0',
        'resources': ['catalog'],
        'types': ['movie'],
        'catalogs': [
          {
            'type': 'movie',
            'id': 'genre',
            'name': 'By Genre',
            'genres': ['Action', 'Comedy', 'Drama'],
          }
        ],
      };
      final manifest = AddonManifest.fromJson(json);
      expect(manifest.catalogs.first.genres, contains('Action'));
    });

    test('handles empty catalogs', () {
      final json = {
        'id': 'test.addon',
        'name': 'Test',
        'version': '1.0.0',
        'resources': ['stream'],
        'types': ['movie'],
        'catalogs': [],
      };
      final manifest = AddonManifest.fromJson(json);
      expect(manifest.catalogs, isEmpty);
    });
  });

  group('InstalledAddon', () {
    test('toJson and fromJson roundtrip', () {
      final manifest = AddonManifest.fromJson({
        'id': 'test.addon',
        'name': 'Test Addon',
        'version': '2.0.0',
        'resources': ['catalog', 'meta'],
        'types': ['movie'],
        'catalogs': [],
      });
      final addon = InstalledAddon(
        baseUrl: 'https://test.example.com',
        manifest: manifest,
        enabled: true,
      );

      final json = addon.toJson();
      final restored = InstalledAddon.fromJson(json);

      expect(restored.baseUrl, addon.baseUrl);
      expect(restored.manifest.id, addon.manifest.id);
      expect(restored.manifest.name, addon.manifest.name);
      expect(restored.enabled, addon.enabled);
    });

    test('disabled addon serializes correctly', () {
      final manifest = AddonManifest.fromJson({
        'id': 'test.addon', 'name': 'Test', 'version': '0.1.0',
        'resources': [], 'types': [], 'catalogs': [],
      });
      final addon = InstalledAddon(baseUrl: 'https://x.com', manifest: manifest, enabled: false);
      final json = addon.toJson();
      expect(json['enabled'], false);
    });
  });
}
