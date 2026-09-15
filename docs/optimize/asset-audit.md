# Asset Audit — `assets/` footprint

> Corrected 2026-09-14 after implementation. The first pass claimed `assets/shaders/`
> and `assets/icon.png` were not in the bundle; they were (declared in `pubspec.yaml`
> `assets:`). All "declared" columns below are verified against `pubspec.yaml`.

## Measured (before)

| Path | Size | Declared | Runtime use |
|---|---|---|---|
| `assets/shaders/anime4k/` — 39 `.glsl` files | 2349 KB | yes (directory) | extracted to app-support dir for libmpv `glsl-shaders` |
| `assets/icon.png` — 2000×2000 | 1019 KB | yes | 6 call sites, all ≤ ~51 logical px |
| `assets/fonts/` (Poppins ×4, Playfair, `subfont.ttf`) | 900 KB | yes (directory) | UI text + libass subtitle fallback |
| `assets/subfont.ttf` — byte-identical to `assets/fonts/subfont.ttf` (same md5) | 156 KB | yes | last fallback candidate only (the `fonts/` copy is tried first) |

Native resources under `android/app/src/main/res/` total ~60 KB — not worth touching.

## Delivered

| Change | Effect |
|---|---|
| Bundle only the **9** shaders the presets reference (`PlayerSettings.shaderFiles` is the union of `Anime4KPreset.*.shaderFiles`); the other 30 files stay in the repo, unlisted | **2349 KB → 437 KB**; extraction loop drops 39 → 9 files |
| Stop bundling `assets/icon.png`; keep it for `flutter_launcher_icons` (build-time only) and add `assets/icon_small.png` (256×256, ffmpeg) for the 6 runtime usages | **1019 KB → 20 KB** |
| Delete duplicate `assets/subfont.ttf` + its entry in the candidate list | **−156 KB** (identical bytes, so no coverage lost) |

Net, **measured** in the shipped bundle (`data/flutter_assets/assets`, Windows release):
**4,506,866 B → 1,368,816 B (−2.99 MB, −66 %)**. The same asset set ships on Android.

## Rejected

- **Font subsetting** (`Poppins`, `Playfair`): both feed the libass subtitle font
  fallback in `PlayerSettings._extractLibassFontFallback`. A Latin-only subset would
  drop glyph coverage for non-Latin subtitle tracks — a feature regression for a
  subtitle-centric player. ~400 KB is not worth it.
- **`assets/icon.png` downscale in place**: it is the source image for
  `flutter_launcher_icons` on every platform; shrinking it degrades generated launcher
  art. Splitting into source + `icon_small` gets the size win without that cost.
- **Deleting the 30 unreferenced `.glsl` files**: they are upstream Anime4K files the
  author staged, possibly for future presets. Unlisting them captures the full size win
  with no data loss; re-enabling a preset means re-adding its two pubspec lines.

## Verification

```bash
python - <<'PY'
import re, pathlib
p = pathlib.Path('pubspec.yaml').read_text(encoding='utf-8')
files = re.findall(r'- (assets/shaders/anime4k/[\w.]+\.glsl)', p)
print(len(files), 'shaders declared; missing:', [f for f in files if not pathlib.Path(f).exists()])
PY
# expect: 9 shaders declared; missing: []
grep -rn "'assets/subfont.ttf'" lib/ pubspec.yaml   # expect: no matches
grep -rn "icon_small.png" lib/ | wc -l               # expect: 6
```
