import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/anime/anime_media.dart';
import 'package:zplay/pages/anime/anime_details_page.dart';

void main() {
  testWidgets('AnimeDetailsPage renders full page layout, 50-chunk selector, jump to ep, and relations', (tester) async {
    const testAnime = AnimeMedia(
      id: 21,
      titleEnglish: 'One Piece',
      titleRomaji: 'ONE PIECE',
      totalEpisodes: 1120,
      format: 'TV',
      status: 'RELEASING',
      genres: ['Action', 'Adventure', 'Fantasy'],
      characters: [
        AnimeCharacter(
          id: 1,
          nameFull: 'Monkey D. Luffy',
          role: 'MAIN',
          imageLarge: 'https://example.com/luffy.jpg',
        ),
      ],
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

    // Set screen size to desktop width (1200x800)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnimeDetailsPage(anime: testAnime),
      ),
    );

    // Verify Title & Episodes
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.textContaining('1120 total'), findsOneWidget);

    // Verify Back Button (top-left)
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

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
    expect(find.text('534'), findsNWidgets(2)); // 1 in TextField, 1 in Episode card

    // Scroll down to check relations
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pump();

    // Verify Franchise & Relations
    expect(find.text('Franchise & Relations'), findsOneWidget);
    expect(find.text('One Piece: Red'), findsOneWidget);

    // Scroll down to check recommendations
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pump();

    // Verify Recommendations
    expect(find.text('You May Also Like'), findsOneWidget);
    expect(find.text('Bleach'), findsOneWidget);
  });
}
