import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/stream/stream_model.dart';
import '../player/player_settings.dart';

/// Production-grade HTTP/HLS/MP4 Stream Health & Liveness Checker for ZPlayHTTP.
///
/// Validates stream URLs using lightweight range requests, respecting exact headers,
/// referrers, origins, and user-agents, and rejecting dead status codes or broken payloads.
///
/// HLS sources are walked past the playlist: a playlist can serve while every
/// media segment behind it is refused, expired or an error page, so the HLS
/// verdict comes from fetching the first segment the playlist points at, not
/// from the playlist text alone.
class StreamHealthChecker {
  static const int _minBytes = 8 * 1024;
  static const int _maxBytes = 64 * 1024;
  static const Duration _timeout = Duration(seconds: 5);

  /// Budget for the whole HLS walk. The caller caps one candidate at 8s while
  /// running probes concurrently, so the manifest plus the variant and segment
  /// requests have to fit in here with room left to spare.
  static const Duration _hlsDeadline = Duration(seconds: 6);

  /// Cap for a single request inside the walk: the manifest plus two walk
  /// requests fit the budget above.
  static const Duration _hlsStepTimeout = Duration(seconds: 2);

  static const String _fallbackUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Tests if a [StreamSource] is alive and delivers a valid video/audio stream.
  ///
  /// Torrent streams (`infoHash != null`) are always considered alive by this checker.
  static Future<bool> isAlive(StreamSource source) async {
    // Torrents are managed by TorrServer / DHT
    if (source.infoHash != null && source.infoHash!.isNotEmpty) {
      return true;
    }

    final rawUrl = source.url ?? source.externalUrl;
    if (rawUrl == null || rawUrl.isEmpty || !rawUrl.startsWith('http')) {
      return false;
    }

    // Resolve complete headers (including Referer, Origin, User-Agent)
    final effectiveHeaders = PlayerSettings.resolveStreamHeaders(rawUrl, source.headers);

    // One deadline covers the whole probe, the manifest included. Only the HLS
    // walk reads it, so direct media keeps its own single-request timings.
    return _probeUrl(rawUrl, effectiveHeaders, DateTime.now().add(_hlsDeadline));
  }

