import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/anime/anime_media.dart';
import '../content/content_settings.dart';

class AnilistService {
  static final AnilistService instance = AnilistService._internal();
  AnilistService._internal();

  static const String _endpoint = 'https://graphql.anilist.co';

  final Map<String, dynamic> _memoryCache = {};

  static String currentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'WINTER';
    if (month >= 4 && month <= 6) return 'SPRING';
    if (month >= 7 && month <= 9) return 'SUMMER';
    return 'FALL';
  }

  static String nextSeason() {
    final current = currentSeason();
    switch (current) {
      case 'WINTER':
        return 'SPRING';
      case 'SPRING':
        return 'SUMMER';
      case 'SUMMER':
        return 'FALL';
      case 'FALL':
        return 'WINTER';
      default:
        return 'WINTER';
    }
  }

  static int nextSeasonYear() {
    final now = DateTime.now();
    return currentSeason() == 'FALL' ? now.year + 1 : now.year;
  }

  Future<Map<String, dynamic>?> _postGraphQL(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final cacheKey = '$query:${jsonEncode(variables)}';
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey] as Map<String, dynamic>?;
    }

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          'Origin': 'https://anilist.co',
          'Referer': 'https://anilist.co/',
        },
        body: jsonEncode({
          'query': query,
          'variables': variables,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (decoded.containsKey('data')) {
          final data = decoded['data'] as Map<String, dynamic>;
          _memoryCache[cacheKey] = data;
          return data;
        }
      } else {
        debugPrint('AniList API error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('AniList API request failed: $e');
    }
    return null;
  }

  static const String _mediaFields = '''
    id
    idMal
    title {
      romaji
      english
      native
      userPreferred
    }
    coverImage {
      extraLarge
      large
      medium
      color
    }
    bannerImage
    format
    status
    episodes
    duration
    genres
    averageScore
    meanScore
    popularity
    favourites
    season
    seasonYear
    isAdult
    description(asHtml: false)
    studios(isMain: true) {
      nodes {
        id
        name
      }
    }
    trailer {
      id
      site
    }
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
  ''';

  /// Trending Anime
  Future<List<AnimeMedia>> fetchTrendingAnime({
    int page = 1,
    int perPage = 20,
  }) async {
    final query = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: TRENDING_DESC, isAdult: ${ContentSettings.adultEnabled.value}) {
            $_mediaFields
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {'page': page, 'perPage': perPage});
    return _parseMediaList(data);
  }

  /// Popular This Season
  Future<List<AnimeMedia>> fetchPopularThisSeason({
    int page = 1,
    int perPage = 20,
  }) async {
    final query = '''
      query (\$page: Int, \$perPage: Int, \$season: MediaSeason, \$seasonYear: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, season: \$season, seasonYear: \$seasonYear, sort: POPULARITY_DESC, isAdult: ${ContentSettings.adultEnabled.value}) {
            $_mediaFields
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {
      'page': page,
      'perPage': perPage,
      'season': currentSeason(),
      'seasonYear': DateTime.now().year,
    });
    return _parseMediaList(data);
  }

  /// Upcoming Next Season
  Future<List<AnimeMedia>> fetchUpcomingNextSeason({
    int page = 1,
    int perPage = 20,
  }) async {
    final query = '''
      query (\$page: Int, \$perPage: Int, \$season: MediaSeason, \$seasonYear: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, season: \$season, seasonYear: \$seasonYear, sort: POPULARITY_DESC, isAdult: ${ContentSettings.adultEnabled.value}) {
            $_mediaFields
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {
      'page': page,
      'perPage': perPage,
      'season': nextSeason(),
      'seasonYear': nextSeasonYear(),
    });
    return _parseMediaList(data);
  }

  /// All-Time Top Rated
  Future<List<AnimeMedia>> fetchTopRated({
    int page = 1,
    int perPage = 20,
  }) async {
    final query = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: SCORE_DESC, isAdult: ${ContentSettings.adultEnabled.value}) {
            $_mediaFields
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {'page': page, 'perPage': perPage});
    return _parseMediaList(data);
  }

  /// Filter By Genre
  Future<List<AnimeMedia>> fetchByGenre(
    String genre, {
    int page = 1,
    int perPage = 20,
  }) async {
    final query = '''
      query (\$page: Int, \$perPage: Int, \$genre: String) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, genre: \$genre, sort: POPULARITY_DESC, isAdult: ${ContentSettings.adultEnabled.value}) {
            $_mediaFields
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {
      'page': page,
      'perPage': perPage,
      'genre': genre,
    });
    return _parseMediaList(data);
  }

  /// Search Anime
  Future<List<AnimeMedia>> searchAnime(
    String search, {
    String? genre,
    int? year,
    String? season,
    String? format,
    String? status,
    String sort = 'SEARCH_MATCH',
    bool isAdult = false,
    int page = 1,
    int perPage = 30,
  }) async {
    final hasSearch = search.trim().isNotEmpty;
    final sortClause = hasSearch ? '[SEARCH_MATCH, POPULARITY_DESC]' : '[$sort]';
    final isAdultFinal = ContentSettings.adultEnabled.value &&
        (isAdult || (genre != null && genre.toLowerCase() == 'hentai'));

    final query = '''
      query (\$page: Int, \$perPage: Int, \$search: String, \$genre: String, \$year: Int, \$season: MediaSeason, \$format: MediaFormat, \$status: MediaStatus, \$isAdult: Boolean) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, search: \$search, genre: \$genre, seasonYear: \$year, season: \$season, format: \$format, status: \$status, sort: $sortClause, isAdult: \$isAdult) {
            $_mediaFields
          }
        }
      }
    ''';

    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'isAdult': isAdultFinal,
      if (hasSearch) 'search': search.trim(),
      if (genre != null && genre.isNotEmpty && genre != 'All') 'genre': genre,
      if (year != null) 'year': year,
      if (season != null && season.isNotEmpty && season != 'All') 'season': season.toUpperCase(),
      if (format != null && format.isNotEmpty && format != 'All')
        'format': format.toUpperCase(),
      if (status != null && status.isNotEmpty && status != 'All')
        'status': status.toUpperCase(),
    };

    final data = await _postGraphQL(query, variables);
    return _parseMediaList(data);
  }

  /// Browse Anime with Filter Parameters
  Future<List<AnimeMedia>> browseAnime({
    String? genre,
    int? year,
    String? season,
    String? format,
    String? status,
    String sort = 'TRENDING_DESC',
    bool isAdult = false,
    int page = 1,
    int perPage = 30,
  }) async {
    return searchAnime(
      '',
      genre: genre,
      year: year,
      season: season,
      format: format,
      status: status,
      sort: sort,
      isAdult: isAdult,
      page: page,
      perPage: perPage,
    );
  }

  /// Full Anime Details (Including Voice Actors/Characters, Relations, Recommendations)
  Future<AnimeMedia?> fetchAnimeDetails(int anilistId) async {
    const query = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          $_mediaFields
          characters(sort: ROLE, perPage: 8) {
            nodes {
              id
              name {
                full
                native
                userPreferred
              }
              image {
                large
                medium
              }
            }
          }
          relations {
            edges {
              relationType
              node {
                id
                title {
                  userPreferred
                  english
                  romaji
                }
                format
                type
                status
                coverImage {
                  large
                  medium
                }
              }
            }
          }
          recommendations(perPage: 12, sort: RATING_DESC) {
            nodes {
              mediaRecommendation {
                id
                title {
                  userPreferred
                  english
                  romaji
                }
                coverImage {
                  large
                  medium
                }
                format
                averageScore
              }
            }
          }
        }
      }
    ''';

    final data = await _postGraphQL(query, {'id': anilistId});
    if (data != null && data.containsKey('Media') && data['Media'] is Map) {
      return AnimeMedia.fromAnilistJson(data['Media'] as Map<String, dynamic>);
    }
    return null;
  }

  List<AnimeMedia> _parseMediaList(Map<String, dynamic>? data) {
    if (data == null) return [];
    final page = data['Page'];
    if (page is Map<String, dynamic> && page['media'] is List) {
      return (page['media'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => AnimeMedia.fromAnilistJson(m))
          .toList();
    }
    return [];
  }
}
