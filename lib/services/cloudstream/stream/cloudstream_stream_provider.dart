import '../../../models/stream/stream_model.dart';
import '../../../models/subtitle/subtitle_model.dart';

class CloudStreamStreamProvider {
  static const Map<String, String> _isoToLang = {
    'ara': 'Arabic',
    'ar': 'Arabic',
    'eng': 'English',
    'en': 'English',
    'spa': 'Spanish',
    'es': 'Spanish',
    'fre': 'French',
    'fra': 'French',
    'fr': 'French',
    'ger': 'German',
    'deu': 'German',
    'de': 'German',
    'ita': 'Italian',
    'it': 'Italian',
    'jpn': 'Japanese',
    'ja': 'Japanese',
    'kor': 'Korean',
    'ko': 'Korean',
    'rus': 'Russian',
    'ru': 'Russian',
    'por': 'Portuguese',
    'pt': 'Portuguese',
    'pob': 'Portuguese (BR)',
    'pb': 'Portuguese (BR)',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'zh': 'Chinese',
    'hin': 'Hindi',
    'hi': 'Hindi',
    'tur': 'Turkish',
    'tr': 'Turkish',
    'ind': 'Indonesian',
    'id': 'Indonesian',
    'vie': 'Vietnamese',
    'vi': 'Vietnamese',
    'tha': 'Thai',
    'th': 'Thai',
    'pol': 'Polish',
    'pl': 'Polish',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'nl': 'Dutch',
    'swe': 'Swedish',
    'sv': 'Swedish',
    'nor': 'Norwegian',
    'no': 'Norwegian',
    'dan': 'Danish',
    'da': 'Danish',
    'fin': 'Finnish',
    'fi': 'Finnish',
    'heb': 'Hebrew',
    'he': 'Hebrew',
    'ces': 'Czech',
    'cze': 'Czech',
    'cs': 'Czech',
    'ell': 'Greek',
    'gre': 'Greek',
    'el': 'Greek',
    'hun': 'Hungarian',
    'hu': 'Hungarian',
    'ron': 'Romanian',
    'rum': 'Romanian',
    'ro': 'Romanian',
    'ukr': 'Ukrainian',
    'uk': 'Ukrainian',
    'per': 'Persian',
    'fas': 'Persian',
    'fa': 'Persian',
    'hrv': 'Croatian',
    'scr': 'Croatian',
    'hr': 'Croatian',
    'bul': 'Bulgarian',
    'bg': 'Bulgarian',
    'est': 'Estonian',
    'et': 'Estonian',
    'ms': 'Malay',
    'may': 'Malay',
    'msa': 'Malay',
    'tl': 'Tagalog',
    'fil': 'Filipino',
    'bn': 'Bengali',
    'ben': 'Bengali',
    'ur': 'Urdu',
    'urd': 'Urdu',
    'ta': 'Tamil',
    'tam': 'Tamil',
    'te': 'Telugu',
    'tel': 'Telugu',
  };

