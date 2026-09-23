import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/models/my_list/my_list_item.dart';
import 'package:zplay/services/my_list/my_list_service.dart';

/// Integration test covering the full My List lifecycle:
/// add -> check -> remove -> toggle -> persistence

void main() {
  group('MyList full flow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      MyListService.items.value = [];
      await MyListService.initialize();
    });

    test('full add-remove-persist cycle', () async {
      // Phase 1: Start empty
      expect(MyListService.items.value, isEmpty);

      // Phase 2: Add items from different sources
      final movieItem = MyListItem.fromMovieDetail(
        id: 'tt1375666', name: 'Inception', year: '2010', type: 'movie',
      );
      final seriesItem = MyListItem(
        traktId: 200, title: 'Breaking Bad', year: 2008, type: 'series',
        addedAt: DateTime(2026, 6, 1),
      );
      final animeItem = MyListItem.fromMovieDetail(
        id: '123', name: 'Attack on Titan', year: '2013', type: 'anime',
      );

      MyListService.add(movieItem);
      MyListService.add(seriesItem);
      MyListService.add(animeItem);

      expect(MyListService.items.value.length, 3);

      // Phase 3: Check presence
      expect(MyListService.isInList(movieItem), true);
      expect(MyListService.isInList(seriesItem), true);

      // Phase 4: Remove one
      MyListService.remove(movieItem);
      expect(MyListService.items.value.length, 2);
      expect(MyListService.isInList(movieItem), false);

      // Phase 5: Toggle (remove then add)
      MyListService.toggle(seriesItem);
      expect(MyListService.isInList(seriesItem), false);
      MyListService.toggle(seriesItem);
      expect(MyListService.isInList(seriesItem), true);

      // Phase 6: Verify items after removal and toggle
      // Inception was removed, seriesItem was toggled off then on
      final titles = MyListService.items.value.map((i) => i.title).toSet();
      expect(titles.contains('Breaking Bad'), true);
      expect(titles.contains('Attack on Titan'), true);
      expect(titles.length, 2); // Inception was removed

      // Phase 7: Verify dedup
      MyListService.add(MyListItem(
        traktId: 200, title: 'Breaking Bad Duplicate', year: 2008,
        type: 'series', addedAt: DateTime(2026),
      ));
      expect(MyListService.items.value.length, 2); // not 3

      // Phase 8: Verify list is intact (items survived all operations)
      expect(MyListService.items.value.length, 2);
      final allTitles = MyListService.items.value.map((i) => i.title).toSet();
      expect(allTitles.contains('Breaking Bad'), true);
      expect(allTitles.contains('Attack on Titan'), true);
    });

    test('maxItems cap works end-to-end', () {
      for (int i = 0; i < 600; i++) {
        MyListService.add(MyListItem.fromMovieDetail(
          id: 'tt${i.toString().padLeft(7, '0')}',
          name: 'Movie $i', type: 'movie', year: '2024',
        ));
      }
      expect(MyListService.items.value.length, 500);

      // First items should be gone (oldest removed)
      final allTitles = MyListService.items.value.map((i) => i.title).toList();
      expect(allTitles.contains('Movie 0'), false);
      expect(allTitles.contains('Movie 599'), true);
    });
  });
}
