// AnimeSlayer (animeslayer.to) native stream extractor for ZPlay.
// Resolves server map (Wit, Rift, RiftV2, Shof, Blkom, Animeify, Kuudere, TopCinema)
// and extracts direct MP4 / HLS streams with Arabic subtitles.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/stream/stream_model.dart';
import 'anime_arabic_service.dart';
import 'mega_proxy.dart';

class ArabicResolvedServer {
  final String name;
  final String displayName;
  final String iframeUrl;

  const ArabicResolvedServer({
    required this.name,
    required this.displayName,
    required this.iframeUrl,
  });
}

class ArabicResolvedStream {
  final ArabicResolvedServer server;
  final String url;
  final String quality;
  final String type;
  final Map<String, String> headers;

  const ArabicResolvedStream({
    required this.server,
    required this.url,
    required this.quality,
    required this.type,
    required this.headers,
  });
}

class AnimeArabicExtractor {
  static final AnimeArabicExtractor instance = AnimeArabicExtractor._internal();
  factory AnimeArabicExtractor() => instance;
  AnimeArabicExtractor._internal();

  static const String _flareUrl =
      'https://patrimoines-en-mouvement.org/lib/flare/v3.php';
  static const String _xorKey = 'AQWXZSCED@@POIUYTRR159';

  static const String _fallbackName = 'KwQdDUVLRBELIQgCEhY=';
  static const String _fallbackBool = 'no';
  static const String _fallbackSan = 'KwQdDUVLRBELIQgCEhY=';
  static const String _fallbackMwsem = 'U29yY2VyeSBGaWdodCxKdWp1dHN1IEthaXNlbixKSks=';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const Map<String, String> _displayNames = {
    'wit': 'Zen-2',
    'rift': 'Zen',
    'riftv2': 'Zen V2',
    'shof': 'Shof',
    'blkom': 'Blkom',
    'animeify': 'Animeify',
    'topcinema': 'TopCinema',
    'kuudere': 'Kuudere',
  };

  static String? _cachedApiFirst;
  static String? _cachedApiSec;
  static DateTime? _flareCachedAt;
  static const Duration _flareTtl = Duration(minutes: 10);

  Future<List<ArabicResolvedStream>> resolveEpisode(
    dynamic episodeOrWatchPath, {
    String animeTitle = '',
    int episodeNumber = 1,
    Duration discoverTimeout = const Duration(seconds: 25),
    Duration sniffTimeout = const Duration(seconds: 25),
    Duration graceWindow = const Duration(seconds: 4),
    void Function(String phase, String detail)? onProgress,
  }) async {
    onProgress?.call('discover', 'Cracking Arabic server map…');

    final servers = await discoverServers(
      episodeOrWatchPath,
      timeout: discoverTimeout,
      onProgress: onProgress,
    );
    if (servers.isEmpty) {
      onProgress?.call('error', 'No servers exposed by API');
      return const [];
    }

    return _scrapeAll(
      servers,
      timeout: sniffTimeout,
      graceWindow: graceWindow,
      onProgress: onProgress,
    );
  }

