# Code-pattern audit

> Evidence drawn from grep scans of `lib/` production pages, plus `pubspec.lock`, `android/app/build.gradle.kts`, CI `.github/workflows/build.yml` (2026-09-14).

## A. Startup / hot-paths

| File:lines | Role | Issue | Risk |
|---|---|---|---|
| `lib/main.dart:41-50` | App init | `Future.wait` of ~22 services blocks runApp; no isolate | **H** |
| `lib/pages/home/home_page.dart:480` | Home | `unawaited(_ensureAnimeRows())` without error handling | **H** |
| `lib/pages/home/home_page.dart:796` | Carousel | `Timer.periodic` never disposed in `dispose()` | **M** |
| `lib/pages/audiobook_player_screen.dart:79` | Audiobook | 5s `Timer.periodic` + stream subscriptions not cancelled | **M** |
| `lib/pages/anime/anime_details_page.dart:129` | Anime | `Future.wait` of 3 large feeds; big arrays held in state | **M** |

## B. List/scroll audit (production pages)

All production `ListView.builder`/`GridView.builder` (≈30+ sites) lack `const`/`addAutomaticKeepAlives:false`/`cacheExtent`. Only `iptv_portal_browser_page.dart:1202` has the full-good set. Affected samples:

- `lib/pages/home/home_page.dart:739` — ListView.builder horizontal, no const, no cacheExtent
- `lib/pages/anime/anime_search_page.dart:306` — ListView.builder, no const
- `lib/pages/catalog/catalog_page.dart:245` — GridView.builder, no const, no cacheExtent
- `lib/pages/details/details_page.dart:794` — ListView.builder, no const
- `lib/pages/audiobooks/audiobooks_page.dart:539`, `:913` — ListView.builder horizontal
- `lib/pages/anime/anime_details_page.dart:897/1276/1432` — ListView.separated (cast/relations/recs)

## C. Image / cache audit

- `CachedNetworkImage` used ~40+ times; none pass `const`, almost none set `memCacheWidth`/`memCacheHeight` (only `iptv_portal_browser_page` and some player thumbnails do).
- No custom `CacheManager`; default caching only.
- `Image.network` (uncached) at:
  - `lib/pages/anime/anime_arabic_stream_sheet.dart:168`
  - `lib/pages/manga/manga_details_page.dart:134,553,662`
- `filterQuality: FilterQuality.high` at `lib/pages/anime/anime_page.dart:1097` (extra GPU cost).
- Placeholder/error builders use anonymous closures (new closure / build).

## D. Async / concurrency

- `lib/main.dart:41-50` Future.wait (22 inits) — see above.
- `lib/pages/home/home_page.dart:480` `unawaited(_ensureAnimeRows())`.
- `compute()` is used correctly in:
  - `lib/services/generate_audiobook_screen.dart:108`
  - `lib/services/epub/epub_parser_service.dart:117`
  - `lib/services/scraper/sites/bestsimal_similar.dart:325` (and snippet sites).

## E. State management rebuild audit

- `setState` used widely: `wewatch_quiz`, `anime_details_page`, `anime_details_modal`, `anime_page`, `anime_search`, `audiobook_player`, `books`, `home` (grep `setState` counts: home ~88, anime_details ~55, wewatch ~31 — from perf recon).
- `MouseRegion` setState for hover arrows (anime details, scroll arrows).
- `ValueNotifier` in `AppThemeService` drives full `MaterialApp` rebuild.
- No `RepaintBoundary` around `mk.Video` in `lib/pages/player/player_screen.dart`.

## F. Largest Dart files (lines)

| File | Approx lines |
|---|---|
| `lib/pages/home/home_page.dart` | ~2214 |
| `lib/pages/audiobooks/audiobook_player_screen.dart` | ~1915 |
| `lib/pages/details/details_page.dart` | ~2000+ |
| `lib/pages/anime/anime_page.dart` | ~1500+ |
| `lib/pages/player/player_screen.dart` | ~1500+ |
| `lib/pages/anime/anime_details_page.dart` | ~1470+ |
| `lib/pages/anime/anime_details_modal.dart` | ~1000+ |
| `lib/pages/ai/wewatch_quiz_page.dart` | ~1000+ |
| `lib/pages/anime/anime_search_page.dart` | ~900+ |
| `lib/pages/addons/addons_page.dart` | ~800+ |

## G. Recommendations

1. Init split / sequential (no Future.wait block) → startup <2 s.
2. `CachedNetworkImage` `memCacheWidth`+`const`; custom CacheManager; eliminate `Image.network`.
3. `const`+`addAutomaticKeepAlives:false`+`cacheExtent`+`itemExtent` everywhere.
4. `RepaintBoundary` around `mk.Video`; decouple overlays from video rebuild.
5. `AnimatedContainer`/HoverButton replacing MouseRegion setState arrows.
6. Split the 2 KB+ Dart pages into smaller files.
