import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/stream/stream_model.dart';
import 'package:zplay/services/stream/stream_health_checker.dart';

/// A 188-byte aligned MPEG-TS payload, the shape a real media segment has.
List<int> _tsSegment({int packets = 50}) {
  final bytes = List<int>.filled(packets * 188, 0);
  for (var i = 0; i < packets; i++) {
    bytes[i * 188] = 0x47; // Sync byte
    bytes[i * 188 + 1] = 0x40;
    bytes[i * 188 + 2] = 0x11;
    bytes[i * 188 + 3] = 0x10;
  }
  return bytes;
}

/// A fragmented MP4 payload, the other container HLS segments come in.
List<int> _mp4Segment({int length = 9400}) {
  final bytes = List<int>.filled(length, 0x00);
  bytes[4] = 0x66; // 'ftyp'
  bytes[5] = 0x74;
  bytes[6] = 0x79;
  bytes[7] = 0x70;
  return bytes;
}

/// Deterministic bytes carrying no container signature, sized like a short audio
/// segment, so only the key declaration can call them media.
List<int> _cipherText() => List<int>.generate(1024, (i) => (i * 31 + 7) % 256);

/// A media playlist whose single segment is [segment], after [tags].
String _mediaPlaylist(String segment, {String tags = ''}) =>
    '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:6\n$tags#EXTINF:6.0,\n$segment\n';

const String _masterPlaylist = '#EXTM3U\n'
    '#EXT-X-VERSION:3\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\n'
    'low.m3u8\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720\n'
    'high.m3u8\n';

const String _playlistUrl = 'http://h/hls/master.m3u8';

