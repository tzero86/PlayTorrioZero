<!-- Annex to docs/RENAME_PRODUCT_PLAN.md — exhaustive per-layer inventory.
     Generated 2026-09-14 by read-only reconnaissance over this repo's working tree.
     `path:line` references match the tree as generated; re-verify before applying edits.
     Rows marked [UNVERIFIED] or [INFERENCE] are unresolved — do not treat them as settled.
     Do not delete rows: an executing agent works this list top-to-bottom. -->

# Inventory — ATTRIBUTION / licensing / upstream provenance / external credentials

Read-only assessment. No files were modified. Every claim is cited `path:line`; legal conclusions a lawyer would need to settle are marked `[INFERENCE]`/`[UNVERIFIED]`.

Question answers up front:
- **License layout**: a single root `LICENSE` (GNU GPL v3, verbatim text) — `LICENSE:1-622`. **No** `NOTICE`, `COPYING`, `AUTHORS`, or `THIRD_PARTY*` file exists at repo root (verified by glob of `NOTICE*; COPYING*; LICENSE*; AUTHORS*; THIRD_PARTY*`).
- **Per-file copyright-header convention**: **none** in any Dart/native source. The only per-file `Copyright` headers in the repo are inside the 39 bundled Anime4K GLSL shaders under `assets/shaders/anime4k/**` (MIT, bloc97; two of them are public-domain dedications). See §1E.
- **`Copyright (C)` occurrences** outside `LICENSE`/shaders: only build-metadata placeholders — `windows/runner/Runner.rc:96` and `macos/Runner/Configs/AppInfo.xcconfig:14`, both `com.example` (not upstream, not ours).

---

## 1. Findings

Column key — `must-change`: `yes` | `optional` | `keep` (reason).

### 1A. Root docs & legal files

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| `LICENSE:4` | ` Copyright (C) 2026 Ayman` | legal / copyright | optional | Keep verbatim; **append** a second line `Copyright (C) <year> <owner>` for our modifications (GPL §5a; see §2) | Removing or replacing this line is a §4/§5a violation. |
| `LICENSE:1-2` | `GNU GENERAL PUBLIC LICENSE` / `Version 3, 29 June 2007` | legal | keep | unchanged | Full verbatim license must stay intact (§4 "give all recipients a copy of this License"). |
| `LICENSE:6-7` | `Everyone is permitted to copy and distribute verbatim copies` / `of this license document, but changing it is not allowed.` | legal | keep | unchanged | Do not edit the license body. |
| `README.md:2` | `<img src="assets/icon.png" alt="PlayTorrio" width="140"/>` | docs / brand | yes | `<new product name>` | — |
| `README.md:5` | `<h1 align="center">PlayTorrio V3</h1>` | docs / upstream name | yes (keep attribution separately) | new product name | Upstream name must still appear as provenance (see §6). |
| `README.md:13` | `<img height="20" src="https://img.shields.io/badge/GPL--3.0-4169A1?style=flat" alt="License"/>` | docs / license badge | keep | unchanged (GPL-3.0 still applies) | — |
| `README.md:21` | `PlayTorrio is a media streaming app built with Flutter.` | docs / upstream name | yes | `<NewName> is … (a fork of PlayTorrio V3 by Ayman)` | Fork disclosure belongs here. |
| `README.md:42` | `Check the [Releases](https://github.com/ayman708-UX/PlayTorrioV3/releases) page.` | docs / upstream URL | yes | point at our own releases page; keep an "upstream" link in an attribution section | Currently download instructions for our users point at the upstream author's releases. |
| `README.md:49-50` | `git clone https://github.com/ayman708-UX/PlayTorrioV3.git` / `cd PlayTorrioV3` | docs / upstream URL | yes | our repo clone URL + `<newrepo>` dir | — |
| `README.md:155` | `PlayTorrio is a media player and aggregator. It doesn't host or store any content. …` | docs / legal blurb | yes (name) | rename; keep text | — |
| `README.md:159` | `[GPL-3.0](LICENSE)` | docs / license | keep | unchanged | — |
| `README.md:164` | `Built by <a href="https://github.com/ayman708-UX">Ayman</a>` | docs / attribution | keep + extend | keep verbatim; add our line above/below (`Fork maintained by <us>`) | Mandatory upstream attribution (§5a/§7b); do not delete. |
| `CONTRIBUTING.md:1` | `# Contributing to PlayTorrio V3` | docs / upstream name | yes | `<NewName>` | — |
| `CONTRIBUTING.md:14` | `PlayTorrio uses a plugin architecture for stream scrapers. To add a new source:` | docs / upstream name | yes | `<NewName>` | — |
| `CONTRIBUTING.md:68` | `By contributing, you agree that your contributions will be licensed under the MIT License.` | legal / licence conflict | **yes (defect)** | replace with `GNU GPL v3 (see LICENSE)` | **Contradicts root GPLv3.** A MIT inbound-licence claim on GPL code is an added restriction / misrepresentation risk (GPL §5/§10). `[INFERENCE]` — a lawyer should confirm remediation wording. |
| `CHANGELOG.md:3` | `All notable changes to PlayTorrio V3 will be documented in this file.` | docs / upstream name | optional | `<NewName>` (or leave as history) | Historical entries `CHANGELOG.md:5` (`## [3.0.0-early] — 2026-08-11`) are upstream history; keep. |
| `pubspec.yaml:1` | `name: playtorrio` | package / identity | yes | `<new_package_name>` | Drives `package:playtorrio/...` imports (see 1D) and Flutter's license page identity. |
| `pubspec.yaml:2` | `description: "All-in-one media streaming app … Powered by Stremio addons, torrent streaming, and the open web."` | package / identity | optional | rename brand tokens only | No upstream name present. |
| `pubspec.yaml:10` | `version: 1.1.5+2018` | package / version | optional | decide-in-plan | Keep or bump for the fork; see §2 migration. |

