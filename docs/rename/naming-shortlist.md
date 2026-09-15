<!-- Annex to docs/RENAME_PRODUCT_PLAN.md — exhaustive per-layer inventory.
     Generated 2026-09-14 by read-only reconnaissance over this repo's working tree.
     `path:line` references match the tree as generated; re-verify before applying edits.
     Rows marked [UNVERIFIED] or [INFERENCE] are unresolved — do not treat them as settled.
     Do not delete rows: an executing agent works this list top-to-bottom. -->

# Naming — candidates, collision research, shortlist

> ## ⚠ SUPERSEDED IN PART — read before acting (corrected 2026-09-14, after this file was generated)
>
> This annex's **§4 recommendation (`Zerova`) is disqualified.** Its own §7 open question ("what is `zerova.com`?") was verified afterwards: **`zerova.com` belongs to ZEROVA Technologies, a live EV-charging manufacturer** (`https://www.zerovatech.com/`) — an active brand in Nice class 9 (electrical apparatus), the same class a software app would file in. Do not rename to `Zerova`.
>
> Two further additions from follow-up verification:
> - **`zerolume.com` is a live French offensive-security consultancy** ("ZEROLUME — cabinet de sécurité offensive, systèmes IA"), so that name is in use as a brand too (class 42 services), despite having **0** GitHub repositories.
> - **`ZeroPlay` collisions confirmed**, not merely suspected: GitHub repository search returns **51** projects including `HorseyofCoursey/zeroplay` — a **46★ CLI media player** (same category) — plus `zeroplay.com` live.
>
> **Current ranked recommendation lives in `../RENAME_PRODUCT_PLAN.md` §8: `Zylova` → `Zeruna` → `ZeroPlay`**, with `Zylova` cleanest on observed evidence (3 GitHub repos, all one hobbyist account; `zylova.com` HTTP 404). This annex remains valid for everything else: requirements R1-R10, the candidate table, the surface-form renderings, the do-not-use list, and the cheap-vs-expensive split (§5) — the latter is the operational core of the plan.
>
> Additional evidence gathered after generation (media-evocative candidate space is saturated): `cinevault` 827 repos / `.com` live, `cinelo` 581 / live, `lumeno` 217 / live, `reelix` 87 (incl. a video player) / free, `reelio` 81 / `.com`+`.app` live, `novero` 30 / live, `lumora` 2007 / live.

> Author note: this slice is research + judgment, no repo files edited. Every repo fact carries `path:line`. Collision claims carry a URL. Where `web_search` failed (see §3.0) the row is marked `[UNVERIFIED — collision not checked]`. Nothing here is legal clearance.

---

## 0. Evidence: the identity surfaces a name must fill

