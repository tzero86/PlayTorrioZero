<!-- Annex to docs/RENAME_PRODUCT_PLAN.md — exhaustive per-layer inventory.
     Generated 2026-09-14 by read-only reconnaissance over this repo's working tree.
     `path:line` references match the tree as generated; re-verify before applying edits.
     Rows marked [UNVERIFIED] or [INFERENCE] are unresolved — do not treat them as settled.
     Do not delete rows: an executing agent works this list top-to-bottom. -->

# Inventory — CODE / UI / assets / package identity

Scope: `lib/**`, `test/**`, `assets/**`, `web/**`, `bin/**`, `docs/**`, `pubspec.yaml`, plus `CONTRIBUTING.md`/`CHANGELOG.md` (brand-bearing). Explicitly NOT covered: `android/ ios/ linux/ macos/ windows/ installer/ .github/` (ReconNativeBuild) and `README.md`/`LICENSE` (ReconAttribution).

---

## 0. Required answers to the brief (summary before the tables)

**(1) Is there a central branding constant? — NO.**
Search over `lib/**` for `kAppName|appName|appTitle|applicationName|kVersion|branding|packageName` returns only:
- `lib/services/simkl/simkl_constants.dart:11` `const String kSimklAppName = 'debrify';` — a **third-party** app name sent to Simkl's API, not the product name.
- `lib/services/simkl/simkl_service.dart:417` `'app-name': kSimklAppName` (consumer of the above).
- `lib/pages/settings/settings_page.dart:367-368` and `lib/pages/settings/updates_settings_page.dart:101,136` — `PackageInfo.appName` (runtime value + hardcoded fallback `'PlayTorrio'`).
- `lib/services/window/window_service.dart` has **no** title/app-name API (pure fullscreen manager).
There is **no** `kAppName`, no `applicationName`, no `branding` file. Every user-visible product name is a hardcoded inline literal. The literals a central constant should absorb are enumerated in §1.

**(2) Window title / splash.** Window title is `MaterialApp.title = 'PlayTorrio'` at `lib/main.dart:144` (MaterialApp has no `onGenerateTitle`, so this is the literal used for the OS task-switcher/web title). The native Windows title bar text is set by `windows/runner` (out of scope) from `MyAppName`/`Runner.rc`. Splash/intro text: `lib/pages/home/home_page.dart:794-833` (`_buildIntroOverlay`: icon + `'PlayTorrio'` at :815 + tagline `'Your Cinema Universe'` at :822); a second persistent logo block at `home_page.dart:987-998`; the anime page header logo at `lib/pages/anime/anime_page.dart:617-627`.

**(3) About/credits/version surfaces.** `lib/pages/settings/about_settings_page.dart` — AppBar `'About PlayTorrio'` (:19), hero name `'PlayTorrio'` (:59), version line `'Version $version • Next-Gen Streaming Hub'` from `PackageInfo.fromPlatform()` (FutureBuilder ~:70-88), description `:111`, tech tiles `:137-165`, and `_buildCreditsSection` (see §1). Settings entry tile `'About PlayTorrio'` at `settings_page.dart:805-812`.
`showLicensePage` / `LicenseRegistry` / `LicensePage` / `addLicense` / `GPL` / `GNU General` — **zero occurrences in `lib/**`** (verified with a case-sensitive grep). There is no licenses/credits screen at all, despite LICENSE = GPL-3.0. **This is a compliance gap the plan must fix by adding a license/attribution surface.**