### 1B. CI, packaging & installer

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| `.github/workflows/build.yml:2` | `#  PlayTorrioV3 — Multi-Platform CI/CD Release Builder` | CI comment | yes | new name | — |
| `.github/workflows/build.yml:12` | `name: Build and Release PlayTorrioV3` | CI workflow name | yes | new name | — |
| `.github/workflows/build.yml:97-101` | `PlayTorrio-Windows-Setup.exe` (×4, lines 97,98,99,101) | CI artifact name | yes | `<NewName>-Windows-Setup.exe` | Must stay in sync with `setup.iss:26` OutputBaseFilename. |
| `.github/workflows/build.yml:107` | `PlayTorrio-Windows-x64-Portable.zip` | CI artifact name | yes | renamed | — |
| `.github/workflows/build.yml:112-115` | `PlayTorrioV3-Windows` (artifact name) + paths `PlayTorrio-Windows-Setup.exe`, `PlayTorrio-Windows-x64-Portable.zip` | CI artifact name | yes | renamed | **Updater coupling**: `app_updater_service.dart:_findWindowsAsset` matches on substrings (`setup`/`install`) — renaming is safe there, but the update *repo* must change (§5). |
| `.github/workflows/build.yml:174-199` | `APP=PlayTorrio.AppDir`; `PlayTorrio.png`; `PlayTorrio.desktop`; `Name=PlayTorrio`; `Icon=PlayTorrio`; `exec ./playtorrio`; `PlayTorrio-Linux-x86_64.AppImage`; `PlayTorrio-Linux-x86_64.tar.gz` | CI / Linux bundle | yes | renamed (exec name follows `linux/CMakeLists.txt:7` BINARY_NAME) | — |
| `.github/workflows/build.yml:204-207` | `PlayTorrioV3-Linux-x64` + `PlayTorrio-Linux-*` | CI artifact | yes | renamed | — |
| `.github/workflows/build.yml:250,252,255,262,264` | `mv playtorrio.app PlayTorrio.app`; `codesign … PlayTorrio.app`; `hdiutil create -volname "PlayTorrio"`; `PlayTorrio-macOS-arm64.dmg/.zip` | CI / macOS bundle | yes | renamed (source name follows `macos/…/AppInfo.xcconfig:8`) | — |
| `.github/workflows/build.yml:269-272` | `PlayTorrioV3-macOS-arm64` + `PlayTorrio-macOS-arm64.dmg/.zip` | CI artifact | yes | renamed | macOS asset match in updater keys on `mac`/`darwin`/`.dmg` — unaffected. |
| `.github/workflows/build.yml:313,315,318,325,327,332-335` | same pattern for `macos-intel` | CI / macOS bundle | yes | renamed | — |
| `.github/workflows/build.yml:374,379-380` | `zip -ry ../../../PlayTorrio-iOS.ipa Payload`; `PlayTorrioV3-iOS`; `PlayTorrio-iOS.ipa` | CI artifact | yes | renamed | — |
| `.github/workflows/build.yml:399` | `name: "PlayTorrio ${{ github.ref_name }}"` | CI release title | yes | `<NewName> ${{ github.ref_name }}` | Release is where the **GPL §6 source-offer** must live; currently `draft: true`, no source link. |
| `.github/workflows/build.yml:43-49, 148-154` | `echo "${{ secrets.ENV_FILE }}" > .env` … | CI / secrets injection | keep | unchanged | Injects runtime secrets (Trakt/Simkl/Discord/keys) into builds — provenance of those values is upstream's (§5). |
| `installer/windows/setup.iss:2` | `;  PlayTorrio — Windows Installer (Inno Setup 6)` | installer | yes | new name | — |
| `installer/windows/setup.iss:6` | `#define MyAppName      "PlayTorrio"` | installer / product name | yes | `<NewName>` | Drives install dir + shortcuts (`DefaultDirName`, `Icons`). |
| `installer/windows/setup.iss:10` | `#define MyAppPublisher "ayman708-UX"` | installer / publisher | yes | our vendor id | — |
| `installer/windows/setup.iss:11` | `#define MyAppExeName   "playtorrio.exe"` | installer / exe name | yes | `<newname>.exe` (match `windows/CMakeLists.txt:7`) | Must match the actual built binary or uninstall/launch breaks. |
| `installer/windows/setup.iss:12` | `#define MyAppURL       "https://github.com/ayman708-UX/PlayTorrioV3"` | installer / upstream URL | yes | our repo URL; keep upstream URL only inside the attribution text | Also feeds `AppPublisherURL`/`AppSupportURL` (lines 20-21). |
| `installer/windows/setup.iss:26` | `OutputBaseFilename=PlayTorrio-Windows-Setup` | installer / artifact | yes | rename (keep in sync with CI lines 97-115) | — |
| `installer/windows/setup.iss:15` | `AppId={{9B8C7D6E-5F4E-3D2C-1B0A-9F8E7D6C5B4A}` | installer / upgrade GUID | **keep** | unchanged | AppId is the install-identity GUID; changing it orphans existing installs / breaks uninstall-upgrade. |

