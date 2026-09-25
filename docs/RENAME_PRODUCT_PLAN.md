# Rename playbook — PlayTorrioZero → own brand

**Status:** executed and closed. The rebrand shipped: the product is **ZPlay** (`tzero86/ZPlay`), and the §8 recommendation (`Zylova`) was **not** taken. The Tier A/B/C decisions were applied as written, with one deliberate deviation — `Runner.rc` `CompanyName`/`ProductName` were **pinned** rather than renamed, so `path_provider` keeps resolving the existing `%APPDATA%\Roaming\com.example\playtorrio` data directory (see §4 and the note in `windows/runner/main.cpp`). Retained as the historical brief; the `path:line` references below describe the pre-rename tree.

**Audience / how to use this file**

1. Read §1 (ground truth) and §3 (tiers) before touching anything.
2. Read the **Do-not-rename list** (§4) — it is the difference between a rebrand and wiping user data.
3. Work §6 phases **in order**, top-down. Each phase has its own acceptance criteria and verification commands.
4. The exhaustive `path:line` row lists live in the annexes (§10). Every row is a work item. Line numbers were accurate when generated; re-verify before editing.
5. Anything marked `[UNVERIFIED]` or `[INFERENCE]` in the annexes is unresolved — never treat it as settled fact.

---

## 0. TL;DR

| Question | Answer |
|---|---|
| Is renaming technically hard? | No. It is a wide but mechanical substitution: **157 files / 635 matches** of `/torrio/i`. |
| Where is the real risk? | **Not** the name. It is (a) identifiers that key stored user data (`applicationId`, `Runner.rc` `CompanyName`/`ProductName`, prefs keys, built-in addon ids, on-disk directory names) and (b) the **GPLv3 obligations** we currently fail. |
| What must we legally do? | Keep `LICENSE` intact, **add a modification notice** (GPLv3 §5a — currently missing everywhere), and **offer the Corresponding Source with every published binary** (§6d — currently missing). Credit upstream "PlayTorrio V3 by Ayman". |
| Can the placeholder wait? | Yes — **but only in the "display" tier.** Never let a placeholder reach `applicationId`, the Inno `AppId` GUID, `Runner.rc` `CompanyName`/`ProductName`, the package name, or the CI artifact names. |
| Recommended name | **Zylova** (evidence-ranked first; see §8) — contingent on the owner's own trademark/domain check. **`ZeroPlay` is workable but has real collisions** and one semantic cost. `Zerova` is **disqualified** (live EV-charger brand, class-9 electronics). |
| Single biggest shortcut to avoid | "Find & replace `playtorrio` → `newname`". It would reset every user's watchlist, addon config, download queue, TorrServer DB and downloaded media. |

---

## 1. Ground truth

| Fact | Evidence |
|---|---|
| Product is a Flutter client: movies/series/anime/manga/audiobooks/music, Stremio addons, torrent streaming (TorrServer), open-web scrapers. | `pubspec.yaml:2`, `lib/pages/settings/about_settings_page.dart:111` |
| Primary targets: **Windows desktop** + **Android TV**. Also ships Linux/macOS/iOS/web artifacts in CI, and a Windows installer. | `.github/workflows/build.yml`, `installer/windows/setup.iss` |
| Upstream project | `https://github.com/ayman708-UX/PlayTorrioV3` — public, **GPL-3.0**, 302★ |
| Our fork | `https://github.com/tzero86/PlayTorrioZero` — **public, GPL-3.0** (so a §6 source link is already satisfiable) |
| Licence in repo | `LICENSE` = GNU GPL v3 verbatim (622 lines), `LICENSE:4` = `Copyright (C) 2026 Ayman` |
| Package name | `pubspec.yaml:1` `name: playtorrio` → drives 48 `package:playtorrio/...` imports |
| Android identity | `applicationId`/`namespace` = `com.example.playtorrio` (`android/app/build.gradle.kts:9,24`), label `playtorrio` (`AndroidManifest.xml:29`) |
| Windows identity | `BINARY_NAME "playtorrio"` (`windows/CMakeLists.txt:7`), window title (`windows/runner/main.cpp:49`), `Runner.rc:92-98` VERSIONINFO |
| Name-match scale | 157 files / 635 occurrences of `/torrio/i` |
| Pre-existing state | release APK is **debug-signed**; `CONTRIBUTING.md:68` claims **MIT** while the project is GPL-3.0; no licence/credits UI anywhere |

---

## 2. Compliance baseline (GPLv3) — what we owe upstream