  /// Probes the stream URL using a GET Range request.
  ///
  /// Direct media is judged on that one response. HLS is judged on the segment
  /// the playlist points at, so its verdict survives a playlist whose media is
  /// gone.
  static Future<bool> _probeUrl(
    String url,
    Map<String, String> headers,
    DateTime deadline, [
    int redirectCount = 0,
  ]) async {
    if (redirectCount > 5) return false;

    final client = http.Client();
    try {
      // An url that announces HLS is known before the request, so its manifest
      // is fetched on the walk timeout instead of the direct one.
      final timeout = isHlsUrl(url) ? _stepTimeout(deadline) : _timeout;
      if (timeout <= Duration.zero) return false;

      final req = _newRequest(url, headers, 'bytes=0-${_maxBytes - 1}');

      final resp = await client.send(req).timeout(timeout);
      final code = resp.statusCode;

      // Handle 3xx Redirects manually to preserve Origin and Referer
      if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
        final location = resp.headers['location'];
        if (location != null && location.isNotEmpty) {
          final redirectedUri = Uri.parse(url).resolve(location).toString();
          final redirectHeaders = PlayerSettings.resolveStreamHeaders(redirectedUri, headers);
          client.close();
          return await _probeUrl(redirectedUri, redirectHeaders, deadline, redirectCount + 1);
        }
        return false;
      }

      // Check valid HTTP response codes
      if (code != 200 && code != 206) {
        return false;
      }

      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      final cl = int.tryParse(resp.headers['content-length'] ?? '') ?? -1;

      final isHls = isHlsUrl(url) || isHlsContentType(ct);

      // Check for dead error pages (HTML/JSON/XML)
      if (!isHls && _isDeadContentType(ct)) {
        return false;
      }

      // Read initial payload bytes. A playlist is read through the whole probe
      // window: a master lists every variant and its best entry can sit past the
      // first chunk, and stopping early would hide the variant to walk into.
      final readCap = isHls ? _maxBytes : _minBytes;
      final buf = <int>[];
      try {
        await for (final chunk in resp.stream.timeout(timeout)) {
          buf.addAll(chunk);
          if (buf.length >= readCap) break;
          if (isHls && !DateTime.now().isBefore(deadline)) break;
        }
      } catch (_) {}

      // HLS validation: the playlist has to parse before it can be walked.
      if (isHls) {
        final manifest = utf8.decode(buf, allowMalformed: true);
        final head = manifest.length < 1024 ? manifest : manifest.substring(0, 1024);
        if (!head.contains('#EXTM3U') && !head.contains('#EXTINF') && !head.contains('#EXT-X-STREAM-INF')) {
          return false;
        }
        client.close();
        return await _probeHls(url, headers, manifest, deadline);
      }

      if (buf.isEmpty) return false;
      if (cl >= 1 && cl <= 1000) return false; // Tiny empty stub files

      // Binary video / stream container signature checks
      if (_hasVideoSignature(buf)) return true;

      // If we received >= _minBytes of binary content without dead content type, it's alive
      if (buf.length >= _minBytes && !_isDeadContentType(ct)) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Walks a playlist down to a media resource and judges that fetch.
  ///
  /// A master playlist names variants rather than media, so the walk steps one
  /// level into a variant first. The verdict then comes from a resource a player
  /// would actually open, which is the point of the walk: a playlist can serve
  /// while its media is refused, expired or an error page.
  static Future<bool> _probeHls(
    String playlistUrl,
    Map<String, String> headers,
    String playlist,
    DateTime deadline,
  ) async {
    var baseUrl = playlistUrl;
    var text = playlist;

    final variant = pickVariantUrl(text, baseUrl);
    if (variant != null) {
      final variantResponse = await _request(
        variant,
        PlayerSettings.resolveStreamHeaders(variant, headers),
        deadline,
        range: 'bytes=0-${_maxBytes - 1}',
      );
      if (variantResponse == null || !variantResponse.isOk) return false;
      baseUrl = variant;
      text = utf8.decode(variantResponse.body, allowMalformed: true);
    }

    final segment = extractFirstSegment(text, baseUrl);
    if (segment == null) return false;

    final segmentResponse = await _request(
      segment.url,
      PlayerSettings.resolveStreamHeaders(segment.url, headers),
      deadline,
      range: segment.rangeHeader ?? 'bytes=0-${_maxBytes - 1}',
    );
    if (segmentResponse == null || !segmentResponse.isOk) return false;

    return isPlayableSegmentPayload(
      encrypted: segment.encrypted,
      contentType: segmentResponse.contentType,
      contentLength: segmentResponse.contentLength,
      buf: segmentResponse.body,
    );
  }

  /// Fetches one resource of the walk inside the probe budget.
  ///
  /// Redirects are followed by hand so Origin and Referer stay attached. A
  /// request that cannot start before the deadline fails rather than eating the
  /// caller's patience. Null means the fetch itself did not complete.
  static Future<_ProbeResponse?> _request(
    String url,
    Map<String, String> headers,
    DateTime deadline, {
    required String range,
    int redirectCount = 0,
  }) async {
    if (redirectCount > 5) return null;

    final timeout = _stepTimeout(deadline);
    if (timeout <= Duration.zero) return null;

    final client = http.Client();
    try {
      final req = _newRequest(url, headers, range);
      final resp = await client.send(req).timeout(timeout);
      final code = resp.statusCode;

      if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
        final location = resp.headers['location'];
        if (location == null || location.isEmpty) return null;
        final redirectedUri = Uri.parse(url).resolve(location).toString();
        final redirectHeaders = PlayerSettings.resolveStreamHeaders(redirectedUri, headers);
        client.close();
        return await _request(
          redirectedUri,
          redirectHeaders,
          deadline,
          range: range,
          redirectCount: redirectCount + 1,
        );
      }

      final buf = <int>[];
      try {
        await for (final chunk in resp.stream.timeout(timeout)) {
          buf.addAll(chunk);
          if (buf.length >= _maxBytes) break;
          if (!DateTime.now().isBefore(deadline)) break;
        }
      } catch (_) {}

      return _ProbeResponse(
        statusCode: code,
        contentType: (resp.headers['content-type'] ?? '').toLowerCase(),
        contentLength: int.tryParse(resp.headers['content-length'] ?? '') ?? -1,
        body: buf,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Builds the probe GET, so every request of the walk carries the same
  /// Referer, Origin, Cookie and User-Agent as the direct probe.
  static http.Request _newRequest(String url, Map<String, String> headers, String? range) {
    final req = http.Request('GET', Uri.parse(url))
      ..followRedirects = false
      ..headers['User-Agent'] = headers['User-Agent'] ?? _fallbackUserAgent
      ..headers['Accept'] = '*/*'
      ..headers['Connection'] = 'keep-alive';
    if (range != null) {
      req.headers['Range'] = range;
    }

    // Attach all scraper headers (Referer, Origin, Cookie, Authorization, etc.)
    headers.forEach((k, v) {
      if (v.isNotEmpty && k.toLowerCase() != 'range' && k.toLowerCase() != 'content-length') {
        req.headers[k] = v;
      }
    });
    return req;
  }

  /// Time left for the next request of the walk, capped at one step.
  static Duration _stepTimeout(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    return left < _hlsStepTimeout ? left : _hlsStepTimeout;
  }

  /// Whether [url] names an HLS playlist by its path, query string ignored.
  @visibleForTesting
  static bool isHlsUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase();
    return path != null && path.endsWith('.m3u8');
  }

  /// Whether a response content type is one of the HLS playlist types.
  @visibleForTesting
  static bool isHlsContentType(String contentType) {
    final ct = contentType.toLowerCase();
    return ct.contains('application/vnd.apple.mpegurl') ||
        ct.contains('application/x-mpegurl') ||
        ct.contains('audio/mpegurl') ||
        ct.contains('application/mpegurl');
  }

  /// The variant a master playlist points at, resolved against [baseUrl].
  ///
  /// Picks the highest declared BANDWIDTH, the rendition a player opens on a
  /// fast link, and keeps document order when no variant declares one. Null when
  /// the playlist lists no variant, which makes it a media playlist.
  @visibleForTesting
  static String? pickVariantUrl(String playlist, String baseUrl) {
    String? best;
    var bestBandwidth = -1;
    int? pendingBandwidth;

    for (final raw in const LineSplitter().convert(playlist)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-STREAM-INF')) {
        pendingBandwidth = _declaredBandwidth(line) ?? -1;
        continue;
      }
      if (line.startsWith('#')) continue;

      // A bare uri follows a variant tag only in a master playlist, so a media
      // playlist never reads as one here.
      final bandwidth = pendingBandwidth;
      if (bandwidth == null) continue;
      pendingBandwidth = null;

      if (best == null || bandwidth > bestBandwidth) {
        best = resolveUri(baseUrl, line);
        bestBandwidth = bandwidth;
      }
    }
    return best;
  }

  /// The first media resource of a media playlist: the segment after the first
  /// `#EXTINF`, or the `#EXT-X-MAP` initialisation resource when the playlist
  /// declares no segment at all. Null when it has neither, which cannot play.
  @visibleForTesting
  static HlsSegmentRef? extractFirstSegment(String playlist, String baseUrl) {
    String? segmentUri;
    String? mapUri;
    String? mapByteRange;
    String? pendingRange;
    var encrypted = false;
    var sawExtinf = false;

    for (final raw in const LineSplitter().convert(playlist)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        if (line.startsWith('#EXT-X-KEY')) {
          final method = _attribute(line, 'METHOD');
          // METHOD=NONE turns encryption back off for the segments after it.
          encrypted = method != null && method.toUpperCase() != 'NONE';
        } else if (line.startsWith('#EXT-X-MAP')) {
          if (mapUri == null) {
            mapUri = _attribute(line, 'URI');
            mapByteRange = _attribute(line, 'BYTERANGE');
          }
        } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
          pendingRange = line.substring('#EXT-X-BYTERANGE:'.length).trim();
        } else if (line.startsWith('#EXTINF')) {
          sawExtinf = true;
        }
        continue;
      }

      // A bare uri is media only once an #EXTINF announced it.
      if (!sawExtinf) continue;
      segmentUri = line;
      break;
    }

