# Performance Optimization playbook — PlayTorrioZero release build

**Status:** assessment + plan. **No source files edited yet.** This document outlines concrete refactors to reduce the release‑build footprint while preserving all features. It synthesizes evidence from:

- Asset inventory (`assets/`, native resources), file sizes, format analysis.
- Dependency and build‑configuration audit (`pubspec.yaml`, `build.gradle.kts`, CI pipelines).
- Code‑pattern audit (ListViews, image caching, state‑management rebuilds, startup init) across `lib/` production pages.

Evidence points to a **~217 MB debug APK**, **~132 MB Windows debug kernel**, plus bundled fonts/shaders and many non‑const lists that trigger repeated rebuilds. The plan is organized by impact tier and includes acceptance criteria so that an executor can verify each change.

---

## 0. TL;DR

| Priority | Refactor | Estimated impact |
|---|---|---|
| **1** | Android **minifyEnabled + shrinkResources + ProGuard**; add release signing | Measured: release APK 54.07 → 50.66 MB (arm64, −6.3 %). The 217 MB debug baseline was mostly debug-only weight — see §9 |
| **2** | **CachedNetworkImage** shared cache + bounded decode | Delivered: 98 sites + 13 `Image.network` → cached; 23 got `memCacheWidth`. Memory/scroll gain **not measured** (needs a profile run) |
| **3** | ~~**ListView/GridView** keepalive/cache sweep~~ | **Dropped** — measured no-op for stateless card rows; see §5.3 correction |
| **4** | **mk.Video** wrapped in `RepaintBoundary` | Delivered — stops control/HUD fades from *repainting* the video layer (not a rebuild elimination) |
| **5** | **main.dart** startup split | Delivered: 14 network/process/IO inits moved behind first frame. Startup time **not measured** here |
| **6** | Anime4K shader pruning + icon split (font subsetting rejected) | Bundle **2349 KB → 437 KB** shaders, icon **1019 KB → 20 KB**; **−2.99 MB measured** in the shipped bundle |
| **7** | MouseRegion setState hover → `AnimatedContainer` | **Not done** in this pass (lower value than the delivered items; needs per-widget judgement) |
| **8** | CI `--split-debug-info` + symbols artifacts + **missing Android job added** | `--obfuscate` rejected: it would corrupt scraper provider ids (§5.8) |

---

## 1. Measurement summary (artifact sizes)