Source of truth for "renders in each surface form" below. All values read directly; verbatim quotes.

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| `pubspec.yaml:1` | `name: playtorrio` | Dart package / import root (128+ files use `package:playtorrio/...`) | yes | `<slug>` (lowercase, no spaces) | Touches every relative import; mechanical but wide. |
| `pubspec.yaml:2` | `description: "All-in-one media streaming app — movies, series, manga, audiobooks, and music. Powered by Stremio addons, torrent streaming, and the open web."` | Store/marketing copy | optional | rewrite around new brand | Contains `Stremio` — see §6. |
| `pubspec.yaml:19` | `version: 1.1.5+2018` | versioning | keep | unchanged | Rename MUST NOT bump version; Android `versionCode` 2018 gates upgrades. |
| `android/app/build.gradle.kts:9` | `namespace = "com.example.playtorrio"` | Android namespace | yes | `com.<vendor>.<slug>` | Must equal applicationId for this project layout. |
| `android/app/build.gradle.kts:24` | `applicationId = "com.example.playtorrio"` | Android app id | **yes (highest risk)** | `com.<vendor>.<slug>` | `com.example.*` is unshippable to Play. Changes upgrade identity. |
| `android/app/build.gradle.kts:35` | `applicationIdSuffix = ".debug"` | debug variant | yes | `.<slug>`-independent, keep `.debug` | Coexists with release build by design. |
| `android/app/src/main/AndroidManifest.xml:29` | `android:label="playtorrio"` | **TV launcher label** (Windows exe name analogue) | yes | `PlayTorrio`-style title case, ≤10 chars | Lowercase today looks unfinished on a TV home row. |
| `AndroidManifest.xml:52-53` | `android.intent.category.LAUNCHER` | Android launcher visibility | keep | — | Do not touch; label/menu changes kept cosmetic. |
| `AndroidManifest.xml:56-57` | `android.intent.category.LEANBACK_LAUNCHER` | **Android TV visibility** | keep | — | MUST remain; removing it hides the app from the TV row. |
| `AndroidManifest.xml:64` | `android:authorities="${applicationId}.ota_update_provider"` | OTA FileProvider | keep (FQN) | — | Placeholder — follows applicationId automatically. A rename invalidates any granted URI permission. |
| `AndroidManifest.xml:74` | `android:name="${applicationId}.ACTION_INSTALL_COMPLETE"` | OTA intent action | keep (FQN) | — | Same; self-consistent via placeholder. |
| `windows/runner/Runner.rc:92` | `VALUE "CompanyName", "com.example" "\0"` | exe VERSIONINFO | yes | `<Vendor>` | See §5 — this feeds the Windows data dir. |
| `windows/runner/Runner.rc:93` | `VALUE "FileDescription", "playtorrio" "\0"` | exe VERSIONINFO | yes | `<Name>` | Shown in Task Manager / file properties. |
| `windows/runner/Runner.rc:95` | `VALUE "InternalName", "playtorrio" "\0"` | exe VERSIONINFO | yes | `<slug>` | |
| `windows/runner/Runner.rc:96` | `VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved." "\0"` | exe VERSIONINFO | yes | owner + upstream attribution | Must not drop GPL attribution — coordinate with attribution slice. |
| `windows/runner/Runner.rc:97` | `VALUE "OriginalFilename", "playtorrio.exe" "\0"` | exe filename | yes | `<slug>.exe` | Must match the actual built exe name. |
| `windows/runner/Runner.rc:98` | `VALUE "ProductName", "playtorrio" "\0"` | exe VERSIONINFO | yes | `<Name>` | **Drives `%APPDATA%` data dir on Windows — see §5.** |
| `windows/runner/main.cpp:49` | `window.Create(L"playtorrio", origin, size)` | Windows window class/title | yes | `<Name>` / `<Vendor>.<Name>` | Window class name is process-local; safe to change. |
| `linux/CMakeLists.txt:7` | `set(BINARY_NAME "playtorrio")` | Linux binary | yes | `<slug>` | Produces the AppRun `exec ./<slug>`. |
| `linux/CMakeLists.txt:10` | `set(APPLICATION_ID "com.example.playtorrio")` | GTK app id | yes | `com.<vendor>.<slug>` | Flathub requires an app id you can prove control of. |
| `macos/Runner/Configs/AppInfo.xcconfig:8` | `PRODUCT_NAME = playtorrio` | macOS `.app` name | yes | `<Name>` | Flutter default window title unless overridden. |
| `macos/Runner/Configs/AppInfo.xcconfig:11` | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio` | macOS bundle id | yes | `com.<vendor>.<slug>` | Same `com.example.*` defect. |
| `macos/Runner.xcodeproj/project.pbxproj:220` | `productReference = ... /* playtorrio.app */` | Xcode product ref | yes | `<Name>.app` | 9 `torrio` matches in this file (see build slice). |
| `installer/windows/setup.iss:5` | `#define MyAppName      "PlayTorrio"` | Installer display name | yes | `<Name>` | Drives Start-menu + Apps-list entry. |
| `installer/windows/setup.iss:10` | `#define MyAppPublisher "ayman708-UX"` | Installer publisher | yes | owner vendor name | Currently upstream's handle — wrong for a rebrand. |
| `installer/windows/setup.iss:11` | `#define MyAppExeName   "playtorrio.exe"` | Installer exe ref | yes | `<slug>.exe` | Must match Runner.rc. |
| `installer/windows/setup.iss:12` | `#define MyAppURL       "https://github.com/ayman708-UX/PlayTorrioV3"` | Installer URL | yes | owner's repo URL | Points at upstream; attribution slice must decide how upstream is credited instead. |
| `installer/windows/setup.iss:15` | `AppId={{9B8C7D6E-5F4E-3D2C-1B0A-9F8E7D6C5B4A}` | **Inno AppId GUID** | **no** | keep | Changing it breaks in-place upgrade + leaves an orphan uninstall entry. See §5. |
| `installer/windows/setup.iss:23` | `OutputBaseFilename=PlayTorrio-Windows-Setup` | Installer artifact | yes | `<Name>-Windows-Setup` | |
| `.github/workflows/build.yml:12` | `name: Build and Release PlayTorrioV3` | CI workflow name | yes | `<Name>` | |
| `.github/workflows/build.yml:174` | `APP=PlayTorrio.AppDir` | AppImage dir | yes | `<Name>.AppDir` | |
| `.github/workflows/build.yml:188` | `Name=PlayTorrio` (.desktop entry) | **Linux `.desktop` name** | yes | `<Name>` | Menu-visible string. |
| `.github/workflows/build.yml:198` | `PlayTorrio-Linux-x86_64.AppImage` | artifact | yes | `<Name>-Linux-x86_64.AppImage` | Bookmarks/hotlinks break — see §5. |
| `.github/workflows/build.yml:250,313` | `mv playtorrio.app PlayTorrio.app` | macOS artifact | yes | `<Name>.app` | |
| `.github/workflows/build.yml:262,325` | `PlayTorrio-macOS-arm64.dmg` | artifact | yes | `<Name>-macOS-arm64.dmg` | |
| `.github/workflows/build.yml:374` | `PlayTorrio-iOS.ipa` | artifact | optional | `<Name>-iOS.ipa` | iOS is not a primary target. |
| `.github/workflows/build.yml:399` | `name: "PlayTorrio ${{ github.ref_name }}"` | release title | yes | `<Name> ${{ github.ref_name }}` | |
| `lib/main.dart:144` | `title: 'PlayTorrio'` | in-app display | yes | `<Name>` | Also `PlayTorrioApp` class at `main.dart:74,77,81,84`. |
| `lib/pages/settings/settings_page.dart:367-368` | `appName: 'PlayTorrio', packageName: 'com.playtorrio'` | PackageInfo fallback | yes | `<Name>` / real appId | **Inconsistent with the real id** (`com.example.playtorrio`); `com.playtorrio` exists nowhere in the build. Fix during rename. |

---

## 1. Requirements the name must satisfy

Derived from this specific product (Stremio-addon client + torrent/P2P streaming + open-web scraping, spanning movies/series/anime/manga/audiobooks/music), not generic branding advice.

