/// Guards that content cards are reachable and activatable without a pointer.
///
/// Every card used to be `MouseRegion > GestureDetector`, and `GestureDetector`
/// is not a `Focus` widget - so on Android TV the whole catalogue was
/// unreachable with a remote (docs/UX_FINDINGS.md, Critical: "Android TV
/// (D-pad) has no focus traversal"). These tests fail if a card regresses to a
/// pointer-only wrapper, if the remote's centre key stops activating a focused
/// card, or if arrow traversal stops moving between cards.
///
/// The key codes here are the ones a real remote sends, not `enter` alone:
/// Android TV reports its centre button as [LogicalKeyboardKey.select], and some
/// gamepad-style remotes report [LogicalKeyboardKey.gameButtonA]. Flutter's
/// `WidgetsApp` defaults bind all of them to `ActivateIntent`, which is what
/// `FocusableCard` handles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/movie/movie.dart';
import 'package:zplay/widgets/common/focusable_card.dart';
import 'package:zplay/widgets/movie/movie_card.dart';

void main() {
  setUp(() {
    // A TV has no touch and no pointer, so a focus highlight must always be
    // drawn. Under the default `automatic` strategy the app starts in touch
    // mode and a focused card would paint no ring at all.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  Finder focusRings() => find.byWidgetPredicate((w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).border != null);

  testWidgets('a card activates on the keys a TV remote actually sends',
      (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          FocusableCard(
            onTap: () => hits.add('first'),
            builder: (_, s) => const SizedBox(width: 120, height: 120),
          ),
          FocusableCard(
            onTap: () => hits.add('second'),
            builder: (_, s) => const SizedBox(width: 120, height: 120),
          ),
        ]),
      ),
    ));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(hits, isEmpty, reason: 'nothing is focused yet');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(hits, ['first'], reason: 'select is the Android TV centre key');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(hits, ['first', 'second'], reason: 'arrowRight must move focus');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(hits, ['first', 'second', 'first'],
        reason: 'gamepad A is what some remotes report instead of select');
  });

  testWidgets('a MovieCard in a horizontal rail is reachable and navigable',
      (tester) async {
    var hits = 0;
    final movie = Movie(
      id: 'zplay-focus-probe',
      name: 'Probe Movie',
      year: '2024',
      type: 'movie',
      addonBaseUrl: 'https://example.invalid',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 380,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(
                width: 170,
                height: 360,
                child: MovieCard(movie: movie, onTap: () => hits += 1),
              ),
              SizedBox(
                width: 170,
                height: 360,
                child: MovieCard(movie: movie, onTap: () => hits += 10),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FocusableCard), findsNWidgets(2),
        reason: 'MovieCard must stay built on the focus primitive');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    expect(hits, 1, reason: 'the first card activates on the remote centre key');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    expect(hits, 11, reason: 'arrowRight must move focus to the next card');

    expect(focusRings(), findsWidgets,
        reason: 'a focused card with no visible ring is unusable on a TV');
  });
}