| Item | Current size (approx) | Target | Path |
|---|---|---|---|
| Android debug APK (`app-debug.apk`) | **217.5 MB** (`build/app/outputs/flutter-apk/app-debug.apk`) | `<80 MB` (minify/shrink) | — |
| Windows debug kernel blob (`kernel_blob.bin`) | **123 MB** (`build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin`) | Same (cannot shrink without optimization) | — |
| Android `com.example.playtorrio` data dir (native) | **~150 MB** (forecast, depends on `config.db`, shader/font caches) | <50 MB (after above) | `%APPDATA%\Roaming\com.example.playtorio\` |
| `assets/fonts` (Poppins + Playfair) | **900 KB** (`assets/fonts`) | <500 KB (subset) | — |
| `assets/shaders/anime4k` | **2.4 MB** GLSL files | 0 MB (lazy load) | — |
| Icon set (`assets/icon.png`) | **1 MB** | Same (single file) | — |
| Windows native libs (`torrserver.exe`, `libmpv-2.dll`, etc.) | **61 MB** (`torrserver.exe`) + others | Same (no change) | `build/windows/...` |

**Evidence:** file-system `du`, `pubspec.yaml` asset declarations, `pubspec.lock` dep footprint (`media_kit`, `pdfium_flutter`, `torrserver_flutter` are large native bundles). Android debug signing exists → large APK; Windows debug build uses full PDB + debug symbols.

---

## 2. Asset audit

### A. Current asset layout (top 20 by size)

| Path | Size (KB) | Pubspec ref? | Used by | Optimization available |
|---|---|---|---|---|
| `assets/shaders/` (anime4k GLSL) | 2400 | No | shader loader | Lazy load per upscaling preset; split bundles |
| `assets/fonts/` (Poppins, Playfair) | 900 | Yes (`fonts: assets/fonts/**`) | UI text | Subset fonts (include only weights: Regular + Bold for UI, defer Italic for reading) |
| `assets/subfont.ttf` (dup) | 156 | No | duplicate of fonts/subfont.ttf | Merge into fonts; drop duplicate |
| `assets/icon.png` | 1020 | Yes (`flutter_launcher_icons.image_path`) | Launcher icons (all platforms) | Single PNG already optimal |
| `android/app/src/main/res/mipmap-xxxhdpi/` | 16 | Yes | Android launcher icons | No loss; keep but consider vector drawables |
| `android/app/src/main/res/values-night` | 4 | Yes | Theme Night mode | No change |

### B. Recommendations (asset)

1. **Font subsetting** – drop unused weights/styles from Poppins/Playfair; target ~400 KB total. Acceptance: `assets/fonts/` size <500 KB.
2. **Shader lazy load** – split `anime4k` GLSL files into preset bundles (`upscale2x.glsl`, `upscale4x.glsl`, `denoise.glsl`). Load only selected ones at runtime. Acceptance: `assets/shaders/` bundle <100 KB.
3. **Duplicate subfont removal** – delete `assets/subfont.ttf`; update references.

---

## 3. Dependency footprint audit

### 1. Largest packages (pub-cache estimated via `du -sh ~/.pub-cache/hosted/pub.dev/*` on a build machine)

The workspace’s pub‑cache is not present in this container, so exact sizes are not measured; however, the **pubspec.lock** lists the top‑size native bundles:

| Package | Version | Native payload (approx) | Notes |
|---|---|---|---|
| `media_kit` (git) | custom | large (media player engine) | Used for video playback, includes bundled libs |
| `media_kit_libs_windows_video` | 1.0.11 | several MB (ffmpeg‑like libs) | Windows video surface |
| `pdfium_flutter` | 0.3.0 | ~6 MB (`pdfium.dll`) | PDF rendering |
| `torrserver_flutter` | 0.0.6 | ~61 MB (`torrserver.exe`) | Torrent server binary |
| `sqflite` | 2.4.4 | native extension (~2 MB) | SQLite local DB |
| `flutter_cache_manager` | 3.4.2 | ~2 MB | Image/network caching |
| `file_picker` | 8.1.7 | native plugins (~1 MB) | File selection |
| `path_provider` | 2.1.6 | small | Path utilities |
| `crypto`, `pointycastle` | ~1 MB | cryptography |

### 2. Build configuration audit

| Item | Current state | Gap / opportunity | Path |
|---|---|---|---|
| `android/app/build.gradle.kts` `buildTypes.release.minifyEnabled` | `false` (absent) | **Missing** — enables ProGuard/R8 shrinking | `android/app/build.gradle.kts:40` |
| `shrinkResources` | `false` (absent) | Same | `android/app/build.gradle.kts:40` |
| ProGuard/rules file | none (`proguard-rules.pro` missing) | No shrink/optimize | `android/app/` |
| Release signing config | `debug` (`signingConfigs.getByName("debug")`) | **Unsigned** release → every install overwrites data, security risk | `android/app/build.gradle.kts:53` |
| Windows release flags (`--obfuscate`, `--split-debug-info`) | not in CI (`.github/workflows/build.yml:55`) | Missing for artifact size reduction | CI workflow |

### 3. Recommendations (deps/build)

1. **Enable Android minify + shrinkResources + ProGuard** → expected APK size <80 MB. Acceptance: `build/app/outputs/flutter-apn/app-release.apk` <100 MB.
2. **Add release keystore** (`key.properties`, `signingConfigs.release`) for OTA upgrade continuity. Acceptance: CI uploads signed APK.
3. **Add `--obfuscate` and `--split-debug-info .symbols`** to all release builds (Windows/macOS/Linux) → reduce artifact size, remove debug symbols.
4. **Consider dependency alternatives** (e.g., replace `pdfium_flutter` with `flutter_pdfview` if smaller) if feasible.

---

## 4. Code‑pattern audit

### 4.1 Hot‑paths & startup issues

| File:lines | Role | Issue | Risk |
|---|---|---|---|
| `lib/main.dart:41-50` | App init | `Future.wait` of ~22 services blocks UI; sequential or isolate recommended | **H** |
| `lib/pages/home/home_page.dart:480` | Home page | `unawaited(_ensureAnimeRows())` without error handling → silent failures | **H** |
| `lib/pages/home/home_page.dart:796` | Carousel timer | `Timer.periodic` never shown cancelled in build; needs dispose | **M** |
| `lib/pages/audiobook_player_screen.dart:79` | Audiobook | Timer.periodic 5s; stream subscriptions not cancelled | **M** |
| `lib/pages/anime/anime_details_page.dart:129` | Anime | `Future.wait` for 3 feeds; large arrays held in state | **M** |
| `lib/pages/player/player_screen.dart` | Player | mk.Video rebuilt via controller changes; setState on every volume/playback event; no RepaintBoundary | **M** |

### 4.2 List / scroll rebuild audit

All production `ListView.builder`/`GridView.builder` (≈30+ sites) lack `const`, `addAutomaticKeepAlives:false`, `cacheExtent`. Only `iptv_portal_browser_page.dart:1202` has the full-good set. Samples: `home_page.dart:739`, `anime_search_page.dart:306`, `catalog_page.dart:245`, `details_page.dart:794`, `anime_details_page.dart:897/1276/1432`.

### 4.3 Image / cache audit

- `CachedNetworkImage` used ~40+ times; none use `const`, almost none set `memCacheWidth/Height`. Only `iptv_portal_browser_page` and some player thumbnails set `memCacheWidth/Height`. No custom `CacheManager`; default only.
- `Image.network` uncached: `anime_arabic_stream_sheet.dart:168`, `manga_details_page.dart:134/553/662`.
- `BoxFit.cover` everywhere; `filterQuality: FilterQuality.high` at `anime_page.dart:1097` increases GPU load.
- Placeholder/error widgets use anonymous closures (new closure per build).

### 4.4 State management rebuild audit

- `setState` used widely (`wewatch_quiz`, `anime_details`, `anime_details_modal`, `anime_page`, `anime_search`, `audiobook_player`, `books`, `home`).
- Many rebuild entire pages on hover/scroll changes (`MouseRegion` setState for arrows).
- No `Provider`/`Riverpod` usage; `ValueNotifier` in `AppThemeService` triggers full MaterialApp rebuild.
- No `RepaintBoundary` around `mk.Video` in `player_screen.dart`.

### 4.5 Top 10 largest Dart files (lines, measured)

| File | Lines |
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
| `lib/pages/anime/anime_stream_sheet.dart` | ~400+ |

These files contribute to startup latency and rebuild cost.

---

## 5. Concrete refactors (ranked by impact)

### 5.1 Android shrink + release signing (≈63 % APK size reduction)

1. **Gradle changes**
   ```kotlin
   // android/app/build.gradle.kts
   buildTypes {
       release {
           isMinifyEnabled = true          // enable R8/ProGuard
           isShrinkResources = true        // drop unused resources
           signingConfig = signingConfigs.getByName("release")
       }
   }
   ```
2. **Create key.properties** (`android/key.properties`) and `signingConfigs { release { keyAlias, storeFile, storePassword, keyPassword } }`.
3. **Add proguard-rules.pro** if custom logic needs preserving.
4. **Acceptance:** `build/app/outputs/flutter-apk/app-release.apk` <100 MB (expected ~70‑80 MB).

### 5.2 CachedNetworkImage optimization

- Add `memCacheWidth`/`memCacheHeight` to all usages; use `const` placeholder/error builders.
- Create custom `CacheManager` with extended maxAge (e.g., 24 h).
- Replace `Image.network` with CachedNetworkImage (or ensure caching).
- **Acceptance:** grep shows `memCacheWidth` or `memCacheHeight` on each CachedNetworkImage; no `Image.network`.

### 5.3 ListView/GridView const + cache + keepalive

> **Correction (2026-09-14, measured):** `addAutomaticKeepAlives: false` is a no-op for
> the lists in this app. It only affects children that *request* keep-alive
> (`AutomaticKeepAliveClientMixin` / `KeepAliveNotification`), i.e. text fields and
> live video tiles — this UI's list children are stateless poster cards. Mass-editing
> the 104 builders would have been churn with no measurable effect, so it was dropped.
> Sliver children already get automatic `RepaintBoundary` wrapping.

What actually moves the needle on scroll cost, in order:

1. **Bounded image decode** (§5.2, delivered) — the dominant per-item cost.
2. `const` card constructors where the builder's arguments allow it (skips rebuilds).
3. `prototypeItem`/`itemExtent` only where the extent is genuinely uniform — not
   applicable to this app's variable-height text rows.

- **Acceptance:** unchanged — verify with a profile-mode scroll trace, not by grepping
  for parameters that do nothing.

### 5.4 Video widget RepaintBoundary

- Wrap `mk.Video` in `RepaintBoundary`; separate overlay widgets (controls, title) into independent `ValueListenable`s.
- **Acceptance:** In `player_screen.dart`, the `mk.Video` is inside a `RepaintBoundary`; playback events do not call setState on the video subtree.

### 5.5 Main.dart init isolation

- Split the 22‑service `Future.wait` into groups or load in background isolates (`compute(() => loadServices(), ...)`).
- Or implement lazy service registry (on‑demand load when navigated to).
- **Acceptance:** Time from splash to UI ready <2 s.

### 5.6 Font subsetting & shader lazy load

- **Fonts:** Keep only required weights (Regular, Bold) from Poppins + Playfair; drop Italic/Condensed; repack.
- **Shaders:** Split `assets/shaders/anime4k/` into per‑preset files; load only selected.
- **Acceptance:** `assets/fonts/` <500 KB; `assets/shaders/` <100 KB.

### 5.7 MouseRegion setState → AnimatedContainer

- Replace hover arrow visibility setState with `AnimatedContainer`/`AnimatedOpacity`.
- **Acceptance:** `grep -n "setState" lib/pages/anime/anime_details_page.dart` reduced by >30 %.

### 5.8 CI release flags

- Delivered: every `flutter build … --release` step in `.github/workflows/build.yml`
  now passes `--split-debug-info=build/symbols` and uploads the symbol directory.
- **`--obfuscate` was deliberately rejected.** `lib/services/scraper/stream_scraper.dart:9-10`
  derives `providerId`/`providerName` from `runtimeType.toString()`:

  ```dart
  String get providerId => runtimeType.toString().replaceAll('Scraper', '').toLowerCase();
  String get providerName => runtimeType.toString().replaceAll('Scraper', '');
  ```

  Under symbol renaming those become `minified:aX`, silently corrupting provider
  identity, dedup (`s.runtimeType == scraper.runtimeType` still works, but the ids do
  not) and anything keyed on them — a release-only failure with no analyzer signal.
  Prerequisite for enabling obfuscation: give each scraper an explicit id/name constant.
- The workflow also had **no Android job** despite its header advertising split-per-ABI
  APKs and a `*.apk` glob in the release job; an `android` job (per-ABI release APKs,
  optional keystore from secrets, symbols artifact) was added and wired into `release.needs`.

---

## 6. Verification checklist

Run after the first cycle of changes (maybe only the high‑impact ones) to confirm the document’s claims:

```bash
# 1. Asset audit
du -sh assets/fonts && du -sh assets/shaders && du -sh assets/icon.png
# Expect: fonts <500KB; shaders <100KB; icon unchanged

# 2. Build artifacts (after Android release build)
ls -lh build/app/outputs/flutter-apk/app-release.apk
# Expect size <100MB

# 3. Code patterns (shell checks)
git grep -n "setState" lib/pages/home/home_page.dart lib/pages/anime/anime_details_page.dart lib/pages/player/player_screen.dart
# Expect fewer setState instances (specific reduction counts per page)

# 4. ListView/GridView const
git grep -n "ListView.builder" lib/pages/ | grep -v "addAutomaticKeepAlives" | grep -v "cacheExtent" | wc -l
# Expect 0 (all have at least one of these)

# 5. CachedNetworkImage memCache
git grep -n "CachedNetworkImage" lib/pages/ | grep -v "memCacheWidth" | wc -l
# Expect 0
```

---

## 7. Annexes

- **A. Asset audit details** → `docs/optimize/asset-audit.md`
- **B. Dependency & build audit** → `docs/optimize/deps-build-audit.md`
- **C. Code‑pattern audit** → `docs/optimize/code-audit.md`

---

## 8. Next steps

1. **Prioritize Android shrink + signing** (clearest size win, also fixes OTA).
2. **Configure CachedNetworkImage** and replace `Image.network` usages.
3. **Iterate ListView/GridView const + cache** across the production pages; consider splitting large home page into smaller widgets.
4. **Apply video RepaintBoundary** and separate overlay controllers.
5. **Add CI release flags** for all platforms.
6. **Font/shader subsets** (optional, lower priority).

---

Prepared 2026‑09‑14 by the performance‑optimization reconnaissance effort.

---

## 9. Implementation log (2026-09-14)

Delivered in this pass. Every entry is in the working tree; nothing is committed.

### Artifact size

| Change | Evidence |
|---|---|
| `android/app/build.gradle.kts` release: `isMinifyEnabled`, `isShrinkResources`, `proguardFiles`, `ndk.abiFilters = [arm64-v8a, armeabi-v7a]`, keystore-optional signing from `android/key.properties` (debug fallback keeps `flutter run --release` working) | `android/app/build.gradle.kts` |
| `android/app/proguard-rules.pro` (engine + plugin method-channel keeps), `android/key.properties.example` (keystore template; `/android/key.properties`, `*.jks`, `*.keystore` already git-ignored) | new files |
| Bundled Anime4K shaders cut from **39 files / 2349 KB → 9 files / 437 KB** — only files the presets reference; unreferenced `glsl` files stay in the repo, the pubspec lists the 9 explicitly | `pubspec.yaml`, `lib/services/player/player_settings.dart:264-276` |
| Launcher icon split: 2000×2000 `assets/icon.png` (1019 KB) no longer bundled (still read by `flutter_launcher_icons` at build time); runtime uses new `assets/icon_small.png` (256×256, **20.4 KB**) at the 6 call sites | `pubspec.yaml:152-168`, `home_page.dart:809,989`, `anime_page.dart:619`, `watch_screen.dart:3096`, `addons_settings_page.dart:500`, `addon_manager.dart:108` |
| Byte-identical duplicate `assets/subfont.ttf` (156 KB, same md5 as `assets/fonts/subfont.ttf`, which is the earlier candidate in the same list) deleted + unlisted | `lib/services/player/player_settings.dart:346-351` |
| CI: `--split-debug-info=build/symbols` + symbols artifact on all 5 build jobs; **new `android` job** producing per-ABI release APKs; no `--obfuscate` (see §5.8) | `.github/workflows/build.yml` |

Net bundle reduction from assets, **measured**: `data/flutter_assets/assets` on Windows went
**4,506,866 B → 1,368,816 B (−2.99 MB)**; the identical asset set ships on Android.

### Runtime

| Change | Where |
|---|---|
| `AppImageCache.manager` — named `CacheManager` (800 objects, 30-day stale) shared by all artwork | new `lib/services/storage/app_image_cache.dart`; `flutter_cache_manager` promoted to a direct dependency |
| All **98** `CachedNetworkImage` sites now pass `cacheManager:`; **23** of them also get a bounded `memCacheWidth` derived from the widget's literal width (×3 DPR, clamped 96–1280) | codemod `tools/apply_image_cache.py` |
| All **13** uncached `Image.network` calls converted to `CachedNetworkImage` (11 codemod + 2 hand-edited in `player_screen.dart`), including the full-bleed player backdrop and logo | `lib/**` |
| `mk.Video` wrapped in `RepaintBoundary` — control fades, volume/aspect HUDs and subtitle edits no longer repaint the video surface | `lib/pages/player/player_screen.dart:1427-1446` |
| Startup split: only first-frame-critical services are awaited before `runApp` (theme, env, player settings, home/my-list/continue-watching, background/glass/dock/content settings); 14 catalog/download/music/torrent/Discord initializers moved to `_initializeDeferredServices()` behind per-service `try/catch` logging | `lib/main.dart` |

### Investigated and deliberately not changed

- **`addAutomaticKeepAlives` sweep** — no-op here (§5.3 correction).
- **Font subsetting** — rejected: `Poppins`/`subfont.ttf` are the libass subtitle fallback, so a Latin-only subset would drop glyphs for non-Latin subtitle tracks. Feature-preserving constraint beats a ~400 KB win.
- **`--obfuscate`** — rejected, would break scraper provider ids (§5.8).
- **PlayerSettings shader/font extraction off the startup path** — the extraction is existence-guarded and now touches 9 files instead of 39; further deferral risks a first-playback window where the shader chain is empty.
- **Deeper `player_screen` rebuild isolation** — position/buffer already flow through `ValueNotifier`s rather than `setState`; the remaining `setState` calls are genuine UI-state changes.

### Verification (measured 2026-09-14)

| Check | Result |
|---|---|
| `flutter analyze lib` | **0 errors, 0 warnings**; 20 pre-existing style `info`s (curly-brace / `prefer_const_constructors` in `multinutz*`, none in edited regions). A full-tree `flutter analyze` is unusable as a gate here — the vendored SDK at `./flutter/` is inside the project and contributes ~26 k issues of its own |
| `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` | ✅ builds clean with R8 + resource shrinking (needed `-dontwarn com.google.android.play.core.**` for the engine's deferred-components references) |
| APK size, shrink **off** (same assets, same ABIs) | arm64 **54,074,341 B**, armv7 **53,223,837 B** |
| APK size, shrink **on** | arm64 **50,656,991 B**, armv7 **49,806,483 B** → **−3.42 MB per APK (−6.3 %)** |
| Asset pipeline end-to-end (listed inside the built APK) | `assets/flutter_assets/assets/shaders/anime4k/` ships exactly **9** `.glsl` (437 KB); `icon_small.png` (20.4 KB) present; root `icon.png` and `subfont.ttf` **absent** |
| Shader bookkeeping | 9 referenced in `player_settings.dart` == 9 bundled in `pubspec.yaml`; 0 pruned shaders still referenced in `lib/` |

**Honest sizing note.** The "217 MB → <80 MB (63 %)" figure this doc originally carried was wrong.
217 MB was a *debug* APK — all three ABIs, JIT snapshot, unstripped — so most of the drop to
~48 MB is simply building **release** with **two** ABIs, not shrinking. Isolated by the
two builds above, the minify/shrink/resource-shrinking configuration is worth **−6.3 %**;
the asset work (§2) is a further **−2.99 MB** of bundle (measured on the Windows bundle). Both are real, neither is 63 %.

### Windows (the platform under test) — measured

| Item | Value |
|---|---|
| `flutter build windows --release --split-debug-info=build/symbols` | ✅ `playtorrio.exe` built in 102 s |
| `build/windows/x64/runner/Release` total | **145 MB** (vs **298 MB** for the pre-existing `Debug/`) |
| Bundled assets `Release/data/flutter_assets/assets` | **1,368,816 B (1.31 MB)** — was 4,506,866 B in the pre-change `Debug/` bundle → **−2.99 MB** |
| Assets actually shipped | 9 shaders, `icon_small.png`, no root `icon.png`, no `subfont.ttf` |
| Dart symbols | split out to `build/symbols/app.windows-x64.symbols` (6.89 MB), uploaded by CI, never shipped to users |

Where the Windows size actually goes (`Release/`, 145 MB): `torrserver.exe` 63.4 MB,
`libmpv-2.dll` 39.1 MB, `flutter_windows.dll` 21.3 MB, `data/app.so` 15.2 MB,
`pdfium.dll` 7.2 MB, `data/icudtl.dat` 0.86 MB, all plugins ~0.5 MB, `assets/` 1.31 MB.
**≈ 90 % is vendor binaries** — only the 1.31 MB asset slice and the app code are ours to move.

**Correction: the Windows PDB strip step was removed.** Flutter's *Release* configuration emits
no `playtorrio.pdb` (only `Debug/` does, 8.2 MB), so the CI step that deleted `*.pdb` before
packaging did nothing. `--split-debug-info` is what actually externalises symbols on Windows.

### Outstanding

- Runtime gains (startup, scroll memory) still need a profile-mode run — only sizes are measured.
- The dominant Windows lever is *build mode*, not code: `Release` is 145 MB / AOT-compiled versus
  the `Debug` 298 MB with a 128.9 MB `kernel_blob.bin` (JIT). Testing the Debug exe tests the
  slowest configuration the app can be in.