### 1C. Native platform identity (copyright / product strings)

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| `windows/runner/Runner.rc:96` | `VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved."` | native / copyright metadata | **yes** | `Copyright (C) 2026 <owner>; portions Copyright (C) 2026 Ayman (PlayTorrio V3, GPLv3)` | Placeholder today; this is the natural home for the GPL modification notice on Windows. |
| `windows/runner/Runner.rc:92` | `VALUE "CompanyName", "com.example"` | native / metadata | yes | our vendor | — |
| `windows/runner/Runner.rc:93` | `VALUE "FileDescription", "playtorrio"` | native / metadata | yes | `<NewName>` | — |
| `windows/runner/Runner.rc:95` | `VALUE "InternalName", "playtorrio"` | native / metadata | yes | `<newname>` | — |
| `windows/runner/Runner.rc:97` | `VALUE "OriginalFilename", "playtorrio.exe"` | native / metadata | yes | `<newname>.exe` | Must match BINARY_NAME. |
| `windows/runner/Runner.rc:98` | `VALUE "ProductName", "playtorrio"` | native / metadata | yes | `<NewName>` | — |
| `windows/CMakeLists.txt:3` | `project(playtorrio LANGUAGES CXX)` | native / build | yes | `<newname>` | — |
| `windows/CMakeLists.txt:7` | `set(BINARY_NAME "playtorrio")` | native / build | yes | `<newname>` | Changes produced `*.exe` name; must match installer + CI. |
| `windows/runner/main.cpp:49` | `if (!window.Create(L"playtorrio", origin, size)) {` | native / window title | yes | `<NewName>` | Visible window title. |
| `macos/Runner/Configs/AppInfo.xcconfig:14` | `PRODUCT_COPYRIGHT = Copyright © 2026 com.example. All rights reserved.` | native / copyright metadata | **yes** | our copyright + upstream notice | Placeholder today; macOS GPL notice home. |
| `macos/Runner/Configs/AppInfo.xcconfig:8` | `PRODUCT_NAME = playtorrio` | native / build | yes | `<newname>` | Drives `playtorrio.app` bundle name referenced throughout `project.pbxproj` + CI. |
| `macos/Runner/Configs/AppInfo.xcconfig:11` | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio` | native / bundle id | yes | `com.<vendor>.<name>` (shape) | Coexistence with an already-installed copy: see §7. |
| `macos/Runner.xcodeproj/project.pbxproj:67,134,220,391,405,419` | `playtorrio.app` / `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/playtorrio.app/…"` | native / build | yes | rename consistently | Mechanical; must accompany AppInfo.xcconfig rename. |
| `macos/Runner.xcodeproj/project.pbxproj:388,402,416` | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio.RunnerTests` | native / test bundle | yes | `com.<vendor>.<name>.RunnerTests` | — |
| `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme:18,34,69,86` | `BuildableName = "playtorrio.app"` | native / scheme | yes | rename consistently | — |
| `ios/Runner/Info.plist:25` | `<string>Playtorrio</string>` (`CFBundleDisplayName`) | native / display name | yes | `<NewName>` | — |
| `ios/Runner/Info.plist:33` | `<string>playtorrio</string>` (`CFBundleName`) | native / bundle name | yes | `<newname>` | — |
| `ios/Runner/Info.plist:13` | `<string>PlayTorrio streams video and audio from local network services and torrent streaming engines.</string>` (`NSLocalNetworkUsageDescription`) | native / user-visible | yes | `<NewName> streams …` | Shown in iOS permission prompt. |
| `ios/Runner.xcodeproj/project.pbxproj:375,554,576` | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio;` | native / bundle id | yes | `com.<vendor>.<name>` | — |
| `ios/Runner.xcodeproj/project.pbxproj:391,408,423` | `com.example.playtorrio.RunnerTests` | native / test bundle | yes | renamed | — |
| `linux/CMakeLists.txt:7,10` | `set(BINARY_NAME "playtorrio")` / `set(APPLICATION_ID "com.example.playtorrio")` | native / build | yes | `<newname>` / `com.<vendor>.<name>` | — |
| `linux/runner/my_application.cc:48,52` | `gtk_header_bar_set_title(header_bar, "playtorrio")` / `gtk_window_set_title(window, "playtorrio")` | native / window title | yes | `<NewName>` | — |
| `android/app/src/main/AndroidManifest.xml:29` | `android:label="playtorrio"` | native / launcher label | yes | `<NewName>` | **TV launcher visibility** lives here + the LEANBACK intent-filter below; renaming the label is safe, do not touch the filters. |
| `android/app/build.gradle.kts:9` | `namespace = "com.example.playtorrio"` | native / namespace | yes | `com.<vendor>.<name>` | Kotlin package dir `android/app/src/main/kotlin/com/example/playtorrio/` must move in lockstep. |
| `android/app/build.gradle.kts:24` | `applicationId = "com.example.playtorrio"` | native / app id | yes | `com.<vendor>.<name>` | **Coexistence**: new applicationId ⇒ installs alongside the existing app (no data migration; see §7). |
| `android/app/src/main/kotlin/com/example/playtorrio/MainActivity.kt:1` | `package com.example.playtorrio` | native / package | yes | `com.<vendor>.<name>` | — |
| `android/app/src/main/kotlin/com/example/playtorrio/MainActivity.kt:12` | `private val CHANNEL = "com.example.playtorrio/power"` | native / method channel | yes | renamed (keep Dart side in sync if referenced) | `[UNVERIFIED]` whether any Dart code references this channel string by literal — grep of `lib` found none. |
| `android/app/src/main/kotlin/com/example/playtorrio/MainActivity.kt:31,42` | `"playtorrio:stream_wifi"` / `"playtorrio:stream_wake"` | native / wake-lock tags | optional | renamed | Cosmetic; tags are process-local. |

