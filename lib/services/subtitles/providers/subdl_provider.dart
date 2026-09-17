import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../../../models/subtitle/subtitle_model.dart';
import '../subtitle_provider.dart';
import '../subtitle_extractor.dart';

class SubdlProvider extends SubtitleProvider {
  @override
  String get name => 'Subdl';

  final String _baseUrl = 'https://subdl.com';
  final String _apiBaseUrl = 'https://api3.subdl.com';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/html, */*',
  };

  @override
  Future<List<SubtitleVariant>> search(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  }) async {
    final List<SubtitleVariant> results = [];
    final bool isTvShow = season != null && episode != null;

    try {
      final parsed = _cleanTitleAndExtractYear(movieName, explicitYear: year);
      final String cleanTitle = parsed['cleanTitle'] as String;
      final int? targetYear = parsed['year'] as int?;

      // 1. Build search query candidates
      final searchQueries = <String>[];
      if (targetYear != null) {
        searchQueries.add('$cleanTitle $targetYear');
      }
      searchQueries.add(cleanTitle);
      if (imdbId != null && imdbId.isNotEmpty) {
        searchQueries.add(imdbId);
      }

      Map<String, dynamic>? bestMatch;

      // 2. Primary Search: API autocomplete (api3.subdl.com/auto)
      for (final query in searchQueries) {
        final items = await _queryApi(query);
        if (items.isNotEmpty) {
          final match = _findBestMatch(items, cleanTitle, targetYear, isTvShow);
          if (match != null) {
            bestMatch = match;
            break;
          }
        }
      }

      // 3. Fallback Search: Web scraping (subdl.com/search/{query})
      if (bestMatch == null) {
        for (final query in searchQueries) {
          final webItems = await _scrapeWebSearch(query);
          if (webItems.isNotEmpty) {
            final match = _findBestMatch(webItems, cleanTitle, targetYear, isTvShow);
            if (match != null) {
              bestMatch = match;
              break;
            }
          }
        }
      }

      if (bestMatch == null) {
        return [];
      }

      final link = bestMatch['link']?.toString();
      if (link == null || link.isEmpty) return [];

      String targetUrl = link.startsWith('http') ? link : '$_baseUrl$link';

      // 4. For TV Shows, find the correct season page
      if (isTvShow) {
        final showHtmlRes = await http.get(Uri.parse(targetUrl), headers: _headers).timeout(const Duration(seconds: 4));
        if (showHtmlRes.statusCode == 200) {
          final doc = html_parser.parse(showHtmlRes.body);
          final links = doc.querySelectorAll('a[href*="/subtitle/"]');

          String? seasonLink;
          final seasonWord = _seasonNumberToWord(season);

          for (final a in links) {
            final text = a.text.trim().toLowerCase();
            final href = (a.attributes['href'] ?? '').toLowerCase();

            if (text.contains('season $season') ||
                text.contains('$seasonWord season') ||
                href.endsWith('/season-$season') ||
                href.endsWith('/$seasonWord-season')) {
              seasonLink = a.attributes['href'];
              break;
            }
          }

          if (seasonLink != null) {
            targetUrl = seasonLink.startsWith('http') ? seasonLink : '$_baseUrl$seasonLink';
          }
        }
      }

      // 5. Scrape the final page (movie or season)
      final htmlRes = await http.get(Uri.parse(targetUrl), headers: _headers).timeout(const Duration(seconds: 4));
      if (htmlRes.statusCode != 200) return [];

      final doc = html_parser.parse(htmlRes.body);
      final langDivs = doc.querySelectorAll('div[data-language-name]');

      for (final langDiv in langDivs) {
        final language = langDiv.attributes['data-language-name'] ?? 'Unknown';

        final rowLis = langDiv.querySelectorAll('li[data-row]');
        for (final rowLi in rowLis) {
          // If TV show, verify episode match
          if (isTvShow) {
            final epFrom = rowLi.attributes['data-episode-from'];
            final epTo = rowLi.attributes['data-episode-to'];

            bool match = false;
            if (epFrom != null && epFrom.isNotEmpty) {
              final from = int.tryParse(epFrom);
              final to = int.tryParse(epTo ?? '') ?? from;
              if (from != null && to != null) {
                if (episode >= from && episode <= to) {
                  match = true;
                }
              }
            }

            if (!match) {
              final titleText = rowLi.querySelector('h4')?.text ?? '';
              final epRegex = RegExp(
                r'\b(?:s\d{1,2})?e0*' + episode.toString() + r'(?:[^\d]|$)',
                caseSensitive: false,
              );
              if (epRegex.hasMatch(titleText)) {
                match = true;
              }
            }

            if (!match) continue;
          }

          final aTag = rowLi.querySelector('a[href*="dl.subdl.com"]') ??
              rowLi.querySelector('a[href*=".zip"]') ??
              rowLi.querySelector('a[title*="Download"]') ??
              rowLi.querySelector('button[title*="Download"]')?.parent ??
              rowLi.querySelector('a[href*="/subtitle/"]');
          final titleTag = rowLi.querySelector('h4') ?? rowLi.querySelector('a');

          if (aTag != null && titleTag != null) {
            String? dlLink = aTag.attributes['href'];
            final title = titleTag.text.trim();

            if (dlLink != null && dlLink.isNotEmpty) {
              if (!dlLink.startsWith('http')) {
                dlLink = '$_baseUrl$dlLink';
              }

              results.add(
                SubtitleVariant(
                  providerName: name,
                  language: language,
                  title: title.isNotEmpty ? title : 'Subtitle',
                  downloadUrl: dlLink,
                  format: 'zip',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Subdl search error: $e');
    }

    return results;
  }

  @override
  Future<String?> download(SubtitleVariant variant) async {
    return SubtitleExtractor.downloadAndExtract(
      variant.downloadUrl,
      headers: _headers,
      providerName: name,
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _cleanTitleAndExtractYear(String input, {int? explicitYear}) {
    final raw = input.trim();
    int? year = explicitYear;

    final normalized = raw.replaceAll(RegExp(r'[\.\_]'), ' ');

    // 1. Extract 4-digit year (1900-2099)
    final yearMatch = RegExp(r'(?:\b|\()((?:19|20)\d{2})(?:\b|\))').firstMatch(normalized);
    String titlePart = normalized;

    if (yearMatch != null) {
      year ??= int.tryParse(yearMatch.group(1)!);
      final beforeYear = normalized.substring(0, yearMatch.start).trim();
      if (beforeYear.isNotEmpty) {
        titlePart = beforeYear;
      }
    } else {
      // Check for resolution/rip tags if no year
      final tagMatch = RegExp(
        r'\b(?:2160p|1080p|1080i|720p|576p|480p|4k|uhd|web-?dl|webrip|bluray|brrip|dvdrip|hdtv|s\d{1,2}e\d{1,2}|season\s*\d{1,2})\b',
        caseSensitive: false,
      ).firstMatch(normalized);

      if (tagMatch != null) {
        final beforeTag = normalized.substring(0, tagMatch.start).trim();
        if (beforeTag.isNotEmpty) {
          titlePart = beforeTag;
        }
      }
    }

    var cleanTitle = titlePart
        .replaceAll(RegExp(r'[\[\]\(\)\{\}\-\:\+]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = raw;
    }

    return {
      'cleanTitle': cleanTitle,
      'year': year,
    };
  }

  Future<List<Map<String, dynamic>>> _queryApi(String query) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/auto?query=${Uri.encodeComponent(query)}');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['results'] as List?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> _scrapeWebSearch(String query) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final url = '$_baseUrl/search/${Uri.encodeComponent(query)}';
      final res = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final doc = html_parser.parse(res.body);
        final links = doc.querySelectorAll('a[href*="/subtitle/"]');
        for (final a in links) {
          final href = a.attributes['href'];
          if (href == null || href.isEmpty) continue;

          final fullText = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
          final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(fullText);
          int? year;
          if (yearMatch != null) {
            year = int.tryParse(yearMatch.group(1)!);
          }

          final isTv = fullText.toLowerCase().contains(' tv ') || fullText.toLowerCase().endsWith(' tv');
          final type = isTv ? 'tv' : 'movie';

          String name = fullText;
          if (yearMatch != null) {
            name = fullText.substring(0, yearMatch.start).trim();
          }

          results.add({
            'type': type,
            'name': name,
            'year': year,
            'link': href,
            'original_name': name,
          });
        }
      }
    } catch (_) {}
    return results;
  }

  Map<String, dynamic>? _findBestMatch(
    List<Map<String, dynamic>> items,
    String cleanTitle,
    int? targetYear,
    bool isTvShow,
  ) {
    final normTitle = _normalizeString(cleanTitle);

    final typeFiltered = items.where((item) {
      final type = item['type']?.toString().toLowerCase() ?? 'movie';
      return isTvShow ? type == 'tv' : type == 'movie';
    }).toList();

    final candidates = typeFiltered.isNotEmpty ? typeFiltered : items;

    // Pass 1: Exact title match AND exact year match
    if (targetYear != null) {
      for (final item in candidates) {
        final itemName = _normalizeString(item['name']?.toString() ?? '');
        final itemOrigName = _normalizeString(item['original_name']?.toString() ?? '');
        final itemYear = int.tryParse(item['year']?.toString() ?? '');

        final titleMatches = itemName == normTitle || itemOrigName == normTitle;
        if (titleMatches && itemYear == targetYear) {
          return item;
        }
      }

      // Pass 2: Title contains/contained AND exact year match
      for (final item in candidates) {
        final itemName = _normalizeString(item['name']?.toString() ?? '');
        final itemOrigName = _normalizeString(item['original_name']?.toString() ?? '');
        final itemYear = int.tryParse(item['year']?.toString() ?? '');

        final titleMatches = itemName.contains(normTitle) ||
            normTitle.contains(itemName) ||
            itemOrigName.contains(normTitle) ||
            normTitle.contains(itemOrigName);
        if (titleMatches && itemYear == targetYear) {
          return item;
        }
      }

      // Pass 3: Year within +/- 1 year AND exact title match
      for (final item in candidates) {
        final itemName = _normalizeString(item['name']?.toString() ?? '');
        final itemOrigName = _normalizeString(item['original_name']?.toString() ?? '');
        final itemYear = int.tryParse(item['year']?.toString() ?? '');

        final titleMatches = itemName == normTitle || itemOrigName == normTitle;
        if (titleMatches && itemYear != null && (itemYear - targetYear).abs() <= 1) {
          return item;
        }
      }

      // STRICT: When targetYear is specified, NEVER return an entry from a different year
      return null;
    }

    // Pass 4: When targetYear is null, match exact title first
    for (final item in candidates) {
      final itemName = _normalizeString(item['name']?.toString() ?? '');
      final itemOrigName = _normalizeString(item['original_name']?.toString() ?? '');
      if (itemName == normTitle || itemOrigName == normTitle) {
        return item;
      }
    }

    // Pass 5: When targetYear is null, match contained title
    for (final item in candidates) {
      final itemName = _normalizeString(item['name']?.toString() ?? '');
      final itemOrigName = _normalizeString(item['original_name']?.toString() ?? '');
      if (itemName.contains(normTitle) ||
          normTitle.contains(itemName) ||
          itemOrigName.contains(normTitle) ||
          normTitle.contains(itemOrigName)) {
        return item;
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  String _normalizeString(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _seasonNumberToWord(int season) {
    const words = [
      '',
      'first',
      'second',
      'third',
      'fourth',
      'fifth',
      'sixth',
      'seventh',
      'eighth',
      'ninth',
      'tenth',
      'eleventh',
      'twelfth',
      'thirteenth',
      'fourteenth',
      'fifteenth',
      'sixteenth',
      'seventeenth',
      'eighteenth',
      'nineteenth',
      'twentieth',
    ];
    if (season >= 1 && season < words.length) {
      return words[season];
    }
    return season.toString();
  }
}
