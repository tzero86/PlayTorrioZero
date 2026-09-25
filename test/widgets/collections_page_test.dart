import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/pages/collections/collection_grid_page.dart';
import 'package:zplay/pages/collections/collections_page.dart';
import 'package:zplay/services/collections/collections_service.dart';
import 'package:zplay/services/collections/curated_collection.dart';
import 'package:zplay/services/collections/curated_collections.dart';
import 'package:zplay/widgets/movie/movie_card.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

/// The hub is fully synchronous, so one frame paints it. Explicit pumps rather
/// than `pumpAndSettle`: the tiles hold network posters that never resolve in a
/// test, and settling waits on their placeholders.
///
/// A tall surface keeps both groups inside the viewport, so the sliver builds
/// every tile and the count assertions below are exact.
Future<void> pumpHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(wrap(const CollectionsPage()));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CollectionsService.initialize();
  });

  group('CollectionsPage', () {
    testWidgets('groups collections under both kind headers', (tester) async {
      await pumpHub(tester);

      expect(find.text('Franchises'), findsOneWidget);
      expect(find.text('Memory Lane'), findsOneWidget);
    });

    testWidgets('renders one tile per curated collection', (tester) async {
      await pumpHub(tester);

      expect(
        find.byType(CollectionTile),
        findsNWidgets(curatedCollections.length),
      );
    });

    testWidgets('tapping a tile opens the grid page for that collection',
        (tester) async {
      final saga = curatedCollections.firstWhere(
        (collection) => collection.kind == CuratedKind.saga,
      );
      await pumpHub(tester);

      await tester.tap(find.byType(CollectionTile).first);
      // The reveal route runs 380 ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final grid = find.byType(CollectionGridPage);
      expect(grid, findsOneWidget);
      expect(
        find.descendant(of: grid, matching: find.text(saga.subtitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: grid, matching: find.byType(MovieCard)),
        findsWidgets,
      );
    });
  });
}