This is the "credit the work we're inheriting" requirement, and it is **independent of the rename** — it can (and should) land first.

| # | Clause (from our own `LICENSE` text) | Required action | Status today |
|---|---|---|---|
| 1 | §4 — publish copyright notices, keep notices intact, **give every recipient a copy of this License** | Keep `LICENSE` byte-for-byte. Ensure installers/bundles actually ship it. | **Partial** — file exists in source; whether CI bundles it into installers is `[UNVERIFIED]`. |
| 2 | §5a — "The work must carry prominent notices stating that you modified it, and giving a relevant date." | Add a dated modification notice in: `README.md`, a new `NOTICE` file, the in-app About screen, and the Windows/macOS copyright metadata (`Runner.rc:96`, `AppInfo.xcconfig:14`). | **UNMET** — no modification notice exists anywhere. |
| 3 | §5b — prominent notice that the work is released under this License (+ any §7 terms) | Keep the GPL-3.0 badge/link; add an in-app "GPLv3" statement. | **Partial** — README only. |
| 4 | §5c — licence the **entire** derivative under GPLv3 | Do **not** add an EULA/ToS restricting redistribution. | **Satisfied in principle** — but `CONTRIBUTING.md:68` (MIT) contradicts it and is a defect to fix. |
| 5 | §5d — interactive UIs "must display Appropriate Legal Notices" *(only if upstream's did)* | Not strictly required (upstream shows none). **Recommended** for a clean provenance trail. | Not required; we will exceed the floor. |
| 6 | §6d — when conveying object code, offer **equivalent access to the Corresponding Source** at the same place, no further charge | Put the source link (this repo, at the release tag) in every GitHub Release body, the README download section, and the About screen. | **UNMET** — releases carry no source offer; README points users at *upstream's* releases. |
| 7 | §7b/§7e — permitted additional terms (preserve attribution; decline trademark rights) | Optional. If adopted, the terms must be stated in the source or in a notice pointing to them (a `NOTICE` file). | Available, unused. |
| 8 | §10 / §2 — no further restrictions; sublicensing not allowed | Remove the false MIT claim; never add "no rebrand"/"non-commercial" style terms. | **Satisfied** except the MIT line. |

### Attribution texts to add (verbatim suggestions — wording is the owner's call)

- **`NOTICE`** (new file, repo root):
  ```
  <Product Name> is a modified fork of PlayTorrio V3.
  PlayTorrio V3 — Copyright (C) 2026 Ayman — GPL-3.0 — https://github.com/ayman708-UX/PlayTorrioV3
  Modifications since the fork: Copyright (C) 2026 <owner>, released under the GNU GPL v3.
  Fork source: https://github.com/<owner>/<repo>
  ```
- **In-app (About)**: `Based on PlayTorrio V3 by Ayman — GPLv3 — source: <upstream url>. This program comes with ABSOLUTELY NO WARRANTY; it is free software and you may redistribute it under the GNU GPL v3.`
  → must be **hard-coded, always visible, not behind a flag, not remotely fetched** (§4 "keep intact all notices").
- **`LICENSE`**: keep the file verbatim; append one line after `LICENSE:4`: `Copyright (C) <year> <owner> (modifications)`.
- **`CONTRIBUTING.md:68`**: replace the MIT claim with `GNU GPL v3 (see LICENSE)`.
- **Updater / README**: after repointing downloads to our repo, keep an "Upstream" credit line — `README.md:164` (`Built by Ayman`) must survive.

---

## 3. Rename tiers — what is safe vs what moves user data

Cut by **blast radius**, not by file type. The tier determines *when* a name may be applied.

### Tier A — display only (safe, reversible, placeholder OK)

Cost to change later: one release. Ship the placeholder here freely.

- In-app strings, window titles, About/credits, splash/logo text: `lib/main.dart:144`; `lib/pages/home/home_page.dart:815,995`; `lib/pages/anime/anime_page.dart:626`; `lib/pages/settings/about_settings_page.dart:19,59,111`; `lib/pages/settings/settings_page.dart:590,614,615,805,809`; `lib/pages/settings/updates_settings_page.dart:35,86,101`; `lib/pages/settings/builtin_providers_settings_page.dart:71,387,399`; `lib/pages/settings/debrid_settings_page.dart:372,419`; `lib/widgets/p2p/p2p_warning_dialog.dart:169,182,211,348,386`; `lib/widgets/player/player_sub_style_modal.dart:280,435`; `lib/widgets/updater/update_dialog.dart:440,595`
- Network identity (externally visible, harmless locally): User-Agent strings `lib/services/iptv/iptv_network.dart:542,551`; `lib/services/music/lyrics_service.dart:76,109`; `lib/services/player/skip_segments_service.dart:77`; AllDebrid `agent=` param `lib/services/debrid/providers/alldebrid_service.dart:39`
- Android **label only**: `AndroidManifest.xml:29` (the `LEANBACK_LAUNCHER` filter at `:55-58` must not be touched)
- Windows window title, Linux GTK titles: `windows/runner/main.cpp:49`; `linux/runner/my_application.cc:48,52`
- Installer display name, release/artifact names, `.desktop` `Name=`, `Icon=`: `installer/windows/setup.iss:2,6,23`, `.github/workflows/build.yml:12,174,179-199,250-272,313-335,374-399`
- Docs prose: `README.md:2,5,21,42,49,50,155`, `CHANGELOG.md:3`, `CONTRIBUTING.md:1,14`

### Tier B — identity & state (expensive, effectively irreversible)

**Decide this once, with the final name.** Each row changes where user data lives or which install an upgrade targets.

| Surface | Evidence | Consequence if changed after release |
|---|---|---|
| Android `applicationId` + `namespace` (+ Kotlin package dir) | `android/app/build.gradle.kts:9,24`; `android/app/src/main/kotlin/com/example/playtorrio/MainActivity.kt:1` | Android treats it as a **different app**: no upgrade path, all private data (`/data/user/0/<applicationId>/…`: prefs, TorrServer DB, app_flutter) is orphaned. **Not migratable in-app** (new package cannot read the old package's sandbox). |
| Windows data dir — `Runner.rc` `CompanyName` + `ProductName` | `windows/runner/Runner.rc:92,98` → `path_provider_windows` derives `%APPDATA%\Roaming\<Company>\<Product>` | Changing these **relocates the app-support root** (TorrServer `config.db`, torrent state, shader/font caches). Settings/addons/history appear wiped without a copy step. Current real path: `%APPDATA%\Roaming\com.example\playtorrio\`. |
| macOS bundle id / Linux `APPLICATION_ID` / macOS `PRODUCT_NAME` | `macos/Runner/Configs/AppInfo.xcconfig:8,11`; `linux/CMakeLists.txt:7,10` | Same class of break; Linux/macOS support dirs derive from these. |
| Dart package name | `pubspec.yaml:1` (+ 48 import sites) | Mechanical/compile-blocking, but wide; do it in one commit. |
| Inno Setup `AppId` GUID | `installer/windows/setup.iss:15` | **Keep it.** Changing it forks a second parallel install and orphans the uninstall entry. |
| Persisted keys/ids/sentinels | prefs: `anime_library_service.dart:13,14`, `reader_settings.dart:223`, `p2p_settings_service.dart:9,10`, `focus_mode_view.dart:72,75`, `iptv_storage.dart:124,209`; addon ids: `addon_manager.dart:29,33,86,95,121-143`; sentinels: `lib/models/continue_watching/continue_watching_item.dart:99,149`, `lib/models/download/download_task_model.dart:137` | Silently resets watchlist, history, P2P prefs, addon enable/priority order, resume matching. |
| On-disk names | `download_service.dart:51` (`playtorrio_download_tasks.json`); `custom_background_service.dart:155`; `download_path_helper.dart:56,63,75`; `music_download_service.dart:80`; `book_download_service.dart:24,31`; `custom_audiobook_service.dart:134,137`; `epub_cover.dart:25,28`; `paper2audio_service.dart:302,305` | Renaming **abandons** downloaded books/music/audiobooks/covers under `Documents\PlayTorrio`, `Downloads\PlayTorrio`, `/storage/emulated/0/Download/PlayTorrio`. |
| Externally-owned credentials/endpoints | `app_updater_service.dart:12-14` (upstream's GitHub releases!), `tmdb_helper.dart:5,7`, `videasy.dart:13,14`, `audiobook_scraper_service.dart:277`, `wyzie_provider.dart:14`, `simkl_constants.dart:11`, `env_service.dart:82-98` | Not data loss — legal/ToS exposure and a self-updater that would install **upstream's** binaries. |

### Tier C — must never change (see §4)

---

## 4. The trap list — fields that *look* cosmetic but are load-bearing

1. **`Runner.rc` `CompanyName`/`ProductName`** — look like version-info cosmetics; they are the Windows data-dir key. This is the single least obvious rename hazard in the repo.
2. **`android:label` vs `applicationId`** — the label is Tier A; the id is Tier B. They are two lines apart in `build.gradle.kts`/manifest.
3. **Built-in addon *display name* vs addon *id*** — `addon_manager.dart:125,144` (name) is Tier A; `:121-143` (`builtin.playtorrio*`, `builtin:playtorrio*`) is Tier B, persisted and string-matched in `watch_screen.dart:110-114,280-293,2968-2977,3076-3077`, `addons_settings_page.dart:159,412`, `stream_service.dart:276-302`, `stream_scraper.dart:61-145`, and in every `lib/services/scraper/sites/*.dart` (`String get name =>`).
4. **CI artifact names ↔ updater asset matching** — `app_updater_service.dart` matches by **substring** (`setup`/`install`, `.apk`+arch, `.dmg` …), so renaming artifacts is safe; but the *repo slug* must be repointed or the app self-updates from upstream.
5. **macOS `PRODUCT_NAME` ↔ CI `mv playtorrio.app …`** — one rename requires the other (`build.yml:250,313`).
6. **`dismissed_update_version`** and other brand-free prefs keys — do not "tidy" them into a brand namespace.
7. **`web/manifest.json` is 0 bytes** — there is nothing to rename there; do not invent web branding.

### Do-not-rename list (verbatim, keep)

- Upstream identity: `Ayman`, `ayman708-UX`, `LICENSE:4` copyright line, the upstream repo URL (retain it as a provenance link even after repointing downloads).
- GPL: `LICENSE` body byte-for-byte; `GPL-3.0` badges/links (`README.md:13,159`).
- Provenance comments: `lib/models/iptv/iptv_models.dart:3` ("ported from PlayTorrio TV IPTV system"), `lib/services/scraper/sites/a111477.dart:9`, `megasource.dart:11-15`, `nova.dart:11-15`, `vadapav.dart:11-17`.
- Third-party product names in UI/comments: Stremio, Cinemeta, TorrServer, AniList, Trakt, Simkl, AllDebrid/Real-Debrid/Premiumize/TorBox/Debrid-Link, TMDB, Subdl, OpenSubtitles, Wyzie, Bookracy, PDFium, Poppins, Playfair Display, Anime4K, libmpv/FFmpeg.
- Third-party ids/endpoints: `com.linvo.cinemeta`, `v3-cinemeta.strem.io`, `graphql.anilist.co`, `opensubtitles*.strem.io`, `api.trakt.tv`, `api.simkl.com`, `api.bookracy.com`, `images.metahub.space`, `image.tmdb.org`.
- Embedded third-party licence headers: `assets/shaders/anime4k/*.glsl:1-22` (MIT/CC0) — these are required notices.
- Technical identifiers: `stremio://` scheme, `tt`/`tmdb:`/`kitsu:`/`mal:` id prefixes, magnet/infohash handling.
- `lib/services/simkl/simkl_constants.dart:11` `kSimklAppName = 'debrify'` — a third-party integration identity, not our brand; change only after registering our own Simkl app.

---

## 5. Pre-existing defects to fix in the same pass

These are not caused by the rename but are found, real, and cheaper to fix while the files are open.

| Defect | Evidence | Fix |
|---|---|---|
| Release APK is **debug-signed** (no `key.properties`, `release { signingConfig = signingConfigs.getByName("debug") }`) | `android/app/build.gradle.kts:37-40`; `android/.gitignore:12` anticipates `key.properties` | Generate a release keystore + `key.properties`; wire a real `signingConfigs.release`. Prerequisite for any distributable Android release, rename or not. |
| `CONTRIBUTING.md:68` claims contributions are **MIT** while the project is GPL-3.0 | `CONTRIBUTING.md:68` vs `LICENSE:1` | Replace with GPL-3.0 reference. |
| No licence/credits surface in-app, despite the settings tile promising "credits" | `settings_page.dart:810`; no `showLicensePage`/`LicenseRegistry` in `lib/**` | Add the About attribution block + a `showLicensePage(...)` entry (Tier A, §2). |
| Self-updater points at **upstream's** releases | `app_updater_service.dart:12-14` | Repoint to our repo (Tier B). |
| Inherited **third-party API keys**: TMDB, Google, Wyzie, plus upstream-run proxy hosts `db.speedracelight.com` / `api.speedracelight.com` | `tmdb_helper.dart:5,7`; `videasy.dart:13,14`; `audiobook_scraper_service.dart:277`; `wyzie_provider.dart:14` | Register our own keys/hosts or remove the provider. Unauthorised credential reuse risks revocation and ToS breach, independently of GPL. `[INFERENCE]` |
| `PackageInfo` fallback names a package id that exists nowhere | `settings_page.dart:367-368` (`appName: 'PlayTorrio'`, `packageName: 'com.playtorrio'` vs real `com.example.playtorrio`) | Correct to the real id during the rename. |
| Bundled font licences not shipped (Poppins, Playfair Display are SIL OFL 1.1) | `pubspec.yaml:110-127`; no OFL text in repo | Bundle the OFL notice. |
| `docs/player.md` documents `fvp`/`libmdk`, which are not dependencies (the app uses `media_kit`) | `docs/player.md:1-3` vs `pubspec.yaml:35-49` | Delete or rewrite. |

---

## 6. Work plan

Legend: **A** = Tier A display, **B** = Tier B identity/state. Each phase is independently landable.

### P0 — Prep (no user-visible change)

- Commit or stash the current in-flight work on `main` so the rename lands on a clean tree (the tree currently carries unrelated modifications).
- Freeze the decisions in §9 (name, applicationId policy, brand constant).
- `git grep -i -n "playtorrio\|torrio" | wc -l` → record the baseline (157 files / 635 matches).

**Acceptance:** clean tree; baseline recorded; §9 decisions answered.

### P1 — Compliance & attribution (Tier A/B-light, name-independent) ✅ *do this even if the name changes later*

- Add `NOTICE` (repo root) with the §2 text.
- Append the modification copyright line to `LICENSE` (do not edit anything else).
- Fix `CONTRIBUTING.md:68` (MIT → GPLv3).
- Add the attribution card to `lib/pages/settings/about_settings_page.dart` — **insert after line 154, before the closing `],` at :155**; follow the existing `_buildTechTile` pattern (`:162-215`). Add a `showLicensePage(context, applicationName: …, applicationLegalese: '… GPLv3 — based on PlayTorrio V3 by Ayman …')` entry point.
- Add `Copyright`/upstream notices to `windows/runner/Runner.rc:96` and `macos/Runner/Configs/AppInfo.xcconfig:14`.
- Add the source-offer line to the release job `.github/workflows/build.yml:399` release body, and to `README.md:42` download section.
- Bundle `LICENSE` + `NOTICE` into shipped bundles (installer `[Files]` `installer/windows/setup.iss:41`, and the portable zip/AppImage/.app steps).
- Bundle the SIL OFL notice for Poppins/Playfair Display.
- Add an upstream credit line to `README.md` (keep `:164` verbatim).

**Acceptance:** `NOTICE` exists; `git grep -n "MIT License" CONTRIBUTING.md` is empty; the About screen shows the attribution + licence entry; the release body contains the source link; `LICENSE` still contains the original copyright line.

**Verification:** `flutter build windows --debug` then launch `build\windows\x64\runner\Debug\playtorrio.exe` → Settings → About → attribution text visible, licence page opens. Inspect `installer/windows/setup.iss` `[Files]` includes `LICENSE`/`NOTICE`.

### P2 — Central branding constant (Tier A)

Owner has not finalised a name, so absorb the sprawl **now** so the final swap is one line.

- Create `lib/services/config/branding.dart` with `const kAppName`, `kAppSlug`, `kVendor`, `kUpstreamName`, `kUpstreamUrl`, `kLicenseId`.
- Replace the ~25 hardcoded inline display literals (Tier A list, §3) with those constants.
- Leave every persisted key/id/sentinel/path literal **untouched** (they are data, not display).

**Acceptance:** `git grep -n "'PlayTorrio" lib/ | grep -v branding.dart` returns only Tier-B rows (persisted ids/keys/sentinels/paths); `flutter analyze lib` clean; app builds and runs.

**Verification:** `flutter analyze lib`; build + launch; confirm the window title, splash, Home header, About and Settings copy all render from the constant.

### P3 — Backup/undo before touching identity

- Tag the current state (`git tag pre-rename-<date>`) and push.
- Snapshot the Windows data dir for local rollback: copy `%APPDATA%\Roaming\com.example\playtorrio\` aside.
- Note the current Android data state (`adb shell run-as com.example.playtorrio ls /data/data/com.example.playtorrio` on a device, optional).

**Acceptance:** tag pushed; data-dir snapshot exists.

### P4 — Identity rename (Tier B) — **requires the final name**

Do all of this in **one** commit series so nothing is half-renamed:

1. `applicationId`/`namespace` + move `android/app/src/main/kotlin/<pkg>/MainActivity.kt` (+ its `package` line and the `…/power` MethodChannel name at `MainActivity.kt:12` — keep the Dart consumer in sync); keep `applicationIdSuffix = ".debug"`.
2. `macos/Runner/Configs/AppInfo.xcconfig:8,11` + `project.pbxproj`/scheme refs; `ios/Runner/Info.plist:13,25,33` + bundle ids; `linux/CMakeLists.txt:7,10`.
3. Windows: `windows/CMakeLists.txt:3,7`, `Runner.rc:92,93,95,96,97,98`, `main.cpp:49`.
4. `pubspec.yaml:1` + all 48 `package:playtorrio/...` imports.
5. Installer: `MyAppName`/`MyAppPublisher`/`MyAppExeName`/`MyAppURL`/`OutputBaseFilename` (`setup.iss:6,10,11,12,26`) — **keep `AppId` `:15`**.
6. CI: workflow name, AppDir/`.desktop`/`Icon=`, AppRun exec, all artifact names and release title (`build.yml:12,174,179-199,250-272,313-335,374-399`) — coordinate with `setup.iss:26` and `windows/CMakeLists.txt:7` (see §4 traps 4-5).
7. Version policy: if `applicationId` is **kept**, do **not** lower `versionCode` (Android rejects a downgrade); if it **changes**, the version may reset. Source of truth is `pubspec.yaml:21`.
8. Repoint the updater repo slug (`app_updater_service.dart:12`).

**Acceptance:** `git grep -i -n "torrio"` returns only: the do-not-rename list (§4), the Tier-B persisted identifiers chosen to be kept, and the attribution/upstream references. Windows + Android builds succeed.

**Verification:** `flutter build windows --debug` (launch, check title/About); `flutter build apk --debug` + install on the TV box (`adb install -r …`), confirm the launcher/TV row label and that the app still appears under **Leanback**; run the installer compile (ISCC) and confirm the artifact name matches CI.

### P5 — Stored-state migration (only if Tier-B identifiers moved)

Implement in the Dart bootstrap (`lib/main.dart`) **before** the first `path_provider`/plugin read, guarded by a completion flag in the new location:

| What | From → To | Notes |
|---|---|---|
| Windows app-support root | `%APPDATA%\Roaming\com.example\playtorrio` → `<newVendor>\<newProduct>` | Recursive copy of `torrserver_data\`, `shaders\`, `fonts\`, prefs file. |
| Documents library | `Documents\PlayTorrio\{Books,Music,CustomAudiobooks,AudiobookCovers,GeneratedAudiobooks}` → new dir | Copy, do not move (leave old data recoverable). |
| Downloads | `Downloads\PlayTorrio`, `/storage/emulated/0/Download/PlayTorrio`, `<ext>/PlayTorrio` | Copy; or simply keep the literal path to avoid migration entirely. |
| Download queue | `playtorrio_download_tasks.json` → new filename | Must migrate or keep literal. |
| Prefs keys | `playtorrio_*`, `pt_iptv_*` | **Recommendation: keep them.** Zero user value in renaming; dual-read adds risk for nothing. |
| Built-in addon ids/sentinels | `builtin.playtorrio*`, `'PlayTorrio'`, `'PlayTorrioHTTP'`, `'PlayTorrio Offline'` | **Recommendation: keep the ids/sentinels as opaque historical values**, rename only display names. Otherwise: rewrite persisted addons + match both old and new strings in `continue_watching_service.dart:1041-1044`, `stream_service.dart:276-302`, `stream_scraper.dart:61-145`. |
| Android | — | **Not migratable.** If `applicationId` changes, accept data loss; the old app stays installed and functional. |

**Acceptance:** after upgrade, the app shows the previous watchlist/history/addons/settings and can resume a previously downloaded item; a second launch does not repeat the migration.

**Verification:** copy a pre-rename data dir into place, launch, confirm prefs/history/addons/torrent DB survive; then launch again and confirm the flag short-circuits.

### P6 — External services & release

- Register our own Discord application (upload the `logo` asset) and set `DISCORD_APP_ID`; update the presence strings (`discord_rpc_service.dart:23,149-483`).
- Own Google / Wyzie keys; replace or self-host `*.speedracelight.com` (`tmdb_helper.dart:7`, `videasy.dart:14`, `audiobook_scraper_service.dart:277`, `wyzie_provider.dart:14`).
- TMDB is now BYOK-first: the user's own key in Settings > TMDB, then a build-time `TMDB_API_KEY`, then the inherited value as a documented last-resort fallback in `tmdb_service.dart`. Rotate the inherited key if the upstream account is reachable and pass the replacement with `--dart-define`; never commit it.
- Set `agent=<our-slug>` for AllDebrid (`alldebrid_service.dart:39`); register our Simkl app (`simkl_constants.dart:11`).
- Fix Android release signing (§5) before producing any public APK.
- Verify the release body carries the Corresponding-Source link (§6d).
- Sanity-pass on the TV: launcher row label, D-pad navigation unaffected, playback unaffected.

**Acceptance:** `git grep -n "AIzaSy\|wyzie-" lib` is empty; the inherited TMDB key appears in exactly one file (`git grep -c "b3556f3b" lib`) and only behind the BYOK and build-time overrides; updater fetches *our* releases; release body links source; APK is release-signed.

---

## 7. Verification checklist (run at the end)

```bash
# 1. Remaining name occurrences — every hit must be on the do-not-rename list (§4)
git grep -i -n "torrio" | grep -v -E "ayman708-UX|Ayman|LICENSE|docs/rename|docs/RENAME" | wc -l

# 2. No stray identifier renames (data integrity)
git grep -n "builtin.playtorrio\|builtin:playtorrio" -- lib | wc -l   # expect unchanged count if ids kept

# 3. Static analysis + build
flutter analyze lib
flutter build windows --debug
flutter build apk --debug

# 4. Launch smoke test (Windows)
#    build\windows\x64\runner\Debug\<name>.exe  → title, splash, Home, About, Settings, playback
# 5. TV smoke test
#    adb install -r build\app\outputs\flutter-apk\app-debug.apk
#    → app appears in the TV launcher row (LEANBACK), label correct, playback works
```

Windows-side data-dir check after a Tier-B rename: `%APPDATA%\Roaming\<Vendor>\<Product>\` must contain the migrated `torrserver_data\` and the prefs file.

---

## 8. Naming

Full candidate table, surface-form renderings and per-URL collision evidence: **`docs/rename/naming-shortlist.md`**.

### Constraints that actually bind *this* product

No piracy/illegal read (the app plays torrents — a name that advertises the mechanism invites store takedowns); not confusingly similar to `PlayTorrio`/`Torrio` (fork distinctness + upstream's identity); ≤10 chars and one space-free token (must serve as `exe`, `.desktop`, `.app`, Dart package segment and Android package segment); medium-neutral (the app is NOT video-only — it also does manga/books/audiobooks/music); not a generic technical term (a media app named after a web server is unfindable).

### Verified collision findings (GitHub search API + live domains, 2026-09-14)

| Candidate | Software-space collision | Domain | Verdict |
|---|---|---|---|
| **Zylova** | **3** repos, all one hobbyist account (`marvcon/*`), 0★, none media | `zylova.com` → **HTTP 404** | **cleanest observed** |
| **Zeruna** | **4** repos, none media, none notable | not checked | clean-ish |
| **ZeroPlay** (owner's idea) | **51** repos incl. `HorseyofCoursey/zeroplay` — a **46★ CLI media player**; a Google Play *developer* named "ZeroPlay Games" | `zeroplay.com` → live (parked/for-sale) | workable, but real collision **in the same category** |
| **Zerova** (scout's pick) | 104 repos, none media | `zerova.com` **is ZEROVA Technologies, a live EV-charging manufacturer** | **DISQUALIFIED** — active brand in class-9 electronics |
| **Zerolume** | **0** repos | `zerolume.com` **is a live French offensive-security consultancy** | disqualified as whitespace; also reads as "zero volume" |
| Veyra / Auralis / Halcyon / Kestrel / Velora / Mythra / Lumen / Nova | established products, incl. Kestrel (Microsoft's ASP.NET server), Halcyon (162★ Android music player), Auralis (625★ TTS) | mostly live | reject |
| Media-evocative lane (checked because it *should* fit the product) | `cinevault` **827** repos, `cinelo` **581**, `lumeno` **217**, `reelix` **87** (incl. a video player), `reelio` **81**, `novero` **30**, `lumora` **2007** | nearly all `.com` live | saturated — no room |

### Recommendation

1. **Zylova** — the cleanest observed whitespace (3 abandoned repos, no live domain `[as of generation]`), 6 chars, one word, keeps the owner's `Zero`/`tzero86` identity, medium-neutral, legal package segment (`com.<vendor>.zylova` → recommend `io.github.tzero86.zylova`). Its weakness is that it is meaningless — which is what makes it available.
2. **Zeruna** — same profile, alternative flavour.
3. **ZeroPlay** — the owner's own preference, genuinely readable, but: a shipping media player already uses the name, a Play developer entity shares it, the `.com` is taken, and "Zero Play" can be parsed as *"no playback"* on a TV launcher row where labels are read without context. If chosen, treat it as an interim and do not put it into the Tier-B identifiers until the checks below pass.

### On `PlayTorrioZero` as the interim

Fine as a **Tier-A placeholder only**. It keeps upstream's `Torrio` stem, so it cannot be the final name (distinctness), and it must never reach `applicationId`, the Inno `AppId`, the data-dir keys or artifact names — those are the Tier-B decisions that want the final name.

### Not legal/stores clearance

Nothing here is clearance. Before the name is frozen into `android/app/build.gradle.kts:24`, the owner must run: (a) a trademark search (own jurisdiction + US/EU, at least Nice classes 9 and 41); (b) a Google Play **app-name** availability attempt and the Microsoft Store equivalent; (c) domain/handle availability for the chosen slug; (d) a Flathub app-id ownership check if Linux is ever distributed (`[UNVERIFIED — not checked]`; Flathub's search API was unreachable during research).

---

## 9. Decisions the owner must make (blocking)

1. **Final name** — or explicitly "placeholder in Tier A only, decide later". Until this is answered, P4/P5 stay blocked; **P1-P2 are not blocked and should proceed**.
2. **Android `applicationId`: change or keep?** Changing = clean new identity, but **all existing app data is lost** (not migratable) and the old app stays installed. Keeping = data survives, `com.example.*` remains (unshippable to Play, but irrelevant for sideloaded TV/desktop use).
3. **Windows data dir: migrate or keep the old directory name?** Keeping `%APPDATA%\Roaming\com.example\playtorrio\` (i.e. not changing `Runner.rc` `CompanyName`/`ProductName`) avoids the whole migration and is invisible to users. Migrating requires the P5 copy step.
4. **Do users need in-place upgrade continuity** on Windows (same Inno `AppId`) or is a clean parallel install acceptable?
5. **Does the built-in provider brand follow the product brand?** ("PlayTorrio"/"PlayTorrioHTTP" → `<Name>`/`<Name>HTTP`) — carries the addon-id migration cost.
6. **Which platforms are actually maintained?** iOS and web ship in CI but iOS is not a listed target and `web/manifest.json` is empty. Dropping them shrinks the rename surface.
7. **Register own credentials now or later?** (Discord / TMDB / Google / Wyzie / Simkl / AllDebrid agent.)
8. **Version policy** — keep the existing `versionCode` (safe for upgrades) or reset for the new brand (only valid if `applicationId` changes).

---

## 10. Annexes — exhaustive inventories

Generated 2026-09-14 by read-only reconnaissance; each row is `path:line | current value | layer | must-change | target | risk`.

| File | Covers |
|---|---|
| `docs/rename/inventory-code.md` | `lib/**`, `test/**`, `assets/**`, `web/**`, `pubspec.yaml`, docs: user-visible strings, network identity (User-Agent/agent params), persisted keys/ids/sentinels, on-disk names, asset inventory, the 48-file import map, and the per-scraper `name`/`addonName` line map (48 scraper files). |
| `docs/rename/inventory-native.md` | `android/ windows/ linux/ macos/ ios/ installer/ .github/`: every native identity surface, CI artifact-name couplings, version plumbing, generated-file exclusions, and the **runtime storage-path table** (which renaming decision moves which user data, with pub-cache evidence for the path derivations). |
| `docs/rename/inventory-attribution.md` | Licence/attribution: upstream provenance rows, the clause-grounded GPLv3 obligation checklist, bundled third-party components (TorrServer/mpv/FFmpeg/PDFium, Anime4K shaders, OFL fonts), the exact in-app insertion point, the externally-owned-identifier table, and the must-not-rename list. |
| `docs/rename/naming-shortlist.md` | Naming: identity surfaces a name must fill, requirements R1-R10, 13 candidates with four-surface renderings, collision research with URLs, top-3 shortlist, cheap-vs-expensive split, do-not-use list. |

Re-running the reconnaissance: the annexes were produced by four parallel read-only agents over the working tree; `git grep -i -n torrio` plus the four scopes above reproduces the row sets. Verify any row before acting on it — the tree has moved since.