| # | Requirement | Why it is load-bearing *here* |
|---|---|---|
| R1 | **No piracy/illegal read.** Must not contain or evoke `torrent`, `torr`, `magnet`, `stream-grab`, `free-movies`, `warez`, `crack`, `nzb`, `bay`, `1337`, `pirate`. | `lib/services/addon/addon_manager.dart:127` literally describes a "Built-in BitTorrent P2P streaming engine (TorrServer). Plays torrents, magnets, and infohashes directly." A name that advertises the mechanism invites Play Store / Microsoft Store rejection, ISP blocking, and CDN abuse reports. |
| R2 | **No NSFW or slur homograph.** Must not read badly when case-folded or when the middle letters are dropped. | Store review and school/workplace SafeSearch are both sensitive to this; a TV launcher label is read by every household member. |
| R3 | **Not confusingly similar to PlayTorrio / Torrio.** Must not be a `Torrio` derivative. | The fork carries GPL-3.0 + upstream attribution obligations; a near-identical name plus identical code reads as upstream impersonation rather than a legitimate fork, which is a distinct legal/ethical problem from copyright. `LICENSE` is GPL v3, `Copyright (C) 2026 Ayman`. |
| R4 | **≤2 words, ideally ≤10 chars.** | Android TV launcher labels truncate; a launcher label is `AndroidManifest.xml:29` today (`playtorrio`, lowercase) and also appears on the Windows taskbar and Start menu (`installer/windows/setup.iss:5`). |
| R5 | **Must work as a single space-free token.** | It has to serve as `<slug>.exe` (`Runner.rc:97`), `<slug>` Linux binary (`CMakeLists.txt:7`), `<Name>.app` (`AppInfo.xcconfig:8`), `<Name>.AppDir` (`build.yml:174`), and a Dart package name (`pubspec.yaml:1` — Dart package names must be lowercase `[a-z0-9_]`). |
| R6 | **Must survive a reverse-DNS package id** `com.<vendor>.<slug>` — so the slug must be a legal Java/Android package segment (no leading digit, no hyphen, no Java keyword). | `android/app/build.gradle.kts:24`, `AppInfo.xcconfig:11`, `CMakeLists.txt:10`. |
| R7 | **Pronounceable in one breath, no spelling ambiguity when heard.** | The product's discovery channel is FMHY/Reddit/`alternativeto.net` word-of-mouth (see §3 URLs), where the name is spoken and re-typed. `ZeroPlay` vs `Zero Play` vs `0Play` is a live ambiguity. |
| R8 | **Not a generic technical-infrastructure term.** | A media client named after a web server/framework collides with every developer's documentation search. `Kestrel` is exactly this failure — see §3. |
| R9 | **Slug must be registrable as a domain/handle you control**, because `applicationId` should be reverse-DNS of something you own. | `com.example.*` is unshippable to Play; `installer/windows/setup.iss:12` currently points at upstream's repo. Owner handle is `github.com/tzero86` (per established facts). |
| R10 | **Neutral on medium.** Must not imply video-only. | The app is movies + series + anime + manga + audiobooks + music + IPTV (`lib/pages/settings/about_settings_page.dart:111`). Names ending in `-flix`, `-movies`, `-tv`, `-video` under-sell half the product and age badly. |

---

## 2. Candidate table

