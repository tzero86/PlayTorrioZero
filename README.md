<p align="center">
  <img src="assets/icon.png" alt="ZPlay" width="150"/>
</p>

<h1 align="center">ZPlay</h1>

<p align="center">
  <b>Movies, TV, Anime, Manga, Audiobooks, Music and Live TV — one app, no subscriptions, no accounts, no telemetry.</b>
</p>

<p align="center">
  <a href="LICENSE"><img height="20" src="https://img.shields.io/badge/licence-GPL--3.0-4169A1?style=flat" alt="Licence"/></a>
  <img height="20" src="https://img.shields.io/badge/telemetry-none-10B981?style=flat" alt="No telemetry"/>
  <img height="20" src="https://img.shields.io/badge/price-free%20forever-7C5CFF?style=flat" alt="Free"/>
  <img height="20" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white" alt="Flutter"/>
  <img height="20" src="https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-1F6FEB?style=flat" alt="Platforms"/>
</p>

---

## Why ZPlay

**Nothing phones home.** No analytics SDK, no crash reporter, no accounts, no "anonymous usage statistics". The only network traffic is the content you actually asked for. Diagnostics — crash breadcrumbs and a performance HUD — are off in release builds and written to a local file you can read or delete (`%APPDATA%\com.example\playtorrio\` on Windows).

**Free, and it stays free.** GPL-3.0, no paywalled tier, no feature-gating, no upsell screens. Bring your own optional third-party accounts (Trakt, Simkl, a debrid provider) if you want them — the app never requires one.

**Install and play.** Download a build, run it, hit play. No sign-up wall, no onboarding, no setup wizard. Your watch progress, reading position and listening position are saved locally from the first title.

**Built for speed.** Stale-while-refresh catalog loading, bounded image decoding, a pruned asset bundle, and release builds that are minified and resource-shrunk. See [Performance](#performance) for measured numbers.

---

## What it plays

| | |
|:--|:--|
| **Movies & TV** | 46 built-in HTTP providers plus 2 torrent providers, all scraped concurrently — results stream in as they arrive instead of waiting for the slowest source. Each result shows resolution, codec, HDR, file size and origin. Full Stremio addon support (any addon URL), catalog-extra and collection addons. |
| **Torrents** | Built-in BitTorrent engine (native `libtorrent` via TorrServer). Streams while downloading, prioritises the pieces playback needs, and picks the right file out of season packs. |
| **Debrid** | Optional Real-Debrid / TorBox integration — resolves torrents through your cloud account instead of the local engine. |
| **Anime** | Dedicated anime section with its own source extractors and Arabic-anime support. |
| **Live TV** | IPTV portal support (Xtream-style), channel search, favourites and hit tracking. |
| **Manga** | Reader with horizontal/vertical modes, pinch-zoom, and exact chapter+page resume. |
| **Audiobooks** | Multi-source aggregator (torrent + direct), speed control, sleep timer, chapter navigation, position saved every 5 seconds. |
| **Music** | Full player with search, artists, playlists, likes, quality switching and a persistent mini-player. |
| **Subtitles** | Automatic fetching, multi-language selection, timing/size adjustment, and a dual-engine renderer with the bundled Poppins font. |
| **Player** | media_kit / libmpv with hardware decoding, Anime4K upscaling shaders, HDR handling, gesture and keyboard controls, PiP, screenshots, and Discord Rich Presence. |
| **Sync** | Optional Trakt and Simkl watchlist / history synchronisation. |

---

## Performance

Everything below is either measured on a release build or verifiable in this repository's configuration.

| | |
|:--|:--|
| Android release APK | **48.5 MB** (arm64-v8a), **47.7 MB** (armeabi-v7a) — minified and resource-shrunk (`isMinifyEnabled`, `isShrinkResources`) with ProGuard rules |
| Windows release tree | **148 MB** total, of which only **~1.35 MB** is bundled app assets (the rest is the media engine and torrent runtime) |
| Shader bundle | **9** Anime4K shaders ship instead of the full 39-file upstream set — the unused 30 were being extracted on every install without ever reaching libmpv's shader chain |
| Launcher art | Only the small icon variant ships; the 1 MB master is build-time input only |
| Catalog loading | Stale-while-refresh: cached catalogs render immediately and refresh underneath, so navigation never blocks on the network |
| Image decoding | Bounded decode plus a shared disk/memory cache, so long scrolling doesn't spike memory |
| Renderer | Skia is the default backend on Windows (selected natively and persisted, overridable in-app) |
| Diagnosability | Crash breadcrumbs + a perf HUD (frames, jank, RSS) — release builds write breadcrumbs locally, the HUD is debug-only |

---

## What we changed in this fork

ZPlay is a fork of [PlayTorrio V3](https://github.com/ayman708-UX/PlayTorrioV3) by Ayman. Since forking we've focused on performance, correctness and owning our own release path:

**Performance & diagnostics**
- Stream-cycle leak fixes and bounded image decoding across the card/slider widgets
- Skia as the default renderer on Windows, selected natively before the first frame
- Crash breadcrumbs and a runtime perf HUD, both local-only
- Stale-while-refresh home catalogs, manga pre-caching, and cache infrastructure
- Removed the in-app sponsor/monetization subsystem entirely (a ~700-line widget plus its settings, injection points and preference key)

**Release engineering**
- Release APKs are minified, resource-shrunk and ProGuard-configured
- Pruned asset bundle (shaders, launcher art) — measured **−2.99 MB** in the shipped bundle
- CI publishes symbol artifacts for every platform so release crashes stay debuggable
- Rebranded end to end: `ZPlay` product identity, our own installer publisher/URL, and a self-updater pointed at **our** releases instead of upstream's (it was previously offering upstream builds over this fork)

**Player correctness**
- Fixed resume black-screening: the black-screen watchdog mis-fired on every resume (it compared absolute position against a 2.5 s grace period, which a resume already exceeds) and its recovery re-opened the stream **without** the HTTP headers that provider URLs require, guaranteeing a 403. Resume now measures elapsed playback and the recovery keeps its headers.
- Resume verifies candidate sources are actually reachable before committing to one, instead of blindly trusting the best textual match.
- Added an in-player **Sources** switcher, available during normal playback for movies as well as series, so a wrong or dead source can be swapped without leaving the player or re-searching the title.
- A stalling stream now offers an actionable way out instead of leaving you on a silent black screen.

---

## Download

Every tagged release is built by CI for all five platforms:

| Platform | Artifacts |
|:---------|:----------|
| **Windows** | `ZPlay-Windows-Setup.exe` (installer) · `ZPlay-Windows-x64-Portable.zip` |
| **Android** | `app-arm64-v8a-release.apk` · `app-armeabi-v7a-release.apk` (also on Android TV — D-pad and leanback launcher supported) |
| **Linux** | `ZPlay-Linux-x86_64.AppImage` · `ZPlay-Linux-x86_64.tar.gz` |
| **macOS** | `ZPlay-macOS-arm64.dmg` / `.zip` (Apple Silicon) · `ZPlay-macOS-intel.dmg` / `.zip` |
| **iOS** | `ZPlay-iOS.ipa` (unsigned, sideload only) |

Grab them from the [Releases](https://github.com/tzero86/PlayTorrioZero/releases) page.

---

## Build from source

Requires Flutter 3.x (Dart 3.11+).

```bash
git clone https://github.com/tzero86/PlayTorrioZero.git
cd PlayTorrioZero
flutter pub get
flutter run -d windows      # or macos / linux
```

Release builds:

```bash
flutter build windows --release
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

---

## How it works

Content comes from Stremio-compatible addons (Cinemeta is installed by default) plus the built-in scrapers. Open a title, hit play, and every enabled provider is queried at once — results appear as they arrive rather than after the slowest one finishes.

Scrapers are isolated plugins: one failing or hanging doesn't affect the others. The built-in provider list supports a custom mode where you control priority order and enable/disable individual providers.

### Adding a scraper

Extend `StreamScraper`, implement `scrape()`, register it in `stream_service.dart`. The manager handles concurrency, timeouts, deduplication and error isolation.

```dart
class MyNewScraper extends StreamScraper {
  @override
  String get name => 'ZPlayHTTP';

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

---

## Tech

- **Flutter / Dart** for the whole app, five platforms from one codebase
- **media_kit / libmpv** for playback, with hardware decoding, HLS/DASH handling and Anime4K GLSL upscaling
- **TorrServer** (`libtorrent`) as the embedded torrent engine
- **Liquid Glass** GPU shader UI via `liquid_glass_easy`, with a settings toggle for low-end devices
- **Stremio addon protocol** for catalogs, search and metadata
- Local persistence via `SharedPreferences` for watchlists, reading/listening positions and settings

<details>
<summary><b>Project layout</b></summary>

```
lib/
├── main.dart                     # entry point
├── models/                       # data classes (movie, stream, subtitle, manga, audiobook, music)
├── services/
│   ├── addon/                    # Stremio addon manager
│   ├── metadata/                 # metadata client + recommendation engine
│   ├── stream/                   # stream aggregation, health checking, torrent engine
│   ├── scraper/                  # scraper base class + manager + built-in providers
│   ├── anime/                    # anime scraper service + extractors
│   ├── subtitles/                # subtitle service + providers
│   ├── manga/                    # reader scraper + progress tracking
│   ├── audiobook/                # multi-source aggregator + progress service
│   ├── music/                    # music API client + library + player controller
│   ├── continue_watching/        # resume + source matching
│   └── diagnostics/              # crash breadcrumbs, perf monitor, renderer backend
├── pages/                        # UI screens
├── widgets/                      # reusable components
└── utils/                        # torrent filename parser, relevance scorer, route transitions
```
</details>

---

## Legal

ZPlay is a media player and aggregator. It hosts no content and stores none. Everything is fetched from third-party sources at your request. You are responsible for ensuring you have the right to access whatever you stream in your jurisdiction.

---

## Licence & credits

**GPL-3.0** — see [LICENSE](LICENSE).

ZPlay is a modified version of **PlayTorrio V3**, © 2026 Ayman ([@ayman708-UX](https://github.com/ayman708-UX)), and is distributed under the same licence. The original project and the full corresponding source are available at [github.com/ayman708-UX/PlayTorrioV3](https://github.com/ayman708-UX/PlayTorrioV3).

Poppins and Playfair Display are bundled under the SIL Open Font License 1.1.

---

<p align="center">
  Maintained by <a href="https://github.com/tzero86">tzero86</a> · based on PlayTorrio V3 by <a href="https://github.com/ayman708-UX">Ayman</a>
</p>
