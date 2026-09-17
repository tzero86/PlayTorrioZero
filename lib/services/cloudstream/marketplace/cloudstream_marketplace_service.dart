import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../cloudstream_manager.dart';

/// Represents a repository listed in the CloudStream Marketplace.
class CloudStreamMarketplaceRepo {
  final String name;
  final String url;
  final String category;
  final List<String> plugins;

  const CloudStreamMarketplaceRepo({
    required this.name,
    required this.url,
    required this.category,
    required this.plugins,
  });

  String get directHttpUrl => CloudStreamManager.normalizeRepoUrl(url);

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'category': category,
    'plugins': plugins,
  };

  factory CloudStreamMarketplaceRepo.fromJson(Map<String, dynamic> json) {
    return CloudStreamMarketplaceRepo(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Multi / English',
      plugins: (json['plugins'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class CloudStreamMarketplaceService {
  CloudStreamMarketplaceService._();
  static final CloudStreamMarketplaceService instance = CloudStreamMarketplaceService._();

  static const String _cachedReposKey = 'cs_marketplace_cached_repos';

  static const List<String> categories = [
    'All',
    'Turkish',
    'Arabic',
    'Hindi / Asian',
    'French',
    'Italian',
    'German',
    'Portuguese / Spanish',
    'Vietnamese',
    'Ukrainian',
    'Anime / Cartoons',
    'Multi / English',
  ];

  List<CloudStreamMarketplaceRepo>? _memoryCache;

  /// Returns marketplace repositories, using memory cache, cached storage, or bundled fallback.
  Future<List<CloudStreamMarketplaceRepo>> getRepos({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache!;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString(_cachedReposKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        try {
          final list = jsonDecode(cachedStr) as List;
          final loaded = list.map((e) => CloudStreamMarketplaceRepo.fromJson(e as Map<String, dynamic>)).toList();
          if (loaded.isNotEmpty) {
            _memoryCache = loaded;
            return loaded;
          }
        } catch (_) {}
      }
    }

    if (forceRefresh) {
      final live = await fetchLiveScrapedRepos();
      if (live.isNotEmpty) {
        _memoryCache = live;
        await prefs.setString(_cachedReposKey, jsonEncode(live.map((r) => r.toJson()).toList()));
        return live;
      }
    }

    _memoryCache = defaultRepos;
    return defaultRepos;
  }

  /// Scrapes the live repositories from https://cloudstream-apk.com/cloudstream-repositories-extensions/
  Future<List<CloudStreamMarketplaceRepo>> fetchLiveScrapedRepos() async {
    try {
      final res = await http.get(
        Uri.parse('https://cloudstream-apk.com/cloudstream-repositories-extensions/'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final parsed = parseFromHtml(res.body);
        if (parsed.isNotEmpty) {
          debugPrint('[CloudStreamMarketplaceService] Successfully scraped ${parsed.length} live repos.');
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[CloudStreamMarketplaceService] Live scraping failed: $e');
    }
    return defaultRepos;
  }

  /// Parses repository sections from HTML content.
  static List<CloudStreamMarketplaceRepo> parseFromHtml(String content) {
    final h3Regex = RegExp(r'<h3[^>]*>(\d+\.\s*[^<]+)</h3>', caseSensitive: false);
    final matches = h3Regex.allMatches(content).toList();
    final repos = <CloudStreamMarketplaceRepo>[];

    for (var i = 0; i < matches.length; i++) {
      final titleRaw = matches[i].group(1)!.trim();
      final startIdx = matches[i].end;
      final endIdx = (i + 1 < matches.length) ? matches[i + 1].start : content.length;
      final block = content.substring(startIdx, endIdx);

      final urlMatch = RegExp('href="(cloudstreamrepo://[^"]+|https?://[^"]+)"', caseSensitive: false).firstMatch(block);
      if (urlMatch == null) continue;

      final rawUrl = urlMatch.group(1)!.trim();

      String? pluginsStr;
      final pluginMatch = RegExp('<h4[^>]*>Plugins</h4>.*?<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(block);
      if (pluginMatch != null) {
        final pText = pluginMatch.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (!pText.contains('Click on the link')) {
          pluginsStr = pText;
        }
      }

      final title = titleRaw.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim()
          .replaceAll('&amp;', '&')
          .replaceAll('&#8211;', '-')
          .replaceAll('&#8217;', "'");

      List<String> plugins = [];
      if (pluginsStr != null && pluginsStr.isNotEmpty) {
        plugins = pluginsStr.split(RegExp(r'[,•|]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != '.')
            .map((s) => s.endsWith('.') ? s.substring(0, s.length - 1).trim() : s)
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final nameLower = title.toLowerCase();
      String category = 'Multi / English';
      if (nameLower.contains('3rabi') || nameLower.contains('عربي') || nameLower.contains('arab')) {
        category = 'Arabic';
      } else if (nameLower.contains('turkish') || nameLower.contains('kekik') || nameLower.contains('dizipal') || nameLower.contains('kraptor') || nameLower.contains('pitipiti')) {
        category = 'Turkish';
      } else if (nameLower.contains('hindi') || nameLower.contains('csx') || nameLower.contains('megix') || nameLower.contains('indostream') || nameLower.contains('bdix') || nameLower.contains('bengali') || nameLower.contains('tamil')) {
        category = 'Hindi / Asian';
      } else if (nameLower.contains('french') || nameLower.contains('cuxplug') || nameLower.contains('gramflix') || nameLower.contains('zzikozz')) {
        category = 'French';
      } else if (nameLower.contains('italian') || nameLower.contains('diegon')) {
        category = 'Italian';
      } else if (nameLower.contains('german')) {
        category = 'German';
      } else if (nameLower.contains('vietnamese')) {
        category = 'Vietnamese';
      } else if (nameLower.contains('portuguese') || nameLower.contains('saimuel') || nameLower.contains('lawliet')) {
        category = 'Portuguese / Spanish';
      } else if (nameLower.contains('ukrainian') || nameLower.contains('caketwix')) {
        category = 'Ukrainian';
      } else if (nameLower.contains('cartoony') || nameLower.contains('anime') || nameLower.contains('aniyomi')) {
        category = 'Anime / Cartoons';
      }

      repos.add(CloudStreamMarketplaceRepo(
        name: title,
        url: rawUrl,
        category: category,
        plugins: plugins,
      ));
    }

    return repos;
  }

  static const List<CloudStreamMarketplaceRepo> defaultRepos = [
    CloudStreamMarketplaceRepo(
      name: 'CloudStream Providers Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/recloudstream/extensions/master/repo.json',
      category: 'Multi / English',
      plugins: ['Dailymotion', 'YouTube', 'Twitch'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Mega Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/self-similarity/MegaRepo/builds/repo.json',
      category: 'Multi / English',
      plugins: ['It contains only one plugin with a similar name', '‘Mega’. It automatically adds all the best functional repositories to the Cloudstream App. Users can easily uninstall the repos and extensions that they don’t want'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Phisher Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/phisher98/cloudstream-extensions-phisher/refs/heads/builds/repo.json',
      category: 'Multi / English',
      plugins: ['AllMovieLand', 'AllWish', 'Anichi', 'AniDb', 'Anikage', 'Animeav1', 'AnimeCloud', 'AnimeDekho', 'Animedubhindi', 'Animekhor', 'Animenosub', 'AnimePahe', 'Animesalt', 'Animexin', 'Anineko', 'Aniworld', 'Anizone', 'BanglaPlex', 'Cinefreak', 'Cinemacity', 'CloudPlay', 'Coflix', 'Desicinemas', 'Donghuastream', 'DoraBash', 'DudeFilms', 'Fibwatch', 'Fivemovierulz', 'FourKHDHub', 'Goojara', 'HDhub4u', 'Hindmoviez', 'Idlix', 'IPTVPlayer', 'Jellyfin', 'KayiFamilyTv', 'Kickassanime', 'Kisskh', 'Latanime', 'LayarKaca', 'MassTamilan', 'Megakino', 'MovieBlast', 'MovieBox', 'Movierulzhd', 'Movies4u', 'MPlayer', 'MultiMovies', 'Netcinez', 'OHLI24', 'OnePace', 'OneTouchTV', 'Pencurimovie', 'Pinoymoviepedia', 'Piratexplay', 'Pmsm', 'PublicSportsIPTV', 'QuickIPTV', 'RingZ', 'ShowBox', 'StreamPlay (⭐)', 'StremioAddon', 'StremioX', 'SuperStream', 'Tamilblasters', 'TokusatsuUltimate', 'TokuZilla', 'ToonHub', 'Toonstream', 'ToonTales', 'Topcartoons', 'Topstreamfilm', 'TorraStream', 'UHDmovies', 'Ultima', 'YTS', 'Zinkmovies'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Megix Repo / CSX (Hindi & English)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/CS.json',
      category: 'Hindi / Asian',
      plugins: ['Bollyflix', 'CineStream (⭐)', 'GDIndex', 'MoviesDrive', 'Moviesmod', 'OnlineMoviesHindit', 'VegaMovies'],
    ),
    CloudStreamMarketplaceRepo(
      name: '3rabi عربي',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Abodabodd/re-3arabi/refs/heads/main/repo',
      category: 'Arabic',
      plugins: ['Aflaam', 'Alooytv', 'Shahidwbas', 'TVgarden(Famelack)', 'Cimalight', 'Anime4up', 'Ohatv', 'Dima toon', 'Tuktukcima', 'Cimawbas', 'Syrialive', 'VIU', 'Tuniflix', 'Cimatn', 'Anime3rbtest', 'Cee (🇮🇶)', 'Anime3rb', 'YouTube', 'LodyNet', 'WeCima', 'TopCinema', 'FullMatchShows', 'Brstej', 'AnimeWitcher', 'Egydead', 'Mycima', 'Asia2tv 2', 'Asia2tv', 'Akwam', '3isk', 'Eshek', 'Krmzy', 'Animerco', 'Witanime', 'Shahid4u', 'CimaClub', 'Faselhd', 'Cimanaw', 'Arabseed', 'Shabakaty Cinemana (🇮🇶)'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Turkish Providers Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/keyiflerolsun/Kekik-cloudstream/master/repo.json',
      category: 'Turkish',
      plugins: ['AnimeciX', 'BelgeselX', 'CanliTV', 'CizgiMax', 'DiziBox', 'DiziKorea', 'Dizilla', 'DiziMom', 'DiziPal', 'DiziYou', 'FilmMakinesi', 'FilmModu', 'FullHDFilm', 'FullHDFilmizlesene', 'GolgeTV', 'HDFilmCehennemi', 'InatBox', 'IzleAI', 'JetFilmizle', 'KoreanTurk', 'KultFilmler', 'NetflixMirror', 'RareFilmm', 'RecTV', 'SetFilmIzle', 'SezonlukDizi', 'SinemaCX', 'SineWix', 'SuperFilmGeldi', 'TurkAnime', 'UgurFilm', 'Watch2Movies', 'WebteIzle', 'YouTube'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'IndoStream Repo (Hindi & English)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/TeKuma25/IndoStream/builds/repo.json',
      category: 'Hindi / Asian',
      plugins: ['Animasu', 'AnimeIndo', 'AnimeSail', 'Anoboy', 'Dramaid', 'DramaSerial', 'Dubbindo', 'Dutamovie', 'Funmovieslix', 'Gomov', 'Gomunime', 'Idlix', 'IndoTV', 'Kuramanime', 'Kuronime', 'LayarKaca', 'Minioppai', 'Nekopoi', 'Neonime', 'Ngefilm', 'Nimegami', 'Nodrakorid', 'NontonAnimeID', 'Oploverz', 'Otakudesu', 'Pencurimovie', 'Pusatfilm', 'Raveeflix', 'Rebahin', 'Samehadaku'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'doGior’s Had Enough',
      url: 'cloudstreamrepo://raw.githubusercontent.com/doGior/doGiorsHadEnough/refs/heads/builds/repo.json',
      category: 'Multi / English',
      plugins: ['AltaDefinizione', 'AnimeUnity', 'AnimeWorld', 'Arte', 'CalcioStreaming', 'CorsaroNero', 'IlCorsaroViola', 'IPTV', 'Nebula', 'Simkl', 'StreamCenter', 'StreamingCommunity', 'TV', 'Vavoo', 'YouTube'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Ukrainian Providers: CakeTwix Repository',
      url: 'https://codeberg.org/CakesTwix/cloudstream-extensions-uk/raw/branch/master/repo.json',
      category: 'Ukrainian',
      plugins: ['AnimeON', 'AnimeUA', 'Anitubeinua', 'BambooUA', 'CikavaIdeya', 'Eneyida', 'HentaiUkr', 'KinoTron', 'KinoVezha', 'KlonTV', 'Serialno', 'Teleportal', 'UAFlix', 'Uakino', 'UASerial', 'UASerialsPro', 'UATuTFun', 'UFDub', 'Unimay'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Italian Providers Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Gian-Fr/ItalianProvider/builds/repo.json',
      category: 'Italian',
      plugins: ['Altadefinizione', 'GuardaSerie'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Redowan’s BDIX Repository (English, Hindi, Bengali)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/redowan99/Redowan-CloudStream/master/repo.json',
      category: 'Hindi / Asian',
      plugins: ['9kMovies', 'BdixBdipTV', 'BdixCircleftp', 'BdixCloudTV', 'BdixDflix', 'BdixDhakaFlix', 'BdixICCFtp', 'BdixMyMovieBazarTV', 'BdixRoarZoneTV', 'EmwBD', 'FootReplays', 'FullReplays', 'FullyMaza', 'MoviPK', 'Mp4Moviez', 'TheMoviesFlix', 'WatchMoviesPk'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Reflex Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Reflex755/ReflexRepo/refs/heads/builds/repo.json',
      category: 'Multi / English',
      plugins: ['DiviCast', 'LibraryOfLadev', 'ProviderTemplate', 'ReflexMirror'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Luna712’s CloudStream Extension Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Luna712/Luna712-CloudStream-Extensions/28885d17ceb7f24782b732b6056085c14c1fd027/repo.json',
      category: 'Multi / English',
      plugins: ['Dailymotion', 'InternetArchive'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'CuxPlug (French)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/ycngmn/CuxPlug/refs/heads/main/repo.json',
      category: 'French',
      plugins: ['Watch32', 'AniZone', 'AnimeSama', 'AnimeLuxe', 'Flixmet', 'FreeDriveMovie', 'FrenchStream', 'StreamCloud'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Saimuel Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/saimuelbr/saimuelrepo/refs/heads/main/builds/repo.json',
      category: 'Portuguese / Spanish',
      plugins: ['NetCine', 'PobreFlix', 'TopFilmes', 'AnimesCloud', 'MegaFlix', 'UltraCine', 'DonghuaNoSekai', 'Doramas', 'AnimesDigital', 'OverFlix'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'DiziPal & TabiiSpor | sarapcanagii/Pitipiti (Turkish)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/sarapcanagii/Pitipitii/master/repo.json',
      category: 'Turkish',
      plugins: ['NeonSpor'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'lawlietrepo (Portuguese)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/lawlietbr/lietrepo/refs/heads/main/builds/repo.json',
      category: 'Portuguese / Spanish',
      plugins: ['AnimeFire', 'AniTube', 'CineAgora', 'DattebayoBR', 'Doramogo', 'EmbedTV', 'Goyabu', 'MendigoFlix', 'PobreFlix', 'ReiDosEmbeds', 'StreamFlix'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'King',
      url: 'cloudstreamrepo://pastebin.com/raw/Cd2g2tfz',
      category: 'Multi / English',
      plugins: ['XtreamIPTV'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Arabico',
      url: 'cloudstreamrepo://raw.githubusercontent.com/aymanbest/Arabico/main/repo.json',
      category: 'Arabic',
      plugins: ['3isk v2', 'Anime3rb', 'Anime4upPack', 'AnimeBlkom', 'Animeiat', 'ArabSeed', 'Btolat', 'CimaNow', 'Cimaster', 'CoolCima', 'Drama Cafe', 'EgyDead', 'FajerShow', 'FaselHD', 'Joy Cinema', 'MyCima', 'OhaTV', 'Shoffree', 'Syrialive', 'Toktok', 'Y.A.P.S', 'asian2tv.&nbsp;'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Aniyomi Compat',
      url: 'cloudstreamrepo://raw.githubusercontent.com/CranberrySoup/AniyomiCompatExtension/master/repo.json',
      category: 'Anime / Cartoons',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'CloudX Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Asm0d3usX/CloudX/builds/repo.json',
      category: 'Multi / English',
      plugins: ['Dutamovie', 'Filmkita', 'Filmlokal', 'Fufafilm', 'Funmovieslix', 'Idlix', 'Indomax', 'Kawanfilm', 'KlikXXi', 'LayarKaca', 'LayarWarna', 'MidasXXi', 'Moviebox', 'Ngefilm', 'Nomat', 'Nontonfilm', 'Oploverz', 'Pencurimovie', 'Pusatfilm', 'Pusatmovie', 'Samehadaku', 'Sarangfilm', 'Savefilm', 'WGFilm21'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'DieGon Repository (Italian Streaming)',
      url: 'cloudstreamrepo://pastebin.com/raw/qndZtL6D',
      category: 'Italian',
      plugins: ['AltaDefinizione', 'AnimeSaturn', 'AnimeUnity', 'AnimeWorld', 'Arte', 'CalcioStreaming', 'CB01', 'CorsaroNero', 'GuardaSerie', 'Huhu', 'IlGenioDelloStreaming', 'OnlineSerieTV', 'SectionOrganizer', 'StreamingCommunity', 'Stremio', 'SyncStream', 'Torrentio', 'TV'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'cs-karma',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Kraptor123/cs-Karma/refs/heads/master/repo.json',
      category: 'Multi / English',
      plugins: ['AnimeAV', 'AnimeWorld', 'AnimeYTX', 'BasketballReplays', 'DocumentaryArea', 'DoramasLatinoX', 'Dramaizle', 'Dubbindo', 'Esheaq', 'F1FullRaces', 'Filmmirasım', 'Flixlatam', 'Footballia', 'FootReplays', 'Full4kizle', 'FullRaces', 'Gnulahd', 'Henaojara', 'Iwatchtheoffice', 'JPFilms', 'KissKH', 'Krmzy', 'Latanime', 'LayarKaca', 'Movix', 'Nekokun', 'OK', 'Streamed', 'Subsplease', 'Supercartoons', 'TVGarden', 'WatchWrestling', 'Wcoflix', 'Yablom', 'YoTurkish'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Netmirror Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Sushan64/NetMirror-Extension/refs/heads/builds/Netflix.json',
      category: 'Multi / English',
      plugins: ['Netmirror (Netflix', 'Disney+', 'Hotstar', 'and Prime Video)'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'German Providers Repository',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Bnyro/GermanProviders/refs/heads/master/repo.json',
      category: 'German',
      plugins: ['Aniworld', 'ARD', 'Arte', 'C3TV', 'Discovery', 'EinschaltenIn', 'FilmPalast', 'HDFilme', 'HuhuTo', 'IptvOrg', 'Kinoger', 'KinoKing', 'Megakino', 'Moflix', 'Netzkino', 'Serienstream', 'Southpark', 'SpiegelTV', 'Welt', 'Xcine', 'ZeroMovies'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'zzikozz / French Repo',
      url: 'https://raw.githubusercontent.com/zzikozz/frenchCS/refs/heads/main/repo.json',
      category: 'French',
      plugins: ['1Jour1Film', 'BuzzMonclick', 'DuLourd', 'FStreamzz', 'FrenchStream', 'Gogoflix', 'HDSto', 'Hdss', 'Sadisflix', 'Senpai-Stream', 'SerieCenter', 'Vostfree', 'Wiflix', 'WookaFR.app', 'WookaFR'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'GramFlix (French Repo)',
      url: 'https://raw.githubusercontent.com/tOntOnbOuLii/GramFlix/main/repo.json',
      category: 'French',
      plugins: ['1JOUR1FILMGF', 'AfterDarkGF', 'Anime-SamaGF', 'CinePlateformeGF', 'CoFliXGF', 'DarkiWorldGF', 'FanStreamGF', 'FilmoFlixGF', 'FlemmixGF', 'FrembedGF', 'FrenchstreamGF', 'GogoFlixGF', 'HDssGF', 'MoiFliXGF', 'MovixGF', 'MuiFlixGF', 'NebryxGF', 'PapaDuStreamGF', 'PurStreamGF', 'SadixflixGF', 'Senpai-StreamGF', 'WoW-FilmsGF', 'WookafrGF', 'XalaFlixGF.&nbsp;'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Cinephile',
      url: 'cloudstreamrepo://raw.githubusercontent.com/rockhero1234/cinephile/refs/heads/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Cartoony Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/med1245/cartoonyrepo/builds/repo.json',
      category: 'Anime / Cartoons',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Storm-ext Fork by redblacker8',
      url: 'cloudstreamrepo://raw.githubusercontent.com/redblacker8/storm-ext/refs/heads/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Kraptor\'un CloudStream Reposu | @kraptor123',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Kraptor123/cs-kraptor/refs/heads/master/repo.json',
      category: 'Turkish',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'CNC Verse Repository (Contains Ads)',
      url: 'cloudstreamrepo://raw.githubusercontent.com/NivinCNC/CNCVerse-Cloud-Stream-Extension/refs/heads/builds/CNC.json',
      category: 'Multi / English',
      plugins: ['Bilibili', 'CastleTV', 'CineTV', 'CNC Verse', 'Cricify', 'DesiSerials', 'DoFlix', 'Einthusan', 'GoldenAudiobook', 'HDO', 'HDrezka', 'LibriVoxAudiobook', 'M3UPlaylistPlayer', 'MLSBD', 'MovieBox', 'MovieBoxProviderIN', 'MovieLinkBD', 'Moviezwap', 'Pikashow', 'PlayZTV', 'RadioIndia', 'Rtally', 'SKTech', 'StreamFlix', 'SubscriptionManager', 'TamilDhool', 'Tamilian', 'TamilUltra', 'Watch32', 'Xon'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'CloudStream Vietnamese',
      url: 'cloudstreamrepo://gitlab.com/tearrs/cloudstream-vietnamese/-/raw/main/repo.json',
      category: 'Vietnamese',
      plugins: ['Cross-Device Sync', 'Fshare', 'IPTV', 'MonPlayer', 'ViStream', 'XtreamIPTV', 'Stremio'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Avocado/Rowdy’s Extension',
      url: 'cloudstreamrepo://raw.githubusercontent.com/Rowdy-Avocado/Rowdycado-Extensions/builds/repo.json',
      category: 'Multi / English',
      plugins: ['AllWish', 'Anichi', 'Anitaku', 'AppAudiobook', 'CodeStream', 'GoldenAudiobook', 'HiAnime', 'KinoKiste', 'LibriVoxAudiobook', 'MangaDex', 'MoviesNiPipay', 'MyFlixer', 'OnePace', 'Ultima'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'English Provider Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/cloudstream-extensions/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Multilingual Providers Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/cloudstream-extensions/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Hexated Providers Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/cloudstream-extensions-hexated/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'LikDev-256 Providers Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/likdev256-tamil-providers/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Arabic Providers Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/arab/raw/branch/builds/repo.json',
      category: 'Arabic',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Horis Providers Repository',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/arab/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'SkillShare-Repo',
      url: 'cloudstreamrepo://codeberg.org/cloudstream/likdev256-tamil-providers/raw/branch/builds/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'FStream',
      url: 'cloudstreamrepo://git.disroot.org/ayza/FStream/raw/branch/main/repo.json',
      category: 'Multi / English',
      plugins: [],
    ),
    CloudStreamMarketplaceRepo(
      name: 'ExtCloud Repo',
      url: 'cloudstreamrepo://raw.githubusercontent.com/duro92/ExtCloud/main/repo.json',
      category: 'Multi / English',
      plugins: ['AnichinMoe', 'Animasu', 'Anoboy', 'Donghub', 'Dutamovie', 'FilmApik', 'Fufafilm', 'Funmovieslix', 'Hidoristream', 'Idlix', 'Kawanfilm', 'Kissasian', 'Kisskh', 'Klikxxi', 'Kuramanime', 'LayarKaca', 'Melongmovie', 'MovieBox', 'Ngefilm', 'Nomat', 'Oploverz', 'Oppadrama', 'Otakudesu', 'Pencurimovie', 'Pusatfilm', 'Samehadaku', 'Sflix', 'SoraStream', 'Winbu'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'IndusAryan’s Plugins',
      url: 'https://codeberg.org/IndusAryan/AR/raw/branch/main/repo.json',
      category: 'Multi / English',
      plugins: ['Bharatiya Movies&nbsp;'],
    ),
    CloudStreamMarketplaceRepo(
      name: 'Darkdemon Extensions',
      url: 'https://raw.githubusercontent.com/daarkdemon/cs-darkdemon-extensions/builds/repo.json',
      category: 'Multi / English',
      plugins: ['5movierulz', 'AnimeWorld', 'Bolly2Tolly', 'Cinevez', 'CricHD', 'GDJioTV', 'IBomma', 'MHDTV', 'MovieMod', 'NPJioTV', 'NollyVerse', 'OnlineMoviesHindit', 'Prmovies', 'SnehIPTV', 'SoraJioTV', 'StreamBlasters', 'UWatchFreeProvider'],
    ),
  ];

}
