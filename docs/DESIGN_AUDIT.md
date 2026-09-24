# ZPlay — Design Audit

Baseline measurements taken before any redesign work. Every number here is a
`grep` over `lib/`, reproducible with the commands at the bottom.

## Scope

| | |
|:--|:--|
| Dart files | 331 |
| Lines of Dart | 152,325 |
| Screen files (`lib/pages`) | 66 |
| Screen areas | ai, anime, anime_arabic, audiobooks, books, calendar, catalog, details, discover, downloads, home, iptv, manga, multinutz, music, my_list, player, search, settings |

## Finding 1 — There is no design system, only a palette picker

`lib/services/theme/app_theme_service.dart` defines `AppThemePalette` with **five**
colours (`primaryColor`, `accentColor`, `scaffoldBackgroundColor`,
`cardBackgroundColor`, `appBarBackgroundColor`) and ships 8 presets: Amethyst
Violet (default), Cyberpunk Neon, Emerald Aurora, Sunset Crimson, Midnight
Sapphire, Golden Amber, Vampire Red, Pink Barbie.

`createThemeData()` then applies that palette with `colorSchemeSeed` only. No
component themes, no typography theme, no spacing, no radius scale, no opacity
scale, no elevation scale.

Consequence: every screen hardcodes its own colours on top.

## Finding 2 — 421 distinct hardcoded colours

```
grep -rhoE "0x[0-9A-Fa-f]{8}" lib --include=*.dart | sort -u | wc -l   → 421
```

Most frequent:

| Uses | Colour | Role |
|--:|:--|:--|
| 412 | `0xFF7C5CFF` | primary purple (the default preset, hardcoded) |
| 124 | `0xFF10B981` | green — used as a *second* accent |
| 81 | `0xFFFFFFFF` | |
| 79 | `0xFF00E5FF` | cyan — used as a *third* accent |
| 73 | `0xFF12151E` | surface |
| 65 | `0xFF00D2EF` | cyan again (near-duplicate of the above) |
| 57 | `0xFF0D1017` | background |
| 57 | `0xFF080A0F` | background |
| 45 | `0xFF1A1A1A` | background/surface |
| 43 | `0xFFCC0000` | provider brand |
| 37 | `0xFF003366` | provider brand |
| 35 | `0xFFEF4444` | red |
| 33 | `0xFF0C0F17` | background |
| 32 | `0xFFFFC107` | yellow |
| 25 | `0xFF7C3AED` | *second* purple |
| 24 | `0xFF151822` | background |
| 20 | `0xFFFFD700` | *second* yellow |
| 20 | `0xFF000000` | pure black |
| 14 | `0xFF1E2235`, `0xFF141724` | background |

Sub-problems:

- **Seven near-identical near-black backgrounds** — `0xFF0D1017`, `0xFF080A0F`,
  `0xFF0C0F17`, `0xFF151822`, `0xFF0F121C`, `0xFF1E2235`, `0xFF141724` — that are
  visually indistinguishable. Choose-one territory.
- **Three competing accents** (purple, green, cyan) plus a second purple and two
  extra yellows. One accent should win.
- **Pure `0xFF000000`** appears 20×, which the dark-mode guidance explicitly
  warns against (halation, smearing on OLED).
- Some colours (`0xFFCC0000`, `0xFF003366`) look like third-party provider brand
  colours and should stay hardcoded — they are not ours to systematise.

## Finding 3 — 12+ ad-hoc white-alpha steps

```
grep -rhoE "Colors\.(white|black)\.withValues\(alpha: [0-9.]+\)" lib | sort | uniq -c | sort -rn
```

| Uses | Value | Typical role |
|--:|:--|:--|
| 275 | `white @ 0.08` | border |
| 102 | `white @ 0.06` | border |
| 84 | `white @ 0.1` | border |
| 76 | `white @ 0.12` | border/divider |
| 62 | `white @ 0.05` | border |
| 57 | `white @ 0.15` | |
| 56 | `white @ 0.35` | muted text |
| 49 | `white @ 0.4` | muted text |
| 48 | `white @ 0.5` | |
| 43 | `white @ 0.8` | |
| 41 | `white @ 0.45` | muted text |
| 37 | `white @ 0.2` | |

Five different alphas (0.05/0.06/0.08/0.1/0.12) all mean "hairline border", and
five more (0.35/0.4/0.45/0.5/0.8) all mean "secondary text". This is the missing
**opacity scale**, not a missing colour.

## Finding 4 — 14 corner radii, 18 font sizes

Radii in use: 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 999.

Font sizes in use: 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15,
16, 18, 19, 20, 22.

Half-pixel type sizes at 12 distinct values between 9 and 15 mean there is no
type scale — sizes were chosen per-widget by eye.

## Finding 5 — Platform adaptation is thin

Only 8 files reference any platform or form-factor check
(`Platform.isAndroid`, `Platform.isWindows`, `MediaQuery…shortestSide`):

```
lib/main.dart
lib/pages/iptv/iptv_player_page.dart
lib/pages/manga/manga_reader_page.dart
lib/pages/player/player_screen.dart
lib/pages/settings/addons_settings_page.dart
lib/pages/settings/appearance_settings_page.dart
lib/pages/settings/settings_page.dart
lib/services/anime/extractors/anidb_extractor.dart
```

Targets are phone, tablet, desktop (Windows/macOS/Linux) and **Android TV**
(D-pad + leanback), yet almost no screen adapts its navigation, density, focus
handling or hit targets per form factor.

## What this implies for the redesign

Hardcoded colour is not a cosmetic problem here — it is the reason a redesign is
expensive. With 421 colours and no scales, every screen restyle is bespoke work,
and any palette change means touching hundreds of files.

So the enabling step is a **token layer**, and the screen work should follow it,
not precede it. Priority order (matches the skill's fix-priority guidance):

1. Token layer — semantic colours, opacity, spacing, radius, type scale, elevation
2. Single accent, one neutral ramp, no pure black
3. Focus/pressed/hover states + reduced-motion support
4. Per-form-factor layout (phone / tablet / desktop / TV)
5. Screen-by-screen application

## Reproduce

```bash
# distinct hardcoded colours
grep -rhoE "0x[0-9A-Fa-f]{8}" lib --include=*.dart | sort -u | wc -l

# colour frequency
grep -rhoE "0x[0-9A-Fa-f]{8}" lib --include=*.dart | sort | uniq -c | sort -rn | head -25

# ad-hoc opacity steps
grep -rhoE "Colors\.(white|black)\.withValues\(alpha: [0-9.]+\)" lib --include=*.dart \
  | sort | uniq -c | sort -rn | head -12

# radii and type sizes
grep -rhoE "BorderRadius\.circular\([0-9.]+\)" lib --include=*.dart | grep -oE "[0-9.]+" | sort -n | uniq -c
grep -rhoE "fontSize: [0-9.]+" lib --include=*.dart | grep -oE "[0-9.]+" | sort -n | uniq -c

# scale
find lib -name "*.dart" | wc -l
find lib -name "*.dart" -exec cat {} + | wc -l
```
