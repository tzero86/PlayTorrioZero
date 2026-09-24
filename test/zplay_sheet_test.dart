/// Guards the shared sheet shell and row.
///
/// Sheets each hand-rolled the same structure with different numbers —
/// `0xFF16161E` with a 28px top radius in one, `0xFF0F121C` with 24 in another,
/// drag handles of 44x4.5 and 40x4. `ZplayRadius.sheetTop` already existed for
/// this and was used by nothing, so the point of these tests is that the shell
/// takes its shape from the token layer rather than from a literal.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/theme/design_tokens.dart';
import 'package:zplay/widgets/common/focusable_card.dart';
import 'package:zplay/widgets/common/zplay_sheet.dart';

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// The shell itself is the outermost [Container] of the sheet.
  BoxDecoration shellDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ZplaySheet),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('the shell takes its shape from the token layer', (tester) async {
    await tester.pumpWidget(host(const ZplaySheet(
      title: 'Sources',
      child: SizedBox(height: 80),
    )));
    await tester.pump();

    expect(shellDecoration(tester).borderRadius, ZplayRadius.sheetTop,
        reason: 'a hand-written radius here is the bug this component removes');
  });

  testWidgets('the header states what you are acting on', (tester) async {
    await tester.pumpWidget(host(const ZplaySheet(
      title: 'Frieren',
      subtitle: 'Episode 12 · 9 sources',
      child: SizedBox(height: 80),
    )));
    await tester.pump();

    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Episode 12 · 9 sources'), findsOneWidget);
  });

  testWidgets('a row is a comfortable target that a remote can drive',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(ZplaySheet(
      title: 'Sources',
      child: Column(
        children: [
          ZplaySheetItem(
            title: 'ReCloud',
            subtitle: '1080p · SUB',
            onTap: () => taps += 1,
          ),
          ZplaySheetItem(
            title: 'VidNest',
            subtitle: '720p · DUB',
            onTap: () {},
          ),
        ],
      ),
    )));
    await tester.pump();

    expect(tester.getSize(find.byType(FocusableCard).first).height,
        greaterThanOrEqualTo(56),
        reason: 'rows must clear the comfortable minimum target');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taps, 1, reason: 'select is the Android TV centre key');
  });

  testWidgets('selection is a tick, and an actionless row is unreachable',
      (tester) async {
    final reached = <String>[];
    await tester.pumpWidget(host(ZplaySheet(
      title: 'Sources',
      child: Column(
        children: [
          ZplaySheetItem(
            title: 'Chosen',
            selected: true,
            onTap: () => reached.add('chosen'),
          ),
          // No onTap: a heading or a disabled row must not be reachable.
          const ZplaySheetItem(title: 'Heading'),
          ZplaySheetItem(
            title: 'Other',
            onTap: () => reached.add('other'),
          ),
        ],
      ),
    )));
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget,
        reason: 'exactly one row may be marked as the current choice');

    // Walking focus: if the actionless row were reachable, the second
    // activation would land on it and reach nothing.
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
    }
    expect(reached, ['chosen', 'other'],
        reason: 'traversal must skip the row that has no action');
  });

  testWidgets('a leading mark renders before the title', (tester) async {
    await tester.pumpWidget(host(const ZplaySheet(
      leading: Icon(Icons.hub_rounded),
      title: 'Marketplace',
      child: SizedBox(height: 40),
    )));
    await tester.pump();

    expect(find.byIcon(Icons.hub_rounded), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(Icons.hub_rounded)).right,
      lessThanOrEqualTo(tester.getRect(find.text('Marketplace')).left),
      reason: 'the leading mark must sit before the title, not overlap it',
    );
  });

  testWidgets('a fixed-height sheet gives its body a definite frame',
      (tester) async {
    // A definite height is what lets a body use Expanded and scroll its own
    // list; a min-height sheet cannot, so sheets that fill their frame need it.
    await tester.pumpWidget(host(const ZplaySheet(
      title: 'Marketplace',
      heightFactor: 0.5,
      child: SizedBox(height: 40),
    )));
    await tester.pump();

    expect(tester.getSize(find.byType(ZplaySheet)).height, greaterThan(40),
        reason: 'a fixed-height sheet fills its frame, not just its content');
  });
}
