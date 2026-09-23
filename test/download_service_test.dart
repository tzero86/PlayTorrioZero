import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/download/download_task_model.dart';
import 'package:zplay/utils/platform/storage_space_helper.dart';

void main() {
  group('Download Task System Tests', () {
    test('DownloadTask serialization round-trip', () {
      final now = DateTime.now();
      final task = DownloadTask(
        id: 'task_123',
        title: 'Inception',
        mediaId: 'tt1375666',
        type: 'movie',
        season: null,
        episode: null,
        posterUrl: 'https://image.tmdb.org/t/p/w500/poster.jpg',
        backdropUrl: 'https://image.tmdb.org/t/p/w1280/backdrop.jpg',
        year: '2010',
        sourceType: DownloadSourceType.p2p,
        sourceName: 'Torrent Galaxy 1080p',
        magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        infoHash: '0123456789abcdef0123456789abcdef01234567',
        targetFilePath: '/downloads/Inception.mkv',
        status: DownloadStatus.downloading,
        receivedBytes: 500 * 1024 * 1024,
        totalBytes: 1000 * 1024 * 1024,
        speedBytesPerSec: 5 * 1024 * 1024,
        etaSeconds: 100,
        peers: 24,
        createdAt: now,
      );

      final json = task.toJson();
      final reconstructed = DownloadTask.fromJson(json);

      expect(reconstructed.id, equals('task_123'));
      expect(reconstructed.title, equals('Inception'));
      expect(reconstructed.mediaId, equals('tt1375666'));
      expect(reconstructed.type, equals('movie'));
      expect(reconstructed.sourceType, equals(DownloadSourceType.p2p));
      expect(reconstructed.status, equals(DownloadStatus.downloading));
      expect(reconstructed.receivedBytes, equals(500 * 1024 * 1024));
      expect(reconstructed.totalBytes, equals(1000 * 1024 * 1024));
      expect(reconstructed.progressPercent, closeTo(0.5, 0.001));
      expect(reconstructed.speedLabel, equals('5.00 MB/s'));
      expect(reconstructed.etaLabel, equals('1m 40s'));
      expect(reconstructed.isDownloading, isTrue);
      expect(reconstructed.isCompleted, isFalse);
    });

    test('DownloadTask copyWith updates state correctly', () {
      final task = DownloadTask(
        id: 'task_456',
        title: 'Stranger Things - S04E01',
        mediaId: 'tt6675666',
        type: 'series',
        season: 4,
        episode: 1,
        sourceType: DownloadSourceType.debrid,
        sourceName: 'Real-Debrid 4K',
        targetFilePath: '/downloads/Stranger_Things_S04E01.mp4',
        status: DownloadStatus.downloading,
        receivedBytes: 100,
        totalBytes: 200,
        createdAt: DateTime.now(),
      );

      final completed = task.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: 200,
        totalBytes: 200,
        completedAt: DateTime.now(),
      );

      expect(completed.status, equals(DownloadStatus.completed));
      expect(completed.isCompleted, isTrue);
      expect(completed.progressPercent, equals(1.0));
      expect(completed.completedAt, isNotNull);
    });

    test('Storage space info formatting', () {
      const info = StorageSpaceInfo(
        freeBytes: 15 * 1024 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024 * 1024,
      );

      expect(info.freeFormatted, equals('15.00 GB'));
      expect(info.totalFormatted, equals('100.00 GB'));
    });
  });
}