    if (segmentUri != null) {
      final range = pendingRange == null ? null : _byteRange(pendingRange);
      return HlsSegmentRef(
        url: resolveUri(baseUrl, segmentUri),
        byteStart: range?.start,
        byteLength: range?.length,
        encrypted: encrypted,
      );
    }

    if (mapUri != null) {
      final range = mapByteRange == null ? null : _byteRange(mapByteRange);
      return HlsSegmentRef(
        url: resolveUri(baseUrl, mapUri),
        byteStart: range?.start,
        byteLength: range?.length,
        encrypted: encrypted,
      );
    }
    return null;
  }

  /// The `start` and `length` of an HLS `length[@offset]` byte range declaration.
  ///
  /// Null when the length does not parse. Only the first resource of a playlist
  /// is ever fetched, so an omitted offset reads as the start of the resource.
  static ({int start, int length})? _byteRange(String declaration) {
    final parts = declaration.split('@');
    final length = int.tryParse(parts[0].trim()) ?? 0;
    if (length <= 0) return null;
    final start = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return (start: start, length: length);
  }

  /// Whether a fetched segment payload proves the variant really carries media.
  ///
  /// A keyed segment is ciphertext, so no container signature survives it: a
  /// healthy fetch of non-empty, non-error-page bytes is as far as it can be
  /// judged. Clear segments keep the checks the direct probe uses.
  @visibleForTesting
  static bool isPlayableSegmentPayload({
    required bool encrypted,
    required String contentType,
    required int contentLength,
    required List<int> buf,
  }) {
    if (buf.isEmpty) return false;
    if (_isDeadContentType(contentType)) return false;
    if (encrypted) return true;
    if (contentLength >= 1 && contentLength <= 1000) return false; // Tiny empty stub files
    if (_hasVideoSignature(buf)) return true;
    return buf.length >= _minBytes;
  }

  /// Resolves an HLS uri reference (relative, `../`, absolute path or absolute
  /// url) against the playlist that declared it.
  @visibleForTesting
  static String resolveUri(String baseUrl, String reference) {
    try {
      return Uri.parse(baseUrl).resolve(reference).toString();
    } catch (_) {
      // A pair a Uri cannot parse resolves to nothing fetchable anyway.
      return reference;
    }
  }

  /// The BANDWIDTH attribute of an `#EXT-X-STREAM-INF` line, or null.
  static int? _declaredBandwidth(String line) {
    final match = RegExp(r'(?:^|[,:])BANDWIDTH=(\d+)').firstMatch(line);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// The value of a quoted or bare `NAME=value` attribute of an HLS tag line.
  static String? _attribute(String line, String name) {
    final match = RegExp('(?:^|[,:])$name=("[^"]*"|[^,]*)').firstMatch(line);
    if (match == null) return null;
    final value = match.group(1)!;
    return value.length >= 2 && value.startsWith('"') && value.endsWith('"')
        ? value.substring(1, value.length - 1)
        : value;
  }

  static bool _isDeadContentType(String ct) =>
      ct.contains('text/html') ||
      ct.contains('application/json') ||
      ct.contains('text/xml') ||
      ct.contains('text/plain') ||
      ct.contains('application/xml');

  static bool _hasVideoSignature(List<int> buf) {
    if (buf.length < 4) return false;

    // MPEG-TS sync byte (0x47)
    if (buf[0] == 0x47) {
      var validTs = true;
      var checkedPackets = 0;
      var i = 0;
      while (i < buf.length - 188 && checkedPackets < 6) {
        if (buf[i] != 0x47) {
          validTs = false;
          break;
        }
        checkedPackets++;
        i += 188;
      }
      if (validTs && checkedPackets >= 2) return true;
    }

    // MP4 / MOV / M4V box identifiers (ftyp, moov, mdat, wide, skip, free)
    if (buf.length >= 8) {
      final s = String.fromCharCodes(buf.sublist(4, 8));
      if (s == 'ftyp' || s == 'moov' || s == 'mdat' || s == 'wide' || s == 'skip' || s == 'free') {
        return true;
      }
    }

    // M3U8 string headers
    if (buf.length >= 7) {
      final s = String.fromCharCodes(buf.sublist(0, 7));
      if (s == '#EXTM3U') return true;
    }
    if (buf.length >= 4) {
      final s = String.fromCharCodes(buf.sublist(0, 4));
      if (s == '#EXT') return true;
    }

    // Matroska / WebM (0x1A 0x45 0xDF 0xA3)
    if (buf.length >= 4 && buf[0] == 0x1A && buf[1] == 0x45 && buf[2] == 0xDF && buf[3] == 0xA3) {
      return true;
    }

    // Ogg stream (0x4F 0x67 0x67 0x53 -> 'OggS')
    if (buf.length >= 4 && buf[0] == 0x4F && buf[1] == 0x67 && buf[2] == 0x67 && buf[3] == 0x53) {
      return true;
    }

    // FLV container ('FLV\x01')
    if (buf.length >= 4 && buf[0] == 0x46 && buf[1] == 0x4C && buf[2] == 0x56 && buf[3] == 0x01) {
      return true;
    }

    // H.264 / H.265 NAL unit start codes (0x000001 or 0x00000001)
    if (buf.length >= 4 && buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0x00 && buf[3] == 0x01) {
      return true;
    }
    if (buf.length >= 3 && buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0x01) {
      return true;
    }

    // AAC ADTS frame sync (0xFFF)
    if (buf.length >= 2 && buf[0] == 0xFF && (buf[1] & 0xF0) == 0xF0) {
      return true;
    }

    // MP3 frame sync (0xFFE or 0xFFF)
    if (buf.length >= 2 && buf[0] == 0xFF && (buf[1] & 0xE0) == 0xE0) {
      return true;
    }

    return false;
  }
}

/// One media resource of an HLS playlist, resolved and ready to fetch.
class HlsSegmentRef {
  /// Absolute url of the segment or initialisation resource.
  final String url;

  /// First byte of the resource when the playlist declared `#EXT-X-BYTERANGE`.
  final int? byteStart;

  /// Byte count of that range, null when the whole resource is requested.
  final int? byteLength;

  /// Whether the playlist keys this resource, which makes it ciphertext.
  final bool encrypted;

  const HlsSegmentRef({
    required this.url,
    this.byteStart,
    this.byteLength,
    this.encrypted = false,
  });

  /// Range header for [url], or null when the resource is requested whole.
  String? get rangeHeader {
    final length = byteLength;
    if (length == null) return null;
    final start = byteStart ?? 0;
    return 'bytes=$start-${start + length - 1}';
  }
}

/// Head and first bytes of one fetch of the HLS walk.
class _ProbeResponse {
  final int statusCode;
  final String contentType;
  final int contentLength;
  final List<int> body;

  const _ProbeResponse({
    required this.statusCode,
    required this.contentType,
    required this.contentLength,
    required this.body,
  });

  bool get isOk => statusCode == 200 || statusCode == 206;
}