  Future<List<ArabicResolvedServer>> discoverServers(
    dynamic episodeOrWatchPath, {
    Duration timeout = const Duration(seconds: 25),
    void Function(String phase, String detail)? onProgress,
  }) async {
    final client = HttpClient()
      ..userAgent = _userAgent
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final String watchPath = episodeOrWatchPath is ArabicEpisode
          ? episodeOrWatchPath.watchPath
          : (episodeOrWatchPath is String ? episodeOrWatchPath : '');
      if (watchPath.isEmpty) return const [];
      final hashIdx = watchPath.indexOf('#');
      final path = hashIdx >= 0 ? watchPath.substring(0, hashIdx) : watchPath;
      final frag = hashIdx >= 0 ? watchPath.substring(hashIdx + 1) : '';
      if (frag.isEmpty) return const [];
      final segs = path.split('-');
      final pe = segs.length > 1 ? segs.last : '';
      if (pe.isEmpty) return const [];

      final flare = await _getFlare(client, timeout: timeout, onProgress: onProgress);
      if (flare == null) return const [];
      final apiFirst = flare.$1;
      final apiSec = flare.$2;

      String name = _fallbackName;
      String san = _fallbackSan;
      String mwsem = _fallbackMwsem;
      String boolStr = _fallbackBool;
      try {
        final pageHtml = await _get(
          client,
          '${AnimeArabicService.baseUrl}$path',
        ).timeout(timeout);
        String? pluck(String key) {
          final re = RegExp('const\\s+$key\\s*=\\s*"([^"]*)"');
          final m = re.firstMatch(pageHtml);
          return m?.group(1);
        }
        final n = pluck('name');
        final s = pluck('san');
        final m = pluck('mwsem');
        final b = pluck('bool');
        if (n != null && n.isNotEmpty) name = n;
        if (s != null && s.isNotEmpty) san = s;
        if (m != null && m.isNotEmpty) mwsem = m;
        if (b != null && b.isNotEmpty) boolStr = b;
      } catch (e) {
        if (kDebugMode) debugPrint('[ArabicExtractor] page-token parse failed, using fallback: $e');
      }

      final r1 = await _post(
        client,
        apiFirst,
        body: 'pe=${Uri.encodeComponent(pe)}&hash=${Uri.encodeComponent(frag)}',
      ).timeout(timeout);

      Map<String, dynamic> j1;
      try {
        j1 = jsonDecode(r1) as Map<String, dynamic>;
      } catch (e) {
        return const [];
      }

      final aid = j1['a']?.toString() ?? '';
      final binfo = j1['b']?.toString() ?? '';
      final cep = j1['c']?.toString() ?? '';
      final dkeyn = j1['d']?.toString() ?? '';
      if (dkeyn.isEmpty || aid.isEmpty || binfo.isEmpty) return const [];

      final secBody = <String, String>{
        'keyn': dkeyn,
        'name': name,
        'pe': cep,
        'bool': boolStr,
        'id': aid,
        'info': binfo,
        'san': san,
        'mwsem': mwsem,
      };
      final secEncoded = secBody.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final r2 = await _post(client, apiSec, body: secEncoded).timeout(timeout);
      Map<String, dynamic> j2;
      try {
        j2 = jsonDecode(r2) as Map<String, dynamic>;
      } catch (_) {
        return const [];
      }

      final rawServers = j2['servers'];
      final servers = <String, dynamic>{};
      if (rawServers is Map) {
        servers.addAll(rawServers.cast<String, dynamic>());
      } else if (rawServers is List) {
        for (var i = 0; i < rawServers.length; i++) {
          final entry = rawServers[i];
          if (entry is Map) {
            final name = (entry['name'] ?? entry['key'] ?? entry['server'] ?? entry['id'])?.toString();
            final enc = (entry['enc'] ?? entry['value'] ?? entry['url'] ?? entry['data'])?.toString();
            if (name != null && enc != null) {
              servers[name] = enc;
            } else if (entry.length == 1) {
              final k = entry.keys.first.toString();
              servers[k] = entry[entry.keys.first]?.toString() ?? '';
            }
          } else if (entry is String) {
            servers['srv$i'] = entry;
          }
        }
      }

      if (servers.isEmpty) return const [];

      final out = <ArabicResolvedServer>[];
      servers.forEach((name, enc) {
        final encStr = enc?.toString() ?? '';
        if (encStr.isEmpty) return;
        final url = decryptXorBase64(encStr);
        if (url == null || !url.startsWith('http')) return;
        out.add(ArabicResolvedServer(
          name: name,
          displayName: _displayNames[name] ?? _titleCase(name),
          iframeUrl: url,
        ));
      });

      return out;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ArabicExtractor] discoverServers error: $e\n$st');
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  Future<List<ArabicResolvedStream>> _scrapeAll(
    List<ArabicResolvedServer> servers, {
    required Duration timeout,
    required Duration graceWindow,
    void Function(String phase, String detail)? onProgress,
  }) async {
    final hits = <ArabicResolvedStream>[];
    final completer = Completer<List<ArabicResolvedStream>>();
    var settled = 0;
    final total = servers.length;
    Timer? grace;

    void finalizeIfDone() {
      if (completer.isCompleted) return;
      if (settled >= total) {
        grace?.cancel();
        completer.complete(List.of(hits));
      }
    }

    for (final s in servers) {
      _scrapeOne(s, timeout: timeout).then((variants) {
        settled++;
        if (variants.isNotEmpty) {
          hits.addAll(variants);
          if (hits.isNotEmpty && !completer.isCompleted && grace == null && settled < total) {
            grace = Timer(graceWindow, () {
              if (!completer.isCompleted) {
                completer.complete(List.of(hits));
              }
            });
          }
        }
        finalizeIfDone();
      }).catchError((e) {
        settled++;
        finalizeIfDone();
      });
    }

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(List.of(hits));
      }
    });

    return completer.future;
  }

  Future<List<ArabicResolvedStream>> _scrapeOne(
    ArabicResolvedServer server, {
    required Duration timeout,
  }) async {
    final iframeHost = Uri.tryParse(server.iframeUrl)?.host.toLowerCase() ?? '';
    if (iframeHost.contains('mega.nz') || iframeHost.contains('mega.co.nz')) {
      try {
        final mega = await MegaProxy.instance.resolve(server.iframeUrl).timeout(timeout);
        if (mega == null) return const [];
        return [
          ArabicResolvedStream(
            server: server,
            url: mega.url,
            quality: 'HD',
            type: 'video',
            headers: const {},
          ),
        ];
      } catch (e) {
        return const [];
      }
    }

    final client = HttpClient()
      ..userAgent = _userAgent
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final html = await _get(
        client,
        server.iframeUrl,
        headers: {
          'Referer': '${AnimeArabicService.baseUrl}/',
          'Accept': 'text/html,*/*',
        },
      ).timeout(timeout);
      return _parseVideos(server, html);
    } catch (e) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }

  List<ArabicResolvedStream> _parseVideos(
    ArabicResolvedServer server,
    String html,
  ) {
    final uri = Uri.tryParse(server.iframeUrl);
    final iframeOrigin = (uri != null && uri.hasScheme && uri.host.isNotEmpty)
        ? '${uri.scheme}://${uri.host}${uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}'
        : '';
    final headers = <String, String>{
      'User-Agent': _userAgent,
      'Referer': iframeOrigin.isNotEmpty ? '$iframeOrigin/' : '',
      if (iframeOrigin.isNotEmpty) 'Origin': iframeOrigin,
    };

    final out = <ArabicResolvedStream>[];
    final blockRe = RegExp(
      r'''src\s*:\s*['"]([^'"]+)['"](?:[^{}]*?label\s*:\s*['"]([^'"]*)['"])?(?:[^{}]*?res\s*:\s*['"]?([0-9a-zA-Z]+)['"]?)?''',
      multiLine: true,
      dotAll: true,
    );
    final seen = <String>{};
    for (final m in blockRe.allMatches(html)) {
      final url = m.group(1)?.trim() ?? '';
      if (url.isEmpty || !url.startsWith('http')) continue;
      if (!seen.add(url)) continue;
      final label = (m.group(2) ?? '').trim();
      final res = (m.group(3) ?? '').trim();
      final quality = label.isNotEmpty ? label : (res.isNotEmpty ? '${res}p' : '');
      final lower = url.toLowerCase();
      final type = lower.contains('.m3u8') ? 'hls' : 'video';
      out.add(ArabicResolvedStream(
        server: server,
        url: url,
        quality: quality,
        type: type,
        headers: headers,
      ));
    }

    out.sort((a, b) => _qualityRank(b.quality).compareTo(_qualityRank(a.quality)));
    return out;
  }

  static int _qualityRank(String q) {
    final m = RegExp(r'(\d{3,4})').firstMatch(q);
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }

  Future<(String, String)?> _getFlare(
    HttpClient client, {
    required Duration timeout,
    void Function(String phase, String detail)? onProgress,
  }) async {
    final now = DateTime.now();
    if (_cachedApiFirst != null &&
        _cachedApiSec != null &&
        _flareCachedAt != null &&
        now.difference(_flareCachedAt!) < _flareTtl) {
      return (_cachedApiFirst!, _cachedApiSec!);
    }
    try {
      final raw = await _get(client, _flareUrl, headers: {
        'Referer': '${AnimeArabicService.baseUrl}/',
        'Accept': 'application/json,*/*',
      }).timeout(timeout);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final first = j['first']?.toString();
      final sec = j['sec']?.toString();
      if (first == null || sec == null || first.isEmpty || sec.isEmpty) {
        return null;
      }
      _cachedApiFirst = first;
      _cachedApiSec = sec;
      _flareCachedAt = now;
      return (first, sec);
    } catch (e) {
      return null;
    }
  }

  Future<String> _get(
    HttpClient client,
    String url, {
    Map<String, String>? headers,
  }) async {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    if (headers != null) headers.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode >= 400) {
      throw HttpException('GET $url → ${res.statusCode}');
    }
    return res.transform(utf8.decoder).join();
  }

  Future<String> _post(
    HttpClient client,
    String url, {
    required String body,
    Map<String, String>? headers,
  }) async {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded; charset=UTF-8');
    req.headers.set('Origin', AnimeArabicService.baseUrl);
    req.headers.set('Referer', '${AnimeArabicService.baseUrl}/');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    if (headers != null) headers.forEach(req.headers.set);
    req.write(body);
    final res = await req.close();
    if (res.statusCode >= 400) {
      final err = await res.transform(utf8.decoder).join();
      throw HttpException('POST $url → ${res.statusCode}\n$err');
    }
    return res.transform(utf8.decoder).join();
  }

  static String? decryptXorBase64(String data) {
    try {
      final decoded = base64.decode(data.trim());
      final keyBytes = utf8.encode(_xorKey);
      final out = StringBuffer();
      for (var i = 0; i < decoded.length; i++) {
        out.writeCharCode(decoded[i] ^ keyBytes[i % keyBytes.length]);
      }
      return out.toString();
    } catch (e) {
      return null;
    }
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Converts resolved Arabic streams into ZPlay `StreamSource` items
  static List<StreamSource> toSources(
    List<ArabicResolvedStream> hits, {
    String animeTitle = '',
    int episodeNumber = 1,
  }) {
    const order = ['wit', 'rift', 'riftv2', 'shof', 'blkom', 'animeify', 'kuudere', 'topcinema'];
    int rank(String name) {
      final i = order.indexOf(name);
      return i < 0 ? 999 : i;
    }

    final sorted = List<ArabicResolvedStream>.from(hits)
      ..sort((a, b) {
        final ra = rank(a.server.name.toLowerCase());
        final rb = rank(b.server.name.toLowerCase());
        if (ra != rb) return ra.compareTo(rb);
        return _qualityRank(b.quality).compareTo(_qualityRank(a.quality));
      });

    final out = <StreamSource>[];
    for (final h in sorted) {
      final qLabel = h.quality.isNotEmpty ? ' • ${h.quality}' : '';
      final sourceName = '⚡ ${h.server.displayName}$qLabel';
      final title = animeTitle.isNotEmpty
          ? '$animeTitle • Ep $episodeNumber [${h.server.displayName}$qLabel]'
          : '${h.server.displayName}$qLabel';

      out.add(StreamSource(
        name: sourceName,
        title: title,
        description: 'AnimeSlayer • ${h.server.displayName} • ${h.type.toUpperCase()}$qLabel (Arabic Sub)',
        url: h.url,
        addonName: 'ArabicAnime',
        headers: h.headers,
        behaviorHints: {
          'notWebReady': false,
          'proxyHeaders': {
            'request': h.headers,
          },
        },
      ));
    }
    return out;
  }
}