### 1D. Dart source — upstream name embedded in code/UI/state

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| `lib/main.dart:74,77,78,81,84` | `runApp(const PlayTorrioApp());` / `class PlayTorrioApp …` / `const PlayTorrioApp({super.key});` / `State<PlayTorrioApp> createState()` / `class _PlayTorrioAppState …` | lib / class names | yes | `<NewName>App` etc. | Mechanical; `main.dart:74` is the call site. |
| `lib/main.dart:144` | `title: 'PlayTorrio',` | lib / MaterialApp title | yes | `<NewName>` | Desktop window/app title. |
| `lib/services/addon/addon_manager.dart:125,126,127` | `name: 'PlayTorrio',` / `version: '3.0.0',` / `description: 'Built-in BitTorrent P2P streaming engine (TorrServer). …'` | lib / built-in addon manifest | yes (name) | `<NewName>` | Manifest is synthesized in-app; not a remote service. |
| `lib/services/addon/addon_manager.dart:144,145,146` | `name: 'PlayTorrioHTTP',` / `version: '3.0.0',` / `description: 'Built-in fast HTTP stream scrapers (111477, Cinejoy, Vuflix, …)'` | lib / built-in addon manifest | yes (name) | `<NewName>HTTP` | Rename must be applied atomically with the addon **id** below. |
| `lib/services/addon/addon_manager.dart:29,33,86,95,121-124,140-143` | `'builtin.playtorrio'`, `'builtin:playtorrio'`, `'builtin.playtorriohttp'`, `'builtin:playtorriohttp'` | lib / addon ids | **yes (with migration)** | `builtin.<newname>` / `builtin:<newname>` | **Persisted in SharedPreferences** (installed addons list). Changing these ids without migration orphans a user's existing install; see §7. |
| `lib/services/addon/addon_manager.dart:83,92,105-107` | `isPlayTorrioActive`, `isPlayTorrioHttpActive`, `nameLower == 'playtorrio'` | lib / API + matching | yes | `<NewName>` variants | Callers: `lib/pages/player/watch_screen.dart:280,283,292,2968`. |
| `lib/pages/player/watch_screen.dart:110,113` | `a.manifest.id == 'builtin.playtorriohttp'` / `'builtin.playtorrio'` | lib / id matching | yes (atomic) | renamed | Must match addon_manager ids. |
| `lib/pages/player/watch_screen.dart:280,283,292,2968-2971` | `isPlayTorrioActive` / `'playtorriohttp'` / `'PlayTorrioHTTP · ${s.providerName}'` | lib / UI + logic | yes | renamed | `:2971` is user-visible label. |
| `lib/pages/player/watch_screen.dart:3076-3077` | `nameLower == 'playtorrio' || nameLower == 'playtorriohttp'` | lib / built-in detection | yes (atomic) | renamed | — |
| `lib/pages/settings/addons_settings_page.dart:159-160,412-413` | `addon.manifest.id == 'builtin.playtorrio'` / `'builtin.playtorriohttp'` | lib / id matching | yes (atomic) | renamed | — |
| `lib/pages/settings/settings_page.dart:367,368` | `appName: 'PlayTorrio',` / `packageName: 'com.playtorrio',` | lib / PackageInfo fallback | yes | `<NewName>` / `com.<vendor>.<name>` | Fallback used only if `PackageInfo.fromPlatform()` throws. Note `com.playtorrio` ≠ Android `com.example.playtorrio` — already inconsistent. |
| `lib/pages/settings/settings_page.dart:577,590,603,614-615,805,809` | `'PlayTorrioHTTP streaming sources…'`, `'PlayTorrio torrent swarms …'`, `'About PlayTorrio'`, `'…Using only direct HTTP streaming (PlayTorrioHTTP)'` | lib / UI strings | yes | renamed | `:805-811` is the tile that opens the About page (see §4). |
| `lib/pages/settings/about_settings_page.dart:19` | `'About PlayTorrio'` | lib / UI | yes | `About <NewName>` | Page title. |
| `lib/pages/settings/about_settings_page.dart:59` | `'PlayTorrio'` | lib / UI brand | yes | `<NewName>` | — |
| `lib/pages/settings/about_settings_page.dart:111` | `'PlayTorrio is an all-in-one entertainment client bringing together …'` | lib / UI description | yes | rename + add provenance sentence | **Candidate home for the attribution block** (see §4). |
| `lib/pages/settings/updates_settings_page.dart:35,86,101` | `'PlayTorrio is up to date!'` / `'Keep PlayTorrio up to date …'` / `appName: 'PlayTorrio'` | lib / UI strings | yes | renamed | — |
| `lib/pages/settings/builtin_providers_settings_page.dart:71,387,399` | `'…restore all 45 PlayTorrioHTTP providers…'` / `'All $totalCount PlayTorrioHTTP providers are active…'` / `'…PlayTorrio uses its native multi-source streaming engine…'` | lib / UI strings | yes | renamed | — |
| `lib/pages/settings/debrid_settings_page.dart:372,419` | `'…all torrents from PlayTorrio and Stremio addons…'` / `'PlayTorrio will send requests to this provider when streaming.'` | lib / UI strings | yes | renamed (keep "Stremio") | — |
| `lib/pages/anime/anime_page.dart:626` | `text: 'PlayTorrio ',` | lib / UI brand | yes | `<NewName> ` | — |
| `lib/pages/home/home_page.dart:815,995` | `'PlayTorrio',` | lib / UI brand | yes | `<NewName>` | Two separate header renderings. |
| `lib/services/p2p/p2p_settings_service.dart:12-13` | `/// Whether the built-in P2P torrent source ('PlayTorrio') is enabled.` / `…only direct HTTP streaming ('PlayTorrioHTTP') and external addons are used.` | lib / docs | yes | renamed | Comments only. |
| `lib/models/download/download_task_model.dart:137` | `addonName: 'PlayTorrio Offline',` | lib / persisted value | optional | `<NewName> Offline` | Persisted inside download-task JSON; changing it only affects newly created tasks (legacy rows keep old string). See §7. |
[…55ln elided…]

---

## 4. Third-party components and their license obligations

### 4a. Declared dependencies (`pubspec.yaml` / `pubspec.lock`)

Copyleft-capable vs attribution-only is `[INFERENCE]` where the license text is not vendored in this repo — verify each on pub.dev/the upstream repo before shipping.

