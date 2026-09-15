<!-- Annex to docs/RENAME_PRODUCT_PLAN.md — exhaustive per-layer inventory.
     Generated 2026-09-14 by read-only reconnaissance over this repo's working tree.
     `path:line` references match the tree as generated; re-verify before applying edits.
     Rows marked [UNVERIFIED] or [INFERENCE] are unresolved — do not treat them as settled.
     Do not delete rows: an executing agent works this list top-to-bottom. -->

# Inventory — NATIVE platforms / packaging / runtime storage paths

Scope: `android/** windows/** linux/** macos/** ios/** installer/** .github/**`. Non-goals (other agents): `lib/** test/** assets/** web/**` docs. All paths are repo-relative; `.github/**` contains only `workflows/build.yml`.

> NOTE on evidence: derived-path claims (Windows `<Company>\<Product>` dir, Android `files`/`app_flutter`) were verified against the resolved pub cache, not just repo files, because the repo's Dart/native config does not restate them. Those sources are cited with absolute pub-cache paths.

---

## 1. Findings

### 1.1 Android — identity & package

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| android/app/build.gradle.kts:9 | `namespace = "com.example.playtorrio"` | Android/build | yes | `com.<vendor>.<name>` | Gradle/manifest namespace; must equal moved Kotlin package dir |
| android/app/build.gradle.kts:24 | `applicationId = "com.example.playtorrio"` | Android/build | **yes (critical)** | `com.<vendor>.<name>`, OR **keep** `com.example.playtorrio` to retain data/upgrades | Package identity = private data dir key, SharedPreferences dir, OTA authority. Changing it breaks in-place upgrade AND orphans all user data (see §2.1). |
| android/app/build.gradle.kts:29 | `versionCode = flutter.versionCode` | Android/build | keep | (derived) | plumbing; see §1.10 |
| android/app/build.gradle.kts:30 | `versionName = flutter.versionName` | Android/build | keep | (derived) | plumbing |
| android/app/build.gradle.kts:33-35 | `buildTypes { debug { applicationIdSuffix = ".debug" } }` | Android/build | keep | `.debug` | Enables debug/release coexistence; keep as-is |
| android/app/build.gradle.kts:37-40 | `release { signingConfig = signingConfigs.getByName("debug") }` | Android/signing | **yes** | real release keystore + `key.properties` storeFile/keyAlias/… | **Release builds are debug-signed.** There is no `signingConfigs` block and no `key.properties` reference anywhere; android/.gitignore:12 anticipates `key.properties` but it does not exist. Consequence: signature varies per build machine → a new release cannot upgrade a previously installed copy; Play submission impossible. |
| android/app/src/main/kotlin/com/example/playtorrio/MainActivity.kt:1 | `package com.example.playtorrio` | Android/src | yes | matching new namespace | Package declaration + containing directory path both change (`.../kotlin/<vendor>/<name>/MainActivity.kt`) |
| MainActivity.kt:12 | `private val CHANNEL = "com.example.playtorrio/power"` | Android/src | yes | `<newId>/power` | Dart-side MethodChannel name must match; consumer file is in `lib/**` **[UNVERIFIED]** which file |
| MainActivity.kt:31 | `createWifiLock(lockMode, "playtorrio:stream_wifi")` | Android/src | optional | `<brand>:stream_wifi` | OS log tag only; no data impact |
| MainActivity.kt:42 | `newWakeLock(PARTIAL_WAKE_LOCK, "playtorrio:stream_wake")` | Android/src | optional | `<brand>:stream_wake` | OS log tag only |
| — | no `MainApplication` class exists | Android/src | keep | — | Only `MainActivity.kt`; glob of android/app/src/** confirms |
| android/app/src/debug/AndroidManifest.xml:1-6; android/app/src/profile/AndroidManifest.xml:1-6 | only `<uses-permission INTERNET>` | Android/manifest | keep | — | No brand strings |
| android/local.properties:4-5 | `flutter.versionName=1.1.5`, `flutter.versionCode=2018` | Android/generated | keep (do not edit) | regenerated | gitignored (android/.gitignore:6) |

### 1.2 Android — manifest components, TV/leanback, intents, providers

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| android/app/src/main/AndroidManifest.xml:29 | `android:label="playtorrio"` | Android/manifest | yes | new display name (e.g. `PlayTorrioZero` or chosen brand) | User-visible launcher + TV label. Hardcoded — there is NO `res/values/strings.xml` (res/values contains only styles.xml). |
| AndroidManifest.xml:30 | `android:name="${applicationName}"` | Android/manifest | keep | — | resolved from Gradle |
| AndroidManifest.xml:33 | `android:icon="@mipmap/ic_launcher"` | Android/manifest | optional | keep / new art | mipmap-* PNGs under res/ |
| AndroidManifest.xml:34-42 | activity `.MainActivity` `exported=true` `launchMode=singleTop` `taskAffinity=""` | Android/manifest | keep | — | `.MainActivity` is relative → follows namespace automatically |
| AndroidManifest.xml:51-54 | `<action MAIN/><category LAUNCHER/>` | Android/manifest | keep | — | Phone launcher entry |
| AndroidManifest.xml:55-58 | `<action MAIN/><category LEANBACK_LAUNCHER/>` | Android/manifest | **keep (critical)** | — | **Android TV launcher visibility.** Removing/altering drops the app from the TV home screen. No `<uses-feature android.software.leanback>` and no `android:banner` declared. |
| AndroidManifest.xml:33 + (absent) `android:banner` | — | Android/manifest | optional | add `android:banner="@drawable/tv_banner"` + asset | Without a banner the leanback launcher falls back to the app icon (still works). Only needed if TV art polish is desired. |
| AndroidManifest.xml:62-70 | `<provider sk.fourq.otaupdate.OtaUpdateFileProvider android:authorities="${applicationId}.ota_update_provider">` | Android/manifest | keep (auto-derives) | — | Authority changes automatically with applicationId; no literal to edit |
| AndroidManifest.xml:64 | `android:authorities="${applicationId}.ota_update_provider"` | Android/manifest | keep | — | OTA self-update provider |
| AndroidManifest.xml:72-76 | `<receiver sk.fourq.otaupdate.InstallResultReceiver>` action `${applicationId}.ACTION_INSTALL_COMPLETE` | Android/manifest | keep (auto-derives) | — | |
| AndroidManifest.xml:17-26 | `<queries>` VIEW https/http | Android/manifest | keep | — | Android 11+ package visibility |
| AndroidManifest.xml:89-94 | `<queries>` PROCESS_TEXT text/plain | Android/manifest | keep | — | Flutter engine |
| android/app/src/main/res/xml/filepaths.xml:3 | `<files-path name="internal_apk_storage" path="ota_update/"/>` | Android/res | keep | — | No brand; feeds OTA provider |
| — | no deep-link `<intent-filter>` with scheme/host | Android/manifest | keep (absence) | — | No custom-scheme deep links exist to rename |
| — | no permission or feature names the app | Android/manifest | keep | — | permissions are all generic |

### 1.3 Windows — CMake / RC / window / manifest

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| windows/CMakeLists.txt:3 | `project(playtorrio LANGUAGES CXX)` | Windows/build | yes | `<name>` | CMake project name |
| windows/CMakeLists.txt:7 | `set(BINARY_NAME "playtorrio")` | Windows/build | yes | `<name>` | Drives `playtorrio.exe`; must stay in sync with Runner.rc:97 and installer MyAppExeName |
| windows/runner/Runner.rc:92 | `VALUE "CompanyName", "com.example"` | Windows/versioninfo | **yes (critical for data)** | `<Vendor>` (new company) | **Path component**: path_provider_windows builds `%APPDATA%\Roaming\<CompanyName>\<ProductName>` (path_provider_windows-2.3.0/lib/src/path_provider_windows_real.dart:180-214) |
| windows/runner/Runner.rc:93 | `VALUE "FileDescription", "playtorrio"` | Windows/versioninfo | yes | `<name>` | Taskbar/Explorer description |
| windows/runner/Runner.rc:95 | `VALUE "InternalName", "playtorrio"` | Windows/versioninfo | yes | `<name>` | |
| windows/runner/Runner.rc:96 | `VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved."` | Windows/versioninfo | yes | new owner copyright; **keep the GPL notice** (upstream attribution lives in LICENSE/About, not here) | decide-in-plan for wording |
| windows/runner/Runner.rc:97 | `VALUE "OriginalFilename", "playtorrio.exe"` | Windows/versioninfo | yes | `<name>.exe` | MUST equal `BINARY_NAME` value |
| windows/runner/Runner.rc:98 | `VALUE "ProductName", "playtorrio"` | Windows/versioninfo | **yes (critical for data)** | `<name>` | **Path component** of `%APPDATA%\Roaming\<Company>\<Product>` (same source) |
| windows/runner/Runner.rc:63-66,69-72 | VERSION_AS_NUMBER fallback `1,1,5,16`; VERSION_AS_STRING `"1.1.5"` | Windows/versioninfo | keep | (derived from FLUTTER_VERSION*) | plumbing §1.10 |
| windows/runner/main.cpp:49 | `window.Create(L"playtorrio", origin, size)` | Windows/runner | yes | `<name>` | Native window title (before Flutter draws) |
| windows/runner/resources/app_icon.ico | icon resource | Windows/assets | optional | new art | Referenced by Runner.rc:47 (`IDI_APP_ICON`) and installer SetupIconFile |
| windows/runner/runner.exe.manifest | DPI + supportedOS only, no brand | Windows/manifest | keep | — | No app name |
| — | no `appxmanifest` / MSIX packaging | Windows | keep (absence) | — | Not used |
| — | no `AppUserModelID` / no single-instance `mutex` | Windows | keep (absence) | — | Absence is fine; default AUMID derives from exe path, so taskbar pin/notification grouping follows the exe rename |
| windows/runner/CMakeLists.txt:24-28 | FLUTTER_VERSION* compile defs | Windows/build | keep | — | plumbing |
| windows/runner/resource.h:6 | `#define IDI_APP_ICON 101` | Windows/build | keep | — | |

### 1.4 Linux

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| linux/CMakeLists.txt:7 | `set(BINARY_NAME "playtorrio")` | Linux/build | yes | `<name>` | Executable name; CI AppRun `exec ./playtorrio` (build.yml:195) consumes it |
| linux/CMakeLists.txt:10 | `set(APPLICATION_ID "com.example.playtorrio")` | Linux/build | yes | `com.<vendor>.<name>` | GTK application id; passed via `-DAPPLICATION_ID` (linux/runner/CMakeLists.txt:20) to `g_set_prgname` / `application-id` (my_application.cc:145-148) |
| linux/runner/my_application.cc:48 | `gtk_header_bar_set_title(header_bar, "playtorrio")` | Linux/runner | yes | `<name>` | Window title (GNOME) |
| linux/runner/my_application.cc:52 | `gtk_window_set_title(window, "playtorrio")` | Linux/runner | yes | `<name>` | Window title (non-GNOME) |
| linux/runner/main.cc:1-5 | no brand | Linux/runner | keep | — | |
| — | no `.desktop` file in repo | Linux | keep (absence) | — | Generated only inside CI (build.yml:186-193) |
| linux/CMakeLists.txt:7 | BINARY_NAME (exe) | Linux/build | yes | `<name>` | AppImage `AppRun` must exec the new name |

### 1.5 macOS

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| macos/Runner/Configs/AppInfo.xcconfig:8 | `PRODUCT_NAME = playtorrio` | macOS/build | yes | `<name>` | Produces `playtorrio.app`; **CI `mv playtorrio.app PlayTorrio.app` depends on it** |
| macos/Runner/Configs/AppInfo.xcconfig:11 | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio` | macOS/build | yes | `com.<vendor>.<name>` | Bundle id |
| macos/Runner/Configs/AppInfo.xcconfig:14 | `PRODUCT_COPYRIGHT = Copyright © 2026 com.example. All rights reserved.` | macOS/build | yes | new owner | |
| macos/Runner.xcodeproj/project.pbxproj:67,134,220 | `playtorrio.app` product refs | macOS/xcode | yes | `<name>.app` | Xcode product name follows PRODUCT_NAME; references regenerated by Xcode |
| macos/Runner.xcodeproj/project.pbxproj:388,402,416 | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio.RunnerTests` | macOS/xcode | yes | `<newId>.RunnerTests` | Test bundle |
| macos/Runner.xcodeproj/project.pbxproj:391,405,419 | `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/playtorrio.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/playtorrio"` | macOS/xcode | yes | `<name>.app/.../<name>` | Test host path |
| macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme:18,34,69,86 | `BuildableName = "playtorrio.app"` | macOS/xcode | yes | `<name>.app` | Committed scheme |
| macos/Runner/Info.plist:22-23 | `CFBundleName = $(PRODUCT_NAME)` | macOS/plist | keep | (derived) | macOS plist has **no** `CFBundleDisplayName` |
| macos/Runner/Configs/Debug.xcconfig / Release.xcconfig / Warnings.xcconfig | no brand matches | macOS/config | keep | — | verified by grep (empty) |
| macos/Runner/MainFlutterWindow.swift | no brand | macOS/runner | keep | — | |
| macos/Runner/Assets.xcassets/AppIcon.appiconset/* + Contents.json | icon art | macOS/assets | optional | new art | |

### 1.6 iOS

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| ios/Runner/Info.plist:13 | `<string>PlayTorrio streams video and audio from local network services and torrent streaming engines.</string>` | iOS/plist | yes | new brand, keep meaning | User-visible local-network permission string |
| ios/Runner/Info.plist:25 | `CFBundleDisplayName = Playtorrio` | iOS/plist | yes | new display name | Home-screen label |
| ios/Runner/Info.plist:33 | `CFBundleName = playtorrio` | iOS/plist | yes | new name | |
| ios/Runner.xcodeproj/project.pbxproj:375,554,576 | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio` | iOS/xcode | yes | `com.<vendor>.<name>` | App bundle id |
| ios/Runner.xcodeproj/project.pbxproj:391,408,423 | `PRODUCT_BUNDLE_IDENTIFIER = com.example.playtorrio.RunnerTests` | iOS/xcode | yes | `<newId>.RunnerTests` | Test bundle |
| — | app target `PRODUCT_NAME = $(TARGET_NAME)` → `Runner.app` (pbxproj:376,555,577) | iOS/xcode | keep | — | **iOS binary stays `Runner.app`**; only bundle id + display name are branding. CI copies `Runner.app` (build.yml:373) — do NOT rename unless PRODUCT_NAME is overridden. |
| — | `TEST_HOST = $(BUILT_PRODUCTS_DIR)/Runner.app/.../Runner` (pbxproj:411,426) | iOS/xcode | keep | — | Consistent with Runner.app |
| ios/Runner/AppDelegate.swift / SceneDelegate.swift / LaunchScreen.storyboard | no brand | iOS/runner | keep | — | |
| ios/Runner/Assets.xcassets/AppIcon.appiconset/* | icon art | iOS/assets | optional | new art | |

### 1.7 Windows installer — installer/windows/setup.iss

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| installer/windows/setup.iss:2 | `;  PlayTorrio — Windows Installer (Inno Setup 6)` | Installer/comment | optional | new brand | |
| setup.iss:6 | `#define MyAppName "PlayTorrio"` | Installer | yes | new display name | Drives AppName, DefaultDirName, DefaultGroupName, shortcuts |
| setup.iss:8 | `#define MyAppVersion "1.1.5"` (inside `#ifndef`) | Installer/version | yes | keep, or new-brand version | CI overrides via `/DMyAppVersion` (build.yml:92) |
| setup.iss:10 | `#define MyAppPublisher "ayman708-UX"` | Installer | yes | new publisher (or retain upstream credit) | decide-in-plan |
| setup.iss:11 | `#define MyAppExeName "playtorrio.exe"` | Installer | yes | `<name>.exe` | MUST equal Windows `BINARY_NAME` |
| setup.iss:12 | `#define MyAppURL "https://github.com/ayman708-UX/PlayTorrioV3"` | Installer | yes | new repo URL (keep upstream credit in About/LICENSE) | decide-in-plan |
| setup.iss:15 | `AppId={{9B8C7D6E-5F4E-3D2C-1B0A-9F8E7D6C5B4A}` | Installer | **keep (critical)** | unchanged | Inno upgrade/uninstall continuity: changing it forks a second install + orphaned uninstall entry |
| setup.iss:19 | `AppPublisherURL={#MyAppURL}` | Installer | yes | new URL | |
| setup.iss:20 | `AppSupportURL={#MyAppURL}` | Installer | yes | new URL | |
| setup.iss:21 | `DefaultDirName={autopf}\{#MyAppName}` | Installer | yes (derived) | — | Changing MyAppName changes install dir; with same AppId an existing install may leave stale files in old dir |
| setup.iss:22 | `DefaultGroupName={#MyAppName}` | Installer | yes (derived) | — | Start-menu group |
| setup.iss:23 | `UninstallDisplayIcon={app}\{#MyAppExeName}` | Installer | yes (derived) | — | |
| setup.iss:24 | `SetupIconFile=..\..\windows\runner\resources\app_icon.ico` | Installer | keep | — | Path, not name |
| setup.iss:26 | `OutputBaseFilename=PlayTorrio-Windows-Setup` | Installer | yes | `<Brand>-Windows-Setup` | **CI consumes this exact filename** (build.yml:97-101,114) — must rename consistently |
| setup.iss:38 | `[Tasks] desktopicon` | Installer | keep | — | No brand |
| setup.iss:41 | `[Files] Source: "..\..\build\windows\x64\runner\Release\*"` | Installer | keep | — | No brand |
| setup.iss:45-46 | `[InstallDelete] {app}\data\flutter_assets\*`, `{app}\*.dll.old` | Installer | keep | — | No brand |
| setup.iss:49-50 | `[Icons] Name:"{group}\{#MyAppName}"`, `{userdesktop}\{#MyAppName}` | Installer | yes (derived) | — | Shortcut names follow MyAppName |
| setup.iss:53 | `[Run] Filename:"{app}\{#MyAppExeName}"` | Installer | keep (derived) | — | Post-install launch |
| — | no `[Registry]`/`Uninstall\` keys authored; no file associations | Installer | keep (absence) | — | Inno auto-generates uninstall registry from AppId |

### 1.8 CI — .github/workflows/build.yml

| path:line | current value (verbatim) | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| .github/workflows/build.yml:2 | `#  PlayTorrioV3 — Multi-Platform CI/CD Release Builder` | CI/comment | optional | new brand | |
| build.yml:12 | `name: Build and Release PlayTorrioV3` | CI/workflow name | yes | `Build and Release <Brand>` | |
| build.yml:16 | `tags: ['v*']` | CI/trigger | keep | `v*` | Tag pattern unchanged; release tag feeds version |
| build.yml:27 | `name: Windows (Installer & Portable)` | CI/job name | optional | — | Job names are cosmetic |
| build.yml:69 | fallback `$cleanVersion = "1.1.5"` | CI/version | yes | new-brand baseline | Passed to Inno as MyAppVersion |
| build.yml:92 | `/DMyAppVersion=$cleanVersion installer\windows\setup.iss` | CI/version | keep | — | |
| build.yml:97-101 | checks/copies `installer\windows\Output\PlayTorrio-Windows-Setup.exe` → `\PlayTorrio-Windows-Setup.exe` | CI/Windows | yes | match setup.iss:26 exactly | **Cross-file consistency** (installer output ↔ CI) |
| build.yml:107 | `Compress-Archive ... "PlayTorrio-Windows-x64-Portable.zip"` | CI/Windows | yes | `<Brand>-Windows-x64-Portable.zip` | Artifact filename |
| build.yml:112 | `name: PlayTorrioV3-Windows` (upload-artifact) | CI/artifact | yes | `<Brand>-Windows` | |
| build.yml:114-115 | `PlayTorrio-Windows-Setup.exe`, `PlayTorrio-Windows-x64-Portable.zip` | CI/artifact paths | yes | match :97/:107 | |
| build.yml:119 | `name: Linux x64 (AppImage & Tar)` | CI/job name | optional | — | |
| build.yml:174 | `APP=PlayTorrio.AppDir` | CI/Linux | yes | `<Brand>.AppDir` | |
| build.yml:179,181,183 | `$APP/PlayTorrio.png` | CI/Linux | yes | `<Brand>.png` | |
| build.yml:186 | `cat <<EOF > "$APP/PlayTorrio.desktop"` | CI/Linux | yes | `<Brand>.desktop` | |
| build.yml:188 | `Name=PlayTorrio` | CI/Linux desktop | yes | `<Brand>` | `.desktop` display name |
| build.yml:190 | `Icon=PlayTorrio` | CI/Linux desktop | yes | `<Brand>` | Must match the `.png` basename (build.yml:179) and AppImage naming |
| build.yml:195 | `exec ./playtorrio "$@"` | CI/Linux AppRun | yes | `exec ./<name>` | MUST match linux `BINARY_NAME` (linux/CMakeLists.txt:7) |
| build.yml:198 | `... PlayTorrio-Linux-x86_64.AppImage` | CI/Linux | yes | `<Brand>-Linux-x86_64.AppImage` | |
| build.yml:199 | `tar -czvf PlayTorrio-Linux-x86_64.tar.gz ...` | CI/Linux | yes | `<Brand>-Linux-x86_64.tar.gz` | |
| build.yml:204 | `name: PlayTorrioV3-Linux-x64` | CI/artifact | yes | `<Brand>-Linux-x64` | |
| build.yml:206-207 | `PlayTorrio-Linux-x86_64.AppImage`, `...tar.gz` | CI/artifact paths | yes | match :198-199 | |
| build.yml:211 | `name: macOS (Apple Silicon ARM64)` | CI/job name | optional | — | |
| build.yml:250 | `mv playtorrio.app PlayTorrio.app` | CI/macOS | **yes** | `mv <name>.app <Brand>.app` | **Depends on macOS PRODUCT_NAME** (AppInfo.xcconfig:8) |
| build.yml:252,255 | `codesign ... PlayTorrio.app`, `cp -R PlayTorrio.app dmg_temp/` | CI/macOS | yes | `<Brand>.app` | consistency with :250 |
| build.yml:262 | `hdiutil ... -volname "PlayTorrio" ... PlayTorrio-macOS-arm64.dmg` | CI/macOS | yes | `<Brand>` / `<Brand>-macOS-arm64.dmg` | |
| build.yml:264 | `zip -ry ../../../../../PlayTorrio-macOS-arm64.zip PlayTorrio.app` | CI/macOS | yes | match :262 | |
| build.yml:269 | `name: PlayTorrioV3-macOS-arm64` | CI/artifact | yes | `<Brand>-macOS-arm64` | |
| build.yml:271-272 | `PlayTorrio-macOS-arm64.dmg/.zip` | CI/artifact paths | yes | match | |
| build.yml:276 | `name: macOS (Intel x86_64)` | CI/job name | optional | — | |
| build.yml:313,315,318,325,327 | intel equivalents (`mv playtorrio.app PlayTorrio.app`, `-volname "PlayTorrio"`, `PlayTorrio-macOS-intel.*`) | CI/macOS | yes | same as arm64 | |
| build.yml:332 | `name: PlayTorrioV3-macOS-intel` | CI/artifact | yes | `<Brand>-macOS-intel` | |
| build.yml:334-335 | `PlayTorrio-macOS-intel.dmg/.zip` | CI/artifact paths | yes | match :325/:327 | |
| build.yml:339 | `name: iOS (IPA)` | CI/job name | optional | — | |
| build.yml:373 | `cp -R Runner.app Payload/` | CI/iOS | keep | `Runner.app` | iOS app target product name is Runner — only change if PRODUCT_NAME is overridden |
| build.yml:374 | `zip -ry ../../../PlayTorrio-iOS.ipa Payload` | CI/iOS | yes | `<Brand>-iOS.ipa` | |
| build.yml:379 | `name: PlayTorrioV3-iOS` | CI/artifact | yes | `<Brand>-iOS` | |
| build.yml:380 | `path: PlayTorrio-iOS.ipa` | CI/artifact path | yes | match :374 | |
| build.yml:384 | `name: Publish GitHub Release` | CI/job name | optional | — | |
| build.yml:399 | `name: "PlayTorrio ${{ github.ref_name }}"` | CI/release | yes | `<Brand> ${{ github.ref_name }}` | Release title |
| build.yml:402-409 | release `files:` globs `*.exe *.zip *.apk *.AppImage *.tar.gz *.dmg *.ipa` | CI/release | keep | — | Glob-only, no brand literals |

### 1.9 versionName / versionCode plumbing

| path:line | current value | layer/category | must-change | recommended target | risk/notes |
|---|---|---|---|---|---|
| pubspec.yaml:21 | `version: 1.1.5+2018` | version/source-of-truth | yes (for rebrand) | `1.1.5+2018` keep, or `<newBrandVersion>+<code>` | Single source for Android/Windows/macOS/iOS |
| android/app/build.gradle.kts:29-30 | `versionCode = flutter.versionCode`, `versionName = flutter.versionName` | version/Android | keep | derived | |
| android/local.properties:4-5 | `flutter.versionName=1.1.5`, `flutter.versionCode=2018` | version/generated | keep | regenerated on `flutter pub get`/build | gitignored |
| windows/runner/CMakeLists.txt:24-28 | `FLUTTER_VERSION*` compile defs | version/Windows | keep | derived | from windows/flutter/ephemeral/generated_config.cmake:5-6 |
| windows/runner/Runner.rc:63-72 | VERSION_AS_NUMBER/STRING fallbacks `1,1,5,16` / `"1.1.5"` | version/Windows | optional | update fallback if desired | Only used when FLUTTER_VERSION* undefined |
| macos/Flutter/ephemeral/Flutter-Generated.xcconfig:7 | `FLUTTER_BUILD_NAME=1.1.5` | version/generated | keep | regenerated | gitignored (macos/.gitignore:2) |
| ios/Flutter/Generated.xcconfig:8-9 | `FLUTTER_BUILD_NAME=1.1.5`, `FLUTTER_BUILD_NUMBER=2018` | version/generated | keep | regenerated | gitignored (ios/.gitignore:21) |
| installer/windows/setup.iss:8 | `#define MyAppVersion "1.1.5"` default | version/installer | yes | new baseline or keep | CI passes `/DMyAppVersion` |
| .github/workflows/build.yml:68-69 | cleanVersion from tag, fallback `"1.1.5"` | version/CI | yes | new baseline | |

### 1.10 Generated / do-not-edit (regenerated by `flutter pub get`/build; not renamed by hand)

| path | why excluded |
|---|---|
| android/local.properties | gitignored (android/.gitignore:6); holds `flutter.versionName/Code` |
| android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java | gitignored (android/.gitignore:7); plugin classes only |
| windows/flutter/ephemeral/generated_config.cmake | gitignored (windows/.gitignore:1); contains repo path `PlayTorrioZero` (project dir), not app identity |
| windows/flutter/generated_plugin_registrant.cc / generated_plugins.cmake | generated; plugin list only |
| linux/flutter/generated_plugin_registrant.cc / generated_plugins.cmake | generated; plugin list only |
| macos/Flutter/GeneratedPluginRegistrant.swift, macos/Flutter/ephemeral/* | generated |
| ios/Flutter/Generated.xcconfig, ios/Flutter/ephemeral/*, ios/Runner/GeneratedPluginRegistrant.* | generated |
| windows/flutter/ephemeral/cpp_client_wrapper/** | vendored engine wrapper (contains the word "example" only inside English prose comments) |

---

## 2. Migration & compatibility notes

### 2.1 Saved-state / data-path migration — HIGHEST RISK

Every path below is derived from an identity we are proposing to change. Evidence for the platform derivations was read from the resolved pub cache (absolute paths).

| # | runtime path (current) | derived from (evidence) | holds user data? | effect of rename / risk if not migrated |
|---|---|---|---|---|
| A | **`%APPDATA%\Roaming\com.example\playtorrio\`** (Windows app-support root) | Runner.rc:92 `CompanyName="com.example"` + Runner.rc:98 `ProductName="playtorrio"` → path_provider_windows `_createApplicationSubdirectory(RoamingAppData)` (path_provider_windows-2.3.0/lib/src/path_provider_windows_real.dart:119-120, 180-214) | **YES** | Renaming CompanyName and/or ProductName relocates the whole root. New dir = `%APPDATA%\Roaming\<newCompany>\<newProduct>`. Without copy, the app starts with an **empty** support dir. |
| B | `%APPDATA%\Roaming\com.example\playtorrio\torrserver_data\config.db` (+ torrent cache, `torrserver.pid`) | #A + torrserver_flutter-0.0.6/lib/src/torrserver_controller_subprocess.dart:440-447 (`getApplicationSupportDirectory()/torrserver_data`); `config.db` lock mentioned :406; `-d <dataDir>` arg :74-75 | **YES** | Torrent DB / settings / cached torrents lost on rename. Requires one-time copy of `torrserver_data\` old→new. |
| C | `%APPDATA%\Roaming\com.example\playtorrio\shaders\anime4k` and `...\fonts` | #A + lib/services/player/player_settings.dart:254, 333 (`getApplicationSupportDirectory()`) | partly (downloaded caches) | Lost → re-downloaded on demand; still a migration nicety. |
| D | `%USERPROFILE%\Documents\PlayTorrio\{Books,Music\{Tracks,Covers},CustomAudiobooks,AudiobookCovers,GeneratedAudiobooks}` | hardcoded `'PlayTorrio'` folder literals in lib/services (book_download_service.dart:24, music_download_service.dart:80, custom_audiobook_service.dart:134, epub_cover.dart:25, paper2audio_service.dart:302) over `getApplicationDocumentsDirectory()` (Windows = user Documents folder) | **YES** | These live in the *user's* Documents, NOT the app-support sandbox, so a rename of the literal abandons them. Must copy `Documents\PlayTorrio` → `Documents\<NewBrand>` (or keep the literal). |
| E | `%USERPROFILE%\Documents\playtorrio_download_tasks.json` | lib/services/download/download_service.dart:51,55 (`getApplicationDocumentsDirectory()` + filename) | **YES** (download task list) | Renaming the file loses resumable task history (media files on disk remain). |
| F | Windows `...\Downloads\PlayTorrio`; Android `/storage/emulated/0/Download/PlayTorrio` and `<external>/PlayTorrio` | lib/utils/download/download_path_helper.dart:56, 63, 75 (hardcoded `'PlayTorrio'`) | **YES** (downloaded media) | User-visible download folder; renaming orphans previously downloaded media. |
| G | **Android private root `/data/user/0/com.example.playtorrio/`** → `.../files` (app support) and `.../app_flutter` (documents) | `applicationId` (build.gradle.kts:24). path_provider_android-2.3.1/lib/src/path_provider_android_real.dart:28-32 (`getApplicationSupportPath` = `context.filesDir`), :36-45 (`getApplicationDocumentsPath` = `getDir("flutter")`) | **YES** | Changing `applicationId` repoints the ENTIRE private tree. The old package's data is not readable by the new package (no root), so **no in-app migration is possible** — data is effectively lost. This is the strongest reason to **keep `applicationId = com.example.playtorrio`** and change only `android:label`. |
| H | Android `.../files/torrserver_data/` (+ `config.db`, `torrserver.pid`) | #G + torrserver_controller_subprocess.dart:440-447 (Android factory uses the subprocess controller per torrserver_flutter.dart:15-22) | **YES** | Same as #G: lost with applicationId change. |
| I | Android SharedPreferences dir `/data/user/0/<applicationId>/shared_prefs` | package name (SharedPreferences/`shared_preferences_android`) | **YES** | Setting flags incl. `playtorrio_p2p_source_enabled`, reader settings, etc. Lost with applicationId change. On Windows, shared_preferences_windows stores under app-support (#A) → also moves. |
| J | Windows cache root `%LOCALAPPDATA%\com.example\playtorrio\` | Runner.rc:92/98 → path_provider_windows_real.dart:127-128 (`getApplicationCachePath`) | no (transient) | Safe to relocate; no migration needed. Also temp dirs via `getTemporaryDirectory()` (subtitle_extractor.dart:46, wyzie_provider.dart:175). |
| K | macOS `~/Library/Application Support/playtorrio` | macOS `PRODUCT_NAME` (AppInfo.xcconfig:8) → path_provider_macos | YES if used | Changes with PRODUCT_NAME; migrate old→new on first run. [UNVERIFIED] exact macOS support-dir name/subdir consumption (lib-owned). |
| L | Linux `$XDG_DATA_HOME/<id>` (typically `~/.local/share/<APPLICATION_ID>`) | linux/CMakeLists.txt:10 APPLICATION_ID → path_provider_linux/getApplicationSupportDirectory | YES if used | Relocates with APPLICATION_ID. [UNVERIFIED] exact path_provider_linux derivation — not read. |

**Where migration must happen:** in the Dart bootstrap (`lib/main.dart`, owned by another agent) *before* the first `path_provider` call / plugin init that reads these dirs — i.e. a one-time “if old dir exists and new dir doesn’t → copy recursively (or rename)” step, guarded by a completion flag written into the new location. This recon only states the requirement and the old→new path shapes:
- A/B/C (Windows support): `%APPDATA%\Roaming\com.example\playtorrio` → `%APPDATA%\Roaming\<newCompany>\<newProduct>`.
- D/E/F (user-visible): `Documents\PlayTorrio` → `Documents\<NewBrand>`; `playtorrio_download_tasks.json` → `<newbrand>_download_tasks.json` (or keep both literals to avoid migration entirely).
- G/H/I (Android): **not migratable in-app** — keep `applicationId` (recommended), or accept data loss.

### 2.2 CI cross-file consistency constraints (rename together or the build/release breaks)

1. Inno `OutputBaseFilename` (setup.iss:26) ↔ CI existence check/copy (build.yml:97-101) ↔ artifact paths (build.yml:114).
2. Windows `BINARY_NAME` (windows/CMakeLists.txt:7) ↔ `OriginalFilename` (Runner.rc:97) ↔ installer `MyAppExeName` (setup.iss:11) ↔ portable-ZIP contents (build.yml:107).
3. macOS `PRODUCT_NAME` (AppInfo.xcconfig:8) ↔ CI `mv playtorrio.app PlayTorrio.app` (build.yml:250,313) ↔ pbxproj/scheme `playtorrio.app` refs.
4. Linux `BINARY_NAME` (linux/CMakeLists.txt:7) ↔ CI AppRun `exec ./playtorrio` (build.yml:195).
5. AppImage `.desktop` `Icon=PlayTorrio` (build.yml:190) ↔ copied `PlayTorrio.png` (build.yml:179/181/183).
6. CI job `needs: [windows, linux-x64, macos-arm64, macos-intel, ios]` (build.yml:385) — job **ids** may be kept; renaming job ids requires updating this list.

### 2.3 Android upgrade / coexistence

- `applicationId` is the coexistence + upgrade key. Changing it installs a brand-new app; the old `com.example.playtorrio` remains installed and its data is not inherited.
- Keeping `applicationId` and changing only `android:label` yields new branding on phone + TV with **no** data loss and in-place upgrades. Recommended default.
- `applicationIdSuffix = ".debug"` (build.gradle.kts:35) keeps debug/release companions distinct — preserve.
- Release is debug-signed (build.gradle.kts:40). Even within one applicationId, a debug keystore differs per machine, so cross-machine updates will fail signature verification. Fixing signing is a prerequisite for any distributable release regardless of rename.

### 2.4 Windows installer upgrade

- Keep `AppId` GUID (setup.iss:15) for uninstall/upgrade continuity. Changing `DefaultDirName` via `MyAppName` (setup.iss:21) with the same AppId can leave orphaned files in the old install dir — the `[InstallDelete]` block (setup.iss:45-46) only cleans `data\flutter_assets` and `*.dll.old`.
- `AppPublisher`, `AppPublisherURL`, `AppSupportURL` currently point at `ayman708-UX` / the upstream repo — update to the new owner, but retain upstream GPL attribution elsewhere (LICENSE/About).

### 2.5 Version-reset guidance (for the final doc)

- Single source is pubspec.yaml:21 `1.1.5+2018`.
- If `applicationId` is KEPT: Android will reject an update whose `versionCode` < 2018 — do **not** reset the version for the new brand; keep monotonic `versionCode`.
- If `applicationId` is CHANGED: version may reset freely (fresh package), e.g. `1.0.0+1`.
- Windows/macOS/iOS are unaffected by the reset decision technically, but should match the chosen brand baseline; Inno receives `/DMyAppVersion` from the git tag (build.yml:68-69,92), so tag naming drives the installer version.

---

## 3. Open questions / [UNVERIFIED]

- **Dart-side path logic** is out of scope here; the exact set of `getApplicationSupportDirectory`/`getApplicationDocumentsDirectory` consumers, the bootstrap migration point, and whether a migration flag already exists are **[UNVERIFIED]** (lib/**.md ownership).
- Which `lib/**` file consumes the `MainActivity` MethodChannel `"com.example.playtorrio/power"` (MainActivity.kt:12) — **[UNVERIFIED]**; must be renamed in lockstep if applicationId changes.
- `path_provider_linux` derivation of the support dir (XDG path + app id usage) — **[UNVERIFIED]** (not read).
- `path_provider_macos` exact support dir name and whether any macOS-only state is written — **[UNVERIFIED]**.
- Whether `android/app/src/main/res/values/strings.xml` should be introduced (currently absent; `android:label` is the only localized-looking surface and it is hardcoded at AndroidManifest.xml:29) — decide-in-plan.
- Whether an `android:banner` (TV) asset is desired — currently absent; not required for LEANBACK_LAUNCHER visibility.
- Final brand string(s), vendor/company name, publisher, and URL are **decide-in-plan**; every `recommended target` above is expressed as a shape where it depends on the chosen name.
- Confirm the chosen release name is not left as the upstream `PlayTorrioV3` in CI artifact names, which would collide with upstream releases.