void main() {
  group('HLS detection', () {
    test('a .m3u8 path is HLS, query string and case included', () {
      expect(StreamHealthChecker.isHlsUrl('http://h/hls/master.m3u8'), isTrue);
      expect(StreamHealthChecker.isHlsUrl('http://h/hls/index.M3U8?token=abc'), isTrue);
    });

    test('a plain mp4 url is not HLS', () {
      expect(StreamHealthChecker.isHlsUrl('http://h/video/movie.mp4'), isFalse);
      expect(StreamHealthChecker.isHlsUrl('http://h/hls/playlist'), isFalse);
      expect(StreamHealthChecker.isHlsContentType('video/mp4'), isFalse);
    });

    test('the HLS playlist content types are recognised', () {
      for (final ct in const [
        'application/vnd.apple.mpegurl',
        'application/x-mpegurl',
        'audio/mpegurl',
        'application/mpegurl; charset=utf-8',
      ]) {
        expect(StreamHealthChecker.isHlsContentType(ct), isTrue, reason: ct);
      }
    });
  });

  group('playlist parsing', () {
    test('a master playlist picks the highest bandwidth variant and resolves it', () {
      expect(StreamHealthChecker.pickVariantUrl(_masterPlaylist, _playlistUrl), 'http://h/hls/high.m3u8');
    });

    test('a variant that declares no bandwidth never beats a declared one', () {
      const playlist = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:RESOLUTION=640x360\n'
          'first.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1500,RESOLUTION=1920x1080\n'
          'second.m3u8\n';
      expect(StreamHealthChecker.pickVariantUrl(playlist, _playlistUrl), 'http://h/hls/second.m3u8');
    });

    test('without any BANDWIDTH the first variant in document order wins', () {
      const playlist = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:RESOLUTION=640x360\n'
          'first.m3u8\n'
          '#EXT-X-STREAM-INF:RESOLUTION=1920x1080\n'
          'second.m3u8\n';
      expect(StreamHealthChecker.pickVariantUrl(playlist, _playlistUrl), 'http://h/hls/first.m3u8');
    });

    test('AVERAGE-BANDWIDTH is not read as BANDWIDTH', () {
      const playlist = '#EXTM3U\n'
          '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=9,BANDWIDTH=2500\n'
          'big.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=2000\n'
          'small.m3u8\n';
      expect(StreamHealthChecker.pickVariantUrl(playlist, _playlistUrl), 'http://h/hls/big.m3u8');
    });

    test('a media playlist lists no variant, so the walk reads it as media', () {
      final playlist = _mediaPlaylist('seg.ts');
      expect(StreamHealthChecker.pickVariantUrl(playlist, _playlistUrl), isNull);
      expect(StreamHealthChecker.extractFirstSegment(playlist, _playlistUrl), isNotNull);
    });

    test('relative, parent, absolute-path and absolute urls resolve against the playlist', () {
      expect(StreamHealthChecker.resolveUri('http://h/a/b.m3u8', 'seg.ts'), 'http://h/a/seg.ts');
      expect(StreamHealthChecker.resolveUri('http://h/a/b.m3u8', '../c/seg.ts'), 'http://h/c/seg.ts');
      expect(StreamHealthChecker.resolveUri('http://h/a/b.m3u8', '/x/seg.ts'), 'http://h/x/seg.ts');
      expect(StreamHealthChecker.resolveUri('http://h/a/b.m3u8', 'https://cdn/seg.ts?t=1'), 'https://cdn/seg.ts?t=1');
    });

    test('a relative variant uri resolves against the playlist that declared it', () {
      expect(StreamHealthChecker.pickVariantUrl(_masterPlaylist, 'http://h/hls/deep/master.m3u8'), 'http://h/hls/deep/high.m3u8');
    });

    test('the first segment after #EXTINF carries its byte range', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXT-X-BYTERANGE:1200@500\n#EXTINF:6.0,\nseg.ts\n',
        _playlistUrl,
      );
      expect(ref, isNotNull);
      expect(ref!.url, 'http://h/hls/seg.ts');
      expect(ref.byteStart, 500);
      expect(ref.byteLength, 1200);
      expect(ref.rangeHeader, 'bytes=500-1699');
      expect(ref.encrypted, isFalse);
    });

    test('a byte range without an offset starts at zero', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-BYTERANGE:1200\n#EXTINF:6.0,\nseg.ts\n',
        _playlistUrl,
      );
      expect(ref!.rangeHeader, 'bytes=0-1199');
    });

    test('the #EXT-X-MAP resource is the fallback only when no #EXTINF exists', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-MAP:URI="init.mp4",BYTERANGE="1200@200"\n#EXT-X-ENDLIST\n',
        _playlistUrl,
      );
      expect(ref, isNotNull);
      expect(ref!.url, 'http://h/hls/init.mp4');
      expect(ref.rangeHeader, 'bytes=200-1399');
    });

    test('a segment wins over the map when both are declared', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:6.0,\nseg.ts\n',
        _playlistUrl,
      );
      expect(ref!.url, 'http://h/hls/seg.ts');
      expect(ref.rangeHeader, isNull);
    });

    test('only the first of several segments is extracted', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXTINF:6.0,\nfirst.ts\n#EXTINF:6.0,\nsecond.ts\n',
        _playlistUrl,
      );
      expect(ref!.url, 'http://h/hls/first.ts');
    });

    test('a playlist with no segment and no map is dead', () {
      expect(
        StreamHealthChecker.extractFirstSegment('#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-ENDLIST\n', _playlistUrl),
        isNull,
      );
    });

    test('an #EXT-X-KEY marks the segment as ciphertext', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="https://k/key",IV=0x1234\n#EXTINF:6.0,\nseg.ts\n',
        _playlistUrl,
      );
      expect(ref!.encrypted, isTrue);
      expect(ref.url, 'http://h/hls/seg.ts');
    });

    test('METHOD=NONE leaves the segment clear', () {
      final ref = StreamHealthChecker.extractFirstSegment(
        '#EXTM3U\n#EXT-X-KEY:METHOD=NONE\n#EXTINF:6.0,\nseg.ts\n',
        _playlistUrl,
      );
      expect(ref!.encrypted, isFalse);
    });
  });

  group('segment payload verdict', () {
    test('a keyed segment is accepted on bytes alone, without a signature', () {
      final cipher = _cipherText();
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: true,
          contentType: 'application/octet-stream',
          contentLength: cipher.length,
          buf: cipher,
        ),
        isTrue,
      );
      // The same bytes prove nothing without the key declaration.
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: false,
          contentType: 'application/octet-stream',
          contentLength: cipher.length,
          buf: cipher,
        ),
        isFalse,
      );
    });

    test('a clear segment needs the container signature or the byte floor', () {
      final ts = _tsSegment();
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: false,
          contentType: 'video/mp2t',
          contentLength: ts.length,
          buf: ts,
        ),
        isTrue,
      );
      final mp4 = _mp4Segment();
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: false,
          contentType: 'video/mp4',
          contentLength: mp4.length,
          buf: mp4,
        ),
        isTrue,
      );
      // A tiny stub is not media even when it syncs like TS.
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: false,
          contentType: 'video/mp2t',
          contentLength: 800,
          buf: List<int>.filled(800, 0x47),
        ),
        isFalse,
      );
    });

    test('an error page is never a segment payload', () {
      final page = '<html><body>Stream expired</body></html>'.codeUnits;
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: true,
          contentType: 'text/html',
          contentLength: page.length,
          buf: page,
        ),
        isFalse,
      );
      expect(
        StreamHealthChecker.isPlayableSegmentPayload(
          encrypted: true,
          contentType: 'application/octet-stream',
          contentLength: 0,
          buf: const [],
        ),
        isFalse,
      );
    });
  });

  group('liveness walk', () {
    late HttpServer server;
    late String origin;
    final requested = <String>[];
    final ranges = <String, String?>{};
    final ts = _tsSegment();
    final cipher = _cipherText();

    setUpAll(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin = 'http://127.0.0.1:${server.port}';

      server.listen((request) async {
        final path = request.uri.path;
        requested.add(path);
        ranges[path] = request.headers.value(HttpHeaders.rangeHeader);
        final response = request.response;

        if (path == '/master.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_masterPlaylist);
        } else if (path == '/low.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('low.ts'));
        } else if (path == '/high.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('seg_high.ts', tags: '#EXT-X-MAP:URI="init.mp4"\n#EXT-X-BYTERANGE:9400@0\n'));
        } else if (path == '/seg_high.ts') {
          response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t')
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-9399/9400')
            ..headers.contentLength = ts.length
            ..add(ts);
        } else if (path == '/forbidden.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('seg403.ts'));
        } else if (path == '/seg403.ts') {
          response
            ..statusCode = HttpStatus.forbidden
            ..write('Forbidden');
        } else if (path == '/missing.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('gone.ts'));
        } else if (path == '/html.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('seg.html'));
        } else if (path == '/seg.html') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'text/html')
            ..write('<html><body>Stream expired</body></html>');
        } else if (path == '/encrypted.m3u8') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write(_mediaPlaylist('enc.ts', tags: '#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x1\n'));
        } else if (path == '/enc.ts') {
          response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
            ..headers.contentLength = cipher.length
            ..add(cipher);
        } else if (path == '/movie.mp4') {
          final mp4 = _mp4Segment();
          response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp4')
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-9399/9400')
            ..headers.contentLength = mp4.length
            ..add(mp4);
        } else {
          response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
        }
        await response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() {
      requested.clear();
      ranges.clear();
    });

    StreamSource source(String path, {Map<String, String>? headers}) =>
        StreamSource(name: path, url: '$origin$path', addonName: 'ZPlayHTTP', headers: headers);

    test('a master playlist is walked through its variant to a served segment', () async {
      expect(await StreamHealthChecker.isAlive(source('/master.m3u8')), isTrue);
      // Two hops into the variant, then the first segment of that variant.
      expect(requested, ['/master.m3u8', '/high.m3u8', '/seg_high.ts']);
      expect(ranges['/seg_high.ts'], 'bytes=0-9399');
    });

    test('an encrypted playlist is alive on a ciphertext segment', () async {
      expect(await StreamHealthChecker.isAlive(source('/encrypted.m3u8')), isTrue);
      expect(requested, ['/encrypted.m3u8', '/enc.ts']);
    });

    test('a manifest whose segment is refused reports dead', () async {
      expect(await StreamHealthChecker.isAlive(source('/forbidden.m3u8')), isFalse);
      expect(requested, ['/forbidden.m3u8', '/seg403.ts']);
    });

    test('a manifest whose segment is missing reports dead', () async {
      expect(await StreamHealthChecker.isAlive(source('/missing.m3u8')), isFalse);
      expect(requested, ['/missing.m3u8', '/gone.ts']);
    });

    test('a manifest whose segment is an html error page reports dead', () async {
      expect(await StreamHealthChecker.isAlive(source('/html.m3u8')), isFalse);
      expect(requested, ['/html.m3u8', '/seg.html']);
    });

    test('a plain mp4 url is probed directly, with no walk', () async {
      expect(await StreamHealthChecker.isAlive(source('/movie.mp4')), isTrue);
      expect(requested, ['/movie.mp4']);
    });
  });
}