| dependency | version | source / path | likely license class | attribution/source obligation | `path:line` |
|---|---|---|---|---|---|
| `torrserver_flutter` | 0.0.6 | pub.dev (`pubspec.lock:950-956`) | `[UNVERIFIED]` (TorrServer is MIT upstream; plugin wrapper unknown) | Ships native `libtorrserver.so` inside builds (see 4b) → keep its notice. | `pubspec.yaml:33` |
| `media_kit`, `media_kit_video`, `media_kit_libs_*` | git `Predidit/media-kit` @`11d02cb8…` / resolved `994465d9…` | git fork of **mad-skills/media_kit** (Predidit) | media_kit is MIT; bundles **libmpv/mpv** (LGPL-2.1+ / GPL depending on build) and **FFmpeg** (LGPL/GPL) → `[UNVERIFIED]` which build | Must ship mpv/FFmpeg notices + their source offer; media_kit itself is attribution-only. | `pubspec.yaml:35-49`, `dependency_overrides:64-95` |
| `pdfrx` | 2.4.7 | pub.dev | MIT wrapper over **PDFium** (BSD-3) | Bundles `libpdfium.so` in builds → keep PDFium BSD notice. | `pubspec.yaml:62` |
| `dart_discord_presence` | 1.2.0 | pub.dev | MIT `[UNVERIFIED]` | attribution-only. | `pubspec.yaml:72` |
| `cupertino_icons` | 1.0.8 | pub.dev | MIT | attribution-only (icon font). | `pubspec.yaml:28` |
| `html`, `http`, `xml`, `archive`, `crypto`, `pointycastle`, `shared_preferences`, `path_provider`, `path`, `url_launcher`, `cached_network_image`, `photo_view`, `file_picker`, `flutter_widget_from_html_core`, `dart_mobi`, `fb2_parse`, `otp_update` (`ota_update`) | per `pubspec.yaml:29-71` | pub.dev | MIT/BSD, attribution-only | Keep pub licenses page (Flutter auto-NOTICES). | `pubspec.yaml:29-71` |
| `liquid_glass_easy` | 4.1.1 | pub.dev | `[UNVERIFIED]` (ships GLSL shaders) | attribution-only, but verify shader license. | `pubspec.yaml:60` |
| `window_manager`, `wakelock_plus`, `package_info_plus` | per `pubspec.lock` | pub.dev | BSD/MIT | attribution-only. | `pubspec.yaml:63,65` |

### 4b. Bundled native binaries (shipped, not downloaded at runtime)

There is **no in-repo `bin/` binary, no `assets/**/*.exe|dll|so|zip`, and no first-run downloader** for torrserver/ffmpeg/mpv. Grep of `lib/**`, `installer/**`, `assets/**` for `torrserver|ffmpeg|ffprobe|libtorrent|mpv` returns only *code references and comments*, never a downloader or URL. The binaries are produced at build time by the native plugins and land in `build/`:

| artifact | built from | evidence | obligation |
|---|---|---|---|
| `libtorrserver.so` (android arm64/armeabi/x86/x86_64) | `torrserver_flutter` 0.0.6 | `build/app/intermediates/…/libtorrserver.so` (x4 ABIs); plugin registered at `windows/flutter/generated_plugin_registrant.cc:12,23-24`, `windows/flutter/generated_plugins.cmake:9` | TorrServer's own license/notice must ship with the app. `[UNVERIFIED]` in-repo (no license file bundled). |
| `libmpv.so`, `libmediakitandroidhelper.so` | `media_kit_libs_*` (git fork) | `build/app/intermediates/…/libmpv.so`, `libmediakitandroidhelper.so`; `pubspec.lock:511-519` | mpv is LGPL-2.1+/GPL; the shipping build's corresponding source offer is required. |
| `libpdfium.so` | `pdfrx` | `build/app/intermediates/…/libpdfium.so` | PDFium BSD-3 notice. |
| Windows: `mpv-*.dll`/`dartjni`/etc. | `media_kit_libs_windows_video` 1.0.11 | plugin in `windows/flutter/generated_plugins.cmake`; `[UNVERIFIED]` exact dll set (only android build intermediates were present) | same as above. |

**Download-at-runtime logic**: none found for media engines. The only runtime downloads are (a) content/streams, and (b) **OTA self-updates** from GitHub Releases (`lib/services/updater/app_updater_service.dart:49-53`) — see §5. TorrServer runs as a **local loopback HTTP server** started in-process (`lib/services/stream/torrent_stream_service.dart:42-91`; `_controller.baseUrl`); it is not fetched over the network. `[UNVERIFIED]` whether `torrserver_flutter` extracts an embedded binary on first run — its `.so` is present in build output, so treat it as **shipped**.

### 4c. Fonts, icons and art assets

| asset | provenance | obligation | `path:line` |
|---|---|---|---|
| `assets/fonts/Poppins-{Regular,Medium,SemiBold,Bold}.ttf` | Google Fonts — Poppins | **SIL OFL 1.1** — requires shipping the OFL notice; **no font license file is bundled** → unmet. | `pubspec.yaml:110-121` |
| `assets/fonts/PlayfairDisplay-SemiBoldItalic.ttf` | Google Fonts — Playfair Display | SIL OFL 1.1 — same unmet notice requirement. | `pubspec.yaml:122-127` |
| `assets/subfont.ttf` (+ `assets/fonts/subfont.ttf`) | subtitle fallback font, referenced as bundled fallback for libass | `[UNVERIFIED]` origin/license; `docs/player.md` ("bundle a fallback font (`subfont.ttf`)") treats it as required for subtitle rendering | `pubspec.yaml:104` |
| `assets/icon.png` | app icon (upstream) | upstream brand asset; will be replaced on rebrand — but the *upstream* icon is upstream's, so if reused it is subject to upstream's GPLv3 (fine). | `pubspec.yaml:103` |
| `assets/shaders/anime4k/**` (39 `.glsl`) | **Anime4K** by bloc97 | MIT / public-domain — headers **are** present in-file (see §1E). Attribution satisfied. | `pubspec.yaml:106` |
| Material Icons font | Flutter SDK (`uses-material-design: true`) | Apache-2.0 — covered by Flutter's auto `NOTICES`. | `pubspec.yaml:99` |
| `docs/player.md` | describes `fvp`/`libmdk` (wang-bin) decoder tuning | **Stale/misleading**: `fvp` is **not** a dependency (`pubspec.yaml` uses `media_kit`); this doc references an engine the app does not use. Not an attribution defect, but should be corrected or removed. | `docs/player.md:1-3` |

