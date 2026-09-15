import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

import 'crash_breadcrumbs.dart';

/// Point-in-time performance numbers for the debug HUD.
///
/// Immutable; [PerfMonitor.snapshot] emits a new instance on each refresh.
@immutable
class PerfSnapshot {
  final double? rssMb;
  final int fps;
  final int jank;
  final double avgRasterMs;
  final int imageCount;
  final int imageBytesMb;
  final double diskMb;
  final String? lastRoute;
  final int? lastRouteMs;

  const PerfSnapshot({
    this.rssMb,
    this.fps = 0,
    this.jank = 0,
    this.avgRasterMs = 0,
    this.imageCount = 0,
    this.imageBytesMb = 0,
    this.diskMb = 0,
    this.lastRoute,
    this.lastRouteMs,
  });

  /// Null arguments keep the current value (nullable fields are never
  /// cleared back to null by the monitor, so no sentinel is needed).
  PerfSnapshot copyWith({
    double? rssMb,
    int? fps,
    int? jank,
    double? avgRasterMs,
    int? imageCount,
    int? imageBytesMb,
    double? diskMb,
    String? lastRoute,
    int? lastRouteMs,
  }) {
    return PerfSnapshot(
      rssMb: rssMb ?? this.rssMb,
      fps: fps ?? this.fps,
      jank: jank ?? this.jank,
      avgRasterMs: avgRasterMs ?? this.avgRasterMs,
      imageCount: imageCount ?? this.imageCount,
      imageBytesMb: imageBytesMb ?? this.imageBytesMb,
      diskMb: diskMb ?? this.diskMb,
      lastRoute: lastRoute ?? this.lastRoute,
      lastRouteMs: lastRouteMs ?? this.lastRouteMs,
    );
  }
}

class _Frame {
  final DateTime at;
  final int rasterUs;
  final bool jank;

  const _Frame(this.at, this.rasterUs, this.jank);
}

/// Always-on, release-safe performance sampler.
///
/// * Frame stats come from a [SchedulerBinding.addTimingsCallback] that only
///   bumps in-memory counters and pushes [snapshot] at most every 500ms —
///   never per-frame I/O.
/// * [sampleSystem] reads RSS ([ProcessInfo.currentRss]) and the Flutter
///   image cache synchronously (both cheap getters); the disk walk runs on a
///   background [Future] at most every 15s.
/// * Jank/memory highlights are forwarded to [CrashBreadcrumbs] through its
///   existing throttled entry points only; this file never touches its
///   internals.
abstract final class PerfMonitor {
  static const Duration jankBudget = Duration(milliseconds: 34);
  static const Duration _sampleMinInterval = Duration(milliseconds: 500);
  static const Duration _hudPushInterval = Duration(milliseconds: 500);
  static const Duration _diskInterval = Duration(seconds: 15);
  static const Duration _jankForwardInterval = Duration(seconds: 30);
  static const int _jankForwardThreshold = 8;
  static const double _rssForwardDeltaMb = 50;
  static const double _bytesPerMb = 1048576;

  static final ValueNotifier<PerfSnapshot> snapshot =
      ValueNotifier<PerfSnapshot>(const PerfSnapshot());

  static bool _started = false;
  static Timer? _timer;
  static DateTime? _lastSample;
  static DateTime? _lastHudPush;
  static DateTime? _lastDiskSample;
  static DateTime? _lastJankForward;
  static double? _lastForwardedRss;
  static final Queue<_Frame> _frames = Queue<_Frame>();

