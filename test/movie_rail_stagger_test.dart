/// Guards the rail entry stagger.
///
/// The stagger's failure mode is severe and silent: if the entry never
/// completes, the first cards stay at opacity zero and the rail renders empty.
/// Every other symptom of a broken stagger looks fine, so this asserts the end
/// state rather than the motion itself.
///
/// Note the explicit pumps. `pumpAndSettle` cannot be used here: a [MovieCard]
/// whose image has not loaded shows `PosterSkeleton`, which pulses forever, so
/// settling would time out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/addon/addon.dart';
import 'package:zplay/models/movie/movie.dart';
import 'package:zplay/models/movie/movie_section.dart';
import 'package:zplay/widgets/movie/movie_card.dart';
import 'package:zplay/widgets/movie/movie_slider_section.dart';

void main() {
  const base = 'https://example.invalid';

  final section = MovieSection(
    title: 'Because you watched',
    subtitle: '',
    contentType: 'movie',
    addonBaseUrl: base,
    catalog: AddonCatalog(type: 'movie', id: 'stagger-probe'),
    movies: [
      for (var i = 0; i < 10; i++)
        Movie(
          id: 'stagger-$i',
          name: 'Title $i',
          year: '2024',
          type: 'movie',
          addonBaseUrl: base,
        ),
    ],
  );

  testWidgets('cards are fully visible once the entry stagger finishes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: MovieSliderSection(section: section),
        ),
      ),
    ));

    // Part way in, so the animation is genuinely running rather than absent.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Past ZplayMotion.slow, which is the entry duration.
    await tester.pump(const Duration(milliseconds: 400));

    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(MovieCard).first,
            matching: find.byType(FadeTransition),
          )
          .first,
    );

    expect(fade.opacity.value, 1.0,
        reason: 'a stagger that never completes leaves the rail invisible');
  });
}