---

## 5. In-app attribution surfaces

### 5a. What exists today

- **No** `showLicensePage`, `LicenseRegistry`, `LicensePage`, `showAboutDialog`, or `AboutListTile` usage anywhere in `lib/**` (grep is empty). Flutter's auto-generated license page is therefore **never shown**.
- The only "About" surface is `lib/pages/settings/about_settings_page.dart`, reached from `lib/pages/settings/settings_page.dart:805-811` (tile titled `'About PlayTorrio'`, subtitle `'Architecture, video engine, and credits'`).
- That page shows: brand header `PlayTorrio` (`:59`), a `PackageInfo` version line (`:68-84`, fallback `'1.1.5'`), a description card (`:111`), and four `_buildTechTile` entries (`:136-154`). **It contains no license, no copyright, and no upstream credit** — despite the settings tile promising "credits".
- The version string is also shown at `lib/pages/settings/updates_settings_page.dart:96-146` (uses `PackageInfo.fromPlatform()`, fallback `appName: 'PlayTorrio'`).
- Because Flutter's `LicenseRegistry` aggregates each dependency's license into a generated `NOTICES` asset (present at `build/flutter_assets/NOTICES.Z` etc.), a one-line `showLicensePage`/`LicenseRegistry` call would surface all package licenses automatically — but it would still show the **app package's own** name from `pubspec.yaml:1`, which is why the two renames must be coordinated.

### 5b. Exact insertion point for the attribution block

**Primary (required):** `lib/pages/settings/about_settings_page.dart` — inside the `ListView(children: [...])`, which opens at `:28` and closes at `:155` (`            ],`). The final child is the `_buildTechTile(...)` ending at `:154` (tile `'Trakt & Cloud Synchronization'`, `:151-154`).

> **Insert after line `154` and before line `155`** a new attribution card/widget, e.g.:
> `Based on PlayTorrio V3 by Ayman — GPLv3 — source: https://github.com/ayman708-UX/PlayTorrioV3` plus our own copyright line.

The `_buildTechTile` helper (`:162-215`) is a reusable pattern for a matching-styled card; a parallel `_buildAttributionTile` (or an inline `Container` in the same card style) drops in cleanly.

**Secondary (recommended):** add the same text as a non-editable line under the version at `lib/pages/settings/updates_settings_page.dart:144-146`, and add a `showLicensePage(context, applicationName: '<NewName>', applicationVersion: version, applicationLegalese: '… GPLv3 — based on PlayTorrio V3 by Ayman …')` entry point (new tile) — `applicationLegalese` is the mechanism Flutter provides for exactly this notice.

**Durability requirement:** GPL §4 requires these notices to be *kept intact* on redistribution. The attribution block must therefore be a **hard-coded, non-removable, non-configurable** UI element — not behind a settings toggle, not fetched from a remote (which could 404), and not stripped by a build flag. If a §7b term is adopted, it belongs in `LICENSE`/`NOTICE` alongside this.

---

## 6. Externally-owned identifiers we inherit as guests

