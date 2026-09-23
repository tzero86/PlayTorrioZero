import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/continue_watching/continue_watching_item.dart';
import 'package:zplay/models/my_list/my_list_item.dart';
import 'package:zplay/services/continue_watching/continue_watching_service.dart';
import 'package:zplay/services/home/home_page_settings.dart';
import 'package:zplay/services/my_list/my_list_service.dart';

import 'dart:io';

class _TestHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _TestHttpOverrides();

  test('Test BestSimilar recommendations for My List and Continue Watching', () async {
    // 1. Setup My List with a movie
    MyListService.items.value = [
      MyListItem(
        imdbId: 'tt0137523',
        title: 'Fight Club',
        type: 'movie',
        year: 1999,
        addedAt: DateTime.now(),
      ),
    ];

    // 2. Setup Continue Watching with a show
    ContinueWatchingService.activeItems.value = [
      ContinueWatchingItem(
        id: 'tt13207736',
        title: 'Severance',
        type: 'series',
        year: '2022',
        positionSeconds: 500,
        totalDurationSeconds: 3000,
        lastWatchedAt: DateTime.now(),
        isTorrent: false,
      ),
    ];

    HomePageSettings.enableSimilar.value = true;

    final listSection = await HomePageSettings.fetchBestSimilarSection(forceRefresh: true);
    print('List Section: ${listSection?.title} -> movies: ${listSection?.movies.length}');
    expect(listSection != null, true);
    expect(listSection!.title.contains('Fight Club'), true);

    final watchingSection = await HomePageSettings.fetchContinueWatchingSimilarSection(forceRefresh: true);
    print('Watching Section: ${watchingSection?.title} -> movies: ${watchingSection?.movies.length}');
    expect(watchingSection != null, true);
    expect(watchingSection!.title.contains('Severance'), true);
  });

  test('Test Recommendation toggles disable fetching', () async {
    HomePageSettings.enableSimilar.value = false;
    HomePageSettings.enableWatchingSimilar.value = false;
    HomePageSettings.enableTraktRecommendations.value = false;
    HomePageSettings.enableSimklRecommendations.value = false;

    expect(await HomePageSettings.fetchBestSimilarSection(forceRefresh: true), isNull);
    expect(await HomePageSettings.fetchContinueWatchingSimilarSection(forceRefresh: true), isNull);
    expect(await HomePageSettings.fetchTraktRecommendationsSection(forceRefresh: true), isNull);
    expect(await HomePageSettings.fetchSimklRecommendationsSection(forceRefresh: true), isNull);
  });
}
