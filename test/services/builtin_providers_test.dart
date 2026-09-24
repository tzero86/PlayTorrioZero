import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zplay/models/stream/stream_model.dart';
import 'package:zplay/services/scraper/builtin_providers_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuiltinProvidersSettingsService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final service = BuiltinProvidersSettingsService.instance;
      await service.init();
      await service.resetToDefault();
      await service.setMode(BuiltinProvidersMode.defaultMode);
    });

    test('Initializes with default mode and all 46 providers enabled', () {
      final service = BuiltinProvidersSettingsService.instance;
      expect(service.isCustom, isFalse);
      expect(service.mode, BuiltinProvidersMode.defaultMode);
      expect(service.customOrder.length, 46);

      // In default mode, all providers are enabled
      for (final p in BuiltinProvidersSettingsService.defaultProviders) {
        expect(service.isProviderEnabled(p.id), isTrue);
      }
    });

    test('Switching to Custom mode enables custom priority and toggles', () async {
      final service = BuiltinProvidersSettingsService.instance;
      await service.setMode(BuiltinProvidersMode.customMode);
      expect(service.isCustom, isTrue);

      // Disable a specific provider
      await service.toggleProvider('cinesrc', false);
      expect(service.isProviderEnabled('cinesrc'), isFalse);
      expect(service.isProviderEnabled('dulo'), isTrue);

      // Re-enable
      await service.toggleProvider('cinesrc', true);
      expect(service.isProviderEnabled('cinesrc'), isTrue);
    });

    test('Reordering moves a provider to top and adjusts getProviderRank', () async {
      final service = BuiltinProvidersSettingsService.instance;
      await service.setMode(BuiltinProvidersMode.customMode);

      // Initially 'cinesrc' is at index 32 in default list
      final initialRank = service.getProviderRank('cinesrc');
      expect(initialRank, 32);

      // Move cinesrc to the very top (index 0)
      final oldIndex = service.customOrder.indexOf('cinesrc');
      await service.reorder(oldIndex, 0);

      expect(service.getProviderRank('cinesrc'), 0);
      expect(service.customOrder.first, 'cinesrc');
    });

    test('MoveProvider with delta adjusts rank correctly', () async {
      final service = BuiltinProvidersSettingsService.instance;
      await service.setMode(BuiltinProvidersMode.customMode);

      final firstId = service.customOrder[0];
      final secondId = service.customOrder[1];

      // Move secondId up by 1
      await service.moveProvider(secondId, -1);
      expect(service.customOrder[0], secondId);
      expect(service.customOrder[1], firstId);
    });

    test('Enable all and disable all functions properly', () async {
      final service = BuiltinProvidersSettingsService.instance;
      await service.setMode(BuiltinProvidersMode.customMode);

      await service.disableAll();
      for (final p in BuiltinProvidersSettingsService.defaultProviders) {
        expect(service.isProviderEnabled(p.id), isFalse);
      }

      await service.enableAll();
      for (final p in BuiltinProvidersSettingsService.defaultProviders) {
        expect(service.isProviderEnabled(p.id), isTrue);
      }
    });

    test('Stream sorting in Custom mode puts top provider first regardless of quality/size', () async {
      final service = BuiltinProvidersSettingsService.instance;
      await service.setMode(BuiltinProvidersMode.customMode);

      // Put CineSrc at rank 0 and Dulo at rank 1
      final cineIndex = service.customOrder.indexOf('cinesrc');
      await service.reorder(cineIndex, 0);
      final duloIndex = service.customOrder.indexOf('dulo');
      await service.reorder(duloIndex, 1);

      expect(service.getProviderRank('cinesrc'), 0);
      expect(service.getProviderRank('dulo'), 1);

      // Create stream items:
      // CineSrc has lower quality (720p, 500MB)
      final cineStream = StreamSource(
        addonName: 'ZPlayHTTP',
        providerId: 'cinesrc',
        providerName: 'CineSrc',
        title: 'CineSrc · Direct · 720p',
        description: '500 MB',
      );

      // Dulo has higher quality (4K, 25GB)
      final duloStream = StreamSource(
        addonName: 'ZPlayHTTP',
        providerId: 'dulo',
        providerName: 'Dulo',
        title: 'Dulo · Source 1 · 4K',
        description: '25 GB',
      );

      final streams = [duloStream, cineStream];

      // Sort matching watch_screen.dart custom logic:
      streams.sort((a, b) {
        final rankA = service.getProviderRank(a.providerId ?? '');
        final rankB = service.getProviderRank(b.providerId ?? '');
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        return b.qualityRank.compareTo(a.qualityRank);
      });

      // CineSrc MUST be first because it is at the top of custom provider settings,
      // even though Dulo is 4K and CineSrc is 720p!
      expect(streams[0].providerId, 'cinesrc');
      expect(streams[1].providerId, 'dulo');
    });

    test('detectProviderId identifies providers from title or description fallback', () {
      final stream1 = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'CineSrc · Direct Master · 1080p',
      );
      expect(BuiltinProvidersSettingsService.detectProviderId(stream1), 'cinesrc');

      final stream2 = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'Videasy Server 1 · 1080p',
      );
      expect(BuiltinProvidersSettingsService.detectProviderId(stream2), 'videasy');

      final stream3 = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '111477 · Direct · 1080p',
      );
      expect(BuiltinProvidersSettingsService.detectProviderId(stream3), 'a111477');
    });
  });
}
