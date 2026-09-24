/// Guards the rail skeleton.
///
/// A skeleton only earns its place if it is the size of the thing it stands in
/// for. One that is the wrong size moves the whole rail when the real cards land,
/// which is worse than having shown nothing — so the geometry assertions here are
/// the point of the test, not incidental detail.
///
/// Nothing in it may be focusable either: a remote must not be able to land on a
/// placeholder and press it.
///
/// Note for future tests: [RailSkeleton] repeats an animation for as long as it
/// is mounted, so `pumpAndSettle` will time out on any tree containing one. Use
/// `pump`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/widgets/common/focusable_card.dart';
import 'package:zplay/widgets/common/rail_skeleton.dart';
import 'package:zplay/widgets/movie/movie_card.dart';

void main() {
  final sizing = MovieCardSizing.fromWidth(1000);

  Widget host({int count = 4, bool showHeader = false}) => MaterialApp(
        home: Scaffold(
          body: RailSkeleton(
            sizing: sizing,
            count: count,
            showHeader: showHeader,
          ),
        ),
      );

  testWidgets('the placeholder row occupies the rail height exactly',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(tester.getSize(find.byType(ListView)).height, sizing.totalHeight,
        reason: 'a rail that changes height when content arrives is a jump');
  });

  testWidgets('it draws the number of cards it was asked for', (tester) async {
    await tester.pumpWidget(host(count: 4));
    await tester.pump();

    final list = tester.widget<ListView>(find.byType(ListView));
    final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 4);
  });

  testWidgets('nothing in a skeleton can take focus', (tester) async {
    await tester.pumpWidget(host(showHeader: true));
    await tester.pump();

    expect(find.byType(FocusableCard), findsNothing,
        reason: 'a remote must never land on a placeholder');
  });
}
