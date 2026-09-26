import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/stream/stream_model.dart';
import 'package:zplay/services/stream/stream_health_checker.dart';

/// A 188-byte aligned MPEG-TS payload, the shape a real HLS media segment has.
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

void main() {
  group('StreamHealthChecker Tests', () {
    late HttpServer testServer;
    late int serverPort;
    final tsSegment = _tsSegment();

    setUpAll(() async {
      testServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverPort = testServer.port;

      testServer.listen((request) async {
        final path = request.uri.path;

        if (path == '/alive.m3u8') {
          // Valid HLS Manifest
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
            ..write('#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10.0,\nsegment1.ts\n');
          await request.response.close();
        } else if (path == '/alive_with_referer.m3u8') {
          // Requires exact Referer
          final referer = request.headers.value(HttpHeaders.refererHeader);
          if (referer == 'https://vuflix.co/') {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl')
              ..write('#EXTM3U\n#EXT-X-VERSION:3\n#EXTINF:10.0,\nsegment_referer.ts\n');
          } else {
            request.response
              ..statusCode = HttpStatus.forbidden
              ..write('Forbidden - Missing Referer');
          }
          await request.response.close();
        } else if (path == '/segment1.ts') {
          // The media behind /alive.m3u8, so the liveness check reaches media
          // rather than stopping at the manifest.
          request.response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t')
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-9399/9400')
            ..headers.contentLength = tsSegment.length
            ..add(tsSegment);
          await request.response.close();
        } else if (path == '/segment_referer.ts') {
          // Carries the same Referer gate as its manifest: the walk only passes
          // when it forwards the resolved headers onto the segment request.
          final referer = request.headers.value(HttpHeaders.refererHeader);
          if (referer == 'https://vuflix.co/') {
            request.response
              ..statusCode = HttpStatus.partialContent
              ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp2t')
              ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-9399/9400')
              ..headers.contentLength = tsSegment.length
              ..add(tsSegment);
          } else {
            request.response
              ..statusCode = HttpStatus.forbidden
              ..write('Forbidden - Missing Referer');
          }
          await request.response.close();
        } else if (path == '/alive.mp4') {
          // Valid MP4 stream with ftyp header
          final mp4Bytes = <int>[
            0x00, 0x00, 0x00, 0x18, // size
            0x66, 0x74, 0x79, 0x70, // 'ftyp'
            0x69, 0x73, 0x6F, 0x6D, // 'isom'
            0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D,
            0x69, 0x73, 0x6F, 0x32,
          ];
          request.response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(HttpHeaders.contentTypeHeader, 'video/mp4')
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-23/24')
            ..add(mp4Bytes);
          await request.response.close();
        } else if (path == '/dead_404') {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        } else if (path == '/html_error') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, 'text/html')
            ..write('<html><body><h1>Error: File removed</h1></body></html>');
          await request.response.close();
        } else {
          request.response
            ..statusCode = HttpStatus.badGateway
            ..close();
        }
      });
    });

    tearDownAll(() async {
      await testServer.close(force: true);
    });

    test('Valid M3U8 stream passes health check', () async {
      final source = StreamSource(
        name: 'Alive M3U8',
        url: 'http://127.0.0.1:$serverPort/alive.m3u8',
        addonName: 'ZPlayHTTP',
      );
      final isAlive = await StreamHealthChecker.isAlive(source);
      expect(isAlive, isTrue);
    });

    test('Stream requiring Referer passes when correct headers are provided', () async {
      final sourceWithReferer = StreamSource(
        name: 'Alive with Referer',
        url: 'http://127.0.0.1:$serverPort/alive_with_referer.m3u8',
        addonName: 'ZPlayHTTP',
        headers: {
          'Referer': 'https://vuflix.co/',
        },
      );
      final isAlive = await StreamHealthChecker.isAlive(sourceWithReferer);
      expect(isAlive, isTrue);
    });

    test('Valid MP4 video container passes health check', () async {
      final source = StreamSource(
        name: 'Alive MP4',
        url: 'http://127.0.0.1:$serverPort/alive.mp4',
        addonName: 'ZPlayHTTP',
      );
      final isAlive = await StreamHealthChecker.isAlive(source);
      expect(isAlive, isTrue);
    });

    test('Dead 404 stream fails health check', () async {
      final source = StreamSource(
        name: 'Dead 404',
        url: 'http://127.0.0.1:$serverPort/dead_404',
        addonName: 'ZPlayHTTP',
      );
      final isAlive = await StreamHealthChecker.isAlive(source);
      expect(isAlive, isFalse);
    });

    test('HTML error response page fails health check', () async {
      final source = StreamSource(
        name: 'HTML Error',
        url: 'http://127.0.0.1:$serverPort/html_error',
        addonName: 'ZPlayHTTP',
      );
      final isAlive = await StreamHealthChecker.isAlive(source);
      expect(isAlive, isFalse);
    });

    test('Torrent source with infoHash always passes health check', () async {
      final source = StreamSource(
        name: 'Torrent Source',
        infoHash: 'abcdef1234567890abcdef1234567890abcdef12',
        addonName: 'ZPlayHTTP',
      );
      final isAlive = await StreamHealthChecker.isAlive(source);
      expect(isAlive, isTrue);
    });
  });
}
