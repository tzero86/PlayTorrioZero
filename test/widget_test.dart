import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zplay/services/my_list/my_list_service.dart';
import 'package:zplay/services/theme/glass_settings.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Initialize services that the app needs
    SharedPreferences.setMockInitialValues({});
    await GlassSettings.initialize();
    await MyListService.initialize();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('PlayTorrio'),
          ),
        ),
      ),
    );

    expect(find.text('PlayTorrio'), findsOneWidget);
  });
}
