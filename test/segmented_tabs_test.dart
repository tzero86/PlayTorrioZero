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
import 'package:flutter/rendering.dart';
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

  testWidgets('it sizes itself inside an unbounded Row, as the app bar does',
      (tester) async {
    // The bug the first version shipped: Expanded segments placed in the app
    // bar's Row, where the incoming width is unbounded. Release collapses the
    // segments toward each other instead of throwing, so rendering it in this
    // context is the only way to catch it — a bounded test host hides it.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            const Text('logo'),
            const Spacer(),
            SegmentedTabs<String>(
              options: options,
              selected: 'all',
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'a flex child under unbounded width is the failure mode');

    final first = tester.getSize(find.byType(FocusableCard).at(0));
    final second = tester.getSize(find.byType(FocusableCard).at(1));
    expect(first.width, greaterThanOrEqualTo(78),
        reason: 'segments sized by Expanded collapse toward zero out here');
    expect(second.width, first.width,
        reason: 'segments must stay equal for the indicator arithmetic');
    expect(
      tester.getSize(find.byType(SegmentedTabs<String>)).width,
      moreOrLessEquals(first.width * options.length, epsilon: 0.5),
      reason: 'the control should be exactly its segments wide',
    );

    // The visible symptom the user reported: adjacent labels touching.
    final all = tester.getRect(find.text('All'));
    final movies = tester.getRect(find.text('Movies'));
    expect(all.right, lessThan(movies.left),
        reason: 'adjacent labels must not run into each other');
  });

  testWidgets('it never exceeds the width it is offered', (tester) async {
    // A loose, bounded parent — what Flexible hands it in the app bar. The
    // control must divide the space it is given rather than run past it: it
    // previously ran off the end of the bar and took the icon buttons with it.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SegmentedTabs<String>(
              options: options,
              selected: 'all',
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final control = tester.getSize(find.byType(SegmentedTabs<String>));
    expect(control.width, lessThanOrEqualTo(200),
        reason: 'running past the offered width is what pushed the bar out');
    expect(control.width, 200,
        reason: 'it should take what it is offered, so segments stay equal');
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

  testWidgets('no label is ellipsised when the control sizes to its content',
      (tester) async {
    // Content-sized is where the padding budget decides everything: the segment
    // width is derived from the measured labels, so any shortfall in that
    // arithmetic truncates the widest one. A bounded host cannot show this,
    // because there the segments simply divide whatever width they are handed.
    //
    // This is the bug it exists for: the budget counted the horizontal padding
    // but not the inset margin inside the segment, so "Movies" landed 2px short
    // and rendered as "Movi…" while the shorter labels were fine.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            const Text('logo'),
            const Spacer(),
            SegmentedTabs<String>(
              options: options,
              selected: 'all',
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    for (final option in options) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(option.label),
      );
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '"${option.label}" was truncated to fit its segment');
    }
  });

  testWidgets('a long label gets the width it needs, not a fixed ceiling',
      (tester) async {
    // The chips this control replaces showed labels like "Compact (Dense Grid)"
    // in full. A 136px segment ceiling silently truncated them, which is a worse
    // outcome than a wide control.
    const longOptions = <SegmentedTabOption<String>>[
      SegmentedTabOption(value: 'compact', label: 'Compact (Dense Grid)'),
      SegmentedTabOption(value: 'spacious', label: 'Spacious (Large Covers)'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            const Text('logo'),
            const Spacer(),
            SegmentedTabs<String>(
              options: longOptions,
              selected: 'compact',
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    for (final option in longOptions) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(option.label),
      );
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '"${option.label}" was truncated by the segment ceiling');
    }
  });
}
