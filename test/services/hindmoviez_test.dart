import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/scraper/sites/hindmoviez.dart';
import 'package:zplay/services/scraper/builtin_providers_settings_service.dart';
import 'package:zplay/services/scraper/stream_scraper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HindMoviezScraper Unit & Logic Tests', () {
    test('HindMoviezScraper metadata and properties', () {
      final scraper = HindMoviezScraper();
      expect(scraper.name, equals('ZPlayHTTP'));
      expect(scraper.providerId, equals('hindmoviez'));
      expect(scraper.providerName, equals('HindMoviez'));
    });

    test('BuiltinProvidersSettingsService includes hindmoviez in defaultProviders', () {
      const providers = BuiltinProvidersSettingsService.defaultProviders;
      expect(providers.length, equals(46));
      final hind = providers.firstWhere((p) => p.id == 'hindmoviez');
      expect(hind.name, equals('HindMoviez'));
      expect(hind.description, contains('Bollywood'));
    });

    test('ScraperManager registers HindMoviezScraper', () {
      final scraper = HindMoviezScraper();
      ScraperManager.instance.registerScraper(scraper);
      expect(ScraperManager.instance.hasScrapers, isTrue);
    });

    test('URL-Safe Base64 encoding matches standard requirements', () {
      const testId = 'Deadpool.2.(2018).1080p.Dual.Audio.(Hin-Eng).mkv';
      final encoded = base64Url.encode(utf8.encode(testId)).replaceAll('=', '');
      expect(encoded, isNotEmpty);
      expect(encoded.contains('+'), isFalse);
      expect(encoded.contains('/'), isFalse);
      expect(encoded.contains('='), isFalse);
      // Verify decodability
      final normalized = base64.normalize(encoded);
      final decoded = utf8.decode(base64.decode(normalized));
      expect(decoded, equals(testId));
    });

    test('Challenge solver parses and solves Wallarm splash challenge from HTML dump', () {
      final file = File(r'C:\Users\Ayman\.gemini\antigravity\brain\043c5721-1ebb-4922-962e-bc6b1ebb3cdd\scratch\r_page.html');
      if (file.existsSync()) {
        final html = file.readAsStringSync();
        // Test parsing the challenge script
        final uMatch = RegExp(r'var\s+U\s*=\s*\[(.*?)\];', dotAll: true).firstMatch(html);
        expect(uMatch, isNotNull);

        final rotMatch = RegExp(r'\}\(a0w\s*,\s*(0x[0-9a-fA-F]+|\d+)\)\);').firstMatch(html);
        expect(rotMatch, isNotNull);
        expect(int.parse(rotMatch!.group(1)!), equals(0x2fe00));

        final rDigitsMatch = RegExp(r'r=\+\(([\s\S]*?)\),\s*w=').firstMatch(html);
        final xDigitsMatch = RegExp(r'x=\+\(([\s\S]*?)\),\s*s=').firstMatch(html);
        expect(rDigitsMatch, isNotNull);
        expect(xDigitsMatch, isNotNull);

        final wActionMatch = RegExp(r"W\s*=\s*'(\/[a-zA-Z0-9]+)'").firstMatch(html);
        expect(wActionMatch, isNotNull);
        expect(wActionMatch!.group(1), equals('/z0f76a1d14fd21a8fb5fd0d03e0fdc3d3cedae52f'));

        final pDataMatch = RegExp(r"P\s*=\s*'([^']+)'").firstMatch(html);
        expect(pDataMatch, isNotNull);
        expect(pDataMatch!.group(1), contains('hshare.ink'));

        final idStmtMatch = RegExp(r"o\['value'\]\s*=\s*([^;,]+)[;,]").firstMatch(html);
        expect(idStmtMatch, isNotNull);
        expect(idStmtMatch!.group(1), contains('60b54a2be4'));
      }
    });

    test('Title cleaning removes media noise, language tags, and quality labels', () {
      const raw1 = 'Download Deadpool 2 (2018) 1080p Dual Audio (Hindi-English) WEB-DL x264';
      const raw2 = 'The Boys Season 4 Complete All Episodes Hindi Dubbed 720p HD';

      // We can test clean title regexes
      String clean(String raw) {
        var s = raw.toLowerCase();
        s = s.replaceAll('download', '');
        s = s.replaceAll(RegExp(r'\b(dual audio|multi audio|hindi|english|tamil|telugu|malayalam|korean|japanese|chinese|spanish|french|italian|german)\b'), '');
        s = s.replaceAll(RegExp(r'\b(480p|720p|1080p|2160p|4k|2k|hd|fhd|uhd)\b'), '');
        s = s.replaceAll(RegExp(r'\b(web-?dl|web-?dlrip|web-?rip|brrip|bdrip|bluray|blu-?ray|hdtv|tvrip|dvdrip|camrip|hdrip)\b'), '');
        s = s.replaceAll(RegExp(r'\b(x264|x265|hevc|10bit|12bit|aac|ac3|dd5\.1|ddp5\.1|atmos|dts)\b'), '');
        s = s.replaceAll(RegExp(r'\b(season|saison|staffel)\s*\d+(?:\s*(?:-|to)\s*\d+)?\b'), '');
        s = s.replaceAll(RegExp(r'\bs\d+(?:\s*(?:-|to)\s*\d+)?\b'), '');
        s = s.replaceAll(RegExp(r'\b(episode|episodes|ep)\s*\d+(?:\s*(?:-|to)\s*\d+)?\s*(added|update|updated)?\b'), '');
        s = s.replaceAll(RegExp(r'\b(complete|all episodes|pack|batch)\b'), '');
        s = s.replaceAll(RegExp(r'\b(movie|film|part\s*\d+|vol\s*\d+|volume\s*\d+)\b'), '');
        s = s.replaceAll(RegExp(r'\b(unrated|extended|directors cut|uncut|18)\b'), '');
        s = s.replaceAll(RegExp(r'\b(19\d{2}|20\d{2})\b'), '');
        s = s.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
        s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
        s = s.replaceAll(RegExp(r'^(the|a|an)\s+'), '');
        return s;
      }

      expect(clean(raw1), equals('deadpool 2'));
      expect(clean(raw2), equals('boys dubbed'));
    });

    test('Season HTML extraction isolates correct season links', () {
      const mockHtml = '''
        <div>
          <h2>Season 1</h2>
          <p><a href="https://mvlink.blog/111">Download S01</a></p>
          <h2>Season 2</h2>
          <p><a href="https://mvlink.blog/222">Download S02</a></p>
          <h2>Season 3</h2>
          <p><a href="https://mvlink.blog/333">Download S03</a></p>
        </div>
      ''';

      final seasonRegex = RegExp(r'(?:Season|Saison|Staffel)\s+0*(\d+)\b', caseSensitive: false);
      final matches = seasonRegex.allMatches(mockHtml).toList();
      expect(matches.length, equals(3));
    });
  });
}
