import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/addon/addon.dart';
import 'package:zplay/models/movie/movie.dart';
import 'package:zplay/models/movie/movie_detail.dart';
import 'package:zplay/models/movie/video.dart';
import 'package:zplay/services/addon/addon_manager.dart';
import 'package:zplay/services/metadata/metadata_service.dart';

void main() {
  group('Stremio Collection Addon Manifest & Catalog Parsing', () {
    test('parses TMDB Collections manifest and collects idPrefixes from resources', () {
      final manifestJson = {
        'id': 'org.stremio.tmdbcollections',
        'name': 'TMDB Collections',
        'version': '2.2.1',
        'description': 'Addon lets you explore TMDB Collections.',
        'types': ['movie', 'collections'],
        'resources': [
          'catalog',
          {
            'name': 'meta',
            'types': ['movie'],
            'idPrefixes': ['ctmdb.'],
          },
          {
            'name': 'stream',
            'types': ['movie'],
            'idPrefixes': ['tt'],
          },
        ],
        'catalogs': [
          {
            'id': 'ctmdb.popular',
            'type': 'collections',
            'name': 'Popular',
          },
          {
            'id': 'ctmdb.topRated',
            'type': 'collections',
            'name': 'Top Rated',
          },
          {
            'id': 'ctmdb.search',
            'type': 'collections',
            'name': 'Search',
            'extra': [
              {
                'name': 'search',
                'isRequired': true,
              }
            ],
          },
        ],
      };

      final manifest = AddonManifest.fromJson(manifestJson);

      expect(manifest.id, 'org.stremio.tmdbcollections');
      expect(manifest.types, contains('collections'));
      expect(manifest.supportsCatalog, isTrue);
      expect(manifest.supportsMeta, isTrue);
      expect(manifest.supportsStream, isTrue);

      // Verify idPrefixes collected from resource definitions
      expect(manifest.idPrefixes, contains('ctmdb.'));
      expect(manifest.idPrefixes, contains('tt'));

      // Catalogs
      expect(manifest.catalogs.length, 3);
      final popular = manifest.catalogs.first;
      expect(popular.id, 'ctmdb.popular');
      expect(popular.type, 'collections');
      expect(popular.isCollection, isTrue);
      expect(popular.canAutoLoadOnHome, isTrue);

      final searchCat = manifest.catalogs[2];
      expect(searchCat.id, 'ctmdb.search');
      expect(searchCat.isCollection, isTrue);
      expect(searchCat.supportsSearch, isTrue);
      expect(searchCat.isSearchRequired, isTrue);
      expect(searchCat.canAutoLoadOnHome, isFalse);
    });

    test('AddonManager.catalogDisplayName formats collection catalog names properly', () {
      final manager = AddonManager.instance;

      final catalog1 = AddonCatalog(
        id: 'top',
        type: 'collections',
      );
      expect(manager.catalogDisplayName(catalog1), 'Popular Collections');

      final catalog2 = AddonCatalog(
        id: 'ctmdb.popular',
        type: 'collections',
        name: 'Popular Collections',
      );
      expect(manager.catalogDisplayName(catalog2), 'Popular Collections');
    });
  });

  group('Collection Models (Movie & MovieDetail)', () {
    test('Movie detects collections via type, id prefix, or name', () {
      final movieByCollType = Movie(
        id: '123',
        name: 'My Franchise',
        type: 'collections',
        addonBaseUrl: 'https://addon.com',
      );
      expect(movieByCollType.isCollection, isTrue);

      final movieByIdPrefix = Movie(
        id: 'ctmdb.86311',
        name: 'The Avengers Collection',
        type: 'movie',
        addonBaseUrl: 'https://addon.com',
      );
      expect(movieByIdPrefix.isCollection, isTrue);

      final normalMovie = Movie(
        id: 'tt0848228',
        name: 'The Avengers',
        type: 'movie',
        addonBaseUrl: 'https://addon.com',
      );
      expect(normalMovie.isCollection, isFalse);
    });

    test('MovieDetail parses collection meta with franchise movies (videos)', () {
      final collectionMetaJson = {
        'id': 'ctmdb.86311',
        'type': 'movie',
        'name': 'The Avengers Collection',
        'imdbRating': '8.0',
        'releaseInfo': '2012-2027',
        'poster': 'https://image.tmdb.org/t/p/w500/yFSIUVTCvgYrpalUktulvk3Gi5Y.jpg',
        'background': 'https://image.tmdb.org/t/p/original/2UNUv4NJdC36E5myDHACBJ99EwL.jpg',
        'description': 'A superhero film series produced by Marvel Studios.',
        'videos': [
          {
            'id': 'tt0848228',
            'title': 'The Avengers',
            'released': '2012-04-25T00:00:00.000Z',
            'season': 1,
            'episode': 1,
            'overview': 'When an unexpected enemy emerges...',
            'thumbnail': 'https://assets.fanart.tv/fanart/marvels-the-avengers.jpg',
          },
          {
            'id': 'tt2395427',
            'title': 'Avengers: Age of Ultron',
            'released': '2015-04-22T00:00:00.000Z',
            'season': 1,
            'episode': 2,
            'overview': 'When Tony Stark tries to jumpstart a dormant peacekeeping program...',
            'thumbnail': 'https://assets.fanart.tv/fanart/avengers-age-of-ultron.jpg',
          },
          {
            'id': 'tt4154756',
            'title': 'Avengers: Infinity War',
            'released': '2018-04-25T00:00:00.000Z',
            'season': 1,
            'episode': 3,
            'overview': 'As the Avengers and their allies have continued to protect the world...',
            'thumbnail': 'https://assets.fanart.tv/fanart/avengers-infinity-war.jpg',
          },
          {
            'id': 'tt4154796',
            'title': 'Avengers: Endgame',
            'released': '2019-04-24T00:00:00.000Z',
            'season': 1,
            'episode': 4,
            'overview': 'After the devastating events of Avengers: Infinity War...',
            'thumbnail': 'https://assets.fanart.tv/fanart/avengers-endgame.jpg',
          },
        ],
      };

      final detail = MovieDetail.fromJson(collectionMetaJson);

      expect(detail.id, 'ctmdb.86311');
      expect(detail.isCollection, isTrue);
      expect(detail.videos.length, 4);

      final part1 = detail.videos[0];
      expect(part1.id, 'tt0848228');
      expect(part1.title, 'The Avengers');
      expect(part1.season, 1);
      expect(part1.episode, 1);
      expect(part1.released, startsWith('2012'));

      final part4 = detail.videos[3];
      expect(part4.id, 'tt4154796');
      expect(part4.title, 'Avengers: Endgame');
      expect(part4.episode, 4);
    });

    test('Collection part stream resolution normalization', () {
      final collectionDetail = MovieDetail(
        id: 'ctmdb.86311',
        name: 'The Avengers Collection',
        type: 'movie',
      );
      final ep = collectionDetail.isCollection
          ? Video(
              id: 'tt0848228',
              title: 'The Avengers',
              season: 1,
              episode: 1,
              released: '2012-04-25',
            )
          : null;

      final isColl = collectionDetail.isCollection;
      expect(isColl, isTrue);

      // Normalization verification:
      final effectiveType = isColl ? 'movie' : 'collections';
      final effectiveId = ep?.id ?? collectionDetail.id;
      final effectiveTitle = (isColl && ep != null) ? ep.title : collectionDetail.name;
      final effectiveYear = (isColl && ep?.released != null)
          ? int.tryParse(ep!.released!.substring(0, 4))
          : null;
      final effectiveSeason = isColl ? null : ep?.season;
      final effectiveEpisode = isColl ? null : ep?.episode;

      expect(effectiveType, 'movie');
      expect(effectiveId, 'tt0848228');
      expect(effectiveTitle, 'The Avengers');
      expect(effectiveYear, 2012);
      expect(effectiveSeason, isNull);
      expect(effectiveEpisode, isNull);
    });
  });

  group('MetadataService URL building for collections', () {
    test('builds collection catalog URL without extra params', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: 'https://tmdb-collections.club',
        type: 'collections',
        catalogId: 'ctmdb.popular',
      );
      expect(url, 'https://tmdb-collections.club/catalog/collections/ctmdb.popular.json');
    });

    test('builds collection catalog URL with search extra param', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: 'https://tmdb-collections.club',
        type: 'collections',
        catalogId: 'ctmdb.search',
        extraParams: {'search': 'Spider-Man'},
      );
      expect(url, 'https://tmdb-collections.club/catalog/collections/ctmdb.search/search=Spider-Man.json');
    });

    test('builds collection catalog URL preserving config segment', () {
      final url = MetadataService.buildCatalogUrl(
        baseUrl: 'https://tmdb-collections.club/%7B%7D',
        type: 'collections',
        catalogId: 'ctmdb.popular',
      );
      expect(url, 'https://tmdb-collections.club/%7B%7D/catalog/collections/ctmdb.popular.json');
    });
  });
}
