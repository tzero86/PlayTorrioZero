import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/player/player_settings.dart';

void main() {
  group('PlayerSettings.isNonFatalError', () {
    test('ignores ffurl_read returned 0xffffff99 error', () {
      const error = 'tcp: ffurl_read returned 0xffffff99';
      expect(PlayerSettings.isNonFatalError(error), isTrue);
    });

    test('ignores various ffurl_read and hex error codes', () {
      expect(PlayerSettings.isNonFatalError('ffurl_read returned -103'), isTrue);
      expect(PlayerSettings.isNonFatalError('tls: ffurl_read returned 0xffffff99'), isTrue);
      expect(PlayerSettings.isNonFatalError('http: ffurl_read returned -5'), isTrue);
      expect(PlayerSettings.isNonFatalError('ffurl_write returned 0xffffff99'), isTrue);
      expect(PlayerSettings.isNonFatalError('returned 0x80000000'), isTrue);
    });

    test('ignores transient socket and network hiccups', () {
      expect(PlayerSettings.isNonFatalError('tcp: connection reset by peer'), isTrue);
      expect(PlayerSettings.isNonFatalError('connection timed out'), isTrue);
      expect(PlayerSettings.isNonFatalError('broken pipe'), isTrue);
      expect(PlayerSettings.isNonFatalError('resource temporarily unavailable'), isTrue);
      expect(PlayerSettings.isNonFatalError('averror_eof'), isTrue);
    });

    test('ignores non-fatal subtitle and demuxer warnings', () {
      expect(PlayerSettings.isNonFatalError('can not open external file subtitle.srt'), isTrue);
      expect(PlayerSettings.isNonFatalError('demuxer: invalid nal unit size'), isTrue);
      expect(PlayerSettings.isNonFatalError('hwdec: auto-safe fallback to software'), isTrue);
      expect(PlayerSettings.isNonFatalError('corrupt input packet detected'), isTrue);
    });

    test('does NOT ignore critical dead stream errors', () {
      expect(PlayerSettings.isNonFatalError('Failed to open file: 404 Not Found'), isFalse);
      expect(PlayerSettings.isNonFatalError('Failed to open https://sabrina-stream-proxy.late-haddock.workers.dev/v/123/index.m3u8'), isFalse);
      expect(PlayerSettings.isNonFatalError('cannot open https://bcdn.hakunaymatata.com/test.mp4'), isFalse);
      expect(PlayerSettings.isNonFatalError('could not open https://example.com/live.m3u8'), isFalse);
      expect(PlayerSettings.isNonFatalError('[mpv] Failed to recognize file format.'), isFalse);
      expect(PlayerSettings.isNonFatalError('No such file or directory'), isFalse);
      expect(PlayerSettings.isNonFatalError('Media format not supported'), isFalse);
      expect(PlayerSettings.isNonFatalError('Server returned 401 Unauthorized'), isFalse);
      expect(PlayerSettings.isNonFatalError('Server returned 403 Forbidden (access denied)'), isFalse);
      expect(PlayerSettings.isNonFatalError('Server returned 429 Too Many Requests'), isFalse);
      expect(PlayerSettings.isNonFatalError('Failed host lookup: den.dulo.tv (OS Error: No such host is known)'), isFalse);
      expect(PlayerSettings.isNonFatalError('Connection refused'), isFalse);
    });
  });
}
