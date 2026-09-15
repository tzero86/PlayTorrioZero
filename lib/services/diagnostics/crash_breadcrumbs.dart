import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Minimal crash-breadcrumb log for post-mortem debugging of the
/// browse -> stream -> back crash/slowdown.
///
/// Design constraints (boring on purpose):
/// * Bounded: at most [maxEntries] in memory; the on-disk file is capped at
///   [maxFileBytes] with tail-rotation. Nothing here can grow unboundedly.
/// * Throttled: file flushes happen at most every [flushInterval]; explicit
///   [memory] samples at most every [memorySampleInterval]. Sampling only
///   happens on discrete events (route / stream / lifecycle) — never
///   per-frame. The RSS read itself ([ProcessInfo.currentRss]) is a cheap
///   synchronous getter, safe to attach to every breadcrumb.
/// * Release-safe: every file/syscall is wrapped in try/catch; diagnostics
///   must never throw into app code. Before [initialize] resolves the
///   directory, entries accumulate in memory only.
/// * Reuses no crash SDK — there is none in this repo (startup failures just
///   `debugPrint`); this file log is the crash trail.
class CrashBreadcrumbs {
  static const int maxEntries = 200;
  static const int maxFileBytes = 64 * 1024;
  static const int _rotatedKeepLines = 100;
  static const Duration flushInterval = Duration(seconds: 5);
  static const Duration memorySampleInterval = Duration(seconds: 15);
  static const String fileName = 'crash_breadcrumbs.log';

  static final ListQueue<Breadcrumb> _entries = ListQueue<Breadcrumb>();
  static Directory? _dir;
  static bool _initializing = false;
  static DateTime? _lastFlush;
  static DateTime? _lastMemorySample;
  static int _seq = 0;
  static int _persistedSeq = 0;

  CrashBreadcrumbs._();

  /// Resolves the log directory. Fire-and-forget from `main()` via
  /// `unawaited(...)` so it never adds startup latency.
  static Future<void> initialize() async {
    if (_dir != null || _initializing) return;
    _initializing = true;
    try {
      _dir = await getApplicationSupportDirectory();
      await _flush();
    } catch (_) {
      // Diagnostics must never break the app.
    } finally {
      _initializing = false;
    }
  }

  static void lifecycle(String state) =>
      _add('lifecycle', 'app.$state', null, forceFlush: true);

  static void route(String action, String? name) =>
      _add('route', '$action ${name ?? '?'}', null);

  static void stream(String event, {String? title, String? addon}) =>
      _add('stream', 'stream.$event', <String, String>{
        if (title != null && title.isNotEmpty) 'title': _truncate(title),
        if (addon != null && addon.isNotEmpty) 'addon': _truncate(addon),
      }, forceFlush: true);

  /// Explicit memory sample. Throttled; every breadcrumb already carries the
  /// current RSS, so rapid event bursts stay fully visible regardless.
  static void memory(String reason) {
    final now = DateTime.now();
    if (_lastMemorySample != null &&
        now.difference(_lastMemorySample!) < memorySampleInterval) {
      return;
    }
    _lastMemorySample = now;
    _add('memory', 'memory.$reason', null, forceFlush: true);
  }

  static void error(Object err, {String? context}) =>
      _add('error', _truncate('$err'), <String, String>{
        if (context != null && context.isNotEmpty)
          'context': _truncate(context),
      }, forceFlush: true);

  static List<Breadcrumb> get entries => List.unmodifiable(_entries);

  static String dumpText() => _entries.map((e) => e.toString()).join('\n');

  @visibleForTesting
  static void clearForTest() {
    _entries.clear();
    _lastFlush = null;
    _lastMemorySample = null;
    _seq = 0;
    _persistedSeq = 0;
  }

  static void _add(
    String category,
    String message,
    Map<String, String>? data, {
    bool forceFlush = false,
  }) {
    try {
      _entries.add(
        Breadcrumb(
          ++_seq,
          DateTime.now(),
          category,
          _truncate(message),
          _currentRssMb(),
          data == null || data.isEmpty ? null : data,
        ),
      );
      while (_entries.length > maxEntries) {
        _entries.removeFirst();
      }
    } catch (_) {
      return;
    }
    _scheduleFlush(force: forceFlush);
  }

  static double? _currentRssMb() {
    try {
      return (ProcessInfo.currentRss / 1048576 * 10).round() / 10;
    } catch (_) {
      return null;
    }
  }

  static String _truncate(String s, [int max = 200]) =>
      s.length <= max ? s : s.substring(0, max);

  static void _scheduleFlush({required bool force}) {
    final now = DateTime.now();
    if (!force &&
        _lastFlush != null &&
        now.difference(_lastFlush!) < flushInterval) {
      return;
    }
    _lastFlush = now;
    unawaited(_flush());
  }

  static Future<void> _flush() async {
    try {
      final dir = _dir;
      if (dir == null) return;
      Breadcrumb? last;
      final pending = _entries.where((e) {
        final keep = e.seq > _persistedSeq;
        if (keep) last = e;
        return keep;
      }).toList();
      if (pending.isEmpty) return;
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && await file.length() > maxFileBytes) {
        await _rotate(file);
      }
      final sink = file.openWrite(mode: FileMode.append);
      try {
        for (final e in pending) {
          sink.writeln(jsonEncode(e.toJson()));
        }
      } finally {
        await sink.close();
      }
      _persistedSeq = last!.seq;
    } catch (_) {
      // Never throw out of diagnostics.
    }
  }

  static Future<void> _rotate(File file) async {
    final lines = await file.readAsLines();
    final tail = lines.length > _rotatedKeepLines
        ? lines.sublist(lines.length - _rotatedKeepLines)
        : lines;
    await file.writeAsString('${tail.join('\n')}\n', mode: FileMode.write);
  }
}

/// Single breadcrumb: what happened, when, and how much RSS the process
/// held at that moment (so the browse -> stream -> back cycle shows memory
/// around each step).
@immutable
class Breadcrumb {
  final int seq;
  final DateTime at;
  final String category;
  final String message;
  final double? rssMb;
  final Map<String, String>? data;

  const Breadcrumb(
    this.seq,
    this.at,
    this.category,
    this.message,
    this.rssMb, [
    this.data,
  ]);

  Map<String, Object?> toJson() => <String, Object?>{
        'seq': seq,
        'ts': at.toIso8601String(),
        if (rssMb != null) 'rssMb': rssMb,
        'cat': category,
        'msg': message,
        if (data != null && data!.isNotEmpty) 'data': data,
      };

  @override
  String toString() {
    final rss = rssMb == null ? '' : ' ${rssMb!.toStringAsFixed(1)}MB';
    final extra =
        data == null || data!.isEmpty ? '' : ' ${data.toString()}';
    return '[${at.toIso8601String()}][$category]$rss $message$extra';
  }
}

/// NavigatorObserver that leaves a breadcrumb on every push/pop/replace.
/// Route names are null for anonymous routes, so the widget type is logged
class BreadcrumbObserver extends NavigatorObserver {
  BreadcrumbObserver();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    CrashBreadcrumbs.route('push', _label(route));
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    CrashBreadcrumbs.route('pop', _label(route));
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    CrashBreadcrumbs.route('replace', _label(newRoute));
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  static String _label(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route?.runtimeType.toString() ?? '?';
  }
}
