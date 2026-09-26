import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/metadata/metadata_service.dart';

/// Live response of the IMDb suggestion endpoint for 'resident evil'
/// (`https://v3.sg.media-imdb.com/suggestion/x/resident%20evil.json`),
/// trimmed to the fields the mapper reads.
const String _residentEvilBody = r'''
{"d":[{"id":"tt35538033","l":"Resident Evil","q":"feature","y":2026},
{"id":"tt0120804","l":"Resident Evil","q":"feature","y":2002},
{"id":"tt9660182","l":"Resident Evil","q":"TV series","y":2022},
{"id":"tt0318627","l":"Resident Evil: Apocalypse","q":"feature","y":2004},
{"id":"tt6920084","l":"Resident Evil: Welcome to Raccoon City","q":"feature","y":2021},
{"id":"tt0432021","l":"Resident Evil: Extinction","q":"feature","y":2007},
{"id":"tt1855325","l":"Resident Evil: Retribution","q":"feature","y":2012},
{"id":"tt1220634","l":"Resident Evil: Afterlife","q":"feature","y":2010}],
"q":"resident%20evil","v":1}
''';

void main() {
  group('Keyless title source', () {
    test('resident evil resolves to the titles the rail shows', () {
      final movies = MetadataService.parseSuggestions(_residentEvilBody);

      expect(
        movies.map((m) => '${m.name} (${m.year}) [${m.id}]').toList(),
        [
          'Resident Evil (2026) [tt35538033]',
          'Resident Evil (2002) [tt0120804]',
          'Resident Evil (2022) [tt9660182]',
          'Resident Evil: Apocalypse (2004) [tt0318627]',
          'Resident Evil: Welcome to Raccoon City (2021) [tt6920084]',
          'Resident Evil: Extinction (2007) [tt0432021]',
          'Resident Evil: Retribution (2012) [tt1855325]',
          'Resident Evil: Afterlife (2010) [tt1220634]',
        ],
      );
      expect(
        movies.map((m) => m.addonBaseUrl).toSet(),
        {'https://v3-cinemeta.strem.io'},
      );
    });

    test('the rail keeps series alongside films when no type is requested',
        () {
      final movies = MetadataService.parseSuggestions(_residentEvilBody);
      final byId = {for (final m in movies) m.id: m};

      expect(byId['tt9660182']!.type, 'series');
      expect(byId['tt0120804']!.type, 'movie');
    });
  });
}
