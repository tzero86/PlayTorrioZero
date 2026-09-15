import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/diagnostics/crash_breadcrumbs.dart';

void main() {
  setUp(() => CrashBreadcrumbs.clearForTest());

  group('CrashBreadcrumbs', () {
    test('buffer is bounded at maxEntries', () {
      for (var i = 0; i < CrashBreadcrumbs.maxEntries + 50; i++) {
        CrashBreadcrumbs.route('push', 'Page$i');
      }
      expect(CrashBreadcrumbs.entries.length, CrashBreadcrumbs.maxEntries);
    });

    test('stream open/stop sequence leaves ordered trail', () {
      CrashBreadcrumbs.route('push', 'DetailsPage');
      CrashBreadcrumbs.stream('open', title: 'Movie', addon: 'stremio');
      CrashBreadcrumbs.route('push', 'PlayerScreen');
      CrashBreadcrumbs.stream('stop', title: 'Movie');
      CrashBreadcrumbs.route('pop', 'PlayerScreen');

      final trail =
          CrashBreadcrumbs.entries.map((e) => e.message).toList();
      expect(trail, [
        'push DetailsPage',
        'stream.open',
        'push PlayerScreen',
        'stream.stop',
        'pop PlayerScreen',
      ]);
    });

    test('error and memory entries are recorded around cycle', () {
      CrashBreadcrumbs.lifecycle('start');
      CrashBreadcrumbs.memory('app.detached');
      CrashBreadcrumbs.error('boom', context: 'PlayerScreen.playback t');

      final cats = CrashBreadcrumbs.entries.map((e) => e.category).toList();
      expect(cats, ['lifecycle', 'memory', 'error']);
    });
    test('dumpText covers browse->stream->back cycle', () {
      CrashBreadcrumbs.route('push', 'DetailsPage');
      CrashBreadcrumbs.stream('open', title: 'Ep1');
      CrashBreadcrumbs.route('pop', 'WatchScreen');
      final dump = CrashBreadcrumbs.dumpText();
      expect(dump, contains('stream.open'));
      expect(dump, contains('pop WatchScreen'));
    });
  });

  group('jank sampler', () {
    FrameTiming timing({required int buildUs, required int rasterUs}) {
      return FrameTiming(
        vsyncStart: 0,
        buildStart: 1000,
        buildFinish: 1000 + buildUs,
        rasterStart: 1000 + buildUs,
        rasterFinish: 1000 + buildUs + rasterUs,
        rasterFinishWallTime: 1000 + buildUs + rasterUs + 10,
        frameNumber: 1,
      );
    }

    test('smooth frames leave no breadcrumb', () {
      CrashBreadcrumbs.recordTimingsForTest(
        List.generate(60, (_) => timing(buildUs: 4000, rasterUs: 6000)),
      );
      expect(
        CrashBreadcrumbs.entries.where((e) => e.category == 'jank'),
        isEmpty,
      );
    });

    test('janky frames leave one breadcrumb with counts, then throttle', () {
      CrashBreadcrumbs.recordTimingsForTest([
        timing(buildUs: 4000, rasterUs: 6000),
        timing(buildUs: 20000, rasterUs: 20000),
        timing(buildUs: 50000, rasterUs: 10000),
      ]);
      final jank =
          CrashBreadcrumbs.entries.where((e) => e.category == 'jank');
      expect(jank, hasLength(1));
      expect(jank.single.data?['frames'], '3');
      expect(jank.single.data?['jank'], '2');
      expect(jank.single.data?['avgRasterMs'], isNotNull);

      CrashBreadcrumbs.recordTimingsForTest([
        timing(buildUs: 50000, rasterUs: 50000),
      ]);
      expect(
        CrashBreadcrumbs.entries.where((e) => e.category == 'jank'),
        hasLength(1),
      );
    });

    testWidgets('start/stop registers and removes the timings callback',
        (tester) async {
      CrashBreadcrumbs.startJankSampling();
      expect(CrashBreadcrumbs.jankSamplingForTest, isTrue);
      CrashBreadcrumbs.startJankSampling();
      CrashBreadcrumbs.stopJankSampling();
      expect(CrashBreadcrumbs.jankSamplingForTest, isFalse);
    });
  });

  group('BreadcrumbObserver', () {
    testWidgets('logs push and pop', (tester) async {
      CrashBreadcrumbs.clearForTest();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [BreadcrumbObserver()],
          home: const _Page('home'),
        ),
      );
      final ctx = tester.element(find.text('home'));
      Navigator.of(ctx).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'details'),
          builder: (_) => const _Page('details'),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      final msgs =
          CrashBreadcrumbs.entries.map((e) => e.message).toList();
      expect(msgs, contains('push details'));
      expect(msgs, contains('pop details'));
    });
  });
}

class _Page extends StatelessWidget {
  final String label;
  const _Page(this.label);

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}