| path:line | what it is | owner | rename-impact |
|---|---|---|---|
| `lib/services/updater/app_updater_service.dart:12` | `static const String githubRepo = 'ayman708-UX/PlayTorrioV3';` | **upstream author** | **replace with our own** — the app currently checks upstream's releases and will offer/download *upstream's* binaries to *our* users after rebrand. |
| `lib/services/updater/app_updater_service.dart:13-14` | `'https://api.github.com/repos/$githubRepo/releases/latest'` | **upstream author** | derived from `:12`; repoint. |
| `lib/widgets/updater/update_dialog.dart` (whole file) | update UI consuming `AppUpdaterService`; macOS/iOS redirect to "GitHub" | upstream runtime | keep UI; inherits `:12` fix. |
| `lib/services/discord/discord_rpc_service.dart:88` (app id) + `lib/services/config/env_service.dart:94-98` | Discord app id from `DISCORD_APP_ID` dart-define/`.env` | **upstream's Discord application** | **replace with our own app**; the `'logo'` asset key (`discord_rpc_service.dart:26`) and the "PlayTorrioV3" asset hover text are registered on the **upstream app** and will be wrong/absent under ours. `[UNVERIFIED]`: the actual app id is not in-repo (supplied via CI secret). |
| `lib/services/metadata/tmdb_service.dart` (`builtInKey`) | the whole inherited TMDB key, now in exactly one place | **upstream's TMDB account** | **last-resort fallback only.** Precedence is the user's own key (Settings > TMDB, BYOK), then a build-time `TMDB_API_KEY`, then this value, so keyless installs behave exactly as before. Inheriting it is still an unauthorised use of a third-party credential and can be rate-limited or revoked: rotate it on the upstream account if reachable, otherwise pass a replacement at build time. Note it was verified still live, and it has been published in this public repo since the v1.1.2 era. |
| `lib/services/scraper/sites/tmdb_helper.dart` (`_tmdbProxy`) | the upstream host is no longer a constant; it comes from `TMDB_PROXY_BASE` and defaults to none | **upstream-operated proxy host** | **defaulted off.** No request reaches that host unless the owner names their own. |
| `lib/services/scraper/sites/videasy.dart:13` | same TMDB key, spliced into the URL inline | upstream's TMDB account | **migrated.** The local constant is gone; the site reads `TmdbService.scraperKey` like the other four. |
| `lib/services/scraper/sites/videasy.dart` (`_apiBase`) | host now read from `VIDEASY_API_BASE`, with no default | upstream-operated host | **defaulted off.** The scraper contributes nothing until the owner points it at their own deployment. |
| `lib/services/audiobook/audiobook_scraper_service.dart` (`ServiceCredential.audiobookSearch`) | an Audionest Firebase client key, no longer inlined | **a third-party service's credential, not upstream's account** | **made configurable.** Supply `AUDIOBOOK_SEARCH_KEY` or leave that source off; the service never issued this key to ZPlay. |
| `lib/services/subtitles/providers/wyzie_provider.dart` (`ServiceCredential.wyzie`) | moved into the credential registry | **a third-party service's key** | **now user-configurable.** Wyzie issues free keys at store.wyzie.io/redeem and forbids shipping one inside an app. |
| `lib/services/debrid/providers/alldebrid_service.dart:39` | `agent=${EnvService.alldebridAgent}` | AllDebrid expects an `agent` id | **done:** the upstream name is gone; the value comes from `ALLDEBRID_AGENT` and defaults to `ZPlay`. Register the agent id with AllDebrid as their terms require. |
| `lib/services/simkl/simkl_constants.dart:11-12` | `kSimklAppName` now resolves through `EnvService.simklAppName`; `simkl_service.dart` sends it as the User-Agent | **another project's identity, removed** | **done:** the default is `ZPlay` and the name comes from `SIMKL_APP_NAME`. A Simkl `client_id` still belongs to whoever registered it, so register your own. |
| `lib/services/config/env_service.dart:82-98` | `TRAKT_CLIENT_ID`/`SECRET`, `SIMKL_CLIENT_ID`/`SECRET`, `DISCORD_APP_ID` getters | upstream's registered OAuth apps | replace via our own `.env` / CI secret; values are **not in-repo** (`[UNVERIFIED]`). |
| `lib/services/trakt/trakt_constants.dart:8-14`, `lib/services/simkl/simkl_constants.dart:8-20` | API bases `api.trakt.tv`, `api.simkl.com`, `data.simkl.in`, PIN URLs | third-party services | keep (public service endpoints) — only the client ids change. |
| `lib/services/addon/addon_manager.dart:183` | `await addAddon('https://v3-cinemeta.strem.io');` | **Stremio/Cinemeta** (third party, public) | keep — third-party public addon, not upstream-owned. Do not rename. |
| `lib/services/metadata/metadata_service.dart:71,104,182,260,358`; `lib/pages/calendar/tv_calendar_page.dart:168`; `lib/pages/my_list/my_list_page.dart:80`; `lib/pages/player/watch_screen.dart:2896`; `lib/services/home/home_page_settings.dart:361,372,531,542,589,600` | `'https://v3-cinemeta.strem.io'` fallback metadata host | Stremio/Cinemeta | keep. |
| `lib/services/subtitles/providers/opensubtitles_provider.dart:13-15` | `'https://opensubtitles.stremio.homes'`, `'https://opensubtitles-v3.strem.io'`, `'https://opensubtitles.strem.io'` | Stremio community hosts | keep. |
| `lib/services/subtitles/providers/subdl_provider.dart:13-14` | `https://subdl.com` / `https://api3.subdl.com` | Subdl | keep. |
| `lib/services/subtitles/providers/stremio_subtitle_provider.dart` | reads user-installed Stremio addons | Stremio protocol | keep. |
| `lib/services/anime/anilist_service.dart:11,61-62` | `https://graphql.anilist.co` (+ `Origin`/`Referer: https://anilist.co`) | AniList | keep. |
| `lib/services/anime/extractors/*.dart` (e.g. `anidb_extractor.dart:35`, `anihq_extractor.dart:28`, `anineko_extractor.dart:29`, `anipm_extractor.dart:28`, `hentaini_extractor.dart:23-24`, `luna_extractor.dart:31,89,118`) | third-party streaming sites (`anidb.app`, `anihq.cc`, `anineko.to`, `ani.pm`, `hentaini.com`, `luna-stream.me`) | third parties | keep (content sources; unaffiliated). |
| `lib/models/book/book_result.dart:115,124` | `https://api.bookracy.com/…` | Bookracy | keep. |
| `lib/models/my_list/my_list_item.dart:141,157-158` | `https://images.metahub.space/…`, `https://simkl.in/posters/…` | MetaHub / Simkl | keep. |
| `lib/services/ai/wewatch_service.dart:18` | `https://image.tmdb.org/t/p/w500$posterPath` | TMDB CDN | keep. |
| `lib/services/subtitles/subtitlecat_service.dart:37,416`; `subtitlecat_provider.dart:14-16` | `https://www.subtitlecat.com`, `translate.googleapis.com/translate_a/single?client=gtx` | third parties | keep. |
| `lib/services/iptv/hardcoded_channels.dart:860` (+ many similar) | `https://shahid.mbc.net/mediaObject/…` channel logos | third-party broadcasters | optional — inherited channel list; verify each logo's usage rights if you keep them. `[INFERENCE]` |
| `lib/services/scraper/sites/vadapav.dart:11-17`, `megasource.dart:11-12`, `nova.dart:11-12` | `stremio.vadapav.mov`, `megasource.wasmer.app`, `nova-streamz.vercel.app` | third parties (Vyla-derived ports) | keep; preserve porting credits. |
| `lib/services/anime_arabic/mega_proxy.dart:79-83` | local loopback proxy server (runtime port) | us | keep. |
| `lib/services/stream/torrent_stream_service.dart:42-91` | local TorrServer loopback HTTP server | us (in-process) | keep. |

---

## 7. What must NOT be renamed

