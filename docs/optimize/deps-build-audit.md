# Dependency & Build Audit

## Dependency footprint

The workspace pub-cache is not present in this container, so exact per-package sizes are unavailable. The `pubspec.lock` identifies the largest native bundles:

| Package | Version | Expected native payload | Notes |
|---|---|---|---|
| `media_kit` | git | large | Player engine; includes bundled libs |
| `media_kit_libs_windows_video` | 1.0.11 | several MB | ffmpeg-like native libs |
| `pdfium_flutter` | 0.3.0 | ~6 MB (`pdfium.dll`) | PDF rendering |
| `torrserver_flutter` | 0.0.6 | ~61 MB (`torrserver.exe`) | Torrent server binary |
| `sqflite` | 2.4.4 | ~2 MB | SQLite local DB |
| `flutter_cache_manager` | 3.4.2 | ~2 MB | Network image caching |
| `file_picker` | 8.1.7 | ~1 MB | File selection |
| `path_provider` | 2.1.6 | small | Path utilities |
| `crypto` / `pointycastle` | 3.x | ~1 MB | Cryptography |

## Build configuration audit

| Item | Current state | Gap |
|---|---|---|
| `android/app/build.gradle.kts` `buildTypes.release.minifyEnabled` | absent (`false`) | Missing R8/ProGuard |
| `shrinkResources` | absent (`false`) | Missing resource shrinking |
| `proguard-rules.pro` | missing | No custom shrink rules |
| Release signing config | `debug` (`signingConfigs.getByName("debug")`) | Unsigned release; OTA install data loss |
| Windows release flags | CI runs `flutter build windows --release --dart-define-from-file=.env` (`.github/workflows/build.yml:55`) | Missing `--obfuscate --split-debug-info` |
| macOS/Linux release flags | CI runs `--release` (`.github/workflows/build.yml:166,245`) | Missing `--obfuscate --split-debug-info` |

## Recommendations

1. Enable `minifyEnabled = true`, `shrinkResources = true`, and add `proguard-rules.pro`.
2. Add a release keystore (`key.properties`, `signingConfigs.release`) for OTA upgrade continuity.
3. Add `--obfuscate --split-debug-info .symbols` to all release builds.
4. Consider replacing `pdfium_flutter` with a smaller PDF viewer only if feature parity is preserved.
