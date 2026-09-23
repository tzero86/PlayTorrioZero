import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/models/my_list/my_list_item.dart';
import 'package:zplay/services/my_list/my_list_service.dart';
import 'package:zplay/pages/my_list/my_list_page.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('MyListPage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      MyListService.items.value = [];
      await MyListService.initialize();
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(wrap(const MyListPage()));
      await tester.pumpAndSettle();
      expect(find.text('Your list is empty'), findsOneWidget);
    });

    testWidgets('shows items when list has content', (tester) async {
      MyListService.add(MyListItem(traktId: 1, title: 'Inception', year: 2010, type: 'movie', addedAt: DateTime(2026)));
      MyListService.add(MyListItem(traktId: 2, title: 'Interstellar', year: 2014, type: 'movie', addedAt: DateTime(2026)));

      await tester.pumpWidget(wrap(const MyListPage()));
      await tester.pumpAndSettle();
      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);
    });

    testWidgets('has sort dropdown', (tester) async {
      await tester.pumpWidget(wrap(const MyListPage()));
      await tester.pumpAndSettle();
      expect(find.text('Recently Added'), findsOneWidget);
    });

    testWidgets('removes item on long press and confirm', (tester) async {
      MyListService.add(MyListItem(traktId: 1, title: 'Test Movie', year: 2024, type: 'movie', addedAt: DateTime(2026)));
      await tester.pumpWidget(wrap(const MyListPage()));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Test Movie'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from My List?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Test Movie'), findsNothing);
    });
  });
}
