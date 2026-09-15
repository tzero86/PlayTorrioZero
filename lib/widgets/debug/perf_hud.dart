import 'package:flutter/material.dart';

import '../../services/diagnostics/perf_monitor.dart';

/// Debug-only live performance overlay.
///
/// Reads [PerfMonitor.snapshot] and repaints at most 2Hz. The stats card is
/// pointer-transparent; only the drag handle absorbs gestures.
class PerfHud extends StatefulWidget {
  const PerfHud({super.key});

  @override
  State<PerfHud> createState() => _PerfHudState();
}

class _PerfHudState extends State<PerfHud> {
  static const int _minIntervalMs = 500;

  Offset _offset = const Offset(8, 32);
  PerfSnapshot? _shown;
  int _lastPaintMs = 0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: ValueListenableBuilder<PerfSnapshot>(
        valueListenable: PerfMonitor.snapshot,
        builder: (context, fresh, _) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (_shown == null || now - _lastPaintMs >= _minIntervalMs) {
            _shown = fresh;
            _lastPaintMs = now;
          }
          final s = _shown ?? fresh;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onPanUpdate: (details) => setState(() {
                  _offset += details.delta;
                  _offset = Offset(
                    _offset.dx.clamp(0.0, double.infinity),
                    _offset.dy.clamp(0.0, double.infinity),
                  );
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    size: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    _format(s),
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _format(PerfSnapshot s) {
  final rss = s.rssMb == null ? '?' : s.rssMb!.toStringAsFixed(0);
  final route = s.lastRoute ?? '-';
  final routeMs = s.lastRouteMs == null ? '' : ' ${s.lastRouteMs}ms';
  return 'FPS ${s.fps} jank ${s.jank} ${s.avgRasterMs.toStringAsFixed(1)}ms\n'
      'RSS ${rss}MB img ${s.imageCount}/${s.imageBytesMb}MB disk ${s.diskMb.toStringAsFixed(0)}MB\n'
      '$route$routeMs';
}
