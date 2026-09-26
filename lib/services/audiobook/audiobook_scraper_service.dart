import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/audiobook/audiobook_model.dart';
import '../../utils/search/relevance_scorer.dart';
import '../config/service_credentials.dart';
import 'audiobookbay_scraper.dart';

class AudiobookScraperService {
  AudiobookScraperService._();

  static final AudiobookScraperService instance = AudiobookScraperService._();

  // List of scrapers to run in parallel (AudiobookBay first for fast results)
  final List<Future<List<Audiobook>> Function(String)> _searchScrapers = [
    AudiobookBayScraper.search,
    _searchBookAudio,
    _searchGolden,
    _searchFullLength,
    _searchHot,
    _searchAudiozaic,
    _searchAudioAZ,
    _searchAudiobooks4Soul,
    _searchAudionest,
  ];

  Future<List<Audiobook>> search(String query) async {
    final futures = _searchScrapers.map(
      (scraper) => scraper(query)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Audiobook>[])
          .catchError((e) {
            debugPrint('Audiobook scraper failed: $e');
            return <Audiobook>[];
          }),
    );

    final results = await Future.wait(futures);
    final allBooks = results.expand((x) => x).toList();

    // Sort strictly by relevance score so exact and substring matches are at the top,
    // keeping 100% of all scraped results without filtering or dropping anything!
    allBooks.sort((a, b) {
      final scoreA = RelevanceScorer.score(title: a.title, query: query);
      final scoreB = RelevanceScorer.score(title: b.title, query: query);
      return scoreB.compareTo(scoreA);
    });

