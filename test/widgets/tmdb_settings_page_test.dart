import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/pages/settings/tmdb_settings_page.dart';
import 'package:zplay/services/metadata/tmdb_service.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

/// A tall surface keeps the credential card and the credits card inside the
/// viewport, so the ListView builds both and the text assertions are exact.
Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(wrap(const TmdbSettingsPage()));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TmdbService.initialize();
  });

  testWidgets('explains the key and keeps the field obscured by default', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.textContaining('themoviedb.org'), findsWidgets);
    expect(find.textContaining('stored only on this device'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.controller!.text, isEmpty);
    expect(find.byTooltip('Show Key'), findsOneWidget);
  });

  testWidgets('shows the TMDb attribution notice verbatim', (tester) async {
    await pumpPage(tester);

    expect(
      find.text(
        'This product uses the TMDB API but is not endorsed or certified by TMDB.',
      ),
      findsOneWidget,
    );
  });
}