Keep these **verbatim** — they are upstream's identity and/or third-party names, and GPL requires the upstream ones survive:

1. **Author name / handle**: `Ayman`, `ayman708-UX` — `README.md:164`, `LICENSE:4`, `installer/windows/setup.iss:10,12`. Removing them defeats §5a/§7b attribution.
2. **Upstream copyright line**: ` Copyright (C) 2026 Ayman` — `LICENSE:4`.
3. **Upstream repository URL** (as a provenance link, even after downloads are repointed): `https://github.com/ayman708-UX/PlayTorrioV3` — `README.md:42,49`, `installer/windows/setup.iss:12`, `lib/services/updater/app_updater_service.dart:12` (retain the old value *somewhere*, e.g. in an attribution/credits string, before repointing the updater).
4. **GPL license text**: `LICENSE:1-622` byte-for-byte; and the `GPL-3.0` link/badge `README.md:13,159`.
5. **Third-party product names**: `Stremio`, `Cinemeta`, `AniList`, `MyAnimeList`, `TorrServer`, `libtorrent`, `FFmpeg`, `MPV`/`libmpv`, `libmdk`/`fvp`, `Anime4K`, `Subdl`, `OpenSubtitles`, `Trakt`, `Simkl`, `AllDebrid`, `Real-Debrid`, `TorBox`, `Premiumize`, `Debrid-Link`, `TMDB`, `WeebCentral`, `Octave`, `Bookracy`, `Wyzie`, `PDFium`, `Poppins`, `Playfair Display`. These appear in UI and comments (e.g. `about_settings_page.dart:138,143`, `watch_screen.dart`, `debrid_service.dart:64-73`).
6. **Third-party addon/manifest ids** that are not ours: `com.linvo.cinemeta` — `addon_manager.dart:185,555`.
7. **Third-party license notices already embedded**: Anime4K shader headers (`assets/shaders/anime4k/*.glsl:1-22`) — MIT/CC0 text must stay.
8. **Upstream porting credits in comments**: `lib/models/iptv/iptv_models.dart:3` (`ported from PlayTorrio TV IPTV system`), `lib/services/scraper/sites/a111477.dart:9`, `megasource.dart:11`, `nova.dart:11`.
9. **Service endpoints** owned by third parties (Stremio/Cinemeta/AniList/Subdl/Trakt/Simkl bases) — renaming them would break the app; they are guests, not our brand.
10. **Standard/technical identifiers** unrelated to branding: magnet/infohash formats, `tt`/`tmdb:`/`kitsu:`/`mal:` id prefixes, `stremio://` URI scheme (`addon_manager.dart:256-260`, `watch_screen.dart:2881-2884`).

---

## 8. Open questions / [UNVERIFIED]

1. **Recon tooling note (resolved).** This report was produced by a read-only agent that had no write tool; it has since been persisted verbatim as `docs/rename/inventory-attribution.md` (not `build/…`). Line numbers match the working tree at generation time — re-verify before applying edits.
2. **`[UNVERIFIED]` bundled-binary licenses.** No license/notice file is vendored for `torrserver_flutter`, `media_kit`/libmpv, FFmpeg, or PDFium. Their concrete license terms and required notices must be read from each package at build time. `[INFERENCE]` mpv/FFmpeg shipping builds may be **GPL** (not merely LGPL) depending on compile flags — which would tighten §6 obligations.
3. **`[UNVERIFIED]` `.env` / CI secret values.** `EnvService` (`env_service.dart`) reads `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`, `SIMKL_CLIENT_ID`, `SIMKL_CLIENT_SECRET`, `DISCORD_APP_ID` from a `.env` that is **not committed** (glob for `.env*`/`secrets*` found nothing; `CONTRIBUTING.md:65` references a `secrets.example.dart` pattern that does not exist). Whether those values are currently upstream's registered apps cannot be confirmed from the repo.
4. **`[UNVERIFIED]` does the CI bundle `LICENSE` into installers?** The Windows/macOS/Linux packaging steps copy `build/.../Release/*` and the `.app`; no explicit `LICENSE` copy step is visible in `build.yml`. If absent, GPL §4 ("give all recipients a copy of this License") is unmet for binary recipients.
5. **`[UNVERIFIED]` Android TV launcher/list**. `AndroidManifest.xml:51-63` contains both `LAUNCHER` and `LEANBACK_LAUNCHER` intent filters; renaming `android:label` (`:29`) is safe, but whether any TV-specific metadata (banner, `android.software.leanback`) exists in `res/` was not audited here — deferred to `ReconNativeBuild`.
6. **Coexistence vs in-place upgrade decision.** Changing `applicationId` (`build.gradle.kts:24`) and `PRODUCT_BUNDLE_IDENTIFIER` gives side-by-side installs but **new, empty app data** (no watchlist/history/addon carry-over). Keeping them preserves data but may conflict with the old install. `[INFERENCE]` this is a product decision for the plan; the GPL rename itself does not require changing the applicationId.
7. **`CONTRIBUTING.md:68`** `[INFERENCE]` the MIT claim should be replaced with GPLv3; a lawyer should confirm the correct remediation wording (it is a defect independent of the rename).
8. **Stale `docs/player.md`** describes `fvp`/`libmdk`, which are **not** dependencies (`pubspec.yaml` uses `media_kit`). Decide whether to delete or rewrite; it is not an attribution issue but is misleading provenance documentation.
9. **TMDB/Google/Wyzie/AllDebrid key inheritance** — beyond attribution, reusing upstream's third-party credentials (`tmdb_helper.dart:5`, `audiobook_scraper_service.dart:277`, `wyzie_provider.dart:14`) raises **ToS/authorization** questions independent of GPL. `[INFERENCE]` flag for legal review.


[Showing lines 1-123 and 179-315 of 315; 55 middle lines (12.1KB) elided. Read artifact://298 for full output]