    return allBooks;
  }

  Future<List<AudiobookChapter>> getChapters(Audiobook book) async {
    try {
      switch (book.source) {
        case 'goldenaudiobooks':
          return await _getStandardWpChapters(book.pageUrl);
        case 'fulllengthaudiobooks':
          return await _getStandardWpChapters(book.pageUrl);
        case 'hotaudiobooks':
          return await _getStandardWpChapters(book.pageUrl);
        case 'bookaudiobooks':
          return await _getStandardWpChapters(book.pageUrl);
        case 'audiozaic':
          return await _getAudiozaicChapters(book.pageUrl);
        case 'audioaz':
          return await _getAudioAZChapters(book.pageUrl);
        case 'audiobooks4soul':
          return await _getAudiobooks4SoulChapters(book.pageUrl);
        case 'audionest':
          return await _getAudionestChapters(book.audioBookId);
        case 'audiobookbay':
          return await AudiobookBayScraper.getChapters(book.pageUrl);
        default:
          return [];
      }
    } catch (e) {
      debugPrint('Failed to fetch chapters for ${book.title}: $e');
      return [];
    }
  }

  // --- Helper Methods ---

  static Future<http.Response> _fetch(String url) {
    return http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );
  }

  static List<String> _extractWpAudio(String html) {
    final RegExp sourceRegExp = RegExp(r'<source[^>]*src="([^"]+)"');
    final matches = sourceRegExp.allMatches(html);
    return matches.map((m) => m.group(1)!).toList();
  }

  static String _cleanAudiobookTitle(String rawTitle) {
    var title = rawTitle;

    // 1. Decode HTML entities
    title = title
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // 2. Remove [Listen], [Download], [Audiobook], etc. prefixes/tags
    title = title.replaceAll(
      RegExp(r'\[\s*(?:Listen|Download|Audiobook|Stream|MP3|Free)\s*\]', caseSensitive: false),
      '',
    );

    // 3. Extract title inside quotes if present (e.g. “The Martian ” or "The Martian")
    final quoteMatch = RegExp(r'["“]([^"”]+)["”]').firstMatch(title);
    if (quoteMatch != null && quoteMatch.group(1)!.trim().isNotEmpty) {
      title = quoteMatch.group(1)!;
    }

    // 4. Remove leftover quote characters, Audiobook suffix, trailing commas/hyphens
    title = title
        .replaceAll(RegExp('["“„”\'\']'), '')
        .replaceAll(RegExp(r'\s*Audiobook\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[,:\-–—\s]+$'), '')
        .replaceAll(RegExp(r'^[,:\-–—\s]+'), '')
        .trim();

    return title.isNotEmpty ? title : rawTitle.trim();
  }

  static List<Audiobook> _parseWordPressResults(
    String html,
    String sourceId,
    String prefix,
  ) {
    final books = <Audiobook>[];
    final RegExp blockExp = RegExp(
      r'(?:<article[^>]*>|<div[^>]*class="[^"]*post[^"]*"[^>]*>|<li[^>]*class="[^"]*post[^"]*"[^>]*>)([\s\S]*?)(?:</article>|div<!-- end .post -->|</div>\s*</article>|</li>)',
      caseSensitive: false,
    );
    final blocks = blockExp
        .allMatches(html)
        .map((m) => m.group(1) ?? '')
        .toList();
    final iterableBlocks = blocks.isNotEmpty ? blocks : [html];

    for (final block in iterableBlocks) {
      final titleExp = RegExp(
        r'<h[23][^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([^<]+)</a>',
        caseSensitive: false,
      );
      final titleMatch = titleExp.firstMatch(block);
      if (titleMatch == null) continue;

      final url = titleMatch.group(1)!;
      final title = _cleanAudiobookTitle(titleMatch.group(2)!);

      final imgExp = RegExp(r'<img[^>]+>', caseSensitive: false);
      final imgMatch = imgExp.firstMatch(block);
      String coverImage = '';
      if (imgMatch != null) {
        final imgTag = imgMatch.group(0)!;
        for (final attr in ['data-lazy-src', 'data-src', 'src']) {
          final attrExp = RegExp('$attr="([^"]+)"', caseSensitive: false);
          final attrMatch = attrExp.firstMatch(imgTag);
          if (attrMatch != null) {
            final val = attrMatch.group(1)!;
            if (!val.startsWith('data:image') &&
                !val.contains('histats.com') &&
                !val.contains('yandex.ru')) {
              coverImage = val;
              break;
            }
          }
        }
      }

      books.add(
        Audiobook(
          uuid: '${prefix}_$url',
          audioBookId: url,
          dynamicSlugId: url,
          title: title,
          coverImage: coverImage,
          source: sourceId,
          pageUrl: url,
        ),
      );
    }
    return books;
  }

  // --- 1. GoldenAudiobooks ---
  static Future<List<Audiobook>> _searchGolden(String query) async {
    final res = await _fetch(
      'https://goldenaudiobooks.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'goldenaudiobooks', 'golden');
  }

  // --- 2. FullLengthAudiobooks ---
  static Future<List<Audiobook>> _searchFullLength(String query) async {
    final res = await _fetch(
      'https://fulllengthaudiobooks.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'fulllengthaudiobooks', 'full');
  }

  // --- 3. HotAudiobooks ---
  static Future<List<Audiobook>> _searchHot(String query) async {
    final res = await _fetch(
      'https://hotaudiobooks.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'hotaudiobooks', 'hot');
  }

  // --- 4. BookAudiobooks ---
  static Future<List<Audiobook>> _searchBookAudio(String query) async {
    final res = await _fetch(
      'https://bookaudiobooks.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'bookaudiobooks', 'book');
  }

  // --- 5. Audiozaic ---
  static Future<List<Audiobook>> _searchAudiozaic(String query) async {
    final res = await _fetch(
      'https://audiozaic.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'audiozaic', 'zaic');
  }

  // --- 6. AudioAZ ---
  static Future<List<Audiobook>> _searchAudioAZ(String query) async {
    final res = await _fetch(
      'https://audioaz.com/en/search?q=${Uri.encodeComponent(query)}',
    );
    final RegExp bookExp = RegExp(
      r'href="(/en/(?:audiobook|archive)/[^"]+)"[^>]*title="([^"]+)"',
      caseSensitive: false,
    );
    final books = <Audiobook>[];
    for (final match in bookExp.allMatches(res.body)) {
      final url = 'https://audioaz.com${match.group(1)!}';
      books.add(
        Audiobook(
          uuid: 'az_${match.group(1)!}',
          audioBookId: url,
          dynamicSlugId: url,
          title: match.group(2)!.trim(),
          coverImage: '',
          source: 'audioaz',
          pageUrl: url,
        ),
      );
    }
    return books;
  }

  // --- 7. Audiobooks4Soul ---
  static Future<List<Audiobook>> _searchAudiobooks4Soul(String query) async {
    final res = await _fetch(
      'https://audiobooks4soul.com/?s=${Uri.encodeComponent(query)}',
    );
    return _parseWordPressResults(res.body, 'audiobooks4soul', 'soul');
  }

  // --- 8. AudionestApp ---
  static String? _audionestIdToken;
  static DateTime? _audionestIdTokenExpiry;

  static Future<String?> _audionestEnsureToken({bool force = false}) async {
    final apiKey = ServiceCredentials.value(ServiceCredential.audiobookSearch);
    if (!force &&
        _audionestIdToken != null &&
        _audionestIdTokenExpiry != null &&
        DateTime.now().isBefore(_audionestIdTokenExpiry!)) {
      return _audionestIdToken;
    }
    try {
      final res = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'returnSecureToken': true}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _audionestIdToken = data['idToken'];
        final expiresIn =
            int.tryParse('${data['expiresIn'] ?? '3600'}') ?? 3600;
        _audionestIdTokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 60),
        );
        return _audionestIdToken;
      }
    } catch (e) {
      debugPrint('Audionest auth error: $e');
    }
    return null;
  }

  static Future<List<Audiobook>> _searchAudionest(String query) async {
    try {
      final res = await http.post(
        Uri.parse('https://search.audionestapp.com/indexes/trackfiles/search'),
        headers: {
          'Authorization':
              'Bearer ${ServiceCredentials.value(ServiceCredential.audiobookService)}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'q': query, 'limit': 30}),
      );
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      final hits = data['hits'] as List?;
      if (hits == null) return [];

      return hits.map((hit) {
        final id = hit['id'].toString();
        return Audiobook(
          uuid: 'nest_$id',
          audioBookId: id,
          dynamicSlugId: id,
          title: hit['title'] ?? '',
          coverImage: hit['thumbnailUrl'] ?? hit['img_prefix'] ?? '',
          source: 'audionest',
          pageUrl: id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Audionest search error: $e');
      return [];
    }
  }

  // --- Chapter Fetchers ---

  Future<List<AudiobookChapter>> _getStandardWpChapters(String url) async {
    final res = await _fetch(url);
    final streams = _extractWpAudio(res.body);
    return List.generate(streams.length, (i) {
      final uri = Uri.parse(url);
      final host = uri.host;
      return AudiobookChapter(
        title: 'Chapter ${i + 1}',
        url: streams[i],
        httpHeaders: {
          'Referer': 'https://$host/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
    });
  }

  Future<List<AudiobookChapter>> _getAudiozaicChapters(String url) async {
    final res = await _fetch(url);
    final RegExp listenExp = RegExp(r"window\.open\('([^']+)'");
    final match = listenExp.firstMatch(res.body);
    if (match == null) return [];

    var listenUrl = match.group(1)!;
    if (listenUrl.startsWith('/')) {
      listenUrl = 'https://audiozaic.com$listenUrl';
    }

    final audioPage = await _fetch(listenUrl);
    final streams = _extractWpAudio(audioPage.body);
    return List.generate(
      streams.length,
      (i) => AudiobookChapter(
        title: 'Chapter ${i + 1}',
        url: streams[i],
        httpHeaders: {
          'Referer': 'https://audiozaic.com/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );
  }

  Future<List<AudiobookChapter>> _getAudioAZChapters(String url) async {
    final res = await _fetch(url);
    final streams = _extractWpAudio(res.body);
    return List.generate(
      streams.length,
      (i) => AudiobookChapter(
        title: streams.length == 1 ? 'Full Audiobook' : 'Part ${i + 1}',
        url: streams[i],
        httpHeaders: {
          'Referer': 'https://audioaz.com/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );
  }

  Future<List<AudiobookChapter>> _getAudiobooks4SoulChapters(String url) async {
    final res = await _fetch(url);
    final RegExp playlistExp = RegExp(
      r'<div[^>]*class="[^"]*simp-playlist[^"]*"[\s\S]*?</div>',
      caseSensitive: false,
    );
    final playlistMatch = playlistExp.firstMatch(res.body);
    if (playlistMatch == null) return [];

    final RegExp dataSrcExp = RegExp(r'''data-src=(?:'|")([^'"]+)(?:'|")''');
    final blobs = dataSrcExp.allMatches(playlistMatch.group(0)!);

    final chapters = <AudiobookChapter>[];
    int chapterNum = 1;
    for (final blob in blobs) {
      final encrypted = blob.group(1)!;
      final decryptRes = await http.get(
        Uri.parse(
          'https://audiobooks4soul.com/wp-content/plugins/custom-story-audio/inc/security/decrypt.php?encrypted=${Uri.encodeComponent(encrypted)}',
        ),
      );

      if (decryptRes.statusCode == 200 && decryptRes.body.startsWith('http')) {
        final streamUrl = decryptRes.body.trim();
        if (!streamUrl.contains('Soulful_Exploration')) {
          chapters.add(
            AudiobookChapter(
              title: 'Chapter $chapterNum',
              url: streamUrl,
              httpHeaders: {
                'Referer': 'https://audiobooks4soul.com/',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ),
          );
          chapterNum++;
        }
      }
    }
    return chapters;
  }

  Future<List<AudiobookChapter>> _getAudionestChapters(String bookId) async {
    var token = await _audionestEnsureToken();
    if (token == null) return [];

    final body = json.encode({
      'structuredQuery': {
        'from': [
          {'collectionId': 'TrackFiles'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'book_id'},
            'op': 'EQUAL',
            'value': {'integerValue': bookId},
          },
        },
        'limit': 1,
      },
    });

    Future<http.Response> runQuery(String tk) => http.post(
      Uri.parse(
        'https://firestore.googleapis.com/v1/projects/learningfirebase-ae02f/databases/(default)/documents:runQuery',
      ),
      headers: {
        'Authorization': 'Bearer $tk',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    var res = await runQuery(token);
    if (res.statusCode == 401 || res.statusCode == 403) {
      token = await _audionestEnsureToken(force: true);
      if (token == null) return [];
      res = await runQuery(token);
    }

    if (res.statusCode != 200) return [];
    try {
      final data = json.decode(res.body) as List;
      for (final entry in data) {
        if (entry['document'] != null) {
          final values =
              entry['document']['fields']['urlLink']['arrayValue']['values'];
          final urls = values.map((v) => v['stringValue'].toString()).toList();
          return List.generate(
            urls.length,
            (i) => AudiobookChapter(
              title: urls.length == 1 ? 'Full Audiobook' : 'Chapter ${i + 1}',
              url: urls[i],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Audionest firestore error: $e');
    }
    return [];
  }
}
