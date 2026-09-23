import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/music/music_track.dart';
import 'package:zplay/services/music/lyrics_service.dart';
import 'package:zplay/services/music/youtube_stream_http.dart';

void main() {
  test('Lyrics parsing correctly formats synced lines', () {
    const lrc = '''
[00:12.50] Hello darkness my old friend
[00:18.20] I've come to talk with you again
[01:05.00] In restless dreams I walked alone
''';
    final lines = LyricsService.parseLrc(lrc);
    final lyrics = LyricsData(
      trackId: '1',
      isSynced: true,
      plainLyrics: lrc,
      syncedLines: lines,
    );
    expect(lyrics.isSynced, isTrue);
    expect(lyrics.syncedLines.length, 3);
    expect(lyrics.syncedLines[0].text, 'Hello darkness my old friend');
    expect(lyrics.syncedLines[0].timestamp, const Duration(seconds: 12, milliseconds: 500));
    expect(lyrics.syncedLines[1].timestamp, const Duration(seconds: 18, milliseconds: 200));

    // Test active line lookup
    expect(lyrics.activeLineIndex(const Duration(seconds: 5)), -1);
    expect(lyrics.activeLineIndex(const Duration(seconds: 15)), 0);
    expect(lyrics.activeLineIndex(const Duration(seconds: 25)), 1);
    expect(lyrics.activeLineIndex(const Duration(seconds: 70)), 2);
  });

  test('YoutubeStreamHttp builds clean headers with user agent', () {
    final headers = YoutubeStreamHttp.streamHeaders(
      'https://rr1---sn-xxx.googlevideo.com/videoplayback?id=123',
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    );
    expect(headers['User-Agent'], isNotNull);
    expect(headers['Accept'], '*/*');
  });

  test('MusicTrack model json round-trip', () {
    const track = MusicTrack(
      id: '123456',
      title: 'Starboy',
      artist: 'The Weeknd',
      album: 'Starboy',
      coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/starboy.jpg',
      durationSeconds: 230,
    );

    final json = track.toJson();
    final restored = MusicTrack.fromJson(json);
    expect(restored.id, '123456');
    expect(restored.title, 'Starboy');
    expect(restored.artist, 'The Weeknd');
    expect(restored.formattedDuration, '03:50');
  });
}
