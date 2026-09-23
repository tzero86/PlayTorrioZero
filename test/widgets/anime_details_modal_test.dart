import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/anime/anime_media.dart';
import 'package:zplay/pages/anime/anime_details_modal.dart';

void main() {
  testWidgets('AnimeDetailsModal renders jump input, 50-chunk selector, and relations', (tester) async {
    const testAnime = AnimeMedia(
      id: 21,
      titleEnglish: 'One Piece',
      titleRomaji: 'ONE PIECE',
      totalEpisodes: 1120,
      format: 'TV',
      status: 'RELEASING',
      genres: ['Action', 'Adventure', 'Fantasy'],
      relations: [
        AnimeRelation(
          id: 1111,
          relationType: 'SIDE_STORY',
          title: 'One Piece: Red',
          format: 'MOVIE',
          status: 'FINISHED',
          coverUrl: 'https://example.com/red.jpg',
        ),
      ],
      recommendations: [
        AnimeMedia(
          id: 22,
          titleEnglish: 'Bleach',
          coverImageLarge: 'https://example.com/bleach.jpg',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeDetailsModal(
            initialAnime: testAnime,
            onPlayEpisode: (ep, isDub, server) {},
            onNavigateToAnime: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    // Verify Title & Episodes count
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.textContaining('1120 total'), findsOneWidget);

    // Verify Jump Input
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Jump to ep #'), findsOneWidget);

    // Verify 50-chunk dropdown
    expect(find.text('1 – 50'), findsOneWidget);

    // Type in Jump to Episode 534
    await tester.enterText(find.byType(TextField), '534');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();

    // Verify it jumped to the chunk containing Episode 534 (501 - 550)
    expect(find.text('501 – 550'), findsOneWidget);
    expect(find.text('534'), findsNWidgets(2));

    // Scroll down to Franchise & Relations
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();

    // Verify Franchise & Relations
    expect(find.text('Franchise & Relations'), findsOneWidget);
    expect(find.text('One Piece: Red'), findsOneWidget);

    // Scroll down to Recommendations
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();

    // Verify Recommendations
    expect(find.text('You May Also Like'), findsOneWidget);
    expect(find.text('Bleach'), findsOneWidget);
  });
}
