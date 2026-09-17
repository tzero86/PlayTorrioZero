<p align="center">
  <img src="assets/icon.png" alt="PlayTorrio" width="140"/>
</p>

<h1 align="center">PlayTorrio V3</h1>

<p align="center">
  Movies, TV, Anime, Manga, Audiobooks, Music — one app, no subscriptions.
</p>

<p align="center">
  <img height="20" src="https://img.shields.io/badge/v1.1.6-7C5CFF?style=flat" alt="Version"/>
  <img height="20" src="https://img.shields.io/badge/GPL--3.0-4169A1?style=flat" alt="License"/>
  <img height="20" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
</p>

---

## What is this?

PlayTorrio is a media streaming app built with Flutter. It pulls content from a bunch of different sources on the web and lets you watch/read/listen to everything from one place. No accounts, no monthly fees.

It handles:
- **Movies & TV** — 45+ VOD scrapers + torrent streaming + Stremio addon support
- **Anime** — 13 extractors for anime-specific sources
- **Manga** — full reader with progress tracking (WeebCentral)
- **Audiobooks** — 9 sources searched in parallel, torrent or direct stream
- **Music** — streaming via the Octave API with playlists and library management

## Downloads

Every tagged release triggers a CI build that produces installers for all platforms:

| Platform | Format |
|:---------|:-------|
| Windows | Installer (Inno Setup) + Portable ZIP |
| Android | Split APKs (arm64, armv7, x86_64) + Universal APK |
| Linux | AppImage + tar.gz |
| macOS | DMG + ZIP (both Apple Silicon and Intel) |
| iOS | Sideloadable IPA (unsigned) |

Check the [Releases](https://github.com/ayman708-UX/PlayTorrioV3/releases) page.

## Building from source

You'll need Flutter 3.x (Dart 3.11+).

```bash
git clone https://github.com/ayman708-UX/PlayTorrioV3.git
cd PlayTorrioV3
flutter pub get
flutter run
```

Target a specific platform with `flutter run -d windows`, `flutter run -d macos`, etc.

## How it works

### Movies & TV

The home screen shows catalogs from your installed Stremio addons (Cinemeta is installed by default). You can browse, search, and tap into any title to see full metadata — cast, genres, seasons/episodes, recommendations, etc.

When you hit play, the app fires off all 45+ scrapers at the same time. Results stream in as they arrive — you don't wait for all of them to finish. Each result shows quality (4K/1080p/720p), codec, HDR info, file size, and which source it came from.

For torrents, there's a built-in BitTorrent client (native `libtorrent` bindings). It streams the video while downloading — prioritizes the pieces you need for playback first. Works with season packs too, it'll figure out which file is the right episode.

You can also install any Stremio-compatible addon (Torrentio, etc.) by pasting its URL in settings.

### Anime

Dedicated anime section with 13 source extractors. Same scraping flow as movies/TV but with anime-specific sites.

### Manga

Browse and search WeebCentral's catalog. The reader supports horizontal swipe or vertical scroll, pinch-to-zoom, and remembers exactly where you left off — chapter and page.

### Audiobooks

Searches 9 sources at once (AudiobookBay for torrents, plus 8 direct streaming sites). Has a proper player with speed control (1x–2x), sleep timer, chapter navigation, and position saving every 5 seconds.

### Music

Full music player powered by Octave. Search tracks, browse artists, create playlists, like songs, switch quality (lossless/320k/128k). Has a mini-player that persists while you navigate and a full-screen player with queue management.

### Subtitles

Subtitles are fetched automatically via Subdl when you open the player. Pick a language, adjust timing/size if needed.

## Tech stuff

- **Flutter/Dart** across the whole app
- **Stremio addon protocol** for content discovery — catalogs, search, metadata
- **libtorrent** (native C++ bindings via `libtorrent_flutter`) for torrent streaming
- **fvp** (FFmpeg Video Player) for broad codec support
- **Glassmorphism UI** with `liquid_glass_easy` — real-time GPU shader effects. There's a toggle in settings to turn it off if your device struggles with it
- **Plugin architecture** for scrapers — each one is independent, they all run concurrently, one failing doesn't affect the others
- All progress (watch history, manga reading position, audiobook listening position) persists via `SharedPreferences`

### Adding a new scraper

Extend `StreamScraper`, implement `scrape()`, register it in `stream_service.dart`. That's it — the manager handles concurrency, timeouts, deduplication, and error isolation.

```dart
class MyNewScraper extends StreamScraper {
  @override
  String get name => 'MyNewScraper';

  @override
  Future<List<StreamSource>> scrape({
    required String type,
    required String title,
    required int? year,
    required int? season,
    required int? episode,
    required String? imdbId,
  }) async {
    // your logic here
  }
}
```

## Project layout

```
lib/
├── main.dart                     # entry point
├── models/                       # data classes (movie, stream, subtitle, manga, audiobook, music)
├── services/
│   ├── addon/                    # Stremio addon manager
│   ├── metadata/                 # Stremio metadata client + recommendation engine
│   ├── stream/                   # stream aggregation + torrent engine
│   ├── scraper/                  # scraper base class + manager + 45+ site implementations
│   ├── anime/                    # anime scraper service + 13 extractors
│   ├── subtitles/                # subtitle service + Subdl provider
│   ├── manga/                    # WeebCentral scraper + progress tracking
│   ├── audiobook/                # 9-source aggregator + progress service
│   └── music/                    # Octave API client + library + player controller
├── pages/                        # all the UI screens
├── widgets/                      # reusable components (cards, dock, scroll track, etc.)
└── utils/                        # torrent filename parser, relevance scorer, route transitions
```

## Platforms

| Platform | Status |
|:---------|:-------|
| Windows | ✅ Full support |
| macOS | ✅ Full support |
| Linux | ✅ Full support |
| Android | ✅ Full support |
| iOS | ✅ Full support |

## Legal

PlayTorrio is a media player and aggregator. It doesn't host or store any content. Everything comes from third-party sources. You're responsible for making sure you have the right to access whatever you're streaming in your jurisdiction. This project is for educational purposes.

## License

[GPL-3.0](LICENSE)

---

<p align="center">
  Built by <a href="https://github.com/ayman708-UX">Ayman</a>
</p>