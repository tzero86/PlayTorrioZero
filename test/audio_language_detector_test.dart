import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/models/stream/stream_model.dart';

void main() {
  group('Audio Language & Dub Detection in StreamSource', () {
    test('Purstream Multi detected as multi and english', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'Purstream · pulse · 1080p · MULTI',
        description: 'Purstream Multi-Audio HLS Stream',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isTrue);
      expect(langs.contains('english'), isTrue);
      expect(s.getAudioBadge(), '🌐 MULTI');
      expect(s.hasAudioLanguage('multi'), isTrue);
    });

    test('Movy Delhi detected as Hindi', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Delhi] 1080p',
        description: 'Hindi audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
      expect(s.hasAudioLanguage('hindi'), isTrue);
    });

    test('Movy Munich detected as German', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Munich] 1080p',
        description: 'German audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('german'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇩🇪 GER');
      expect(s.hasAudioLanguage('german'), isTrue);
    });

    test('Movy Paris detected as French', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Paris] 1080p',
        description: 'French audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('french'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇫🇷 FRE');
      expect(s.hasAudioLanguage('french'), isTrue);
    });

    test('Movy Cancun detected as Spanish', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Cancun] 1080p',
        description: 'Spanish audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('spanish'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇪🇸 SPA');
      expect(s.hasAudioLanguage('spanish'), isTrue);
    });

    test('Movy Miami detected as English / Original', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Miami] 1080p',
        description: 'Original audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('english'));
      expect(langs.contains('hindi'), isFalse);
      expect(langs.contains('multi'), isFalse);
      expect(s.hasAudioLanguage('english'), isTrue);
    });

    test('Vuflix Hindi Audio stream', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Vuflix - Beta] Hindi Audio',
        description: 'Beta • Hindi Audio • MOVIE',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('MeowTV Hindiv3 stream', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'MeowTV · Hindiv3 · 1080p',
        description: 'MeowTV Stream · HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('RiveStream hindicast stream', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Rive - hindicast] HD',
        description: 'hindicast • HD • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('Vadapav Hindi release', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        name: 'vadapav.mov 1080P',
        title: '3.Idiots.[2009].1080p.10bit.BluRay.x265.Hindi.AAC.5.1.Esub.mkv',
        description: '3.Idiots.[2009].1080p.10bit.BluRay.x265.Hindi.AAC.5.1.Esub.mkv',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('111477 Telugu Indian dub release', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'Inception.2010.720p.AMZN.WEB-DL.TELUGU.DDP2.0.H.265-GTM.mkv [a11 970.6 MB]',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 TELUGU');
    });

    test('DownloadEverything Dual Audio Hindi release', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[HubCloud] Movie.2024.1080p.Dual.Audio.Hindi.English.x264',
        description: '1080p · Dual Audio · Hindi · HubCloud',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('multi'));
      expect(langs, contains('hindi'));
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('ZERO JUNK: MultiEmbed does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '2embed XPS · Server 1',
        description: '2embed Multi-CDN Stream',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse, reason: 'Multi-CDN must not trigger multi-audio');
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: FlaxMovies Multi-CDN does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'FlaxMovies · Airflix · 1080p',
        description: 'FlaxMovies Multi-CDN Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse);
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: Dulo Multi-CDN does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'Dulo · Source · 1080p',
        description: 'Dulo Multi-CDN HLS Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse);
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: Indiana Jones movie title does NOT trigger Indian/Hindi', () {
      final s = StreamSource(
        addonName: 'ZPlay',
        title: 'Indiana.Jones.and.the.Dial.of.Destiny.2023.1080p.WEBRip.x264-FLUX.mkv',
      );
      final langs = s.getAudioLanguages(mediaTitle: 'Indiana Jones and the Dial of Destiny');
      expect(langs.contains('hindi'), isFalse, reason: 'Movie title Indiana Jones must not trigger Indian');
      expect(langs, contains('english'));
    });

    test('ZERO JUNK: German Sub does NOT trigger German audio', () {
      final s = StreamSource(
        addonName: 'ZPlay',
        title: 'Movie.2024.1080p.WEBRip.x264 [German-Sub]',
        description: 'Subs: German, French, Spanish',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('german'), isFalse, reason: 'German-Sub is a subtitle, not audio');
      expect(langs.contains('french'), isFalse);
      expect(langs.contains('spanish'), isFalse);
      expect(langs, contains('english'));
    });

    test('ZERO JUNK: Multi-Sub does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'ZPlay',
        title: 'Movie.2024.1080p.Multi-Sub.x265',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse, reason: 'Multi-Sub is subtitles, not audio');
      expect(langs, contains('english'));
    });

    test('French VF / Truefrench triggers French audio', () {
      final s = StreamSource(
        addonName: 'ZPlay',
        title: 'Movie.2024.1080p.VF.x264-ZONE',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('french'));
      expect(s.getAudioBadge(), '🇫🇷 FRE');
    });

    test('Standard LookMovie / VidSrc defaults to English / Original', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'LookMovie · 1080p',
        description: 'LookMovie HLS Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('english'));
      expect(s.hasAudioLanguage('english'), isTrue);
      expect(s.hasAudioLanguage('hindi'), isFalse);
      expect(s.hasAudioLanguage('all'), isTrue);
    });

    test('VidVault backend language and MKV extraction', () {
      final s1 = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'VidVault · MP4 · Hindi · IN · 1080p',
        description: 'VidVault Direct MP4 · Hindi · IN',
      );
      expect(s1.getAudioLanguages(), contains('hindi'));
      expect(s1.getAudioBadge(), '🇮🇳 HINDI');

      final s2 = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'VidVault · MKV · German · DE · 1080p · 2.8GB',
        description: 'VidVault Direct MKV · German DE 2.8GB',
      );
      expect(s2.getAudioLanguages(), contains('german'));
      expect(s2.getAudioBadge(), '🇩🇪 GER');
    });

    test('VidZee backend language extraction', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'VidZee · Alpha · Spanish · 1080p',
        description: 'VidZee Stream · Spanish · HLS',
      );
      expect(s.getAudioLanguages(), contains('spanish'));
      expect(s.getAudioBadge(), '🇪🇸 SPA');
    });

    test('VixSrc foreign language extraction', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'VixSrc · Master HLS · Spanish · 1080p',
        description: 'VixSrc Master Stream · Spanish',
      );
      expect(s.getAudioLanguages(), contains('spanish'));
      expect(s.getAudioBadge(), '🇪🇸 SPA');
    });

    test('Movy server language in title', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: '[Movy - Munich · German] 1080p',
        description: 'German audio • HLS',
      );
      expect(s.getAudioLanguages(), contains('german'));
      expect(s.getAudioBadge(), '🇩🇪 GER');
    });

    test('X-Downloader spokenLanguages extraction', () {
      final s = StreamSource(
        addonName: 'ZPlayHTTP',
        title: 'X-Downloader · Hindi, English',
        description: 'X-Downloader Direct MP4 Stream · Hindi, English',
      );
      expect(s.getAudioLanguages(), contains('hindi'));
      expect(s.getAudioLanguages(), contains('english'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });
  });
}