  /// Normalizes language code/label to clean human-readable name (e.g. 'en' -> 'English').
  static String normalizeLanguageName(String raw) {
    var base = raw
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'-\s*(sdh|cc|forced)', caseSensitive: false), '')
        .trim();
    if (base.isEmpty) base = raw.trim();

    final clean = base.toLowerCase();
    if (_isoToLang.containsKey(clean)) {
      return _isoToLang[clean]!;
    }
    final codeMatch = RegExp(r'^([a-z]{2,3})[-_ ]').firstMatch(clean);
    if (codeMatch != null && _isoToLang.containsKey(codeMatch.group(1))) {
      return _isoToLang[codeMatch.group(1)]!;
    }

    for (final entry in _isoToLang.entries) {
      if (entry.value.toLowerCase() == clean) {
        return entry.value;
      }
    }
    for (final entry in _isoToLang.entries) {
      if (entry.value.length > 3 && clean.contains(entry.value.toLowerCase())) {
        return entry.value;
      }
    }

    if (base.isNotEmpty) {
      return base[0].toUpperCase() + base.substring(1);
    }
    return 'English';
  }

  /// Transforms a raw link Map emitted by CloudStream into PlayTorrio's StreamSource.
  static StreamSource? toStreamSource(
    Map<String, dynamic> data, {
    required String extensionName,
    String? mediaTitle,
  }) {
    var rawUrl = data['url']?.toString().trim();
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final magnetIdx = rawUrl.indexOf('magnet:?xt=urn:');
    if (magnetIdx != -1) {
      rawUrl = rawUrl.substring(magnetIdx);
    }

    final qualityStr = (data['quality']?.toString().trim() ?? '').isNotEmpty
        ? data['quality'].toString().trim()
        : (data['qualityInt'] != null ? '${data['qualityInt']}p' : 'HD');

    final name = data['name']?.toString().trim() ??
        data['title']?.toString().trim() ??
        extensionName;

    // Resolve and fix headers
    Map<String, String>? headersMap;
    if (data['headers'] is Map) {
      headersMap = (data['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (data['extraData'] is Map && (data['extraData'] as Map)['allHeaders'] is Map) {
      headersMap = ((data['extraData'] as Map)['allHeaders'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    if (headersMap != null) {
      final referer = data['referer']?.toString();
      if (referer != null && referer.isNotEmpty && !headersMap.containsKey('Referer')) {
        headersMap['Referer'] = referer.endsWith('/') ? referer : '$referer/';
      }
    }

    // Extract, normalize, and parse all subtitles
    final List<SubtitleVariant> parsedSubtitles = [];
    final rawSubs = data['subtitles'] as List?;
    if (rawSubs != null && rawSubs.isNotEmpty) {
      final seenUrls = <String>{};
      for (final s in rawSubs) {
        if (s is Map) {
          final file = s['file']?.toString() ?? s['url']?.toString();
          if (file == null || file.trim().isEmpty) continue;
          final cleanUrl = file.trim();
          if (!seenUrls.add(cleanUrl.toLowerCase())) continue;
          final rawLabel = (s['label'] ?? s['lang'] ?? s['language'] ?? 'English').toString().trim();
          final lang = normalizeLanguageName(rawLabel);

          // Detect subtitle format
          String format = (s['format'] ?? s['subFormat'] ?? '').toString().trim().toLowerCase();
          if (format.isEmpty) {
            final lowerUrl = cleanUrl.toLowerCase();
            if (lowerUrl.contains('.vtt')) {
              format = 'vtt';
            } else if (lowerUrl.contains('.ass')) {
              format = 'ass';
            } else {
              format = 'srt';
            }
          }

          // Headers for downloading subtitle
          Map<String, String>? subHeaders;
          if (s['headers'] is Map) {
            subHeaders = (s['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          } else if (headersMap != null) {
            subHeaders = Map<String, String>.from(headersMap);
          }

          final displayTitle = rawLabel.isNotEmpty && rawLabel.toLowerCase() != lang.toLowerCase()
              ? '$rawLabel ($extensionName)'
              : '$lang ($extensionName)';

          parsedSubtitles.add(
            SubtitleVariant(
              providerName: extensionName,
              language: lang,
              title: displayTitle,
              downloadUrl: cleanUrl,
              format: format,
              extraData: {
                if (subHeaders != null) 'headers': subHeaders,
                if (data['referer'] != null) 'referer': data['referer'],
                'source': 'cloudstream',
                'isForced': s['isForced'] == true || rawLabel.toLowerCase().contains('forced'),
                'isHearingImpaired': s['isHearingImpaired'] == true ||
                    rawLabel.contains('[CC]') ||
                    rawLabel.toLowerCase().contains('sdh'),
              },
            ),
          );
        }
      }
    }

    final isDub = data['isDub'] == true ||
        data['type']?.toString().toLowerCase() == 'dub' ||
        name.toLowerCase().contains('dub') ||
        (data['extra']?.toString().toLowerCase().contains('dub') ?? false) ||
        (data['description']?.toString().toLowerCase().contains('dub') ?? false);

    final isSub = data['type']?.toString().toLowerCase() == 'sub' ||
        name.toLowerCase().contains('sub') ||
        (data['extra']?.toString().toLowerCase().contains('sub') ?? false);

    final catLabel = isDub ? 'Dub' : (isSub ? 'Sub' : null);
    final desc = catLabel != null
        ? 'CloudStream • $extensionName • $catLabel'
        : 'CloudStream • $extensionName';

    return StreamSource(
      name: '[$qualityStr] $name',
      title: mediaTitle != null && mediaTitle.isNotEmpty ? '$mediaTitle ($extensionName)' : name,
      url: rawUrl,
      headers: headersMap,
      addonName: extensionName,
      description: desc,
      subtitles: parsedSubtitles.isNotEmpty ? parsedSubtitles : null,
      behaviorHints: {
        if (parsedSubtitles.isNotEmpty) 'subtitles': rawSubs,
      },
    );
  }
}
