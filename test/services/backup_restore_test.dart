import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/services/backup/backup_restore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('export then import preserves a debrid credential', () async {
    SharedPreferences.setMockInitialValues({
      'rd_access_token': 'rd-secret-token',
      'debrid_service': 'Real-Debrid',
      'use_debrid_for_streams': true,
    });

    final exported = await BackupRestoreService.exportSettingsJson();

    // The exporter must not write a debrid object full of keys no provider uses.
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    expect(decoded.containsKey('debrid'), isFalse);
    expect(
      (decoded['settings'] as Map<String, dynamic>)['rd_access_token'],
      'rd-secret-token',
    );

    // Fresh install on another device: drop the live store before importing.
    SharedPreferences.setMockInitialValues({});
    await BackupRestoreService.importSettingsJson(exported);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('rd_access_token'), 'rd-secret-token');
    expect(prefs.getString('debrid_service'), 'Real-Debrid');
    expect(prefs.getBool('use_debrid_for_streams'), isTrue);
  });

  test('older backup with a debrid object still imports', () async {
    final legacy = const JsonEncoder.withIndent('  ').convert({
      'version': '1.1.6',
      'platform': 'android',
      'settings': {
        'rd_access_token': 'legacy-token',
        'debrid_service': 'Real-Debrid',
      },
      'debrid': {
        'selectedService': 'Real-Debrid',
        'rdKey': '',
        'torboxKey': '',
        'alldebridKey': '',
        'premiumizeKey': '',
        'debridlinkKey': '',
      },
      'iptv': {
        'customPortals': <String>[],
        'favoritePortals': <String>[],
      },
    });

    SharedPreferences.setMockInitialValues({});
    await BackupRestoreService.importSettingsJson(legacy);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('rd_access_token'), 'legacy-token');
    expect(prefs.getString('debrid_service'), 'Real-Debrid');
  });
}
