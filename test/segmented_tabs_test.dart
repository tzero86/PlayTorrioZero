/// Guards the shared segmented control.
///
/// This exists because the app hand-rolls the same single-choice pattern in
/// several places (`ChoiceChip` rows in IPTV, audiobooks and books; text tabs
/// with a per-tab underline on Home), and every one of those was pointer-sized
/// with no D-pad story. Two promises are worth failing a build over:
///
/// * a segment is reachable and activatable from a remote, and
/// * the accent indicator sits on the selected segment and on nothing else —
///   before this, a focused tab and a selected tab looked the same.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/theme/design_tokens.dart';
import 'package:zplay/widgets/common/focusable_card.dart';
import 'package:zplay/widgets/common/segmented_tabs.dart';

void main() {
  const options = <SegmentedTabOption<String>>[
    SegmentedTabOption(value: 'all', label: 'All', count: 412),
    SegmentedTabOption(value: 'movies', label: 'Movies', count: 238),
    SegmentedTabOption(value: 'series', label: 'Series', count: 174),
  ];

  Widget host(
    String selected,
    void Function(String) onSelected, {
    String? semanticsLabel,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SegmentedTabs<String>(
                options: options,
                selected: selected,
                onSelected: onSelected,
                semanticsLabel: semanticsLabel,
              ),
            ),
          ),
        ),
      );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  /// The one accent-filled decoration: the selection indicator.
  Finder indicator(WidgetTester tester) {
    final accent =
        ZplayTokens.of(tester.element(find.byType(SegmentedTabs<String>))).accent;
    return find.byWidgetPredicate((widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == accent);
  }

  testWidgets('a segment activates on the keys a TV remote actually sends',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(host('all', picked.add));
    await tester.pump();

    expect(find.byType(FocusableCard), findsNWidgets(options.length),
        reason: 'segments must be built on the focus primitive');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(picked, ['all'], reason: 'select is the Android TV centre key');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, ['all', 'movies'], reason: 'arrowRight must traverse');
  });

  testWidgets('a tap picks the segment it landed on', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(host('all', picked.add));
    await tester.pump();

    await tester.tap(find.text('Series'));
    await tester.pump();

    expect(picked, ['series']);
  });

  testWidgets('every segment is at least a 44px target', (tester) async {
    await tester.pumpWidget(host('movies', (_) {}));
    await tester.pump();

    for (var i = 0; i < options.length; i++) {
      final size = tester.getSize(find.byType(FocusableCard).at(i));
      expect(size.height, greaterThanOrEqualTo(44),
          reason: 'segment $i is below the minimum comfortable target');
    }
  });

  testWidgets('the indicator moves to the selected segment and marks only it',
      (tester) async {
    for (var i = 0; i < options.length; i++) {
      await tester.pumpWidget(host(options[i].value, (_) {}));
      await tester.pumpAndSettle();

      expect(indicator(tester), findsOneWidget,
          reason: 'exactly one segment may wear the accent fill');

      final slot = tester.getRect(find.byType(FocusableCard).at(i));
      final mark = tester.getRect(indicator(tester));
      expect(mark.center.dx, moreOrLessEquals(slot.center.dx, epsilon: 1.0),
          reason: 'the indicator must sit on the selected segment');
    }
  });

  testWidgets('a segment announces its label and count', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host('all', (_) {}, semanticsLabel: 'Filter'));
    await tester.pump();

    expect(find.bySemanticsLabel('Filter'), findsOneWidget);
    expect(find.bySemanticsLabel('Movies, 238 titles'), findsOneWidget,
        reason: 'the count is only useful if it is announced too');
    expect(find.bySemanticsLabel('Series, 174 titles'), findsOneWidget);

    // The segment is one node carrying its state, so a screen reader can say
    // "All, 412 titles, selected" rather than reading the label and the number
    // as unrelated items.
    expect(
      tester.getSemantics(find.bySemanticsLabel('All, 412 titles')),
      matchesSemantics(
        label: 'All, 412 titles',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        textDirection: TextDirection.ltr,
      ),
    );

    // Must be disposed before the test body returns: the framework verifies
    // handles at the end of the body, before tearDown callbacks run.
    handle.dispose();
  });
}