Surface forms are shown as concrete renderings. `<vendor>` = the reverse-DNS root you control; **recommended vendor = `io.github.tzero86`** (owner's GitHub handle — needs no domain purchase, and GitHub Pages is a valid reverse-DNS root).

| # | Candidate | Rationale (what it evokes) | `<slug>.exe` | Installer `OutputBaseFilename` | Android `applicationId` | TV label / `.desktop` / `.app` / AppImage | Slug & package-id shape | Collision |
|---|---|---|---|---|---|---|---|---|
| 1 | **PlayTorrioZero** *(owner's placeholder)* | "PlayTorrio for me" — a personal marker appended to upstream's name | `playtorriozero.exe` | `PlayTorrioZero-Windows-Setup` | `com.<vendor>.playtorriozero` | `PlayTorrioZero` / `PlayTorrioZero.desktop` / `PlayTorrioZero.app` / `PlayTorrioZero-Linux-x86_64.AppImage` | 15 chars, 3 words; fails R4/R5 (still contains `Torrio` → R3) | **HIGH** — retains the exact upstream stem; violates R3. Upstream site live at https://playtorrio.pages.dev/ |
| 2 | **ZeroPlay** *(owner's idea)* | "zero friction, just play" — the `Zero` ties to the owner's identity (`tzero86`) | `zeroplay.exe` | `ZeroPlay-Windows-Setup` | `com.<vendor>.zeroplay` | `ZeroPlay` (8 ch, fits) / `ZeroPlay.desktop` / `ZeroPlay.app` / `ZeroPlay-Linux-x86_64.AppImage` | 8 chars, 2 words, clean slug; package segment `zeroplay` legal | **MEDIUM-HIGH** — 51 GitHub repos incl. a media player; Google Play developer "ZeroPlay Games" exists; `zeroplay.com` is parked/for-sale. See §3 |
| 3 | **Zerova** | Coinage: `Zero` + `-ova` (feminine/place suffix). Short, brandable, implies "from the ground up" without naming any media mechanism | `zerova.exe` | `Zerova-Windows-Setup` | `com.<vendor>.zerova` | `Zerova` (6 ch) / `Zerova.desktop` / `Zerova.app` / `Zerova-Linux-x86_64.AppImage` | 6 chars, 2 syllables, 1 word; segment legal | **MEDIUM** — `zerova.com` is a registered live site; 104 GitHub repos, none a media app. `[UNVERIFIED]` on what zerova.com does |
| 4 | **Zerolume** | Blend `Zero` + `Lumen`/`Volume` — light + sound, explicitly medium-neutral (satisfies R10) | `zerolume.exe` | `Zerolume-Windows-Setup` | `com.<vendor>.zerolume` | `Zerolume` (8 ch) / `Zerolume.desktop` / `Zerolume.app` / `Zerolume-Linux-x86_64.AppImage` | 8 chars, 3 syllables (mild R7 cost); segment legal | **LOW** — GitHub repo search returns **0** results; no brand surfaced |
| 5 | **Veyra** | Pure coinage, soft consonants, clearly a brand not a utility | `veyra.exe` | `Veyra-Windows-Setup` | `com.<vendor>.veyra` | `Veyra` (5 ch, shortest here) / `Veyra.desktop` / `Veyra.app` / `Veyra-Linux-x86_64.AppImage` | 5 chars, 2 syllables; segment legal | **HIGH** — at least four live independent brands. See §3 |
| 6 | **Mythra** | Mythic register; "stories" framing suits anime/manga/books | `mythra.exe` | `Mythra-Windows-Setup` | `com.<vendor>.mythra` | `Mythra` (6 ch) / `Mythra.desktop` / `Mythra.app` / `Mythra-Linux-x86_64.AppImage` | 6 chars | **HIGH** — `Mythra` is a major character in Nintendo's *Xenoblade Chronicles 2*; also an AI platform. IP-holder collision + search noise |
| 7 | **Halcyon** | "calm, golden-age" — premium/timeless register | `halcyon.exe` | `Halcyon-Windows-Setup` | `com.<vendor>.halcyon` | `Halcyon` (7 ch) / `Halcyon.desktop` / `Halcyon.app` / `Halcyon-Linux-x86_64.AppImage` | 7 chars, 3 syllables | **HIGH** — multiple shipping GitHub music players, incl. a 162★ MIUI-style Android player. See §3 |
| 8 | **Auralis** | `Aural`-rooted — audio-forward | `auralis.exe` | `Auralis-Windows-Setup` | `com.<vendor>.auralis` | `Auralis` (7 ch) / `Auralis.desktop` / `Auralis.app` / `Auralis-Linux-x86_64.AppImage` | 7 chars, 3 syllables | **HIGH** — 823 GitHub matches; a 625★ TTS engine owns the name in search. See §3 |
| 9 | **Kestrel** | Bird of prey; sharp/lightweight register | `kestrel.exe` | `Kestrel-Windows-Setup` | `com.<vendor>.kestrel` | `Kestrel` (7 ch) / `Kestrel.desktop` / `Kestrel.app` / `Kestrel-Linux-x86_64.AppImage` | 7 chars, 2 syllables | **HIGH** — `Kestrel` is Microsoft's ASP.NET Core web server (verified). Violates R8 outright. See §3 |
| 10 | **Velora** | Coinage, "velo-" speed + soft ending | `velora.exe` | `Velora-Windows-Setup` | `com.<vendor>.velora` | `Velora` (6 ch) / `Velora.desktop` / `Velora.app` / `Velora-Linux-x86_64.AppImage` | 6 chars | **HIGH** — `velora.com` is Velora Studios LLC; a 774★ crypto project ships as `VeloraDEX`. See §3 |
| 11 | **Zylova** | Coinage, no semantic load — maximum whitespace, minimum meaning | `zylova.exe` | `Zylova-Windows-Setup` | `com.<vendor>.zylova` | `Zylova` (6 ch) / `Zylova.desktop` / `Zylova.app` / `Zylova-Linux-x86_64.AppImage` | 6 chars | **LOW** — 3 GitHub repos, all personal/abandoned; `zylova.com` returned HTTP 404 |
| 12 | **Lumen** *(illustrative reject)* | Light/brightness — popular coinage base | `lumen.exe` | `Lumen-Windows-Setup` | `com.<vendor>.lumen` | `Lumen` (5 ch) | 5 chars | **HIGH** — heavily used in dev tooling/space, incl. Laravel's micro-framework; unusable bare |
| 13 | **Nova** *(illustrative reject)* | "new/star" | `nova.exe` | `Nova-Windows-Setup` | `com.<vendor>.nova` | `Nova` (4 ch) | 4 chars | **HIGH** — Apache OpenStack Nova, Nova Launcher (an Android TV-adjacent surface). Unusable |

Rendering observed for the four required surfaces, taking **Zerova** as the worked example (all others follow identically by substitution):

| Surface | Today | After rename to `Zerova` | Source of truth |
|---|---|---|---|
| Windows exe | `playtorrio.exe` | `zerova.exe` | `Runner.rc:97`, `installer/windows/setup.iss:11` |
| Installer | `PlayTorrio-Windows-Setup.exe` | `Zerova-Windows-Setup.exe` | `setup.iss:5,23` |
| Android `applicationId` | `com.example.playtorrio` (+`.debug`) | `io.github.tzero86.zerova` (+`.debug`) | `build.gradle.kts:24,35` |
| TV launcher label | `playtorrio` | `Zerova` | `AndroidManifest.xml:29` (LEANBACK filter at `:57`) |
| Linux / macOS artifacts | `PlayTorrio-Linux-x86_64.AppImage`, `PlayTorrio.app`, `PlayTorrio.desktop`, `PlayTorrio-macOS-arm64.dmg` | `Zerova-Linux-x86_64.AppImage`, `Zerova.app`, `Zerova.desktop`, `Zerova-macOS-arm64.dmg` | `build.yml:174,186-198,250,262` |

---

## 3. Collision research

### 3.0 Method + tooling caveat (read this first)

- **`web_search` was partially unavailable during this task.** Of 14 queries issued, **6 returned results**; the remaining 8 failed across every configured provider (Gemini 403, xAI 402/429, z.ai 429, Startpage/DuckDuckGo/Ecosia/Mojeek bot-blocked, Google unrenderable). Failures were transient and batch-order dependent — two consecutive identical batches returned opposite results.
- **Fallback used for the rest:** direct URL reads against the **GitHub repositories search API** (`https://api.github.com/search/repositories?...`), live **domain reads** (`zeroplay.com`, `zerova.com`, `velora.com`, `zylova.com`), **Microsoft Learn** for the Kestrel term, and **Flathub** (whose search page is JS-only and whose `/api/v2/search` endpoint returned HTTP 405 — Flathub was therefore **not** successfully queried; every Flathub claim is `[UNVERIFIED]`).
- **No Google Play / App Store / Microsoft Store API was reachable.** Store-listing claims below rest on search-result URLs only, and each is marked with its confidence.
- **Web results are NOT trademark clearance.** See §4.

### 3.1 Collision findings

Rating: `low` = no plausible confusion found; `medium` = same-space use or a live domain/company; `high` = an established product already owns the term in this space, or an IP holder is involved.

| Candidate | Finding | Evidence URL | Risk |
|---|---|---|---|
| **PlayTorrioZero** | Upstream is a live, *indexed* product: an official marketing site, an `alternativeto.net` software listing, and recognition in FMHY's Nov-2025 update. Retaining `PlayTorrio` risks being read as the upstream project rather than a fork. | https://playtorrio.pages.dev/ ; https://alternativeto.net/software/playtorrio/about/ ; https://fmhy.net/posts/Nov-2025 | **high** |
| **ZeroPlay** | (a) 51 GitHub repos match; the top hit is a **CLI media player**, 46★, created 2026-03, MIT — same domain. (b) `liaosunny123/ZeroPlay`, description verbatim "ZeroPlay, a player for short videos." (c) A **Google Play developer** named "ZeroPlay Games" publishes under `io.zeroplay.solitaire`. (d) `zeroplay.com` is parked and **for sale**. | https://github.com/HorseyofCoursey/zeroplay ; https://github.com/liaosunny123/ZeroPlay ; https://play.google.com/store/apps/developer?id=ZeroPlay+Games ; https://zeroplay.com | **medium-high** |
| **Zerova** | 104 GitHub repos match, but the top hits are unrelated (`ZeroVault` crypto CLI, `zerovah-game` Java framework, `zerovalidate` JS form validator) — **no media app**. `zerova.com` is a registered live site with a logo and privacy policy. What the company does is `[UNVERIFIED — web_search unavailable for this query]`. | https://api.github.com/search/repositories?q=zerova ; https://www.zerova.com/ | **medium** |
| **Zerolume** | GitHub repository search returns **`total_count: 0`** — no software project uses the name. No brand surfaced. Domain status not checked (`[UNVERIFIED]`). | https://api.github.com/search/repositories?q=zerolume | **low** |
| **Zylova** | 3 GitHub repos, all personal and abandoned (0★ / 0★ / 0★). `zylova.com` returned **HTTP 404** — no live site. No brand surfaced. | https://api.github.com/search/repositories?q=zylova ; https://zylova.com | **low** |
| **Veyra** | At least **four** independent live brands: a streetwear marketplace app; an India social-commerce platform; a software LLC; an AI agentic-commerce platform; and a website-builder tool. Crowded across unrelated sectors = high search noise and trademark exposure. | https://veyraapp.com/ ; https://veyra.co.in/ ; https://www.veyra-llc.com/about/ ; https://veyraweb.com/about ; https://withveyra.com/ | **high** |
| **Mythra** | `Mythra` is a lead character in Nintendo's **Xenoblade Chronicles 2** (and a Smash Bros. fighter) — an active, litigious IP holder. Also an AI platform at `app.mythra.space`, plus multiple YouTube/SoundCloud identities. | https://www.reddit.com/r/SmashBrosUltimate/comments/urbh44/any_tips_for_playing_pyramythra/ ; https://app.mythra.space/about | **high** |
| **Halcyon** | Multiple shipping **music players** already use it: `Kifranei/Halcyon` (MIUI/HyperOS-style Android music player, **162★**, Apache-2.0, active 2026-09); `Halcyoninae/Halcyon_v2` ("Native Audio Player"); `exoad/HalcyonLite` ("lightweight development of the Halcyon music player"). Direct same-category collision. | https://github.com/Kifranei/Halcyon ; https://github.com/Halcyoninae/Halcyon_v2 ; https://github.com/exoad/HalcyonLite | **high** |
| **Auralis** | 823 GitHub matches; the term is owned in search by `astramind-ai/Auralis`, a **625★** TTS engine with a commercial homepage. Also `antonpme/auralis-pulse`. Audio-adjacent, so confusion is plausible. | https://github.com/astramind-ai/Auralis ; https://github.com/antonpme/auralis-pulse | **high** |
| **Kestrel** | **`Kestrel` is Microsoft's cross-platform web server for ASP.NET Core** — the default server in every ASP.NET template (verified directly from Microsoft's docs). A desktop *media app* named Kestrel is permanently unfindable and collides with a first-party product. Additionally a "Kestrel Sound" Android app exists on Play. | https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel ; https://play.google.com/store/apps/details?id=appinventor.ai_caio_carlos222.kastrel | **high** |
| **Velora** | `velora.com` is **Velora Studios, LLC**, a live Austin-based design studio (© 2008-2026) with an active X/Twitter handle. Separately, `VeloraDEX/sdk` is a **774★** crypto project shipping the `velora` topic with a live `velora.xyz`. | https://velora.com ; https://github.com/VeloraDEX/sdk | **high** |
| **Lumen / Nova** *(rejected)* | Both are established in developer/consumer infrastructure (Laravel's Lumen micro-framework; OpenStack Nova; Nova Launcher). Bare use is not defensible. | `[UNVERIFIED — collision not checked; illustrative rejects, no search performed]` | **high** |
| **All candidates — Flathub** | Flathub's app index could **not** be queried: the search page is client-rendered and `/api/v2/search` returned HTTP 405. **No Flathub collision check was performed for any candidate.** | `[UNVERIFIED — collision not checked]` | — |
| **All candidates — Microsoft Store / App Store / Google Play APIs** | No store search API was reachable. Store-listing collision for every candidate is **unchecked** except where a search-result URL is listed above. | `[UNVERIFIED — collision not checked]` | — |

### 3.2 What the collision data actually says

Not one of the 13 names checked is clean in the media-player space. The general pattern: short, pronounceable, `-a`-ending coinages are exactly the names every AI/dev-tool startup picks now (Velora, Veyra, Auralis all have AI-company tenants). The two lowest-collision candidates — **Zerolume** and **Zylova** — are low-collision precisely because they are *less* natural, which is the trade being made.

---

## 4. Top-3 shortlist and recommendation

### Shortlist

| Rank | Name | Why it is on the list | Why it is not rank 1 |
|---|---|---|---|
| **1** | **Zerova** | Best balance found: 6 chars, 2 syllables, one word, medium-neutral (R10), legal package segment (R6), no media-app collision, keeps the owner's `Zero` identity (`tzero86`). Reads as a deliberate brand, not a utility. | `zerova.com` is registered to a live (unrelated) company, so the `.com` is likely not obtainable and a real trademark search is required. |
| **2** | **Zerolume** | The cleanest *observed* collision profile — literally zero projects on GitHub. Directly satisfies R10 (light + sound + video), and is unambiguous when spoken. | Clunkier: 3 syllables in 8 chars, and a blended coinage is harder to remember than a 2-syllable one. Only checked against GitHub + generic web; stores unchecked. |
| **3** | **ZeroPlay** | Owner preference; genuinely readable; keeps the `Zero` identity; 8 chars fits every surface. | Weakest of the three on paper: an existing GitHub media player, an existing Google Play **developer** named "ZeroPlay Games", a for-sale `.com`, **and** a semantic problem — see below. |

### On `ZeroPlay`, honestly

- **Is it taken?** Partially. Nothing is a household name, but a 46★ CLI media player, a short-video player repo, a Play Store developer entity, and a for-sale domain all share the string. It is **not** free whitespace.
- **Does it read well?** It reads well *as a brand*, but it has a real ambiguity problem: **"Zero Play" parses as "no playback" / "playback is zero"** — an unfortunate literal reading for a media player, especially on a TV launcher row where the label is read without context. `PlayZero` inverts it and reads worse.
- **Does the word order hurt?** Yes, mildly. `Zero` in first position is being used as a modifier ("a play app from Zero"), which only parses for people who already know the owner's `tzero86` identity. For everyone else the compound reads as a statement about playback quantity. It is workable with a strong wordmark and a distinctive icon, but it is a real cost, not zero.

### Recommendation

> **Recommended final name: `Zerova`**
> **Recommended identity: `io.github.tzero86.zerova`** for the Android `applicationId`, macOS `PRODUCT_BUNDLE_IDENTIFIER`, and Linux `APPLICATION_ID`; `Zerova` for the TV launcher label, Windows `ProductName`, installer `MyAppName`, and release title; `zerova` for the Dart package name, the Windows/Linux binary, and the `.desktop`/AppImage/`.app` slugs.

For a product whose distribution is word-of-mouth (FMHY, `alternativeto.net`, GitHub releases), the deciding factors are *findability* and *zero unwanted legal surface*. `ZeroPlay` loses findability to an existing media player and a Play Store developer; `Zerolume` wins findability but loses memorability; `Zerova` is the best point on that curve and preserves the owner's existing `tzero86` branding equity.

> **Mandatory before committing:** this document is **not** legal or store availability clearance. Before the name is frozen in `build.gradle.kts:24` (where a mistake cannot be undone without data loss), the owner MUST run (a) a trademark search in their jurisdiction and the US/EU, covering at least Nice classes 9 and 41; (b) a Google Play **app-name availability** check by attempting a listing, and the equivalent for Microsoft Store; and (c) a domain/handle availability check for `zerova.*`. Web search results are evidence of *existing use*, not of *absence of rights*.

---

## 5. Placeholder strategy — cheap vs expensive to change later

The owner intends to keep a placeholder temporarily. That is safe **only if the placeholder does not enter the expensive tier.** Ship the placeholder in the cheap tier only.

### 5.1 Cheap to change later (safe to placeholder now)

| Surface | Evidence | Cost to change |
|---|---|---|
| In-app display strings ("PlayTorrio") | `lib/main.dart:144`; `home_page.dart:815,995`; `anime_page.dart:626`; `about_settings_page.dart:19,59,111`; `settings_page.dart:367,590,614,809` | Cosmetic; regenerate and ship an update |
| Windows window title | `windows/runner/main.cpp:49` | Cosmetic |
| Windows exe VERSIONINFO strings | `Runner.rc:92,93,95,96,97` | Cosmetic **except** `ProductName`/`CompanyName` — see §5.2 |
| Installer display name | `installer/windows/setup.iss:5,10,23` | Cosmetic (Start-menu/Apps entry renames on next install) |
| CI artifact / release names | `build.yml:12,174,186-198,250,262,325,374,399` | Breaks bookmarked download URLs only |
| Linux `.desktop` name, AppImage/`.app`/dmg filenames | `build.yml:188,198,262` | Cosmetic |
| Android TV + phone launcher **label** | `AndroidManifest.xml:29` | Cosmetic; the LEANBACK filter at `:57` keeps the app visible throughout |

### 5.2 Expensive / irreversible — decide these **once**, with the final name

| Surface | Evidence | What breaks if changed later |
|---|---|---|
| **Android `applicationId`** | `android/app/build.gradle.kts:24` | Android treats a new applicationId as a **different app**: existing users cannot upgrade, and any Play listing, review history, and install base are abandoned. Also relocates the app's private data dir (`/data/data/<applicationId>` → all SharedPreferences below). |
| **Android `namespace`** | `build.gradle.kts:9` | Must move with applicationId in this layout; R-class paths. |
| **Inno Setup `AppId` GUID** | `installer/windows/setup.iss:15` | Controls Windows in-place upgrade + uninstall registration. A new GUID produces a second parallel install and an orphaned uninstall entry, and `DefaultDirName` collisions between old/new. |
| **Windows data directory** (`path_provider_windows` derives `%APPDATA%\<Company>\<Product>` from the exe VERSIONINFO) | `Runner.rc:92` `CompanyName`, `Runner.rc:98` `ProductName` | Changing `CompanyName`/`ProductName` after release silently moves the app's data dir — settings, addon list, history appear wiped. |
| **Hardcoded on-disk directory names** | `lib/services/audiobook/custom_audiobook_service.dart:134` (`PlayTorrio/CustomAudiobooks`); `books/epub_cover.dart:25` (`PlayTorrio/AudiobookCovers`); `audiobook/paper2audio_service.dart:302` (`PlayTorrio/GeneratedAudiobooks`); `books/book_download_service.dart:24` (`PlayTorrio/Books`); `music/music_download_service.dart:80` (`PlayTorrio/Music`); `utils/download/download_path_helper.dart:75` (`Downloads/PlayTorrio`) | These are **literal strings, not derived from the package id**. Renaming them orphans every downloaded audiobook, book, music track, and download on disk — with no migration, the user's library simply vanishes. |
| **Persisted SharedPreferences keys** | `focus_mode_view.dart:72` (`playtorrio_seen_focus_coach_v2`); `anime_library_service.dart:13-14` (`playtorrio_anime_watchlist_v1`, `playtorrio_anime_history_v1`) | Renaming silently resets watchlist + anime history + coach state. Cheap to *keep*; must not be renamed as part of a "find and replace". |
| **Built-in addon ids + baseUrls** | `addon_manager.dart:29,33,104-107,121-143` (`builtin.playtorrio`, `builtin.playtorriohttp`, `builtin:playtorrio`, `builtin:playtorriohttp`); matched at `watch_screen.dart:110-114,280-293,3076-3077` and `settings/addons_settings_page.dart:159,412-413` | Persisted in the user's installed-addon list and matched by **string equality** against resume records (`continue_watching_item.dart:24,99,149`). Renaming these breaks addon enable/disable state, provider ordering, and torrent/HTTP toggle semantics for existing users — and `watch_screen.dart:284` would stop matching stored `addonName` values. |
| **`LegalCopyright` / attribution strings** | `Runner.rc:96`; `AppInfo.xcconfig:14` | Not a rename risk but a **GPL compliance** one — must not be dropped in a rebrand. Coordinate with the attribution slice. |

### 5.3 Recommended split

1. **Decide `applicationId` / bundle id / GCC app id / Inno `AppId` ONCE**, using the final chosen name — not the placeholder. If a placeholder must ship, ship it with today's ids (`com.example.playtorrio`), and treat the id change as the *one* deliberate breaking release, done with the final name.
2. **Keep the display layer swappable** — UI strings, window title, launcher label, installer name, artifact names. A single rename pass can move all of these later.
3. **Freeze the data layer** — do **not** rename the `PlayTorrio/` on-disk directories or the `playtorrio_*` preference keys or the `builtin.*` addon ids during a cosmetic rebrand. If they must change, ship a one-time on-first-run migration that moves directories and re-keys preferences, and keep reading the old names. This is the single most damaging shortcut available in this whole rename.
4. **Fix the pre-existing inconsistency while there:** `lib/pages/settings/settings_page.dart:368` hardcodes `packageName: 'com.playtorrio'`, which matches no build config in the repo (`build.gradle.kts:24` says `com.example.playtorrio`). It is only a PackageInfo fallback, but it should be corrected to the real id rather than renamed to a guess.

---

## 6. Do-not-use warning list

Names that collide with, or falsely imply affiliation to, existing products/services in this space. Everything in this list is a separate hazard class from ordinary name collision: it can trigger store takedowns or a complaint from the affected vendor.

| # | Avoid | Why | Evidence |
|---|---|---|---|
| 1 | Anything containing **`Stremio`** | The app consumes Stremio addons (`pubspec.yaml:2`; `addon_manager.dart:127` region; `debrid_settings_page.dart:372`). Stremio is a third-party product; naming yourself `Stremio*` implies endorsement/affiliation. Describe compatibility in the description instead. | `pubspec.yaml:2`; `lib/pages/settings/debrid_settings_page.dart:372` |
| 2 | Anything containing **`Torrio`** / **`PlayTorrio`** as the product name | Upstream's identity. Keeping the stem fails the distinctness requirement (R3) and reads as upstream impersonation — a separate issue from the GPL licence, which permits forking but not passing off. | https://playtorrio.pages.dev/ ; `LICENSE` (GPL v3, `Copyright (C) 2026 Ayman`) |
| 3 | **`Torr`-prefixed names** (`TorrStream`, `TorrPlay`, `Torrflix`) | Reads as a torrent tool (violates R1) *and* is one letter from TorrServer, the engine named at `addon_manager.dart:127`. Worst of both worlds. | `lib/services/addon/addon_manager.dart:127` |
| 4 | Anything containing **`Plex`, `Kodi`, `Jellyfin`, `Emby`** | Established media-server brands with enforcement history; a media client carrying their name implies affiliation. Also actively confusing for users looking for the real thing. | `[UNVERIFIED — no web search performed for these; listed from established knowledge]` |
| 5 | **`Real-Debrid`, `Debrid`, `AllDebrid`, `Premiumize`** | Third-party paid services the app integrates with (`debrid_settings_page.dart:372,419`). Naming the product after one implies a partnership that does not exist and makes the app's legality a function of that vendor's ToS. | `lib/pages/settings/debrid_settings_page.dart:372,419` |
| 6 | **`TorrServer`**, or naming a feature/release the same as the embedded engine | `addon_manager.dart:127` names TorrServer as the built-in engine. Third-party component; do not brand on it. | `lib/services/addon/addon_manager.dart:127` |
| 7 | **`Kestrel`** | Microsoft's ASP.NET Core web server — an unrelated first-party product. Verified. | https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel |
| 8 | **`Mythra`** | Nintendo's Xenoblade Chronicles 2 character. Active IP holder. | https://www.reddit.com/r/SmashBrosUltimate/comments/urbh44/any_tips_for_playing_pyramythra/ |
| 9 | **`ZeroPlay`** *(if the final name is chosen elsewhere — it is on the shortlist, so this is conditional)* | An existing Google Play **developer account** named "ZeroPlay Games" and an existing GitHub **media player** named `zeroplay`. Using it as a *stopgap* while a final name is chosen is fine; do not launch a store listing under it without the checks in §4. | https://play.google.com/store/apps/developer?id=ZeroPlay+Games ; https://github.com/HorseyofCoursey/zeroplay |
| 10 | Any name containing **`free`, `HD`, `4K`, `1080p`, `movies`, `stream-free`** | Classic pirate-app keyword signature. Store review and ad networks flag these strings; they also violate R1/R10. | `[UNVERIFIED — heuristic, no web search]` |
| 11 | **`FMHY`** or anything implying endorsement by the FMHY curation list | The project is merely *listed* there (https://fmhy.net/posts/Nov-2025). Implying endorsement would misrepresent a third party. | https://fmhy.net/posts/Nov-2025 |

---

## 7. Open questions / [UNVERIFIED]

1. **`[UNVERIFIED — collision not checked]` Flathub** could not be queried (JS-only search; `/api/v2/search` HTTP 405). No candidate has been checked against Flathub. This matters because `linux/CMakeLists.txt:10` ships a `com.example.playtorrio` app id and Flathub enforces app-id ownership.
2. **`[UNVERIFIED — collision not checked]` Microsoft Store / App Store / Google Play APIs** were unreachable. Store name availability for every candidate is unchecked; §4 requires the owner to verify by attempting a listing.
3. **`[UNVERIFIED]`** What `zerova.com` (a live site, Zerova-branded, with a privacy policy) actually sells. If it is an EV-charging brand, the `.com` and likely the trademark are unavailable; this is the single fact most likely to disqualify the recommendation. **Verify before committing.**
4. **`[UNVERIFIED]`** Trademark registers (USPTO/EUIPO) were not searched at all — no register API was reachable. Nothing in this document substitutes for that search.
5. **`[UNVERIFIED]`** Whether the owner already holds a domain or company name that should define the `<vendor>` reverse-DNS root. This document assumes `io.github.tzero86` (from the established `github.com/tzero86` remote) as the zero-cost default; a custom domain is strictly better if one exists.
6. **Open question — name for the built-in providers.** The `builtin.playtorrio` / `builtin.playtorriohttp` ids (and their user-visible labels "PlayTorrio", "PlayTorrioHTTP", `settings_page.dart:577,590,603,614,809`) are shown in the UI and persisted. The owner must decide whether the *provider* brand follows the *product* brand — and if yes, that decision carries the migration cost in §5.2.
7. **Open question — iOS.** `build.yml:374` ships `PlayTorrio-iOS.ipa`. iOS is not listed as a primary target (Windows desktop + Android TV). If it is retained, the same `com.example.*` defect applies at `AppInfo.xcconfig:11`.
