import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/pages/anime/anime_search_page.dart';

void main() {
  testWidgets('AnimeSearchPage renders custom dropdown buttons, 18+ toggle, and search input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnimeSearchPage(),
      ),
    );

    // Verify search input
    expect(find.byType(TextField), findsOneWidget);

    // Verify 18+ toggle
    expect(find.text('18+'), findsOneWidget);

    // Verify custom dropdown filter buttons
    expect(find.textContaining('Sort:'), findsOneWidget);
    expect(find.text('Genre'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });
}