**(4) Updater.** `lib/services/updater/app_updater_service.dart:12-14`: `githubRepo = 'ayman708-UX/PlayTorrioV3'`, `githubApiUrl = 'https://api.github.com/repos/$githubRepo/releases/latest'`; auth header `Accept: application/vnd.github.v3+json`; asset selection is *substring-based* per platform (`.apk` + arch keywords arm64-v8a/armeabi-v7a/x86_64 + `universal` + `release`; Windows `setup`/`install`/`.exe`/`.msix`/`.zip`; Linux `.appimage`/`.deb`/`.tar.gz`; macOS `.dmg`/`.pkg`). `update_dialog.dart` builds download filenames `'PlayTorrio_<ver>.apk'` (:416) and `'PlayTorrio-<ver><ext>'` (:516-517), and shows copy at :440 and :595. Because matching is substring-based, renaming CI artifact names (owned by ReconNativeBuild) will not break the updater — but the **repo slug** is upstream-owned and must be `replace-or-keep` decided (point it at the fork to receive the owner's own releases).

**(5) Discord RPC.** App id is **not** hardcoded in Dart: `discord_rpc_service.dart:78` `final appId = EnvService.discordAppId;` → `lib/services/config/env_service.dart:96-100` reads `DISCORD_APP_ID` from a `--dart-define`, root `.env`, `rootBundle` asset `.env`, or `assets/.env`. No `.env`/`.env.example` is committed (globs found only `macos|ios/Flutter/ephemeral/flutter_native_integration.env`). **Whether the id is upstream's is [UNVERIFIED]** — if it is, presence will show the upstream app's name/icon until the owner registers their own Discord application. Asset key is `_defaultAssetKey = 'logo'` (`:23`) and must exist in the Discord app's asset library. Presence strings are all `PlayTorrioV3` (see §1/§2).

**(6) Deep links / schemes.** The only scheme handled/emitted in Dart is Stremio's: `addon_manager.dart:256-260` rewrites `stremio://`/`stremio:` → `https://`; `watch_screen.dart:2881-2886` parses a `stremio:///detail/...` `externalUrl` to launch the Stremio app. **There is no custom product scheme** (no `playtorrio://`) registered or emitted anywhere in Dart. Coverage: `test/vadapav_and_stremio_scheme_test.dart:64-73`.

**(7) Upstream URLs in Dart.** Exactly two: `lib/services/music/lyrics_service.dart:76,109` `'PlayTorrio/1.0.0 (https://github.com/ayman708-UX/PlayTorrioV3)'` (LRCLIB User-Agent) and `app_updater_service.dart:12-14`. All other `github.com`/`githubusercontent` strings in `lib/**` are third-party (`tv-logo/tv-logos` channel art, `zoreu/megasource_scrapers` config blob) — keep.

**(8) Assets inventory.** No asset file is brand-named. `assets/icon.png` is the app logo (referenced 8×: `main`? no — see §4). `assets/subfont.ttf`, `assets/fonts/subfont.ttf` are a generic subtitle font, not brand. `web/manifest.json` is **0 bytes**; `web/favicon.png` + `web/icons/Icon-{192,512}.png` + `Icon-maskable-{192,512}.png` are stock Flutter names. See §4.

**(9) docs/bin/CONTRIBUTING/CHANGELOG/analysis_options.** `docs/player.md` and `bin/inspect.dart` contain **no** product-name occurrences (player.md is a generic FVP/libmdk guide using `MyApp`). `analysis_options.yaml` — none. `CONTRIBUTING.md` and `CHANGELOG.md` do (see §5).

---

## 1. Findings

### Layer A — user-visible strings (window titles, About/credits, splash, dialogs, settings copy, Discord text)

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| lib/main.dart:144 | `title: 'PlayTorrio',` | user-visible (MaterialApp title / task switcher) | yes | `<AppName>` | No `onGenerateTitle`; literal is the only title source. |
| lib/pages/home/home_page.dart:815 | `'PlayTorrio',` | user-visible (intro splash) | yes | `<AppName>` | Splash overlay `_buildIntroOverlay`. |
| lib/pages/home/home_page.dart:822 | `'Your Cinema Universe',` | user-visible (tagline) | optional | keep or new tagline | Brand-adjacent identity, no literal match. |
| lib/pages/home/home_page.dart:995 | `'PlayTorrio',` | user-visible (header/logo) | yes | `<AppName>` | |
| lib/pages/anime/anime_page.dart:626 | `text: 'PlayTorrio ',` | user-visible (page header logo) | yes | `<AppName> ` | Trailing space intentional in TextSpan. |
| lib/pages/settings/about_settings_page.dart:19 | `'About PlayTorrio',` | user-visible (AppBar) | yes | `'About <AppName>'` | |
| lib/pages/settings/about_settings_page.dart:59 | `'PlayTorrio',` | user-visible (hero) | yes | `<AppName>` | |
| lib/pages/settings/about_settings_page.dart:80 | `'Version $version • Next-Gen Streaming Hub'` | user-visible (version line) | optional | keep | Version from PackageInfo; tagline optional. |
| lib/pages/settings/about_settings_page.dart:105 | `'Universal Entertainment Ecosystem'` | user-visible (section) | optional | keep | |
| lib/pages/settings/about_settings_page.dart:111 | `'PlayTorrio is an all-in-one entertainment client bringing together movies, TV series, anime, live IPTV, music, manga, and audiobooks into a unified, high-performance interface with custom Liquid Glass visuals.'` | user-visible (description) | yes | reword with `<AppName>` | |
| lib/pages/settings/about_settings_page.dart (tech tiles, ~:137-165) | `'High-Performance Video Engine'`, `'Debrid & Multi-Source Scrapers'`, `'Liquid Glass GLSL Shaders'`, `'Trakt & Cloud Synchronization'` + subtitles | user-visible (About) | keep | — | No brand literal; credits/licence section is MISSING (see §0.3). |
| lib/pages/settings/settings_page.dart:809 | `title: 'About PlayTorrio',` | user-visible (settings tile) | yes | `'About <AppName>'` | |
| lib/pages/settings/settings_page.dart:810 | `subtitle: 'Architecture, video engine, and credits',` | user-visible | keep | — | |
| lib/pages/settings/settings_page.dart:590 | `'PlayTorrioHTTP streaming sources, priority order & toggles'` | user-visible (settings subtitle) | yes | `<Name> HTTP streaming sources, …` | |
| lib/pages/settings/settings_page.dart:614 | `'PlayTorrio torrent swarms (Knaben, TorrentGalaxy) active'` | user-visible | yes | `<Name> torrent swarms …` | |
| lib/pages/settings/settings_page.dart:615 | `'P2P disabled. Using only direct HTTP streaming (PlayTorrioHTTP)'` | user-visible | yes | `… (<Name>HTTP)` | |
| lib/pages/settings/builtin_providers_settings_page.dart:71 | `'This will restore all 45 PlayTorrioHTTP providers to their default order and re-enable any disabled providers.'` | user-visible (dialog) | yes | `<Name>HTTP` | Note count says 45 while code comment says 46 (`builtin_providers_settings_service.dart:31`). |
| lib/pages/settings/builtin_providers_settings_page.dart:387 | `'All $totalCount PlayTorrioHTTP providers are active and scraped concurrently.'` | user-visible | yes | `<Name>HTTP` | |
| lib/pages/settings/builtin_providers_settings_page.dart:399 | `'In Default mode, PlayTorrio uses its native multi-source streaming engine. …'` | user-visible | yes | `<AppName>` | |
| lib/pages/settings/debrid_settings_page.dart:372 | `'When enabled, all torrents from PlayTorrio and Stremio addons are resolved exclusively through your active Debrid provider without touching the local torrent engine.'` | user-visible | yes | `<AppName>` | |
| lib/pages/settings/debrid_settings_page.dart:419 | `'PlayTorrio will send requests to this provider when streaming.'` | user-visible | yes | `<AppName>` | |
| lib/pages/settings/updates_settings_page.dart:35 | `'PlayTorrio is up to date!'` | user-visible (SnackBar) | yes | `<AppName>` | |
| lib/pages/settings/updates_settings_page.dart:86 | `'Keep PlayTorrio up to date with the latest features, security patches, and performance improvements.'` | user-visible | yes | `<AppName>` | |
| lib/pages/settings/updates_settings_page.dart:101 | `snapshot.data!.appName : 'PlayTorrio'` | user-visible (fallback) | yes | `<AppName>` fallback | |
| lib/pages/settings/updates_settings_page.dart:136 | `appName,` | user-visible (rendered value) | keep | — | Renders runtime PackageInfo value. |
| lib/widgets/p2p/p2p_warning_dialog.dart:169 | `title: 'PlayTorrio HTTP (Direct Stream)',` | user-visible (dialog) | yes | `<Name> HTTP (Direct Stream)` | |
| lib/widgets/p2p/p2p_warning_dialog.dart:182 | `title: 'PlayTorrio (Torrent Engine)',` | user-visible | yes | `<Name> (Torrent Engine)` | |
| lib/widgets/p2p/p2p_warning_dialog.dart:211 | `'Would you like to turn off the built-in PlayTorrio P2P torrent source and use only direct HTTP streaming?'` | user-visible | yes | `<AppName>` | |
| lib/widgets/p2p/p2p_warning_dialog.dart:348 | `Text('P2P torrent source turned off. PlayTorrioHTTP will be used.')` | user-visible (SnackBar) | yes | `<Name>HTTP` | duplicate at :386 |
| lib/widgets/p2p/p2p_warning_dialog.dart:386 | `Text('P2P torrent source turned off. PlayTorrioHTTP will be used.')` | user-visible (SnackBar) | yes | `<Name>HTTP` | duplicate of :348 |
| lib/widgets/player/player_sub_style_modal.dart:280 | `'PlayTorrio • Sample Subtitle Preview'` | user-visible (preview) | yes | `<AppName> • …` | |
| lib/widgets/player/player_sub_style_modal.dart:435 | `f == 'subfont' ? 'Default (PlayTorrio Subfont)' : f` | user-visible (dropdown label) | yes | `'Default (<AppName> Subfont)'` | |
| lib/widgets/updater/update_dialog.dart:440 | `'Please enable "Install unknown apps" permission for PlayTorrio in Android settings.'` | user-visible | yes | `<AppName>` | |
| lib/widgets/updater/update_dialog.dart:595 | `'Close PlayTorrio and run the installer to update.'` | user-visible (Windows) | yes | `<AppName>` | |
| lib/services/addon/addon_manager.dart:125 | `name: 'PlayTorrio',` | user-visible (addon display name) + internal id key | yes | `<AppName>` | Displayed in addon lists; see Layer C for matching risk. |
| lib/services/addon/addon_manager.dart:144 | `name: 'PlayTorrioHTTP',` | user-visible (addon display name) + internal id key | yes | `<AppName>HTTP` | Same risk. |
| lib/services/addon/addon_manager.dart:127 | `'Built-in BitTorrent P2P streaming engine (TorrServer). Plays torrents, magnets, and infohashes directly.'` | user-visible (addon description) | optional | keep | |
| lib/services/addon/addon_manager.dart:146 | `'Built-in fast HTTP stream scrapers (111477, Cinejoy, …)'` | user-visible (addon description) | optional | keep | |
| lib/pages/player/watch_screen.dart:2971 | `'PlayTorrioHTTP · ${s.providerName}'` | user-visible (source label) | yes | `<Name>HTTP · …` | Paired with matching check at :2968 — change both together. |
| lib/pages/settings/addons_settings_page.dart:571 | `'Built-in TorrServer P2P streaming engine'` | user-visible | keep | — | Third-party engine name, not product. |

### Layer B — network identity (User-Agent, app-id params, service registration)

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| lib/services/iptv/iptv_network.dart:542 | `static const _oauthUa = 'PlayTorrio/1.3.6 (by /u/PlayTorrioApp)';` | network identity (Reddit OAuth UA) | yes | `'<AppName>/1.3.6 (by /u/<redditUser>)'` | Reddit may rate-limit unknown UA; the `/u/PlayTorrioApp` handle belongs to upstream. |
| lib/services/iptv/iptv_network.dart:551 | `static const _ua = 'Mozilla/5.0 (Linux; Android 11; PlayTorrio) ' 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36';` | network identity (UA) | yes | substitute `<AppName>` in the platform token | |
| lib/services/music/lyrics_service.dart:76 | `'User-Agent': 'PlayTorrio/1.0.0 (https://github.com/ayman708-UX/PlayTorrioV3)',` | network identity (UA to LRCLIB) | yes | `'<AppName>/<ver> (<owner repo url>)'` | Also embeds upstream repo URL. |
| lib/services/music/lyrics_service.dart:109 | `'User-Agent': 'PlayTorrio/1.0.0 (https://github.com/ayman708-UX/PlayTorrioV3)',` | network identity (UA) | yes | same | duplicate of :76 |
| lib/services/player/skip_segments_service.dart:77 | `'User-Agent': 'PlayTorrio/3.0.0 (VideoPlayer SkipEngine)',` | network identity (UA to introdb/segment API) | yes | `'<AppName>/3.0.0 (VideoPlayer SkipEngine)'` | |
| lib/services/debrid/providers/alldebrid_service.dart:39 | `Uri.parse('https://api.alldebrid.com/v4/user?agent=PlayTorrio&apikey=$trimmed'),` | network identity (AllDebrid agent param) | yes | `agent=<AppName>` | AllDebrid records the agent string. |
| lib/services/updater/app_updater_service.dart:12 | `static const String githubRepo = 'ayman708-UX/PlayTorrioV3';` | network identity (service endpoint) | decide-in-plan | `'<owner>/<RepoName>'` | Upstream-owned; point at fork to get own releases. |
| lib/services/updater/app_updater_service.dart:13-14 | `githubApiUrl = 'https://api.github.com/repos/$githubRepo/releases/latest'` | network identity (endpoint) | decide-in-plan | derived from `githubRepo` | |
| lib/services/simkl/simkl_constants.dart:11 | `const String kSimklAppName = 'debrify';` | network identity (third-party `app-name` param to Simkl) | keep | — | Not the product name; changing it may affect Simkl API-side allowlisting. Do not touch. |
| lib/services/addon/addon_manager.dart:122,124,141,143 | `baseUrl: 'builtin:playtorrio'` / `id: 'builtin.playtorrio'` / `baseUrl: 'builtin:playtorriohttp'` / `id: 'builtin.playtorriohttp'` | internal identifier used as addon identity across boundaries | yes (coordinated) | `'builtin:<slug>'` / `'builtin.<slug>'` | These IDs appear in UI and are compared everywhere; see Layer C. |

### Layer C — internal identifiers (prefs keys, file names, addon-id contracts, stored state)

> ⚠️ Everything in this table is **stored on the user's device**. Renaming without a read-old/write-new migration resets the user's data (watchlist, history, reader/player settings, P2P toggles, download queue) or orphans their installed addons.

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| lib/services/anime/anime_library_service.dart:13 | `static const String _watchlistKey = 'playtorrio_anime_watchlist_v1';` | internal id (SharedPreferences key) | decide-in-plan | keep, or migrate | Renaming loses the anime watchlist. |
| lib/services/anime/anime_library_service.dart:14 | `static const String _historyKey = 'playtorrio_anime_history_v1';` | internal id (prefs key) | decide-in-plan | keep, or migrate | Renaming loses anime history. |
| lib/services/books/reader_settings.dart:223 | `static const String _storageKey = 'playtorrio_reader_settings_v3';` | internal id (prefs key) | decide-in-plan | keep, or migrate | Renaming loses reader settings. |
| lib/services/p2p/p2p_settings_service.dart:9 | `static const String _kP2pEnabledKey = 'playtorrio_p2p_source_enabled';` | internal id (prefs key) | decide-in-plan | keep, or migrate | Renaming resets the P2P toggle. |
| lib/services/p2p/p2p_settings_service.dart:10 | `static const String _kNeverShowWarningKey = 'playtorrio_p2p_warning_never_show';` | internal id (prefs key) | decide-in-plan | keep, or migrate | Renaming re-shows the warning modal once. |
| lib/pages/books/widgets/focus_mode_view.dart:72 | `prefs.getBool('playtorrio_seen_focus_coach_v2')` | internal id (prefs key) | decide-in-plan | keep, or migrate | Read+write pair with :75. |
| lib/pages/books/widgets/focus_mode_view.dart:75 | `prefs.setBool('playtorrio_seen_focus_coach_v2', true)` | internal id (prefs key) | decide-in-plan | keep, or migrate | |
| lib/services/iptv/iptv_storage.dart:124 | `static String _key(String channelId) => 'pt_iptv_ch_$channelId';` | internal id (prefs key, `pt`=PlayTorrio abbreviation) | decide-in-plan | keep, or migrate | Brand-derived but **no literal 'playtorrio'**; easy to miss. Stores IPTV channel hits. |
| lib/services/iptv/iptv_storage.dart:209 | `static String _key(String channelId) => 'pt_iptv_chfav_$channelId';` | internal id (prefs key) | decide-in-plan | keep, or migrate | Favourites. Same caveat. |
| lib/services/download/download_service.dart:51 | `static const String _storageFilename = 'playtorrio_download_tasks.json';` | internal id (on-disk file) | decide-in-plan | keep, or rename+migrate | Renaming loses the download queue. |
| lib/services/theme/custom_background_service.dart:155 | `p.join(appDocDir.path, 'playtorrio_custom_background$ext')` | internal id (on-disk file) | decide-in-plan | keep, or rename+migrate | Renaming loses the user's custom background. |
| lib/utils/download/download_path_helper.dart:56 | `Directory('/storage/emulated/0/Download/PlayTorrio')` | internal id (public Downloads dir) | optional | `<AppName>` | Android TV/phone: old folder stays behind unless migrated; user-visible in Files. |
| lib/utils/download/download_path_helper.dart:63 | `Directory(p.join(extDirs.first.path, 'PlayTorrio'))` | internal id (external storage dir) | optional | `<AppName>` | |
| lib/utils/download/download_path_helper.dart:75 | `Directory(p.join(downloadsDir.path, 'PlayTorrio'))` | internal id (desktop downloads dir) | optional | `<AppName>` | Windows primary target. |
| lib/services/music/music_download_service.dart:80 | `Directory(p.join(appDocDir.path, 'PlayTorrio', 'Music'))` | internal id (app-docs dir) | optional | `<AppName>` | Renaming hides previously downloaded music. |
| lib/services/books/book_download_service.dart:24 | `Directory(p.join(appDocDir.path, 'PlayTorrio', 'Books'))` | internal id (app-docs dir) | optional | `<AppName>` | |
| lib/services/books/book_download_service.dart:31 | `Directory(p.join(Directory.systemTemp.path, 'PlayTorrio', 'Books'))` | internal id (temp dir) | optional | `<AppName>` | |
| lib/services/audiobook/custom_audiobook_service.dart:134 | `Directory(p.join(appDocDir.path, 'PlayTorrio', 'CustomAudiobooks'))` | internal id (app-docs dir) | optional | `<AppName>` | |
| lib/services/audiobook/custom_audiobook_service.dart:137 | `Directory(p.join(temp.path, 'PlayTorrio', 'CustomAudiobooks'))` | internal id (temp dir) | optional | `<AppName>` | |
| lib/services/audiobook/epub_cover.dart:25 | `Directory(p.join(appDocDir.path, 'PlayTorrio', 'AudiobookCovers'))` | internal id (app-docs dir) | optional | `<AppName>` | |
| lib/services/audiobook/epub_cover.dart:28 | `Directory(p.join(temp.path, 'PlayTorrio', 'AudiobookCovers'))` | internal id (temp dir) | optional | `<AppName>` | |
| lib/services/audiobook/paper2audio_service.dart:302 | `Directory(p.join(appDocDir.path, 'PlayTorrio', 'GeneratedAudiobooks'))` | internal id (app-docs dir) | optional | `<AppName>` | |
| lib/services/audiobook/paper2audio_service.dart:305 | `Directory(p.join(temp.path, 'PlayTorrio', 'GeneratedAudiobooks'))` | internal id (temp dir) | optional | `<AppName>` | |
| lib/models/continue_watching/continue_watching_item.dart:99 | `addonName: addonName ?? 'PlayTorrio',` | internal id (persisted sentinel in resume spec) | yes (coordinated) | new sentinel `<AppName>` | Written into stored continue-watching JSON; old rows contain `'PlayTorrio'`. |
| lib/models/continue_watching/continue_watching_item.dart:149 | `addonName: json['addonName']?.toString() ?? 'PlayTorrio',` | internal id (stored-state default) | yes (coordinated) | new sentinel | Same file; must match `watch_screen`/`stream_service` comparisons. |
| lib/models/download/download_task_model.dart:137 | `addonName: 'PlayTorrio Offline',` | internal id (persisted sentinel in download task) | yes (coordinated) | `'<AppName> Offline'` | Written into `playtorrio_download_tasks.json`. |
| lib/services/addon/addon_manager.dart:29 | `a.manifest.id == 'builtin.playtorrio' \|\| a.baseUrl == 'builtin:playtorrio'` | internal id (addon contract) | yes | new id | `_ensureBuiltInsExist`. |
| lib/services/addon/addon_manager.dart:33 | `a.manifest.id == 'builtin.playtorriohttp' \|\| a.baseUrl == 'builtin:playtorriohttp'` | internal id (addon contract) | yes | new id | |
| lib/services/addon/addon_manager.dart:86 | `a.manifest.id == 'builtin.playtorrio' \|\| a.baseUrl == 'builtin:playtorrio'` | internal id (addon contract) | yes | new id | `isPlayTorrioActive`. |
| lib/services/addon/addon_manager.dart:95 | `a.manifest.id == 'builtin.playtorriohttp' \|\| a.baseUrl == 'builtin:playtorriohttp'` | internal id | yes | new id | `isPlayTorrioHttpActive`. |
| lib/services/addon/addon_manager.dart:105-106 | `nameLower == 'playtorrio' \|\| nameLower == 'playtorriohttp'` | internal id (name→icon resolver) | yes | new slugs | Case-insensitive. |
| lib/pages/player/watch_screen.dart:110-114 | `'builtin.playtorriohttp'`/`'builtin:playtorriohttp'`/`'playtorriohttp'`; `'builtin.playtorrio'`/`'builtin:playtorrio'`/`'playtorrio'` | internal id (addon ordering cache) | yes | new ids | Keys of `_cachedAddonOrder`. |
| lib/pages/player/watch_screen.dart:284 | `s.addonName.toLowerCase() != 'playtorriohttp'` | internal id (filter) | yes | new sentinel | |
| lib/pages/player/watch_screen.dart:292-293 | `a.addonName.toLowerCase() == 'playtorriohttp'` / `b… == 'playtorriohttp'` | internal id (sort key) | yes | new sentinel | |
| lib/pages/player/watch_screen.dart:2968,2971 | `s.addonName.toLowerCase() == 'playtorriohttp'` … `'PlayTorrioHTTP · ${s.providerName}'` | internal id + user-visible | yes | new sentinel + `<Name>HTTP` | Pair. |
| lib/pages/player/watch_screen.dart:3076-3077 | `nameLower == 'playtorrio' \|\| nameLower == 'playtorriohttp'` | internal id (built-in detection) | yes | new slugs | |
| lib/pages/settings/addons_settings_page.dart:159-160 | `addon.manifest.id == 'builtin.playtorrio' \|\| … 'builtin.playtorriohttp'` | internal id | yes | new ids | |
| lib/pages/settings/addons_settings_page.dart:412-413 | `addon.manifest.id == 'builtin.playtorrio' \|\| addon.baseUrl == 'builtin:playtorrio'` / `… playtorriohttp …` | internal id | yes | new ids | |
| lib/services/stream/stream_service.dart:137 | `AddonManager.instance.isPlayTorrioHttpActive` | internal symbol | yes | rename symbol | |
| lib/services/stream/stream_service.dart:189,276-278 | `'PlayTorrioHTTP'` / `'PlayTorrio'` in doc + `normalizedTarget == 'playtorriohttp' \|\| normalizedTarget == 'playtorrio' \|\| normalizedTarget.contains('playtorrio')` | internal id (target-addon routing) | yes | new slugs | `contains('playtorrio')` is a broad match — review. |
| lib/services/stream/stream_service.dart:297,302 | `normalizedTarget == 'playtorriohttp'` / `normalizedTarget == 'playtorrio'` | internal id (routing) | yes | new slugs | |
| lib/services/scraper/stream_scraper.dart:61,80,81,88,98,145 | `s.name == 'PlayTorrio'` / `s.name == 'PlayTorrioHTTP'` (scraper registry filter/sort) | internal id (scraper-name contract) | yes | new names | Tightly coupled to every scraper's `name` getter (Layer C/E below). |
| lib/services/scraper/sites/knaben.dart:9,107,108 | `String get name => 'PlayTorrio';` / `name: 'PlayTorrio'` / `addonName: 'PlayTorrio'` | internal id + stored sentinel | yes | `<AppName>` | Torrent scraper; `addonName` persists into continue-watching. |
| lib/services/scraper/sites/torrent_galaxy.dart:10,151,152 | `String get name => 'PlayTorrio';` / `name: 'PlayTorrio'` / `addonName: 'PlayTorrio'` | internal id + stored sentinel | yes | `<AppName>` | |
| lib/services/scraper/builtin_providers_settings_service.dart:31 | `/// Master list of all 46 PlayTorrioHTTP providers in standard default order.` | internal id (comment; mismatch w/ UI '45') | optional | comment | Provider **ids** (`'a111477'`, `'vadapav'`, …) are brand-free — keep. |
| lib/services/p2p/p2p_settings_service.dart:4,9,12-13 | comments + `'PlayTorrio'`/`'PlayTorrioHTTP'` in doc comments | internal id (doc) | optional | comment | |
| lib/services/continue_watching/continue_watching_service.dart:503,1041 | `'PlayTorrioHTTP'` in doc comments | internal id (doc) | optional | comment | |
| lib/services/addon/addon_manager.dart:108 | `return 'asset:assets/icon.png';` | internal id (icon in selector) | keep | — | Ties built-ins to the icon asset (Layer D). |
| lib/services/discord/discord_rpc_service.dart:23 | `static const String _defaultAssetKey = 'logo';` | internal id (Discord asset key) | decide-in-plan | `'logo'` (re-upload to own Discord app) | Must exist in whatever Discord app id is used. |
| lib/services/discord/discord_rpc_service.dart:22 | `static const String _prefKey = 'discord_rpc_enabled';` | internal id (prefs key) | keep | — | Brand-free. |
| lib/services/updater/app_updater_service.dart:15 | `static const String _keyDismissedVersion = 'dismissed_update_version';` | internal id (prefs key) | keep | — | Brand-free. |
| lib/services/player/player_settings.dart:123-128,158,188,224 | prefs keys `player_sub_*`, value `'subfont'` | internal id (prefs keys/values) | keep | — | Brand-free; `'subfont'` is a font, not the product. |
| lib/services/window/window_service.dart (whole file) | no brand string | internal id | keep | — | No window-title API here; title comes from `main.dart:144`. |

### Layer D — asset / path

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| assets/icon.png | app icon (no brand in filename) | asset | optional | replace image with own logo | Referenced at: `lib/pages/home/home_page.dart:808,988`, `lib/pages/anime/anime_page.dart:618`, `lib/pages/player/watch_screen.dart:3095`, `lib/pages/settings/addons_settings_page.dart:499`, `lib/services/addon/addon_manager.dart:108`, `pubspec.yaml:128,131,134,135,152`. **Content may depict upstream branding** — visually inspect before shipping. |
| pubspec.yaml:128,131,134,135 | `image_path: "assets/icon.png"` (flutter_launcher_icons) | asset | keep path; regenerate icons | — | Regenerates android/windows icons (those outputs owned by ReconNativeBuild). |
| pubspec.yaml:152 | `- assets/icon.png` | asset (bundle) | keep | — | |
| assets/subfont.ttf | generic subtitle font | asset | keep | — | Not brand. |
| assets/fonts/subfont.ttf | generic subtitle font | asset | keep | — | Referenced `player_settings.dart:350,351`. |
| assets/shaders/anime4k/*.glsl (40 files) | Anime4K shaders | asset | keep | — | Third-party shader pack; no brand. |
| assets/fonts/Poppins-*.ttf, PlayfairDisplay-SemiBoldItalic.ttf | fonts | asset | keep | — | No brand. |
| web/manifest.json | **0 bytes / empty** | asset | decide-in-plan | if web is ever built, populate with own name | No content to rename; nothing references it from Dart. |
| web/favicon.png, web/icons/Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png | stock Flutter web icons | asset | optional | replace images | Filenames brand-free; images may be default Flutter logo. |
| (none) | — | asset | — | — | **There are no brand-named asset files** (no `assets/logo*`, no `splash*`). |

### Layer E — incidental / test / code symbols

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| lib/main.dart:74,77,78,81,84 | `PlayTorrioApp` / `_PlayTorrioAppState` | code symbol | optional | `<Name>App` | `runApp(const PlayTorrioApp())` at :74. |
| lib/services/addon/addon_manager.dart:30,34,87,96,121,140 | `playTorrioBuiltin` / `playTorrioHttpBuiltin` | code symbol | optional | `<name>Builtin` | |
| lib/services/addon/addon_manager.dart:83,92 | `isPlayTorrioActive` / `isPlayTorrioHttpActive` | code symbol (public getters) | yes (coordinated) | `is<Name>Active` etc. | Consumers: `watch_screen.dart:280,283`, `stream_service.dart:137`. |
| lib/pages/settings/about_settings_page.dart, lib/pages/anime/…, etc. | `/// Design tokens for the PlayTorrio Reader.` and ~40 scraper doc comments `… for PlayTorrioHTTP.` | incidental (comments) | optional | comment | Collapse in one sed pass. Files: `lib/pages/books/widgets/reader_design_tokens.dart:3`, `lib/models/iptv/iptv_models.dart:3`, `lib/services/anime_arabic/anime_arabic_extractor.dart:1,475`, `lib/services/stream/stream_health_checker.dart:7`, plus every `lib/services/scraper/sites/*.dart` header listed in §"scraper table". |
| lib/services/scraper/sites/*.dart (see table below) | `String get name => 'PlayTorrioHTTP';` (1 per HTTP scraper) | internal id + user-visible | yes | `<Name>HTTP` | Registry contract — must match `stream_scraper.dart`. |
| lib/services/metadata/metadata_service.dart | no brand | incidental | keep | — | Verified absent. |
| test/** (43 files) | `import 'package:playtorrio/…'` | incidental (import) | yes | `package:<new_pkg>/…` | Mechanical; compile-blocking. Files+lines listed below. |
| lib/** (5 files) | `import 'package:playtorrio/…'` | incidental (import) | yes | `package:<new_pkg>/…` | `downloads_page.dart:4-5`, `player_screen.dart:12-16`, `subtitle_provider.dart:2`, `subtitle_service.dart:2`, `player_subtitle_menu.dart:2-3`. |
| test/audio_language_detector_test.dart:8,21,34,47,60,73,86,97,108,119,131,141,154,166,178,190,200,213,223 | `addonName: 'PlayTorrioHTTP'` (×17) and `'PlayTorrio'` (×4 at :190,200,213,223) | incidental (fixtures) | yes | new sentinel | 27 `/torrio/i` matches in this file (the single densest test). |
| test/a111477_test.dart:31,52; test/chunk1_vyla_test.dart:31,49,67,85,103; test/chunk3_vyla_test.dart:30; test/vadapav_and_stremio_scheme_test.dart:34,55; test/episodes_panel_test.dart:46,53,70; test/stream_health_checker_test.dart:82,92,105,115,125,135; test/builtin_providers_test.dart:105,114,141,147,153; test/hindmoviez_test.dart:14; test/continue_watching_source_matching_test.dart:17,18,25,26,33,34,41,42; test/widget_test.dart:19,25 | `expect(…, 'PlayTorrioHTTP')` / `addonName: 'PlayTorrioHTTP'` / `find.text('PlayTorrio')` | incidental (assertions/fixtures) | yes | new sentinel | These assertions pin the exact addon-name contract — keep them in sync with the chosen new sentinel or they will fail. |
| test/widget_test.dart:19,25 | `Text('PlayTorrio')` / `expect(find.text('PlayTorrio'), findsOneWidget)` | incidental (assertion) | yes | `<AppName>` | Pins the product name literal. |
| web/**, assets/**, bin/**, docs/** | no `/playtorrio/i` occurrences (verified twice) | incidental | keep | — | Clean. |
| analysis_options.yaml | no occurrences | incidental | keep | — | Clean. |

#### Scraper table — exact `PlayTorrioHTTP` line map (Layer C/E)

Format: `file : lines of String get name => 'PlayTorrioHTTP' ; lines of StreamSource name/addonName`.

| file (under lib/services/scraper/sites/) | name-getter line | StreamSource `name:`/`addonName:` lines |
|---|---|---|
| a111477.dart | 16 | 160 |
| bcine.dart | 15 | 145, 146, 194, 195 |
| cinejoy.dart | 20 | 394 |
| cinesrc.dart | 14 | 117, 118 |
| cinesu.dart | 14 | 118, 119 |
| downloadeverything.dart | 15 | 228, 229 |
| dulo.dart | 12 | 48, 49 |
| flaxmovies.dart | 15 | 171, 172 |
| flystream.dart | 14 | 83, 84 |
| fourkhdhub.dart | 12 | 230, 231 |
| frame.dart | 15 | 120, 121 |
| fsharetv.dart | 15 | 145, 146 |
| fsonic.dart | 14 | 135, 136 |
| fsonline.dart | 13 | 118, 119 |
| hexa.dart | 16 | 137, 138 |
| hindmoviez.dart | 14 | 864 |
| kisskh.dart | 14 | 136, 137 |
| knaben.dart | 9 (`'PlayTorrio'`) | 107, 108 |
| lmscript.dart | 15 | 78, 79 |
| lookmovie.dart | 14 | 209, 210 |
| mapple.dart | 16 | 241, 242 |
| megasource.dart | 15 | 98, 99 |
| meowtv.dart | 15 | 114, 115 |
| movienight.dart | 14 | 120, 121 |
| movy.dart | 15 | 174 |
| multiembed.dart | 10 | 132, 133 |
| nova.dart | 15 | 100, 101 |
| peestream.dart | 15 | 102, 103, 169, 170 |
| purstream.dart | 14 | 123, 124 |
| rivestream.dart | 16 | 206 |
| torrent_galaxy.dart | 10 (`'PlayTorrio'`) | 151, 152 |
| vadapav.dart | 15 | 110 |
| vidapi.dart | 15 | 103, 104 |
| vidcore.dart | 12 | 131, 132 |
| videasy.dart | 11 | 244, 245 |
| vidfast.dart | 15 | 175, 176 |
| vidgod.dart | 15 | 187, 188 |
| vidlink.dart | 15 | 85, 86, 107, 108 |
| vidrock.dart | 16 | 145, 146, 174, 175 |
| vidsrc.dart | 10 | 65, 66, 98, 99 |
| vidup.dart | 15 | 181, 182 |
| vidvault.dart | 15 | 125, 126, 153, 154, 190, 191 |
| vidzee.dart | 15 | 110, 111 |
| vixsrc.dart | 15 | 126, 127 |
| vuflix.dart | 28 | 412 |
| xdownloader.dart | 9 | 104, 105, 139, 140 |
| xpass.dart | 15 | 124, 125 |
| zxcstream.dart | 17 | 212, 213 |

Each file additionally carries a `/// … Stream Scraper for PlayTorrioHTTP.` doc comment (line 8-11 range) — incidental, optional rename.

### Layer F — `package:playtorrio` import map (compile-blocking)

**lib/ (5 files):** `lib/pages/downloads/downloads_page.dart:4-5`; `lib/pages/player/player_screen.dart:12-16`; `lib/services/subtitles/subtitle_provider.dart:2`; `lib/services/subtitles/subtitle_service.dart:2`; `lib/widgets/player/player_subtitle_menu.dart:2-3`.

**test/ (43 files, lines):** `a111477_test.dart:3`; `anime_extractors_test.dart:3-4`; `anime_smoke_test.dart:2-4`; `audio_language_detector_test.dart:2`; `chunk1_vyla_test.dart:3-7`; `chunk2_anime_vyla_test.dart:3-4`; `chunk3_vyla_test.dart:3-6`; `chunk4_anime_vyla_test.dart:3-4`; `chunk5_vyla_test.dart:3-6`; `chunk6_vyla_test.dart:3-5`; `chunk7_vyla_test.dart:3-6`; `continue_watching_source_matching_test.dart:2-4`; `download_service_test.dart:2-3`; `episodes_panel_test.dart:2-4`; `integration/my_list_flow_test.dart:3-4`; `iptv_reddit_extractor_test.dart:3-4`; `models/addon_test.dart:2`; `models/catalog_extra_test.dart:2-3`; `models/collection_addon_test.dart:2-7`; `models/movie_test.dart:2`; `models/my_list_item_test.dart:2`; `models/stream_model_test.dart:2`; `music_smoke_test.dart:2-4`; `services/builtin_providers_test.dart:3-4`; `services/cinejoy_scraper_test.dart:3`; `services/hindmoviez_test.dart:4-6`; `services/movy_scraper_test.dart:2`; `services/my_list_service_test.dart:3-4`; `services/recommendation_sliders_test.dart:2-6`; `skip_segments_test.dart:2`; `stream_health_checker_test.dart:3-4`; `subtitle_test.dart:3`; `subtitlecat_test.dart:3`; `test_in_player_anime.dart:2-4`; `test_player_error_filter.dart:2`; `utils/parse_torrent_title_test.dart:2`; `utils/relevance_scorer_test.dart:2`; `vadapav_and_stremio_scheme_test.dart:3-4`; `widget_test.dart:5-6`; `widgets/anime_details_modal_test.dart:3-4`; `widgets/anime_details_page_test.dart:3-4`; `widgets/anime_search_page_test.dart:3`; `widgets/my_list_page_test.dart:4-6`.

### Layer G — docs & manifests

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| pubspec.yaml:1 | `name: playtorrio` | package identity | yes | `<new_pkg_name>` (lower_snake_case) | Drives every `package:playtorrio/…` import (48 files, Layer F). |
| pubspec.yaml:2 | `description: "All-in-one media streaming app — … Powered by Stremio addons, torrent streaming, and the open web."` | metadata | optional | reword | Brand-free currently. |
| pubspec.yaml:24 | `version: 1.1.5+2018` | version | keep | — | Note: hardcoded fallback elsewhere is `'1.1.5'`/build `'16'` (`settings_page.dart:369-370`) — stale. |
| CONTRIBUTING.md:1 | `# Contributing to PlayTorrio V3` | doc | yes | `# Contributing to <AppName>` | |
| CONTRIBUTING.md:14 | `PlayTorrio uses a plugin architecture for stream scrapers. To add a new source:` | doc | yes | `<AppName> uses …` | |
| CONTRIBUTING.md:68 | `By contributing, you agree that your contributions will be licensed under the MIT License.` | doc (legal) | yes | correct to GPL-3.0 | **Conflicts with `LICENSE` = GPL-3.0.** Flag; coordinate with ReconAttribution. |
| CHANGELOG.md:3 | `All notable changes to PlayTorrio V3 will be documented in this file.` | doc | yes | `<AppName>` | |
| CHANGELOG.md:5 | `## [3.0.0-early] — 2026-08-11` | doc | optional | keep/rename | Version history; consider adding a fork note (attribution). |
| docs/player.md | no `/playtorrio/i` occurrences | doc | keep | — | Generic FVP guide; uses `MyApp`. |
| bin/inspect.dart | no `/playtorrio/i` occurrences | tool | keep | — | Generic UA. |
| analysis_options.yaml | no occurrences | config | keep | — | |
| web/manifest.json | empty (0 B) | asset | decide-in-plan | populate if web shipped | |

---

## 2. Migration & compatibility notes

Applies wherever the rename touches stored state, IDs, or artifact names.

1. **Package name (`pubspec.yaml:1`) — mechanical, compile-blocking.** Changing `name:` requires updating all 48 `package:playtorrio/…` imports (Layer F) and re-running `flutter pub get`/build. No runtime data impact.

2. **SharedPreferences keys — data loss if renamed naively.** Keys `playtorrio_anime_watchlist_v1`, `playtorrio_anime_history_v1`, `playtorrio_reader_settings_v3`, `playtorrio_p2p_source_enabled`, `playtorrio_p2p_warning_never_show`, `playtorrio_seen_focus_coach_v2`, and the `pt_iptv_ch_*` / `pt_iptv_chfav_*` families. Options: (a) **keep keys verbatim** (zero risk; internal-only), or (b) rename + one-shot migration that reads the old key, writes the new, removes the old. Recommend (a) unless the owner demands a clean namespace.

3. **On-disk paths — old content becomes invisible if renamed.** `playtorrio_download_tasks.json`, `playtorrio_custom_background<ext>`, and the `<AppName>/{Music,Books,CustomAudiobooks,AudiobookCovers,GeneratedAudiobooks}` app-docs dirs, plus the public `Download/PlayTorrio` folder on Android. Renaming without a scan-and-move step hides previously downloaded media and resets the download queue. If renamed, migrate at first launch.

4. **Built-in addon IDs are persisted and matched everywhere.** `builtin.playtorrio` / `builtin:playtorrio` and `builtin.playtorriohttp` / `builtin:playtorriohttp` are written into the persisted installed-addon list and compared in `addon_manager.dart`, `watch_screen.dart`, `addons_settings_page.dart`, `stream_service.dart`, `stream_scraper.dart`. Renaming the IDs without migrating stored addons will (a) make the app fail to recognise an already-stored built-in addon, (b) re-add duplicates via `_ensureBuiltInsExist` (`addon_manager.dart:29-36`), and (c) lose the user's enable/disable + priority order. Migrate the stored addon IDs, or keep the IDs and rename only the display `name`.

5. **Stored `addonName` sentinels.** Continue-watching rows and download tasks persist `'PlayTorrio'`, `'PlayTorrioHTTP'`, `'PlayTorrio Offline'`. Source-matching code compares against the same hardcoded literals (`continue_watching_service.dart:1042-1044`, `stream_service.dart:276-302`, `stream_scraper.dart:61,80-88,98,145`). Renaming the literals either breaks resume-for-old-items or requires a data migration. Safest: keep the sentinels as opaque historical values and add new-name equivalents, or migrate rows on first load.

6. **Updater / artifact names.** Asset selection is substring-based (`.apk`+arch keyword+`universal`/`release`; Windows `setup`/`install`; `.dmg`/`.appimage` etc.), so renaming CI artifact names is safe for the updater. But `app_updater_service.dart:12` points at the **upstream** repo; to receive the owner's own builds it must point at the fork. `update_dialog.dart:416,516` writes local filenames `PlayTorrio_<ver>.apk` / `PlayTorrio-<ver><ext>` — cosmetic, rename freely.

7. **User-Agent strings.** Changing them is externally visible but harmless locally. Some IPTV/Reddit/paste endpoints may key rate-limits on UA; low risk but the `/u/PlayTorrioApp` Reddit handle is upstream's and should be replaced.

8. **Discord RPC.** The application id is env-provided (`DISCORD_APP_ID`) and the asset key is `'logo'`. If the id is upstream's, presence will display the upstream application's name/icon in all viewers' Discord clients. Owner must register their own Discord app, upload an asset named `logo`, and set `DISCORD_APP_ID`; the presence strings themselves are safe to rename.

9. **GPL-3.0 attribution gap.** `lib/**` has no license/credits surface at all (`showLicensePage`/`LicenseRegistry` absent) and no in-app reference to the upstream project, though `about_settings_page.dart` presents an "About"/credits page. Under GPL-3.0 the plan should add an in-app licence/attribution section citing the upstream PlayTorrioV3 + `Copyright (C) 2026 Ayman`, and correct `CONTRIBUTING.md:68` (MIT → GPL-3.0).

10. **Android TV / Windows launcher visibility.** Nothing in this slice changes launcher visibility or package identity (that lives in `android/`, `windows/`, `installer/`). The Dart-side renames in Layers A/B/C do not affect package coexistence; only the prefs/addon-id migrations above affect user data.

---

## 3. Open questions / [UNVERIFIED]

- **[UNVERIFIED] Discord application id.** Not in the repo — resolved at runtime from `DISCORD_APP_ID` (dart-define / root `.env` / `assets/.env`), none of which are committed. Cannot confirm whether the id currently in use is upstream's. Owner must supply/confirm.
- **[UNVERIFIED] Image content of `assets/icon.png`, `web/favicon.png`, `web/icons/*.png`.** Filenames are brand-free; whether the pixels depict upstream branding was not checked (images not opened). Visual review required before shipping.
- **[UNVERIFIED] Whether the persisted installed-addon list actually stores the literal `builtin.playtorrio*` IDs** (and where). The IDs are used in all in-memory comparisons; the persistence write path in `addon_manager.dart` was not traced (file range not read). Confirm before deciding keep-vs-migrate.
- **Open:** is `web/` (empty `manifest.json`, no `index.html`) a build target at all? No `- web` target evidence found in this slice.
- **Open (decision for Main):** keep internal prefs keys / addon IDs / stored sentinels verbatim (recommended, zero data risk) vs. rename + migration. This determines ~40 rows across Layer C.
- **Note (cross-slice):** `CONTRIBUTING.md:68` states MIT while `LICENSE` is GPL-3.0 — legal inconsistency; README/LICENSE are ReconAttribution's scope but the CONTRIBUTING line is in this slice.
- **Note:** count mismatch — `builtin_providers_settings_page.dart:71` says "45" providers, `builtin_providers_settings_service.dart:31` says "46".