  /// Idempotent and safe without a bound [SchedulerBinding].
  static void start() {
    if (_started) return;
    _started = true;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } catch (_) {
      // No binding (e.g. unit tests); system sampling still works.
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => sampleSystem());
    unawaited(sampleSystem());
  }

  static void stop() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  /// Stores the latest route transition and forwards it to [CrashBreadcrumbs].
  static void recordRoute(String action, String? name, {int? durationMs}) {
    try {
      snapshot.value = snapshot.value.copyWith(
        lastRoute: '$action ${name ?? '?'}',
        lastRouteMs: durationMs,
      );
    } catch (_) {
      // Diagnostics must never break the app.
    }
    try {
      CrashBreadcrumbs.route(action, name);
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  /// Refreshes RSS, image-cache and (throttled) disk numbers.
  ///
  /// Self-throttled to at most 2Hz; safe to call from a timer and the HUD.
  static Future<void> sampleSystem() async {
    final now = DateTime.now();
    if (_lastSample != null &&
        now.difference(_lastSample!) < _sampleMinInterval) {
      return;
    }
    _lastSample = now;

    double? rssMb;
    try {
      rssMb = ProcessInfo.currentRss / _bytesPerMb;
    } catch (_) {
      // Release-safe: keep the previous value.
    }

    var imageCount = snapshot.value.imageCount;
    var imageBytesMb = snapshot.value.imageBytesMb;
    try {
      final cache = PaintingBinding.instance.imageCache;
      imageCount = cache.currentSize;
      imageBytesMb = cache.currentSizeBytes ~/ _bytesPerMb;
    } catch (_) {
      // No binding or cache unavailable; keep previous values.
    }

    try {
      snapshot.value = snapshot.value.copyWith(
        rssMb: rssMb,
        imageCount: imageCount,
        imageBytesMb: imageBytesMb,
      );
    } catch (_) {
      // Diagnostics must never break the app.
    }

    if (rssMb != null &&
        (_lastForwardedRss == null ||
            (rssMb - _lastForwardedRss!).abs() >= _rssForwardDeltaMb)) {
      _lastForwardedRss = rssMb;
      try {
        CrashBreadcrumbs.memory('perf rss=${rssMb.toStringAsFixed(0)}MB');
      } catch (_) {
        // Diagnostics must never break the app.
      }
    }

    if (_lastDiskSample == null ||
        now.difference(_lastDiskSample!) >= _diskInterval) {
      _lastDiskSample = now;
      unawaited(_refreshDiskUsage());
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    try {
      final now = DateTime.now();
      for (final timing in timings) {
        final cost = timing.buildDuration + timing.rasterDuration;
        _frames.add(_Frame(
          now,
          timing.rasterDuration.inMicroseconds,
          cost > jankBudget,
        ));
      }
      while (_frames.length > 480) {
        _frames.removeFirst();
      }
      final cutoff = now.subtract(const Duration(seconds: 1));
      while (_frames.isNotEmpty && _frames.first.at.isBefore(cutoff)) {
        _frames.removeFirst();
      }
      if (_lastHudPush != null &&
          now.difference(_lastHudPush!) < _hudPushInterval) {
        return;
      }
      _lastHudPush = now;

      var jank = 0;
      var rasterTotalUs = 0;
      for (final frame in _frames) {
        if (frame.jank) jank++;
        rasterTotalUs += frame.rasterUs;
      }
      final fps = _frames.length;
      final avgRasterMs =
          _frames.isEmpty ? 0.0 : rasterTotalUs / _frames.length / 1000;
      snapshot.value = snapshot.value.copyWith(
        fps: fps,
        jank: jank,
        avgRasterMs: avgRasterMs,
      );

      if (jank >= _jankForwardThreshold &&
          (_lastJankForward == null ||
              now.difference(_lastJankForward!) >= _jankForwardInterval)) {
        _lastJankForward = now;
        try {
          CrashBreadcrumbs.memory('perf jank fps=$fps jank=$jank');
        } catch (_) {
          // Diagnostics must never break the app.
        }
      }
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  static Future<void> _refreshDiskUsage() async {
    try {
      var totalBytes = 0.0;
      for (final dir in await _cacheDirs()) {
        totalBytes += await _dirBytes(dir);
      }
      final diskMb = totalBytes / _bytesPerMb;
      try {
        snapshot.value = snapshot.value.copyWith(diskMb: diskMb);
      } catch (_) {
        // Diagnostics must never break the app.
      }
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  static Future<List<Directory>> _cacheDirs() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getApplicationSupportDirectory());
    } catch (_) {
      // Plugin unavailable on this platform; skip.
    }
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {
      // Plugin unavailable on this platform; skip.
    }
    return dirs;
  }

  static Future<double> _dirBytes(Directory dir) async {
    var total = 0.0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        try {
          if (entity is File) total += await entity.length();
        } catch (_) {
          // Single unreadable file must not kill the walk.
        }
      }
    } catch (_) {
      // Unreadable directory; contributes nothing.
    }
    return total;
  }

  @visibleForTesting
  static void resetForTest() {
    try {
      if (_started) {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      }
    } catch (_) {
      // No binding in some unit-test setups; just reset the state.
    }
    _started = false;
    _timer?.cancel();
    _timer = null;
    _frames.clear();
    _lastSample = null;
    _lastHudPush = null;
    _lastDiskSample = null;
    _lastJankForward = null;
    _lastForwardedRss = null;
    try {
      snapshot.value = const PerfSnapshot();
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }
}
