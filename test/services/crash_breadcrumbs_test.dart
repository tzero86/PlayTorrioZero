import 'package:flutter/material.dart';
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
